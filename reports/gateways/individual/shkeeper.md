[← Master Report](../../payment-gateway-research.md) | [← Category B: Self-Hosted Crypto Gateways](../B-crypto-gateways.md)

---

# SHKeeper — Deep-Dive Report

> Lightweight, privacy-focused open-source crypto processor supporting Monero and USDT.

---

## 1. Overview

SHKeeper is an open-source, self-hosted cryptocurrency payment processor engineered specifically for high privacy, operational simplicity, and non-custodial operations. Written in Python, SHKeeper specializes in payment acceptance for Bitcoin, Monero, Litecoin, Ethereum, and TRON (USDT-TRC20) without KYC verification, telemetry, or third-party dependencies.

SHKeeper is particularly popular for cross-border e-commerce operations that accept USDT on the TRON network (TRC-20) due to its sub-cent transaction fees and stable fiat parity.

---

## 2. Key Features

- **Privacy-First Core** — Zero tracking, zero telemetry, and native Monero view-key scanning.
- **USDT-TRC20 Native Integration** — Direct acceptance of dollar-pegged stablecoins on the low-fee TRON blockchain.
- **Automated Cold Storage Sweeps** — Automatically transfers received customer funds to pre-configured cold storage addresses.
- **Minimalist REST API** — Simple endpoints for creating invoices, checking payment status, and registering webhooks.

---

## 3. Pros & Cons

### Pros
1. Excellent support for USDT-TRC20 (crucial for cross-border emerging market e-commerce)
2. Native Monero privacy handling without data leakage
3. Lightweight architecture compared to enterprise multi-node suites

### Cons
1. API-first tool: lacks a sophisticated consumer-facing checkout UI (developer must build frontend)
2. Smaller community and limited public security audit history
3. Requires managing connection to underlying blockchain nodes or reliable RPCs

---

## 4. Links & Reference

- **GitHub Repository**: https://github.com/vsys-host/shkeeper
- **Official Website**: https://shkeeper.io
