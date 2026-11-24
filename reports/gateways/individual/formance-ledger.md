[← Master Report](../../payment-gateway-research.md) | [← Category F: Banking & Ledger Infrastructure](../F-banking-ledger-infrastructure.md)

---

# Formance Ledger — Deep-Dive Report

> Programmable double-entry ledger with Numscript domain-specific language.

---

## 1. Overview

Formance Ledger (part of the Formance Stack, formerly Numary) is a programmable double-entry ledger designed for modern payment applications and marketplaces. It allows engineering teams to model complex money flows (e.g. commission splits, multi-wallet payouts, escrow holds) using a dedicated domain-specific language called Numscript.

---

## 2. Key Features

- **Numscript DSL** — Human-readable programming language for financial transactions with guaranteed balance conservation.
- **Immutable Double-Entry Ledger** — Append-only transaction logging with cryptographic integrity.
- **Multi-Asset & Multi-Currency** — Track real currencies, cryptocurrencies, loyalty points, and in-game assets within the same account.
- **RESTful API & Webhooks** — Real-time event notifications on transaction commit.
- **Visual Explorer Dashboard** — Web UI to inspect account trees, balances, and transaction histories.

---

## 3. Pros & Cons

### Pros
1. Numscript eliminates mathematical logic errors in complex fee splits and escrow allocations
2. Standard PostgreSQL persistence: easy to back up, inspect, and host on standard cloud providers
3. Modern API-first design with clean SDKs and documentation

### Cons
1. Query throughput is limited by underlying PostgreSQL performance compared to TigerBeetle
2. Requires running an additional Go microservice
3. Early-stage commercial ecosystem

---

## 4. Links & Reference

- **Official Website**: https://formance.com
- **GitHub Repository**: https://github.com/formancehq/ledger
- **Documentation**: https://docs.formance.com
