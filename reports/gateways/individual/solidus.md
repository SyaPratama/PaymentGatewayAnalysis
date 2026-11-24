[← Master Report](../../payment-gateway-research.md) | [← Category E: E-Commerce Platforms](../E-ecommerce-platforms.md)

---

# Solidus — Deep-Dive Report

> Enterprise Ruby on Rails e-commerce framework powered by Active Merchant.

---

## 1. Overview

Solidus is a community-driven fork of Spree Commerce built on Ruby on Rails. Designed specifically for high-volume, enterprise e-commerce merchants, Solidus features a decoupled, modular payment architecture backed by Active Merchant. It handles partial captures, split payments, store credits, and multiple payment sources on a single order.

---

## 2. Key Features

- **Active Merchant Backbone** — Leverages Active Merchant's 100+ proven gateway drivers.
- **Split & Multi-Source Payments** — Apply gift cards, loyalty points, and credit cards to a single checkout.
- **Asynchronous State Machine** — State transitions manage `checkout -> pending -> authorized -> captured -> void`.
- **Enterprise PCI Support** — Vault-friendly architectures avoiding cardholder data storage.

---

## 3. Pros & Cons

### Pros
1. Extremely mature and robust payment state machine
2. Exceptional handling of complex order adjustments, refunds, and partial captures
3. Clean Ruby code with heavy emphasis on software engineering quality and test coverage

### Cons
1. Ruby on Rails only: inaccessible for direct PHP code sharing
2. High configuration overhead; requires experienced Rails engineers
3. Smaller community than modern headless alternatives

---

## 4. Links & Reference

- **Official Website**: https://solidus.io
- **GitHub Repository**: https://github.com/solidusio/solidus
- **Documentation**: https://docs.solidus.io
