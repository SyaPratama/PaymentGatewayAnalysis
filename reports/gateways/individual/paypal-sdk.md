[← Master Report](../../payment-gateway-research.md) | [← Category D: Payment SDK Libraries](../D-payment-sdk-libraries.md)

---

# PayPal Server SDK — Deep-Dive Report

> Official server SDKs for PayPal v2 Checkout and Orders API.

---

## 1. Overview

PayPal maintains official server SDKs (`paypal-server-sdk-php`) for interacting with its modern v2 Orders, Payments, and Subscriptions REST APIs. Replacing the legacy PayPal-PHP-SDK, the modern library provides strongly-typed request builders, OAuth 2.0 token caching, webhook validation, and idempotency key propagation.

---

## 2. Key Features

- **Orders v2 API** — Create, authorize, and capture orders with buyer approval flows.
- **Vault & Subscriptions** — Save payment methods for recurring subscription billing.
- **Native Webhook Verification** — Validate PayPal signature headers using PayPal's public certificates.
- **Disputes & Refunds API** — Programmatically track customer disputes and issue full or partial refunds.

---

## 3. Pros & Cons

### Pros
1. Official first-party support backed by PayPal engineering
2. Automatic OAuth token lifecycle and credential management
3. Global acceptance across 200+ markets and 100+ currencies

### Cons
1. Single-vendor lock-in: supports only PayPal ecosystem
2. Higher merchant transaction fees compared to local payment aggregators
3. PayPal account review policies can disrupt cash flow for high-growth accounts

---

## 4. Links & Reference

- **GitHub Repository**: https://github.com/paypal/paypal-server-sdk-php
- **Documentation**: https://developer.paypal.com/docs/api/orders/v2/
