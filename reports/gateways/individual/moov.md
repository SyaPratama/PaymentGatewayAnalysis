[← Master Report](../../payment-gateway-research.md) | [← Category F: Banking & Ledger Infrastructure](../F-banking-ledger-infrastructure.md)

---

# Moov — Deep-Dive Report

> Open-source cloud-native US banking and payment rail primitives written in Go.

---

## 1. Overview

Moov is an open-source fintech platform providing low-level financial protocol libraries and microservices written in Go. Rather than relying on legacy proprietary banking middleware, Moov implements standard United States banking specifications—NACHA ACH, Fedwire, FedNow, ISO 8583, and ISO 20022—as pure, modern open-source software.

---

## 2. Key Features

- **NACHA ACH Engine** — Complete ACH file generation, parsing, validation, and batching with zero dependencies.
- **Wire & RTP Primitives** — Parsers and state engines for Fedwire, Real-Time Payments (RTP), and ISO 20022 formats.
- **OFAC & Sanctions Screening** — Built-in automated watch-list checking against US Treasury SDN lists.
- **Microservices Architecture** — Modular standalone services connectable via REST or gRPC.

---

## 3. Pros & Cons

### Pros
1. Deep protocol correctness: battle-tested against strict Federal Reserve and NACHA compliance specifications
2. Clean, fast Go implementations with zero external runtime dependencies
3. Apache-2.0 licensed, enabling safe incorporation into commercial banking products

### Cons
1. Primarily oriented toward United States banking rails (ACH, Fedwire) — limited relevance to Indonesian BI-FAST or RTGS
2. Requires financial institution sponsorship or direct Federal Reserve routing access to execute live wire settlements
3. High domain complexity requiring specialized payments compliance knowledge

---

## 4. Links & Reference

- **Official Website**: https://moov.io
- **GitHub Organization**: https://github.com/moov-io
- **Documentation**: https://docs.moov.io
