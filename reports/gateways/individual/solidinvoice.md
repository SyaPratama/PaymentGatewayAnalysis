[← Master Report](../../payment-gateway-research.md) | [← Category C: Billing & Subscription Platforms](../C-billing-subscription-platforms.md)

---

# SolidInvoice — Deep-Dive Report

> Open-source Symfony and Payum-powered general-purpose invoicing application.

---

## 1. Overview

SolidInvoice is an open-source, general-purpose billing application built on Symfony and the Payum payment abstraction framework. It provides quote generation, recurring invoice creation, and client payment processing with an emphasis on clean architecture, strict typing, and PHP standards (PSR).

---

## 2. Key Features

- **Powered by Payum** — Leverages Payum's robust state-machine and action pipeline for multi-gateway payment processing.
- **Quote-to-Invoice Workflows** — Digital client quote approval and electronic signature capture.
- **Client Billing Area** — Secure, branded portal for clients to inspect invoice history and execute payments.
- **Clean Symfony Architecture** — Strict adherence to modern PHP standards, dependency injection, and Doctrine ORM.

---

## 3. Pros & Cons

### Pros
1. Permissive MIT license: safe for commercial integration with zero copyleft risk
2. High-quality architectural standards adhering strictly to enterprise PHP best practices
3. Leverages Payum's mature payment gateway adapter ecosystem

### Cons
1. Smaller community and slower update frequency than Invoice Ninja or Crater
2. Symfony and Doctrine-centric: patterns differ from Laravel's Active Record conventions
3. Basic feature set focused strictly on traditional invoicing

---

## 4. Links & Reference

- **Official Website**: https://solidinvoice.co
- **GitHub Repository**: https://github.com/SolidInvoice/SolidInvoice
- **Documentation**: https://docs.solidinvoice.co
