[← Master Report](../../payment-gateway-research.md) | [← Category E: E-Commerce Platforms](../E-ecommerce-platforms.md)

---

# Spree Commerce — Deep-Dive Report

> Headless, open-source Ruby on Rails e-commerce framework with extensive payment gateway coverage.

---

## 1. Overview

Spree Commerce is one of the oldest and most established open-source e-commerce frameworks in the world. Modern Spree operates as a headless e-commerce backend exposing REST and GraphQL APIs to Next.js or mobile frontends, while providing modular payment drivers for dozens of global PSPs.

---

## 2. Key Features

- **Headless REST & GraphQL APIs** — Clean API endpoints for checkout and payment processing.
- **Payment Method Adapters** — Drivers for Stripe, PayPal, Braintree, Adyen, Mollie, and Authorize.Net.
- **Flexible Order Pipeline** — Customizable checkout state machine with hook points for custom payment validation.
- **Next.js Storefront Starter** — Pre-built React storefront with hosted payment component integrations.

---

## 3. Pros & Cons

### Pros
1. Over 15 years of continuous production testing across thousands of online stores
2. Decoupled headless architecture allows modern frontend integration
3. Strong ecosystem of third-party extensions

### Cons
1. Ruby on Rails backend requires specialized DevOps and infrastructure
2. Legacy architectural patterns remain in parts of the codebase
3. Slower API responses compared to modern Go or Rust backends

---

## 4. Links & Reference

- **Official Website**: https://spreecommerce.org
- **GitHub Repository**: https://github.com/spree/spree
- **Documentation**: https://docs.spreecommerce.org
