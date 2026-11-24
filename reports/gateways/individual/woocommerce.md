[← Master Report](../../payment-gateway-research.md) | [← Category E: E-Commerce Platforms](../E-ecommerce-platforms.md)

---

# WooCommerce — Deep-Dive Report

> The world's most widely-used open-source e-commerce platform with 100+ payment extensions.

---

## 1. Overview

WooCommerce powers over 30% of all online stores globally. Built on top of WordPress in PHP, it features the largest payment plugin ecosystem in the world, with official and community gateways available for practically every bank, processor, and regional fintech on earth.

---

## 2. Key Features

- **Massive Gateway Library** — Over 100+ gateways available, including TripPay, DOKU, Midtrans, Xendit, Stripe, and PayPal.
- **`WC_Payment_Gateway` Class** — Standardized abstraction class for generating payment forms, processing charges, and handling IPNs.
- **Webhook Subsystem** — Comprehensive webhook engine delivering signed order state events to external services.
- **WooCommerce Payments** — Integrated white-label Stripe solution for native card and APM checkout.

---

## 3. Pros & Cons

### Pros
1. Unrivaled payment gateway availability: every regional payment gateway writes a WooCommerce plugin first
2. PHP-based: easy to read and understand driver mechanics for PHP developers
3. Huge global developer community and extensive documentation

### Cons
1. Strict WordPress dependency: cannot be used as a standalone headless payment library
2. Inherits WordPress architectural legacy (global state, hooks, procedural elements)
3. Heavy database footprint under high transaction concurrency

---

## 4. Links & Reference

- **Official Website**: https://woocommerce.com
- **GitHub Repository**: https://github.com/woocommerce/woocommerce
- **Documentation**: https://developer.woocommerce.com
