[← Master Report](../../payment-gateway-research.md) | [← Category A: Payment Orchestrators](../A-payment-orchestrators.md)

---

# Hyperswitch Prism — Deep-Dive Report

> Lightweight single-connector payment proxy variant of Hyperswitch.

---

## 1. Overview

Hyperswitch Prism is a streamlined, single-connector deployment mode of the Hyperswitch payment orchestration platform. Designed for engineering teams that desire the high throughput, memory safety, and sub-millisecond execution of Rust without the operational complexity of managing multi-PSP routing engines, Apache Kafka clusters, and complex routing rules, Prism acts as a standardized, hardened proxy in front of a single payment provider.

It provides the same OpenAPI-compliant REST interface and standardized data structures as full Hyperswitch. This ensures that an application built on Prism can effortlessly upgrade to full multi-processor orchestration in the future with zero client code refactoring.

---

## 2. Architecture & Data Flow

```
┌────────────────────────────────────────────────────────┐
│                   Laravel Application                   │
│         Communicates via Unified Hyperswitch REST API   │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTP POST /payments
┌──────────────────────────▼─────────────────────────────┐
│                 Hyperswitch Prism Server               │
│                  (Standalone Rust Binary)              │
│                                                        │
│  ┌─────────────────────────┐  ┌─────────────────────┐  │
│  │ Unified API Normalizer  │  │ Webhook Forwarder   │  │
│  │ (Transforms Request)    │  │ (Signature Verifier)│  │
│  └────────────┬────────────┘  └──────────┬──────────┘  │
└───────────────┼──────────────────────────┼─────────────┘
                │                          │
                └─────────────┬────────────┘
                              │ Standardized Outbound Call
                              ▼
                     Target Processor (e.g., Stripe / Adyen)
```

1. **Client Call**: Laravel calls the local Prism instance with standard payment parameters.
2. **Proxy Translation**: Prism's typed Rust engine converts the payload into the exact format expected by the configured upstream gateway.
3. **Upstream Execution**: Prism executes the HTTP call upstream, records telemetry, and normalizes the response code.
4. **Normalized Webhook**: Upstream webhooks pass through Prism, where signatures are validated before being forwarded as clean, standardized JSON events to your Laravel endpoint.

---

## 3. Key Features

- **Single-Binary Footprint** — Runs as a self-contained Rust binary with minimal RAM requirements (<100MB).
- **Zero Kafka Dependency** — Strips away the distributed message bus required by multi-PSP Hyperswitch clusters.
- **Identical API Contract** — 100% compatible with Hyperswitch client SDKs and REST schemas.
- **Built-in Webhook Relay** — Validates incoming processor webhook signatures and forwards them safely to your internal network.
- **Seamless Upgrade Path** — Migrate to full Hyperswitch multi-routing simply by altering server deployment configuration.

---

## 4. Pricing & TCO Analysis

- **Software License**: Free (Apache-2.0).
- **Server Infrastructure**: ~$10–$25/month (standard single-container VPS or Docker service).
- **Operational Overhead**: Extremely low; does not require Kafka or Redis clustering.

---

## 5. Pros & Cons

### Pros
1. Rust performance and memory safety without enterprise infrastructure bloat
2. Clean separation between application business logic and processor-specific quirks
3. Perfect transitional architecture for companies planning to add multiple PSPs later

### Cons
1. Lacks dynamic multi-PSP routing (the flagship feature of full Hyperswitch)
2. Adds an extra internal network hop compared to calling the processor directly via an SDK
3. Smaller standalone documentation footprint than the main Hyperswitch repository

---

## 6. Links & Reference

- **GitHub Repository**: https://github.com/juspay/hyperswitch
- **Documentation**: https://docs.hyperswitch.io
