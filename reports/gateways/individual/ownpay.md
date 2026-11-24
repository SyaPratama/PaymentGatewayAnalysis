[← Master Report](../../payment-gateway-research.md) | [← Category A: Payment Orchestrators](../A-payment-orchestrators.md)

---

# OwnPay — Deep-Dive Report

> Minimalist open-source self-hosted payment gateway proxy written in Go.

---

## 1. Overview

OwnPay is a lightweight, self-hosted payment proxy service developed in Go. Built for developers seeking a zero-maintenance proxy layer to decouple their backend applications from commercial payment processors like Stripe and PayPal, OwnPay bundles payment creation, status querying, and webhook forwarding into a single lightweight binary requiring less than 50MB of memory.

OwnPay avoids the heavy microservices footprint of enterprise orchestrators like Hyperswitch by using SQLite or embedded key-value stores for transaction state persistence.

---

## 2. Architecture & Data Flow

```
┌────────────────────┐    HTTP REST     ┌────────────────────────┐    Upstream API    ┌────────────────┐
│  Laravel Backend   ├─────────────────►│     OwnPay Daemon      ├───────────────────►│ Stripe / PayPal│
│  (E-Commerce App)  │◄─────────────────┤       (Go Binary)      │◄───────────────────┤ Payment Gateway│
└────────────────────┘                  └────────────────────────┘                    └────────────────┘
```

1. **Initiation**: Laravel sends a standard JSON payload (`amount`, `currency`, `customer`) to the OwnPay REST API.
2. **Translation**: OwnPay maps generic parameters to processor-specific parameters (e.g. Stripe PaymentIntent vs. PayPal Order).
3. **Execution**: OwnPay handles outbound TLS connection pooling and returns a normalized transaction reference.
4. **Relay**: Webhooks received from Stripe/PayPal are stored in SQLite and dispatched reliably to your registered webhook URL.

---

## 3. Key Features

- **Microscopic Resource Footprint** — <50MB RAM usage; runs easily on a $5/month cloud instance.
- **Embedded Database** — Uses SQLite with WAL mode enabled; zero external database setup required.
- **Dual Connector Support** — Built-in adapters for Stripe and PayPal REST APIs.
- **Webhook Retry Dispatcher** — Built-in exponential backoff queue for re-delivering failed webhook callbacks.

---

## 4. Pros & Cons

### Pros
1. Trivial to deploy via Docker (`docker run -p 8080:8080 ownpay/ownpay`)
2. MIT license: completely free for commercial and proprietary use
3. Simple, readable Go codebase that is easy to audit and extend

### Cons
1. Limited connector library (currently supports only Stripe and PayPal)
2. Small open-source community with infrequent updates
3. Lacks advanced fraud prevention, 3DS challenge orchestration, or card vaulting

---

## 5. Links & Reference

- **GitHub Repository**: https://github.com/ownpay
