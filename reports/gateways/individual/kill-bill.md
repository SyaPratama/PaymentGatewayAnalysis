[← Master Report](../../payment-gateway-research.md) | [← Category C: Billing & Subscription Platforms](../C-billing-subscription-platforms.md)

---

# Kill Bill — Deep-Dive Report

> Enterprise-grade open-source subscription billing and payments platform.

---

## 1. Overview

Kill Bill is the open-source industry standard for enterprise recurring billing, subscription lifecycle management, and payment routing. Originally architected at Groupon to power massive global flash sales and subscriptions across dozens of currencies and tax regimes, Kill Bill now powers billing infrastructure at Zendesk and major international enterprises.

Kill Bill is not merely a payment wrapper—it is a complete financial core system written in Java. It models the entire subscription lifecycle (trials, plans, addons, proration, cancellations, pause/resume, upgrades/downgrades), handles multi-currency invoicing with customizable PDF templates, tracks double-entry account balances, and delegates payment execution to modular payment plugins (Stripe, Adyen, PayPal, CyberSource, etc.).

---

## 2. Architecture & How It Works

```
┌────────────────────────────────────────────────────────┐
│                   Laravel Application                   │
│         Interacts via Kill Bill Client SDK / REST       │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTP REST (Catalog, Accounts, Invoices)
┌──────────────────────────▼─────────────────────────────┐
│                 Kill Bill Core Server                  │
│                     (Java / OSGi)                      │
│                                                        │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │ Subscription Engine   │   │ Invoicing & Dunning  │  │
│  │ (Proration, Catalogs) │   │ (Tax, Credit Ledger) │  │
│  └───────────┬───────────┘   └──────────┬───────────┘  │
│              │                          │              │
│  ┌───────────▼──────────────────────────▼───────────┐  │
│  │ OSGi Plugin Framework (Kill Bill Payment Router) │  │
│  └───────────────────────┬──────────────────────────┘  │
└──────────────────────────┼─────────────────────────────┘
                           │
            ┌──────────────┴──────────────┐
            ▼                             ▼
    ┌───────────────┐             ┌───────────────┐
    │ Stripe Plugin │             │ Adyen Plugin  │
    └───────────────┘             └───────────────┘
```

1. **Catalog Module**: Encapsulates your pricing plans, currencies, trial durations, billing intervals, and billing alignment rules in an XML or JSON catalog definition.
2. **Subscription Engine (Entitlement)**: Tracks active user subscriptions, handles mid-cycle upgrades or downgrades with exact-to-the-second proration calculations.
3. **Invoicing Engine**: Runs automated cron schedules to generate itemized invoices, apply credits, compute localized taxes, and trigger payment attempts.
4. **OSGi Plugin Architecture**: Decouples payment processors from core billing logic. New gateways can be added as isolated Java/Ruby plugins without recompiling the core server.
5. **Kaui (Kill Bill Admin UI)**: A standalone Rails web application providing administrative dashboards for customer support and finance teams.

---

## 3. Key Features

- **Proration & Catalog Precision** — Mathematically correct recurring calculations down to millisecond timestamps.
- **Dunning & Automated Retries** — Configurable dunning schedules (retry in 2 days, email notification, suspend in 7 days, cancel in 14 days).
- **Payment Routing & Failover** — Route payments across different processor plugins based on account currency or geographic tags.
- **Account Balance & Ledger** — Tracks credit balances, advance payments, refunds, and adjustments directly within each customer account.
- **Multi-Tenancy** — Run multiple discrete business entities or white-label platforms on a single Kill Bill cluster.
- **Kaui Administrative Portal** — Turnkey back-office interface for support teams to inspect invoices, issue manual refunds, or adjust account credits.

---

## 4. Pricing & TCO Analysis

Kill Bill is free under the Apache-2.0 license. Operating costs are driven by Java server infrastructure and DevOps expertise.

| Metric | Kill Bill (Self-Hosted) | Chargebee / Stripe Billing |
|---|---|---|
| **Software License** | $0 (Apache-2.0) | 0.5%–0.75% of recurring volume |
| **At $100K / mo ($1.2M ARR)** | ~$250/mo infra = **$3,000/yr** | ~$7,200/yr SaaS fees |
| **At $1M / mo ($12M ARR)** | ~$800/mo infra = **$9,600/yr** | ~$60,000–$90,000/yr SaaS fees |
| **Engineering Setup** | High (2–4 weeks setup) | Low (2–3 days) |

*TCO Verdict:* Kill Bill yields massive financial savings at scale (> $2M ARR) by eliminating percentage-based revenue cuts on subscription billing.

---

## 5. Integration Guide for Laravel

Kill Bill maintains an official PHP client library (`killbill/killbill-client-php`).

### Step 1: Install SDK
```bash
composer require killbill/killbill-client-php
```

### Step 2: Initialize Client in Service Provider
```php
namespace App\Services\Payment;

use Killbill\Client\KillbillClient;
use Killbill\Client\Type\Account;
use Killbill\Client\Type\Subscription;

class KillBillService
{
    protected KillbillClient $client;

    public function __construct()
    {
        $this->client = new KillbillClient();
        KillbillClient::$serverUrl = config('services.killbill.url', 'http://127.0.0.1:8080');
        KillbillClient::$apiKey = config('services.killbill.api_key');
        KillbillClient::$apiSecret = config('services.killbill.api_secret');
    }

    public function createCustomer(string $externalKey, string $email, string $currency = 'IDR'): Account
    {
        $account = new Account();
        $account->setExternalKey($externalKey);
        $account->setEmail($email);
        $account->setCurrency($currency);

        return $account->create('LaravelApp', 'UserSignup', 'Created via Laravel');
    }

    public function subscribeToPlan(string $accountId, string $planName): Subscription
    {
        $subscription = new Subscription();
        $subscription->setAccountId($accountId);
        $subscription->setPlanName($planName);

        return $subscription->create('LaravelApp', 'UserSubscription', 'Subscribed to plan');
    }
}
```

---

## 6. Security & PCI DSS Scope

- **Isolated Payment Vault**: Kill Bill handles token references only; actual credit card numbers are collected via processor-hosted iframes (e.g. Stripe Elements) and passed to Kill Bill as gateway payment method tokens.
- **Reduced PCI Scope**: When used with tokenization plugins, the Kill Bill core server stays at the SAQ-A or SAQ-A-EP compliance boundary.
- **Audit Trails**: Every invoice state change, balance adjustment, and payment retry is recorded immutably with user metadata.

---

## 7. Scalability & Operational Footprint

- **Infrastructure Requirements**:
  - Kill Bill Server: 2x 4GB RAM JVM instances (Spring / OSGi)
  - Kaui Admin UI: 1x 1GB RAM container
  - Database: Highly available MySQL 8.x or PostgreSQL 14+ cluster
- **Throughput**: Processes thousands of subscription invoice state transitions per minute in clustered multi-node deployments.

---

## 8. Pros & Cons

### Pros
1. Total control of subscription business logic without third-party platform lock-in
2. Enormous cost savings at scale compared to commercial SaaS billing platforms
3. Battle-tested by major public enterprises (Groupon, Zendesk)
4. Extensible OSGi plugin system allows integrating any proprietary payment rail
5. Complete account ledger tracking past-due balances, credits, and adjustments

### Cons
1. High operational barrier to entry: requires Java JVM tuning and enterprise database administration
2. Steep learning curve for catalog XML schemas and entitlement state rules
3. Overly complex for simple e-commerce checkouts that don't need recurring billing
4. Documentation is geared toward enterprise systems architects rather than frontend developers

---

## 9. When to Use vs. When to Avoid

### When to Use
- You run a high-volume SaaS or subscription platform (> $100K/month MRR).
- You need custom localized payment gateways connected to recurring subscription plans.
- You refuse to pay 0.5%–1.0% of gross recurring revenue to SaaS billing aggregators.

### When to Avoid
- Pure one-time e-commerce retail (like standard physical goods checkout).
- Small engineering teams without Java/DevOps maintenance capacity.

---

## 10. Links & Reference

- **Official Website**: https://killbill.io
- **GitHub Repository**: https://github.com/killbill/killbill
- **Documentation**: https://docs.killbill.io
