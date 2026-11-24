[← Master Report](../../payment-gateway-research.md) | [← Category B: Self-Hosted Crypto Gateways](../B-crypto-gateways.md)

---

# Globee (OSS Edition) — Deep-Dive Report

> PHP/Laravel reference implementation for cryptocurrency payment processing.

---

## 1. Overview

Globee OSS is an open-source PHP and Laravel reference implementation of a cryptocurrency payment processor. Originally developed alongside commercial digital asset payment platforms, Globee provides standard Eloquent models, controllers, and queue listeners for creating crypto invoices, locking exchange rates against fiat currencies, and handling Instant Payment Notifications (IPN).

---

## 2. Key Features

- **Laravel Native Architecture** — Implements standard Eloquent relationships, migrations, and service providers.
- **Fiat Rate Locking** — Locks fiat-to-crypto exchange rates for a configurable window (e.g., 15 minutes) during checkout.
- **IPN Callback Architecture** — Standardized HMAC-verified instant payment notifications.
- **Database Schema Reference** — Transparent relational database schema modeling crypto invoices, addresses, and transactions.

---

## 3. Pros & Cons

### Pros
1. 100% PHP/Laravel stack: instant familiarity for Laravel engineering teams
2. Clear code reference for building custom in-house crypto invoicing state machines
3. Permissive MIT license

### Cons
1. Infrequent upstream updates; requires updating dependencies for modern PHP 8.x compatibility
2. Does not include an embedded Lightning Network node
3. Still requires connection to external blockchain RPC providers

---

## 4. Links & Reference

- **GitHub Organization**: https://github.com/Globee-Official
- **License**: MIT
