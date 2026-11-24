[← Master Report](../../payment-gateway-research.md) | [← Category E: E-Commerce Platforms](../E-ecommerce-platforms.md)

---

# Saleor — Deep-Dive Report

> Enterprise-grade, headless GraphQL commerce platform with modular payment apps.

---

## 1. Overview

Saleor is a headless e-commerce platform built on Python, Django, and GraphQL. Designed for high-scale, multi-channel commerce, Saleor isolates payment processing into a modular App/Plugin architecture. It enables asynchronous payment authorization, automated capture triggers upon order fulfillment, and multi-currency payouts across international borders.

---

## 2. Key Features

- **GraphQL-First Architecture** — Unified GraphQL schema for checkout, authorization, capture, and refunds.
- **Saleor Apps Architecture** — Modern webhook-driven micro-apps for Stripe, Adyen, Braintree, and Klarna.
- **Multi-Warehouse & Multi-Channel** — Configure distinct payment gateways per currency, country, or sales channel.
- **Event-Driven Checkout** — Webhook delivery for `PAYMENT_AUTHORIZE`, `PAYMENT_CAPTURE`, `PAYMENT_REFUND`, `PAYMENT_VOID`.

---

## 3. Pros & Cons

### Pros
1. Clean, modern architecture with comprehensive GraphQL documentation
2. Decoupled apps architecture prevents third-party payment plugins from crashing core checkout
3. Permissive BSD-3 license allows unrestricted commercial modification

### Cons
1. Python/Django stack: cannot be directly embedded into a PHP/Laravel monolith
2. GraphQL-only API requires a learning curve if your team is standardizing on REST
3. Requires running multiple microservices (Django API, Celery workers, Redis, PostgreSQL)

---

## 4. Links & Reference

- **Official Website**: https://saleor.io
- **GitHub Repository**: https://github.com/saleor/saleor
- **Documentation**: https://docs.saleor.io
