[← Master Report](../../payment-gateway-research.md) | [← Category E: E-Commerce Platforms](../E-ecommerce-platforms.md)

---

# Sylius — Deep-Dive Report

> Clean-architecture Symfony e-commerce platform powered by Payum.

---

## 1. Overview

Sylius is an open-source, enterprise e-commerce platform built on Symfony and full clean-architecture principles. Widely regarded as having one of the best codebases in the PHP ecosystem, Sylius uses Payum as its core payment engine, providing strict state-machine management for payment processing, authorization, and refunds.

---

## 2. Key Features

- **State Machine Architecture** — Strict Winzou state machine controlling payment transitions (`cart -> processing -> completed -> refunded`).
- **Payum Integration** — Deep integration with Payum for secure payment capture and token storage.
- **Clean Architecture & DDD** — Domain-Driven Design principles with 100% test coverage.
- **API Platform Native** — Complete REST and GraphQL APIs generated via Symfony API Platform.

---

## 3. Pros & Cons

### Pros
1. Gold standard of PHP software architecture, automated testing, and maintainability
2. Fully MIT licensed without commercial copyleft restrictions
3. Excellent modeling of complex enterprise checkout and payment flows

### Cons
1. Symfony-centric: patterns differ significantly from Laravel's Active Record conventions
2. Higher initial development investment compared to turnkey platforms
3. Resource-heavy enterprise framework

---

## 4. Links & Reference

- **Official Website**: https://sylius.com
- **GitHub Repository**: https://github.com/Sylius/Sylius
- **Documentation**: https://docs.sylius.com
