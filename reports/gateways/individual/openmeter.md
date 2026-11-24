[← Master Report](../../payment-gateway-research.md) | [← Category C: Billing & Subscription Platforms](../C-billing-subscription-platforms.md)

---

# OpenMeter — Deep-Dive Report

> Cloud-native, real-time usage metering platform built on Apache Kafka and ClickHouse.

---

## 1. Overview

OpenMeter is an open-source, cloud-native usage metering platform designed to solve the high-throughput engineering challenge of ingesting, validating, deduplicating, and aggregating billable events in real time. Built in Go on top of Apache Kafka and ClickHouse, OpenMeter is engineered for modern AI platforms, cloud infrastructure providers, and high-volume API services that bill customers based on consumption (e.g., tokens processed, compute seconds, GBs transferred).

Rather than attempting to be a full accounting suite or invoicing engine, OpenMeter focuses exclusively on the metering layer, exposing real-time entitlement balances and pushing aggregated usage data directly into Stripe Billing or custom accounting ledgers.

---

## 2. Key Features

- **CloudEvents Standard** — Fully compliant with the CNCF CloudEvents JSON specification.
- **Sub-Millisecond Ingestion** — High-concurrency Go ingestion pipeline capable of accepting tens of thousands of events per second.
- **Real-Time Entitlement Checks** — Query customer balance and usage limits instantly to enforce API rate limits or feature gating.
- **Stripe Billing Integration** — Automatically synchronizes aggregated usage figures to Stripe subscription billing meters.
- **ClickHouse Analytics Core** — Ultra-fast windowed aggregations over billions of raw usage records with zero latency degradation.

---

## 3. Pros & Cons

### Pros
1. Purpose-built for extreme scale (AI token metering and streaming API platforms)
2. Permissive Apache-2.0 license: completely free for commercial infrastructure
3. Clean architectural separation: does metering exceptionally well without bloating into accounting

### Cons
1. Not a standalone checkout gateway: does not collect card payments or generate customer invoices
2. Requires significant infrastructure (Kubernetes, Apache Kafka, ClickHouse cluster)
3. Overkill for simple e-commerce or fixed-price subscription models

---

## 4. Links & Reference

- **Official Website**: https://openmeter.io
- **GitHub Repository**: https://github.com/openmeterio/openmeter
- **Documentation**: https://openmeter.io/docs
