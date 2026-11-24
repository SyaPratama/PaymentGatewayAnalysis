[← Master Report](../../payment-gateway-research.md) | [← Category C: Billing & Subscription Platforms](../C-billing-subscription-platforms.md)

---

# Lago — Deep-Dive Report

> Modern, open-source usage-based and subscription billing engine (Stripe Billing alternative).

---

## 1. Overview

Lago is an open-source, real-time metering and usage-based billing platform designed specifically for modern SaaS and consumption-driven business models. Positioned as the open-source alternative to Stripe Billing, Chargebee, and Metronome, Lago allows engineering teams to ingest massive volumes of billable events (API calls, compute time, storage GBs, tokens), aggregate them against arbitrary pricing formulas, and automatically generate invoices for customer payment collection.

Lago's architecture is built with an API-first philosophy using modern technologies: a high-throughput event ingestion engine written in Go, a core business logic engine written in Ruby on Rails, and an administrative dashboard built in React. It integrates directly with Stripe, Adyen, and GoCardless for automated payment execution.

---

## 2. Architecture & How It Works

```
┌────────────────────────────────────────────────────────┐
│                   Laravel Application                   │
│         Sends Usage Events & Manages Subscriptions      │
└──────────────────────────┬─────────────────────────────┘
                           │ POST /api/v1/events (Async High-Volume)
┌──────────────────────────▼─────────────────────────────┐
│                       Lago Core                        │
│                                                        │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │ Event Ingestor (Go)   │   │ Aggregation Engine   │  │
│  │ (ClickHouse / Redis)  │   │ (Tiers, Packages)    │  │
│  └───────────┬───────────┘   └──────────┬───────────┘  │
│              │                          │              │
│  ┌───────────▼──────────────────────────▼───────────┐  │
│  │ Rails Business API (Invoicing, Taxes, Coupons)    │  │
│  └───────────────────────┬──────────────────────────┘  │
└──────────────────────────┼─────────────────────────────┘
                           │ Automated Charge Trigger
            ┌──────────────┴──────────────┐
            ▼                             ▼
    ┌───────────────┐             ┌───────────────┐
    │ Stripe Charge │             │ Adyen Charge  │
    └───────────────┘             └───────────────┘
```

1. **Event Ingestion**: Your application emits raw usage events (`transaction_id`, `customer_id`, `code`, `properties.tokens`) via Lago's Go-powered ingestion API.
2. **Real-Time Aggregation**: Lago processes events in real time against configured billable metrics (sum, max, unique count, latest).
3. **Billing Cycles**: At the end of the customer's billing period, Lago's invoicing engine calculates line items based on plan models (graduated tiers, volume pricing, prepaid credit wallets).
4. **Payment Dispatch**: Lago communicates with configured payment providers (Stripe, Adyen) to automatically charge the customer's stored payment method.
5. **Webhooks**: Dispatches real-time webhooks (`invoice.created`, `invoice.payment_failure`, `credit_wallet.depleted`) back to your application.

---

## 3. Key Features

- **Modern Metered & Hybrid Billing** — Native support for subscription base fees + pay-as-you-go metered usage + prepaid credit top-ups.
- **Complex Pricing Models** — Package pricing, graduated tiered pricing, volume discounts, and percentage fees.
- **Prepaid Credit Wallets** — Customers purchase credit bundles upfront; Lago automatically deducts credits based on consumption.
- **Stripe & Adyen Native Sync** — Automatically creates Stripe customers and charges payment intents without building custom billing glue.
- **Modern React Admin Portal** — Clean UI for non-technical finance and growth teams to inspect customer consumption, create coupons, and issue credit notes.
- **Official PHP / Laravel Client** — First-party SDK (`lago-php-client`) with strongly typed request builders.

---

## 4. Pricing & TCO Analysis

Lago operates on an open-core model. The self-hosted Community Edition is licensed under AGPL-3.0.

| Volume | Lago Self-Hosted | Stripe Billing (0.5%–0.7%) | Annual Savings |
|---|---|---|---|
| **$50,000 / mo MRR** | ~$80 / mo (VPS) | $350 / mo | **$3,240 / yr** |
| **$200,000 / mo MRR** | ~$150 / mo (Cluster) | $1,400 / mo | **$15,000 / yr** |
| **$1,000,000 / mo MRR** | ~$400 / mo (ClickHouse setup) | $7,000 / mo | **$79,200 / yr** |

---

## 5. Integration Guide for Laravel

### Step 1: Install Lago PHP SDK
```bash
composer require getlago/lago-php-client
```

### Step 2: Configure Environment (`config/services.php`)
```php
'lago' => [
    'api_key' => env('LAGO_API_KEY'),
    'url'     => env('LAGO_URL', 'http://localhost:3000'),
],
```

### Step 3: Emit Metered Usage Events in Laravel
```php
namespace App\Services\Billing;

use Exception;
use GuzzleHttp\Client;
use Illuminate\Support\Str;

class LagoMeteringService
{
    protected string $url;
    protected string $apiKey;
    protected Client $http;

    public function __construct()
    {
        $this->url = rtrim(config('services.lago.url'), '/');
        $this->apiKey = (string) config('services.lago.api_key');
        $this->http = new Client();
    }

    /**
     * Ingest billable usage event (e.g. AI tokens, API requests, storage bytes)
     */
    public function sendUsageEvent(string $customerId, string $metricCode, float $amount): bool
    {
        try {
            $response = $this->http->post("{$this->url}/api/v1/events", [
                'headers' => [
                    'Authorization' => "Bearer {$this->apiKey}",
                    'Content-Type'  => 'application/json',
                ],
                'json' => [
                    'event' => [
                        'transaction_id'          => (string) Str::uuid(),
                        'external_customer_id'   => $customerId,
                        'code'                   => $metricCode,
                        'timestamp'              => time(),
                        'properties'             => [
                            'amount' => $amount,
                        ],
                    ],
                ],
            ]);

            return $response->getStatusCode() === 200;
        } catch (Exception $e) {
            report($e);
            return false;
        }
    }
}
```

---

## 6. Security & PCI Scope

- **Zero Card Data Handled**: Lago stores customer identifiers, usage metrics, and subscription states. Credit card numbers, CVVs, and raw payment methods reside entirely within Stripe or Adyen.
- **SAQ-A Scope**: Because Lago acts as a billing orchestration layer triggering charges via tokenized payment IDs, the merchant infrastructure remains at the minimal SAQ-A level.

---

## 7. Scalability & Operational Footprint

- **Throughput**: Lago's Go event ingestion pipeline can ingest **thousands of events per second** per node into Redis buffers before persisting to PostgreSQL or ClickHouse.
- **Infrastructure Requirements**:
  - Web Server & API: 1x 2GB RAM container (Rails)
  - Worker & Ingestor: 1x 1GB RAM container (Go + Sidekiq)
  - Database: PostgreSQL 14+ (ClickHouse recommended for multi-million event throughput)
  - Cache / Queue: Redis 6+

---

## 8. Pros & Cons

### Pros
1. The most modern, intuitive user interface among open-source billing platforms
2. First-class support for usage-based, consumption-based, and credit wallet models
3. Seamless integration with Stripe and Adyen
4. First-party PHP SDK and clean REST API documentation
5. Active open-source development with frequent release cycles

### Cons
1. Dual-licensed under AGPL-3.0 (must disclose modifications if distributing software)
2. Microservices stack requires running Rails + Go + Redis + Postgres simultaneously
3. Fewer traditional enterprise legacy features compared to Kill Bill
4. Direct support for Indonesian local payment gateways (VA/QRIS) requires custom webhook wiring

---

## 9. When to Use vs. When to Avoid

### When to Use
- You run a modern SaaS, API platform, or AI service with usage-based billing.
- You want an open-source equivalent to Stripe Billing that you can host on your own infrastructure.
- You need a beautiful administrative dashboard for non-technical finance colleagues.

### When to Avoid
- Pure one-off physical e-commerce (like the current TripPay/DOKU cart setup).
- Environments where AGPL-3.0 licensing is restricted by enterprise legal guidelines.

---

## 10. Links & Reference

- **Official Website**: https://getlago.com
- **GitHub Repository**: https://github.com/getlago/lago
- **API Reference**: https://docs.getlago.com/api-reference/overview
