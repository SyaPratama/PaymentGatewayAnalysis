[← Master Report](../../payment-gateway-research.md) | [← Category F: Banking & Ledger Infrastructure](../F-banking-ledger-infrastructure.md)

---

# Mojaloop — Deep-Dive Report

> Open-source real-time payment switch for interoperable national financial rails.

---

## 1. Overview

Mojaloop is an open-source real-time payment switch designed to achieve financial inclusion by interconnecting digital financial service providers (banks, mobile money operators, merchants) across entire national payment systems. Initiated by the Bill & Melinda Gates Foundation, Mojaloop implements the Interledger Protocol (ILP) to execute instantaneous, low-cost clearing and settlement between incompatible payment providers.

---

## 2. Key Features

- **Real-Time Clearing & Settlement** — Sub-second irrevocable payment routing between different banks and telcos.
- **Interledger Protocol (ILP)** — Cryptographic condition verification ensuring atomic execution across distinct ledgers.
- **Open Loop Interoperability** — Enables a user with a telco mobile wallet to pay a merchant banked with an independent commercial bank.
- **Scalable Microservices** — Distributed Kubernetes deployment utilizing Kafka streaming.

---

## 3. Pros & Cons

### Pros
1. World-class architectural standards backed by international development organizations
2. Eliminates walled gardens between telco wallets at a national level
3. Apache-2.0 open governance

### Cons
1. Built for national central banks and regional payment switches, not individual e-commerce merchants
2. Massive infrastructure footprint requiring a multi-node Kubernetes cluster
3. Immense operational and regulatory complexity

---

## 4. Links & Reference

- **Official Website**: https://mojaloop.io
- **GitHub Repository**: https://github.com/mojaloop/mojaloop
- **Documentation**: https://docs.mojaloop.io
