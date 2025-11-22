---
title: Loki and Grafana on Cloud Run
---

Telemetry is complicated. There's a lot left to learn, but I'm at a point where I can make sense of my application logs. That's a good start.

## Tooling

Loki and Grafana are telemetry tools developed by the same organisation. Loki ingests and processes application logs. Grafana visualises all sorts of telemetry data including logs. It also allows me to set up dashboards and alerts[^alert].

They help me answer one question:

> **Is my system behaving as it should right now?**[^more]

So how do we run these tools?

## Infrastructure

I have a simple project setup and I wanted a telemetry solution with as few moving parts as possible. Terraforming and maintaining Cloud infrastructure is cumbersome. The final solution looks a bit like this.

```
 ┌──────────────────────────────────────────────────────┐  
 │                    GCP perimeter                     │  
 │  ┌──────────────────────────┐                        │  
 │  │     Cloud Run service    │                        │  
 │  │            ┌─────────────┼─────────────┐          │  
 │  │   ┌────────┼─────────┐   │             │          │  
 │  │   │ Loki    (sidecar)◄─┐ │   ┌─────────▼────────┐ │  
 │  │   └────────▲─────────┘ │ │   │                  │ │  
 │  │            │           │ │   │  Storage bucket  │ │  
 │  │            │           │ │   │                  │ │  
 │  │   ┌────────▼─────────┐ │ │   └─────────▲────────┘ │  
 │  │   │ Grafana (sidecar)┼─┼─┼─────────────┘          │  
 │  │   └────────▲─────────┘ │ │                        │  
 │  │            │           │ │                        │  
 │  │            │           │ │                        │  
 │  │   ┌────────▼─────────┐ │ │                        │  
 │  │   │ nginx            ┼─┘ │                        │  
 │  │   └────────▲─────────┘   │                        │  
 │  │            │             │                        │  
 │  └────────────┼─────────────┘                        │  
 └───────────────┼──────────────────────────────────────┘  
                 ▼                                         
       Publically accessible                               
```

I have exactly two resources to think about here: A Cloud Run service and a storage bucket.

My application sends all its logs to nginx along with an API key. The request is forwarded to Loki, processed, and stored on GCS.

To *look* at telemetry, I open a different URL that also points to nginx. I get forwarded to the Grafana portal where I log in with my credentials. Grafana talks to Loki within the Cloud Run service and persists its dashboards and alert settings on GCS.

Clearly, multiple actors are involved. How is there only one service?

### Google Cloud Run sidecars

[As of recently](https://cloud.google.com/blog/products/serverless/cloud-run-now-supports-multi-container-deployments), GCP allows configuring up to ten containers per Cloud Run service. Only one container can be listening for external connections, but all other containers can freely communicate internally.

By making nginx my service's entry point, I can run Loki, Grafana, and up to seven other services with just a single piece of infrastructure! As a bonus, I get to put Loki's ingestion endpoint behind a basic auth layer.

This simplicity does come at a cost. I'm giving up scalability options, coupling containers to each other, and creating a single point of failure. But it's the right tradeoff for the current project size.

But wait. Why am I doing all this anyway?

## Avoiding vendor lock-in

The reason I started building new infrastructure at all is that I wanted to break free from Cloud vendor lock-in. GCP provides a decent telemetry experience out of the box - Cloud Run logs just work out of the box. But I don't want to get stuck in the Google ecosystem.

The [OpenTelemetry project](https://opentelemetry.io/) (OTel) tries to solve this problem by providing a suite of vendor-agnostic telemetry protocols. It's widely adopted in the industry and Loki is one of many tools that natively support ingesting OTel data over HTTP. On the application code side, most of the bigger language ecosystems have packages that allow the app to emit OTel data. 

It no longer matters where my app runs as long as it can reach OTel endpoints. 

Other than logs, is there anything else I might want to know about my system?

## Metrics and traces

Yes! There is more to telemetry than logs.

Metrics give insight into the overall health of the system and tend to be aggregated over time. For a web server, classic examples include the [four golden signals of SRE](https://sre.google/sre-book/monitoring-distributed-systems/) (latency, traffic, error rate, saturation). This is the kind of thing you'll want on your dashboards.

A trace links multiple related logs across service boundaries. Think about what happens when a user places an order in a retail system: we'll update user data, talk to an inventory system, initiate a payment process, create an invoice, and more.[^micro] It's useful to thread the new order ID throughout all relevant logs.


[^more]: Of course there's much more to it.
[^alert]: With the right alerting policies, you'll know if your system is down *before* your users do.
[^micro]: It may sound like this is only relevant for microservice architectures, but that's not the case. It doesn't matter if my inventory and payment services are separate deployments - I still want context across all the logs they emit.
