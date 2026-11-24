[← Master Report](../../payment-gateway-research.md) | [← Category F: Banking & Ledger Infrastructure](../F-banking-ledger-infrastructure.md)

---

# TigerBeetle — Deep-Dive Report

> Purpose-built, high-throughput distributed financial accounting database written in Zig.

---

## 1. Overview

TigerBeetle is a groundbreaking open-source financial accounting database engineered specifically to track financial balances and execute double-entry transfers with mathematical guarantees of correctness. Developed in Zig by Joran Dirk Greef and the TigerBeetle team, it fundamentally rethinks financial ledgers: instead of forcing financial accounting into general-purpose SQL databases (PostgreSQL, MySQL) where concurrency race conditions, deadlocks, and floating-point errors run rampant, TigerBeetle is a purpose-built distributed ledger engine designed to execute **over 1,000,000 double-entry transfers per second**.

TigerBeetle operates with static memory allocation, zero garbage collection pauses, direct kernel bypass via Linux `io_uring`, and the Viewstamped Replication (VSR) consensus protocol. It guarantees that debits always equal credits, prevents double-spending at the database storage engine level, and is mathematically immune to silent data corruption or power loss failures.

---

## 2. Architecture & Data Flow

```
┌────────────────────────────────────────────────────────┐
│                   Laravel Application                   │
│          App\Services\Ledger\TigerBeetleService         │
└──────────────────────────┬─────────────────────────────┘
                           │ TCP / IPC via Client SDK or Sidecar
┌──────────────────────────▼─────────────────────────────┐
│                 TigerBeetle Cluster (VSR)              │
│                (6-node Viewstamped Replication)        │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ State Machine Engine (Zig / io_uring)            │  │
│  │ - Balances are 128-bit unsigned integers         │  │
│  │ - Static memory allocations (Zero GC)            │  │
│  └───────────────────────┬──────────────────────────┘  │
│                          │                             │
│  ┌───────────────────────▼──────────────────────────┐  │
│  │ Storage Engine: LSM Forest (Hash-Chained Blocks) │  │
│  │ - Strict Invariant: Σ Debits == Σ Credits        │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

1. **Primitive Entities**: TigerBeetle stores only two foundational primitives:
   - **`Account`**: Represents a financial balance (id, ledger, code, debits_pending, debits_posted, credits_pending, credits_posted).
   - **`Transfer`**: Represents a movement of value from a debit account to a credit account (id, debit_account_id, credit_account_id, amount, ledger, code, flags).
2. **Two-Phase Transfers (2PC)**: TigerBeetle natively supports two-phase commits:
   - *Phase 1 (Pending)*: When an order is placed, transfer funds into `debits_pending` / `credits_pending` (reserving authorization).
   - *Phase 2 (Post / Void)*: When the payment gateway webhook arrives, execute a post-pending transfer (capturing funds) or void-pending transfer (releasing hold).
3. **Storage Engine (LSM Forest)**: Appends transactions to disk using direct I/O (`O_DIRECT`) and kernel asynchronous completion (`io_uring`).

---

## 3. Key Features

- **1,000,000+ Transfers / Second** — Optimized to fully saturate modern NVMe SSDs without memory stalls or garbage collection overhead.
- **Strict Invariant Enforcement** — It is physically impossible to create an unbalanced transaction; debits must equal credits at all times.
- **Fault-Injection Verified** — Tested using automated deterministic simulation (Jepsen-style chaos testing) against corrupt disk sectors, sudden power outages, and network splits.
- **Built-in Two-Phase Transfers** — Direct support for `authorize -> capture` or `authorize -> cancel` lifecycles at the database layer.
- **Deterministic Replication** — Viewstamped Replication (VSR) consensus provides sub-millisecond automated master-replica failover.

---

## 4. How Laravel Can Utilize TigerBeetle

While TigerBeetle does not have a pure PHP extension yet, high-throughput e-commerce and marketplace architectures integrate it in Laravel via a lightweight **Go or Node.js sidecar service** or direct Redis/HTTP queue dispatcher:

```php
namespace App\Services\Ledger;

use App\Models\Order;
use Illuminate\Support\Facades\Http;

class TigerBeetleLedgerService
{
    protected string $sidecarUrl;

    public function __construct()
    {
        $this->sidecarUrl = config('services.tigerbeetle.sidecar_url', 'http://127.0.0.1:3000');
    }

    /**
     * Record an immutable double-entry transfer upon order payment
     */
    public function recordPayment(Order $order, string $gateway): bool
    {
        // Double-entry: Debit Gateway Clearing Account, Credit Merchant Revenue Account
        $response = Http::post("{$this->sidecarUrl}/transfers", [
            'id'                => (string) $order->id,
            'debit_account_id'  => config("ledger.accounts.{$gateway}_clearing"),
            'credit_account_id' => config("ledger.accounts.merchant_revenue"),
            'amount'            => (int) ($order->total_amount * 100),
            'ledger'            => 1, // IDR Ledger
            'code'              => 1001, // E-Commerce Order Settlement
        ]);

        return $response->successful();
    }
}
```

---

## 5. Pros & Cons

### Pros
1. Unrivaled performance: can process the entire daily transaction volume of Visa on a single commodity server
2. Eliminates balance drift and race conditions mathematically
3. Native two-phase transfers perfectly model card authorization and capture states
4. 100% open-source under Apache-2.0

### Cons
1. Purpose-built ledger database: does not support generic SQL queries, product catalogs, or user auth
2. Requires running a dedicated Zig binary or cluster
3. No direct first-party PHP SDK (requires interfacing via HTTP sidecar or IPC)
4. Unnecessary for small e-commerce stores processing <10,000 orders per day

---

## 6. When to Use

- You operate a multi-vendor marketplace with thousands of sub-merchants requiring real-time wallet balances.
- You process millions of transactions per day and MySQL row-locking on account tables has become a severe bottleneck.
- You require cryptographic auditability and absolute guarantee against double-spending.

---

## 7. Links & Reference

- **Official Website**: https://tigerbeetle.com
- **GitHub Repository**: https://github.com/tigerbeetle/tigerbeetle
- **Documentation**: https://docs.tigerbeetle.com
