[← Master Report](../../payment-gateway-research.md) | [← Category F: Banking & Ledger Infrastructure](../F-banking-ledger-infrastructure.md)

---

# Hatchet Ledger — Deep-Dive Report

> Lightweight TypeScript double-entry ledger library backed by PostgreSQL.

---

## 1. Overview

Hatchet Ledger is a modern, lightweight double-entry ledger library implemented in TypeScript. Designed to be embedded directly into backend services, it provides programmatic account trees, credit/debit validation, and transaction audit trails backed by PostgreSQL.

---

## 2. Key Features

- **Pure Double-Entry Invariants** — Guarantees debits equal credits before persisting transactions.
- **PostgreSQL Concurrency Locks** — Prevents race conditions and overdrafts using row-level locking.
- **Clean TypeScript Types** — Fully typed account and transaction entities.
- **Audit-Ready History** — Append-only design where transactions cannot be mutated or deleted.

---

## 3. Pros & Cons

### Pros
1. Ultra-lightweight: zero extra server daemons needed if you already run PostgreSQL
2. Permissive MIT license
3. Clean modern codebase, easy to comprehend and audit

### Cons
1. Early stage with limited ecosystem tooling
2. Lacks advanced multi-currency conversion and automated reconciliation features
3. Modest throughput compared to purpose-built databases like TigerBeetle

---

## 4. Links & Reference

- **GitHub Repository**: https://github.com/hatchet-dev
- **License**: MIT
