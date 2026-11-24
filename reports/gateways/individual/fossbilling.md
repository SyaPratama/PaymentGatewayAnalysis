[← Master Report](../../payment-gateway-research.md) | [← Category C: Billing & Subscription Platforms](../C-billing-subscription-platforms.md)

---

# FOSSBilling — Deep-Dive Report

> Community-driven open-source billing and client management software for web agencies and hosting.

---

## 1. Overview

FOSSBilling is an open-source, community-led billing and client management application written in PHP. Created as a modernized, actively maintained fork of BoxBilling, FOSSBilling provides automated recurring invoicing, support ticketing, client self-service portals, and payment gateway adapters designed specifically for web hosting companies, digital agencies, and freelance developers.

---

## 2. Key Features

- **Turnkey Client Area** — Fully responsive, passwordless or authenticated portal for clients to pay invoices and manage accounts.
- **Pre-Configured Payment Adapters** — Built-in support for Stripe, PayPal, Mollie, 2Checkout, and bank wire transfers.
- **Automated Invoicing Engine** — Cron-driven automated recurring billing, PDF generation, and overdue payment notices.
- **Modular Architecture** — Simple hook and extension system for developing custom PHP modules.

---

## 3. Pros & Cons

### Pros
1. Runs on standard PHP 8.x and MySQL stacks with zero special server requirements
2. Permissive Apache-2.0 license maintained by an active community
3. Complete out-of-the-box solution including customer billing and support ticketing

### Cons
1. Heavily tailored toward web hosting and domain reselling rather than general e-commerce
2. Monolithic architecture makes it difficult to embed headlessly inside custom Laravel applications
3. Server-rendered Twig frontend rather than modern headless React/Vue APIs

---

## 4. Links & Reference

- **Official Website**: https://fossbilling.org
- **GitHub Repository**: https://github.com/FOSSBilling/FOSSBilling
- **Documentation**: https://fossbilling.org/docs
