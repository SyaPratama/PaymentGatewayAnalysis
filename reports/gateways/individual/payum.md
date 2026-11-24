[← Master Report](../../payment-gateway-research.md) | [← Category D: Payment SDK Libraries](../D-payment-sdk-libraries.md)

---

# Payum — Deep-Dive Report

> Advanced action and request pipeline payment framework for PHP.

---

## 1. Overview

Payum is an advanced payment processing framework for PHP that implements a functional request/action pipeline and state-machine pattern. Unlike simple wrapper libraries that execute direct imperative API calls, Payum provides architectural abstractions for managing complex asynchronous payment flows, recurring payment tokens, notifications, and security tokens.

It serves as the default underlying payment engine powering enterprise Symfony platforms like Sylius and SolidInvoice.

---

## 2. Key Features

- **Action & Request Pipeline** — Requests (`Capture`, `Authorize`, `Sync`, `Status`) pass through targeted action handlers.
- **Storage Abstraction** — Native storage layers for Doctrine ORM/ODM, Eloquent, and filesystem persistence.
- **Security Tokens** — Encrypted, expiring single-use URLs for safe payment callbacks and customer redirects.
- **Order State Resolution** — Standardized payment state checking (`isCaptured()`, `isPending()`, `isFailed()`) across all gateways.
- **Extensive Gateway Plugins** — Drivers for Stripe, PayPal, Klarna, Be2Bill, Authorize.net, and custom off-site providers.

---

## 3. Pros & Cons

### Pros
1. Architecturally superior handling of multi-step, asynchronous payment and capture state machines
2. Deep integration with Symfony, Doctrine, and modular frameworks
3. Built-in token expiration and replay prevention mechanisms

### Cons
1. Steep learning curve compared to Omnipay (requires understanding Payum's execution context and action hierarchy)
2. Heavy abstraction layer can feel over-engineered for simple direct-charge integrations
3. Documentation is scattered across older versions and lacks modern Laravel-specific guides

---

## 4. Links & Reference

- **Official Website**: https://payum.forma-dev.com
- **GitHub Repository**: https://github.com/Payum/Payum
