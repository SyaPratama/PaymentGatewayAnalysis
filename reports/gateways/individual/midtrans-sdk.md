[← Master Report](../../payment-gateway-research.md) | [← Category D: Payment SDK Libraries](../D-payment-sdk-libraries.md)

---

# Midtrans SDKs — Deep-Dive Report

> Official client libraries for integrating Midtrans payment services.

---

## 1. Overview

Midtrans provides official, first-party SDKs across all major backend languages (`midtrans-php`, `midtrans-go`, `midtrans-node`, `midtrans-python`, `midtrans-java`). The PHP client library (`midtrans/midtrans-php`) represents the standard tool for integrating Midtrans Snap and Core API directly into Laravel applications.

---

## 2. Key Features

- **Snap Checkout Integration** — Generate Snap payment tokens in 3 lines of code for modal/redirect checkout.
- **Core API Operations** — Direct API access for custom checkout forms, VA creation, and direct GoPay/QRIS deep linking.
- **Automated Webhook Handling** — Built-in `Notification` class automatically verifies callback integrity and parses status.
- **Sandbox Environment Switching** — Seamless switching via `Config::$isProduction` and `Config::$serverKey`.

---

## 3. Pros & Cons

### Pros
1. 100% feature-complete for all Indonesian payment methods (GoPay, ShopeePay, OVO, QRIS, Indomaret, Alfamart)
2. Maintained directly by Midtrans/GoTo engineers with immediate updates for new channels
3. Easy integration into Laravel controllers and service providers

### Cons
1. Single-vendor SDK: zero abstraction for switching to Xendit, TripPay, or DOKU
2. No multi-gateway failover logic
3. Global credit card processing requires separate international merchant approvals

---

## 4. Links & Reference

- **GitHub Repository**: https://github.com/Midtrans/midtrans-php
- **Documentation**: https://docs.midtrans.com
