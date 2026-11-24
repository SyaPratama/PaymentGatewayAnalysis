[← Master Report](../../payment-gateway-research.md) | [← Category D: Payment SDK Libraries](../D-payment-sdk-libraries.md)

---

# go-payment — Deep-Dive Report

> Lightweight Go payment gateway client library for Southeast Asian processors.

---

## 1. Overview

`go-payment` is a lightweight Go payment gateway client library specifically targeted at Southeast Asian payment gateways. It provides standardized data types and request builders for integrating Indonesian and regional payment providers such as Midtrans and Xendit within Go microservices.

---

## 2. Key Features

- **Southeast Asia Gateway Focus** — Purpose-built wrappers for Midtrans, Xendit, and regional virtual accounts.
- **Go Concurrency & Typing** — Strongly typed request/response structs with sub-millisecond execution.
- **Unified Invoice Lifecycle** — Generic methods for creating payment links, checking statuses, and parsing callbacks.
- **Minimal Dependencies** — Pure standard library HTTP client usage without external framework bloat.

---

## 3. Pros & Cons

### Pros
1. Tailored directly to Indonesian payment mechanisms (BCA VA, Mandiri VA, QRIS, GoPay, OVO)
2. Ultra-low latency and minimal memory footprint
3. Great for building a high-speed Indonesian payment proxy microservice

### Cons
1. Small personal/community project with limited commit frequency
2. Covers only a few regional gateways
3. Go-only: not directly callable from PHP without an external service or FFI

---

## 4. Links & Reference

- **GitHub Repository**: https://github.com/pandudpn/go-payment
- **License**: MIT
