[← Master Report](../../payment-gateway-research.md) | [← Category E: E-Commerce Platforms](../E-ecommerce-platforms.md)

---

# PrestaShop — Deep-Dive Report

> Established European open-source e-commerce platform with modular payment hooks.

---

## 1. Overview

PrestaShop is an established European open-source e-commerce platform powering over 300,000 stores. It features a modular payment gateway architecture with extensive European, Latin American, and Asian payment modules available in its marketplace.

---

## 2. Key Features

- **Modular Payment Hooks** — Standard hook points: `paymentOptions`, `actionPaymentConfirmation`, `displayPaymentReturn`.
- **PrestaShop Checkout** — Official PayPal-backed unified payment suite.
- **Marketplace Modules** — 300+ commercial and free payment connectors.
- **Multi-Store Management** — Run multiple storefronts with distinct payment settings from one back office.

---

## 3. Pros & Cons

### Pros
1. Very large international merchant and agency community
2. Broad support for European localized payment systems (Bancontact, iDEAL, Sofort)
3. Modern versions are migrating toward standard Symfony components

### Cons
1. Legacy technical debt from older architectural versions
2. OSL-3.0 license is reciprocal and complex for proprietary adaptations
3. Marketplace add-ons often carry recurring commercial license fees

---

## 4. Links & Reference

- **Official Website**: https://prestashop-project.org
- **GitHub Repository**: https://github.com/PrestaShop/PrestaShop
- **Documentation**: https://devdocs.prestashop-project.org
