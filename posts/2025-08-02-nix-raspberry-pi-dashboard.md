---
title: Service dashboards on a NixOS Raspberry Pi
---

We have a big, shared office. I want a big, shared screen in it, and I want our dashboards on it.

## Scope

We need a low-power device to run our web-based monitoring application on. I've decided on a third-generation Raspberry Pi for its availability and full-sized HDMI output. I'll put in one of my spare SD cards specifically designed for long-running devices. That's probably overkill.

The Pi shall be responsible for exactly one thing: displaying our payment monitoring dashboards. To get there, we'll cover a few topics of interest.

**Limit permissions**

Only authenticated users can access dashboards. That means we need new user credentials. The new user shall not be permitted to view anything but dashboards.

**Make hardware access useless**

Our office is a semi-public coworking space. Typically, one of us is in the room while the device is running. We might occasionally all leave the room or forget to turn the device off after work. If this happens, it should not be possible for a third party to extract sensitive information from the device or from the network.

Let's keep in mind that we *are* running a browser, so we can't reasonably prevent web browsing.

**Run a sensible OS**

A low-maintenance device that has one simple job is a *perfect* use case for NixOS. The promise is that we'll write a handful of Nix configuration files that are trivial to reason about, and out comes a fully prepared operating system with no further setup work required.

## Dashboard switching

Our team has multiple dashboards, but we don't want to put up multiple screens. Let's switch between them every minute or so.

... how *does* one periodically switch between websites though? There's *probably* a browser extension? We can go more lightweight and declarative than that.

I recently learned about the [Marionette protocol](https://firefox-source-docs.mozilla.org/testing/marionette/Protocol.html). After launching Firefox with it enabled, the browser will start listening for remote control commands over TCP on port 2828. We can send commands to navigate to certain pages, for example - sounds like what we need.

> Marionette is Firefox-specific, but the protocol and its commands largely follow the WebDriver API which we already know from testing frameworks like Selenium. Even if we don't know WebDriver yet, we can consult [Marionette source code](https://searchfox.org/mozilla-central/source/remote/marionette/driver.sys.mjs#3857) to learn about all supported commands. It's easy to read.

Let's write some bash.

We'll open Firefox with Marionette enabled and use `netcat` to send commands to the Marionette server. Specifically, we want to navigate to a certain page with a `Navigate` command. There are a few more peculiarities we have to watch out for:

- Before we can navigate, we need a session - this means sending a `NewSession` command
- The server expects additional metadata with each command - see the snippet below
- We encounter race conditions unless we `sleep` between commands - maybe this is on me

```bash
#! /usr/bin/env -S nix shell nixpkgs#firefox nixpkgs#netcat --command bash

firefox --marionette &

# We must send along a unique ID per command.
# Let's simply count up from 0.
COMMAND_COUNTER=0

command() {
  COMMAND_COUNTER=$(( $COMMAND_COUNTER + 1 ))
  command="[0,$COMMAND_COUNTER,\"$1\",$2]"
  
  # For each command we send, we must prepend
  # the character count of that command.
  echo -n "${#command}:$command"

  sleep 1
}

sleep 1

(
  command 'WebDriver:NewSession' '{}'
  command 'WebDriver:Navigate' '{"url":"https://example.com"}'
) | tee /dev/tty | nc localhost 2828
```

The `command` function merely enriches our command with the metadata the protocol expects. If we run this, we'll see Firefox open and immediately navigate to `https://example.com`.

Let's try opening multiple websites:

```bash
cycle() {
  while true
  do
    command 'WebDriver:Navigate' '{"url":"https://beispiel.de"}'
    sleep 5
    command 'WebDriver:Navigate' '{"url":"https://example.com"}'
    sleep 5
  done
}

(
  command 'WebDriver:NewSession' '{}'
  cycle
) | tee /dev/tty | nc localhost 2828
```

Just like that, we're cycling between pages. How cool is that, and could it take any less code?[^1] [^2]

Marionette supports many more commands. For our simple use case, this is all we need.

## Running one program on startup

The script above opens a browser and cycles between our dashboards (or example URLs, in this case). How do we automatically run the script when the Pi is turned on?

The idea of running a singular, isolated, full-screen program right after starting up is not new. We're describing *kiosk software*. [Wikipedia](https://en.wikipedia.org/wiki/Kiosk_software) defines it as such (shortened):

> Kiosk software prevents user interaction outside the scope of execution of the software.

We'll use [cage](https://github.com/cage-kiosk/cage/) this time around. *Once the system is up*[^3], all we have to do after is invoke `cage` with the script we wrote above. `cage` will take over the rest and turn our device into a kiosk. 

## Building an image

We still don't have an operating system for the Pi. Typically, Linux distributions provide an image that you can flash onto a thumb drive. We could download a copy of any distro, boot into it, and set it up from scratch.

A bit of `sudo apt-get install firefox` ...

... except, let's not do that. I've written some Nix code to create a purpose-built image instead. I know *exactly* what I'm getting upfront this way - no runtime configuration needed.

Here's a distilled version.[^4]

`flake.nix`:
```nix
{
  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; };
  outputs = { nixpkgs, ... }: {
  nixosConfigurations.nix-pi = nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    ./configuration.nix
    ];
  };
  };
}


```

`configuration.nix`:
```nix
{
  networking.hostName = "nix-pi";

  # Disallow SSH password auth
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Allow my user to connect via SSH so I can push updates
  users.users.root = {
    openssh.authorizedKeys.keys = [
      // …
    ];
    
    hashedPassword = "…";
  };

  # Run `cage` at startup  
  services.cage = {
    enable = true;
    program = pkgs.writeShellScript "cage-script" ''
      # Our script from above goes here
    '';
  }
}
```

Building this results in a ready-to-flash operating system image.

Given we're building a full OS image, you may be wondering if making updates to the system means building a new OS image every time and flashing it onto the Pi. It doesn't. After modifying the configuration, it takes mere seconds to rebuild the parts that have changed with `nixos-rebuild`. We can then push those updates directly to the device over the network.

We're done. Let's stare at some dashboards.

[^1]: The final script does a bit more than is visible here (like handling SIGINT correctly).
[^2]: The Nix shebang is great: we know that we need Firefox and Netcat for our script to work and we can make that explicit right in the first line. Nix then automatically fetches these dependencies.
[^3]: NixOS will take care of this for us because we asked it to enable `services.cage`. Under the hood, Nix creates a `systemd` unit for us. But we don't have to think about that at all.
[^4]: Some of the things I've omitted: trimming the amount of dependencies the default installation ships with, figuring out the cross-compilation setup, the correct CLI incantations to build the image, and glue code.
