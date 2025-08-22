---
title: Delidding a 9000-series AMD Ryzen CPU
---

There are names that are impossible to miss in the CPU delidding community. Thermal Grizzly is one of them. They sell specialised tools for delidding[^delid] specific CPU model ranges.

[^delid]: Removing the so-called IHS (integrated heat spreader) from a CPU so that the die can be cooled directly. In our builds, this tends to result in 20° C temperature drops.

To get the lid off of my Intel i9-9900k a while ago, we used a Thermal Grizzly tool. It worked like a charm and made Thermal Grizzly the obvious choice when we decided to delid an AMD Ryzen 9950X.

They sell several great products. To delid an Intel, you insert your chip into the tool and tighten one screw. Off pops the lid. Their liquid metal is a top performer.

The AMD tool didn't work for us at all. You insert the AMD chip and slowly, _slowly_ loosen its lid by repeatedly tightening and loosening two screws on opposite ends of the contraption. This moves the IHS by a few millimetres at a time, back and forth.

If you poke around online forums, the tool is said to require some 50 rounds of back-and-forth for the IHS to come off. I'm not sure we got to that number, but after a few dozen repetitions, one of the screws _broke off_.

So now there's an expensive chip stuck in a _solid metal tool that was designed not to let go of the chip_. Great.

# Now what?

We did get the chip out eventually and went back to the IHS drawing board. I'm not sure how I came across [this clip](https://www.youtube.com/watch?v=BQ00B93w8hY), but I did, and it kind of looked promising. We're out of AMD delidding tools anyway.

![First, you use dental floss to cut through the glue that's under each "leg" ...](/assets/images/amd-floss.png)

![... then you apply enough heat to the IHS to melt the solder...](/assets/images/amd-iron.png)

![... and off comes the PCB!](/assets/images/amd-pcb.png)

The floss step was straightforward. Cutting through the glue on each leg took little force. Applying heat is the scary part. Intel's indium solder melts at around 160° C and I'll assume that's what we're going for here. I also don't have an iron, so a stove top and a pot will have to do. 

We considered spreading thermal paste onto the IHS before placing the chip into the pot, but apparently that's not needed: After a few minutes at moderate heat, we could simply pick up the PCB from the pot as though it had never been attached to the IHS. It was quite satisfying, and we'd never been so sure that we'd broken a CPU.

But no. As it turns out, it survived the procedure and it's happily computing now.
