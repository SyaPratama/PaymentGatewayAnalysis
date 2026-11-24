[← Master Report](../../payment-gateway-research.md) | [← Category A: Payment Orchestrators](../A-payment-orchestrators.md)

---

# Hyperswitch — Deep-Dive Report

> Open-source, high-performance payment orchestrator written in Rust by Juspay.

---

## 1. Overview

Hyperswitch is a modern, enterprise-grade payment orchestration platform developed and open-sourced by Juspay, India's leading payment infrastructure provider (processing over 50M daily transactions). Hyperswitch acts as a smart abstraction and routing layer sitting between your customer-facing applications and 50+ underlying payment processors. 

Instead of locking an application to a single processor or writing bespoke integration logic for every provider, Hyperswitch exposes a unified API. Behind this API, its rule engine dynamically routes each transaction to the optimal processor based on real-time success rates, interchange fees, geographic latency, or custom merchant business rules. Built in Rust with asynchronous I/O, Hyperswitch achieves sub-200ms p95 latencies while reducing payment drop-offs by 5% to 15%.

---

## 2. Architecture & How It Works

```
┌────────────────────────────────────────────────────────┐
│               Client / Web Checkout                     │
│      (Hyperswitch SDK / Pre-built Unified Elements)     │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTPS (Payment Intent)
┌──────────────────────────▼─────────────────────────────┐
│                 Hyperswitch Core Server                │
│                     (Rust Binary)                      │
│                                                        │
│  ┌─────────────────┐ ┌───────────────┐ ┌────────────┐  │
│  │ Smart Router    │ │ Card Vault    │ │ 3DS 2.0    │  │
│  │ (Decision Rule) │ │ (PCI-DSS L1)  │ │ Orchestrator│ │
│  └────────┬────────┘ └───────────────┘ └────────────┘  │
└───────────┼────────────────────────────────────────────┘
            │
            ├───────────────┬───────────────┐
            ▼               ▼               ▼
     ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
     │ Connector:  │ │ Connector:  │ │ Connector:  │
     │   Stripe    │ │    Adyen    │ │  Razorpay   │
     └─────────────┘ └─────────────┘ └─────────────┘
```

1. **Client Layer**: Uses the Hyperswitch unified checkout SDK (React, iOS, Android, Flutter) to collect payment method credentials safely.
2. **Core Router**: Hyperswitch receives the payment request, evaluates routing rules (e.g. "If currency is IDR, try Midtrans; if failed, fallback to DOKU"), and checks card BIN data.
3. **Card Vault**: Built-in PCI DSS Level 1 compliant card vault stores and tokenizes PAN data if self-hosting with vault capabilities.
4. **Connector Adapters**: Strongly typed Rust connector modules translate the internal payment model into vendor-specific HTTP payloads.
5. **Event Bus & Storage**: Uses PostgreSQL for transactional state, Redis for distributed caching and rate-limiting, and Kafka for asynchronous webhook and event fan-out.

---

## 3. Key Features

- **Smart Dynamic Routing** — Define volume splits, cost-minimization rules, or success-rate-maximizing algorithms.
- **Automatic Cascading & Retries** — If a primary processor returns a 5xx error or soft decline, Hyperswitch automatically attempts a fallback processor before returning an error to the user.
- **50+ Pre-Built Connectors** — Integrations with Stripe, Adyen, Braintree, PayPal, Razorpay, Worldpay, Checkout.com, Klarna, etc.
- **Unified 3D Secure (3DS)** — Native 3DS 2.0 orchestration handling challenge flows uniformly across processors.
- **Card Vault & Network Tokenization** — Store cardholder data securely without being locked to a single processor's token vault.
- **Unified Refund & Dispute Management** — Single API to initiate refunds and manage chargebacks regardless of processor.
- **Unified Analytics Dashboard** — Centralized visualization of payment conversion rates, failure codes, and connector health.
- **Webhooks Normalization** — Dispatches standardized webhook events (`payment_succeeded`, `payment_failed`) to your application.

---

## 4. Pricing & Total Cost of Ownership (TCO)

Hyperswitch software is 100% free under the Apache-2.0 license. Operating costs stem entirely from server hosting and engineering operations.

| Monthly Volume | Infrastructure (AWS/GCP) | Software License | PSP Processing Fees | Estimated TCO / mo |
|---|---|---|---|---|
| **$10,000 / mo** (Small) | ~$150 – $250 | $0 | Standard (2.9% + $0.30) | ~$450 – $550 |
| **$100,000 / mo** (Medium) | ~$300 – $500 | $0 | Standard or blended | ~$3,200 – $3,500 |
| **$1,000,000 / mo** (Enterprise) | ~$800 – $1,500 | $0 | Negotiated (~1.5% - 2%) | ~$16,000 – $22,000 |

*ROI Benefit:* At $1M/month, reducing payment failure rates by just 3% through smart routing recovers $30,000/month in revenue—vastly exceeding the infrastructure cost.

---

## 5. Integration Guide for Laravel

Hyperswitch exposes a clean REST API. To integrate it into this Laravel application alongside the existing `PaymentGatewayInterface`:

### Step 1: Add Configuration (`config/hyperswitch.php`)

```php
<?php

return [
    'api_key'    => env('HYPERSWITCH_API_KEY'),
    'publishable_key' => env('HYPERSWITCH_PUBLISHABLE_KEY'),
    'base_url'   => env('HYPERSWITCH_BASE_URL', 'http://localhost:8080'),
    'profile_id' => env('HYPERSWITCH_PROFILE_ID'),
];
```

### Step 2: Implement Service Class

```php
namespace App\Services\Payment;

use App\Models\Order;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class HyperswitchPaymentService implements PaymentGatewayInterface
{
    protected string $baseUrl;
    protected string $apiKey;
    protected string $profileId;

    public function __construct()
    {
        $this->baseUrl = config('hyperswitch.base_url');
        $this->apiKey = config('hyperswitch.api_key');
        $this->profileId = config('hyperswitch.profile_id');
    }

    public function getPaymentChannels(): array
    {
        return [
            ['code' => 'card', 'name' => 'Credit / Debit Card'],
            ['code' => 'klarna', 'name' => 'Klarna Pay Later'],
        ];
    }

    public function createTransaction(Order $order, string $paymentMethod): array
    {
        $response = Http::withHeaders([
            'api-key' => $this->apiKey,
            'Content-Type' => 'application/json',
        ])->post("{$this->baseUrl}/payments", [
            'amount' => (int) ($order->total_amount * 100), // cents
            'currency' => $order->currency ?? 'USD',
            'order_id' => (string) $order->id,
            'customer_id' => (string) $order->user_id,
            'profile_id' => $this->profileId,
            'confirm' => false,
        ]);

        $data = $response->json();

        return [
            'reference' => $data['payment_id'] ?? null,
            'client_secret' => $data['client_secret'] ?? null,
            'status' => $data['status'] ?? 'pending',
            'raw' => $data,
        ];
    }

    public function validateCallback(Request $request): bool
    {
        // Hyperswitch webhook signature check (HMAC-SHA512)
        $signature = $request->header('X-Webhook-Signature');
        $secret = config('hyperswitch.webhook_secret');
        $expected = hash_hmac('sha512', $request->getContent(), $secret);

        return hash_equals($expected, (string) $signature);
    }

    public function parseCallback(Request $request): array
    {
        $payload = $request->json()->all();
        $content = $payload['content']['object'] ?? [];

        return [
            'merchant_ref' => $content['order_id'] ?? '',
            'status' => $content['status'] === 'succeeded' ? 'PAID' : 'FAILED',
            'reference' => $content['payment_id'] ?? null,
            'raw' => $payload,
        ];
    }
}
```

---

## 6. Security & PCI Compliance

- **PCI DSS Level 1 Certified**: When using Hyperswitch's pre-built client SDKs, card details are posted directly from the user's browser to the Hyperswitch server.
- **SAQ Scope Reduction**: If Hyperswitch is hosted in a segregated VPC or using hosted elements, your Laravel application remains in the lightweight **SAQ-A** compliance scope.
- **Vault Tokenization**: PAN data is encrypted with AES-256-GCM. Decryption keys can be integrated with AWS KMS or HashiCorp Vault.

---

## 7. Scalability & Performance

- **Rust Concurrency**: Built on Tokio async runtime; handles 10,000+ concurrent connections per node with minimal RAM footprint (~200MB idle).
- **Horizontal Scaling**: Stateless app nodes scale horizontally behind an Application Load Balancer. State is isolated in PostgreSQL and Redis.
- **Failover**: Distributed health checks continuously ping connectors. If an upstream PSP degrades, traffic is redirected within 500ms.

---

## 8. Pros & Cons

### Pros
1. True independence from processor lock-in
2. Smart routing immediately recaptures failed transactions
3. Blazing fast Rust execution with minimal memory usage
4. Open-source Apache-2.0 license with active corporate backing
5. Unified reporting and dispute interface across 50+ PSPs

### Cons
1. Substantial infrastructure requirements (Postgres, Redis, Kafka)
2. Requires dedicated DevOps personnel to maintain clusters
3. Overkill for small applications using 1 or 2 local gateways
4. Relatively new project (launched in 2023) compared to legacy gateways
5. Complex initial rule configuration

---

## 9. Comparison with Alternatives

| Feature | Hyperswitch | Spreedly (Commercial) | Primo (Adyen / Stripe Direct) |
|---|:---:|:---:|:---:|
| **License** | Open Source (Apache-2.0) | Proprietary SaaS | Proprietary SaaS |
| **Monthly Base Cost** | $0 (+ Infra ~$200) | $1,000+ / mo | $0 |
| **Routing Control** | Full Custom Rules | Pre-configured | Locked to single PSP |
| **Card Vault Ownership** | You own the database | Vendor lock-in | Vendor lock-in |
| **Latency (p95)** | <200ms | ~450ms | ~300ms |

---

## 10. When to Use vs. When to Avoid

### When to Use
- You process over **$100K/month** across multiple currencies.
- You operate in multiple geographical regions and need localized acquirers.
- High transaction failure rates are directly impacting gross revenue.

### When to Avoid
- You operate exclusively in Indonesia with TripPay and DOKU (your existing architecture is simpler and cheaper).
- You process less than 10,000 transactions/month.
- Your team lacks DevOps capacity to manage Docker/Kubernetes clusters.

---

## 11. Links & Reference

- **GitHub Repository**: https://github.com/juspay/hyperswitch
- **Official Documentation**: https://docs.hyperswitch.io
- **API Reference**: https://api-reference.hyperswitch.io
