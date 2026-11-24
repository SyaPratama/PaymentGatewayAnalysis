[← Master Report](../../payment-gateway-research.md) | [← Category G: Commercial Free-Tier Gateways](../G-commercial-free-tier-gateways.md)

---

# Stripe — Deep-Dive Report

> The global developer gold standard for digital payments, billing, and financial infrastructure.

---

## 1. Overview

Stripe is the world's most developer-acclaimed payment infrastructure company. Founded in 2010 by Patrick and John Collison, Stripe transformed digital commerce by reducing payment acceptance from a multi-month bureaucratic banking ordeal into a few lines of JavaScript and an API call. Processing hundreds of billions of dollars annually, Stripe powers companies from Amazon, Google, and Shopify to early-stage startups.

Stripe provides a comprehensive suite of financial primitives:
- **Payments**: Core acquiring for credit cards, debit cards, and 40+ local payment methods.
- **Billing**: Recurring subscriptions, metered usage-based billing, and invoicing.
- **Connect**: Multi-sided marketplace payments, seller payouts, and escrow holdbacks.
- **Radar**: Machine-learning fraud detection trained across the collective volume of the entire Stripe global network.
- **Elements / Checkout**: Pre-built, PCI-compliant UI components that adapt dynamically to the buyer's device and currency.

---

## 2. Architecture & Data Flow

```
┌────────────────────────────────────────────────────────┐
│               Customer Browser / Device                │
│             Stripe Elements (Hosted Fields)            │
└──────────────────────────┬─────────────────────────────┘
                           │ 1. Card details sent DIRECTLY to Stripe
                           │ 2. Returns payment_method_id (pm_xxx)
┌──────────────────────────▼─────────────────────────────┐
│                 Laravel Backend Server                 │
│         Interacts via official stripe-php SDK          │
└──────────────────────────┬─────────────────────────────┘
                           │ 3. POST /v1/payment_intents (confirm=true)
┌──────────────────────────▼─────────────────────────────┐
│                      Stripe API                        │
│                                                        │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │ Payment Intents Core  │   │ Radar ML Risk Engine │  │
│  │ (3DS 2.0 Auth State)  │   │ (Score: 0 - 99)      │  │
│  └───────────┬───────────┘   └──────────┬───────────┘  │
└──────────────┼──────────────────────────┼──────────────┘
               │                          │
        Card Networks              Issuer 3DS Bank
               ▼                          ▼
     ┌───────────────────┐      ┌───────────────────┐
     │ Visa / Mastercard │      │ 3DS Challenge Flow│
     └───────────────────┘      └───────────────────┘
```

1. **Cardholder Data Isolation**: The customer's credit card number and CVC are entered into an iframe hosted securely on Stripe's domain (`js.stripe.com`). The card details **never touch your Laravel application server**.
2. **Tokenization**: Stripe's servers return a secure, single-use PaymentMethod token (`pm_1N...`).
3. **Intent Confirmation**: Your frontend sends the token to your Laravel backend. Laravel uses its private API key (`sk_live_...`) to confirm a `PaymentIntent`.
4. **Automated 3D Secure 2**: If the issuing bank requires biometric or OTP verification, Stripe's SDK automatically renders the modal challenge.
5. **Webhook Confirmation**: Upon successful bank settlement, Stripe sends a cryptographically signed webhook (`payment_intent.succeeded`) to your Laravel callback endpoint.

---

## 3. Key Features

- **Payment Intents API** — Unified state machine that tracks the complete lifecycle of a customer transaction from initiation to capture.
- **Radar Fraud Detection** — Real-time machine-learning risk scoring trained on billions of global card transactions.
- **Dynamic Payment Methods** — Automatically displays Apple Pay, Google Pay, Klarna, Afterpay, or local European payment methods based on customer geography.
- **Stripe CLI** — Unrivaled local development tooling: stream live webhooks, trigger mock test events, and test edge cases locally without ngrok.
- **Multi-Party Payouts (Stripe Connect)** — Split order totals, deduct marketplace platform fees, and disburse seller balances automatically.

---

## 4. Pricing & TCO Analysis

Stripe operates with transparent pay-as-you-go pricing with zero setup or monthly maintenance fees.

| Transaction Type | Fee Structure |
|---|---|
| **Domestic US Cards** | 2.9% + $0.30 per successful charge |
| **International Cards** | +1.5% cross-border fee |
| **Currency Conversion** | +1.0% if transaction currency differs from payout bank |
| **ACH Direct Debit** | 0.8% (capped at $5.00) |
| **Stripe Billing** | 0.5%–0.7% on recurring volume |
| **Monthly / Gateway Fee**| **$0.00** |

*Volume Comparison:*
- **At $10,000 / mo**: Fee = ~$320 / month (100% justified by zero server overhead)
- **At $100,000 / mo**: Fee = ~$3,200 / month
- **At $1,000,000 / mo**: Fee = ~$25,000–$32,000 / month (At this volume, negotiating custom Interchange++ or migrating to Adyen becomes financially advantageous).

---

## 5. Integration Guide for Laravel

Laravel provides official first-party support for Stripe via **Laravel Cashier** (for subscriptions) or the official `stripe/stripe-php` SDK (for custom e-commerce checkouts).

### Step 1: Install Official SDK
```bash
composer require stripe/stripe-php
```

### Step 2: Implementation of `PaymentGatewayInterface`
```php
namespace App\Services\Payment;

use App\Models\Order;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use Exception;
use Illuminate\Http\Request;
use Stripe\PaymentIntent;
use Stripe\Stripe;
use Stripe\Webhook;

class StripePaymentService implements PaymentGatewayInterface
{
    public function __construct()
    {
        Stripe::setApiKey(config('services.stripe.secret'));
    }

    public function getPaymentChannels(): array
    {
        return [
            ['code' => 'card', 'name' => 'Credit / Debit Card (Stripe)'],
            ['code' => 'apple_pay', 'name' => 'Apple Pay / Google Pay'],
        ];
    }

    public function createTransaction(Order $order, string $paymentMethod): array
    {
        $intent = PaymentIntent::create([
            'amount'   => (int) ($order->total_amount * 100), // convert to cents
            'currency' => strtolower($order->currency ?? 'usd'),
            'metadata' => [
                'order_id'     => (string) $order->id,
                'order_number' => $order->order_number,
            ],
            'automatic_payment_methods' => ['enabled' => true],
        ]);

        return [
            'reference'     => $intent->id,
            'client_secret' => $intent->client_secret,
            'status'        => 'pending',
            'raw'           => $intent->toArray(),
        ];
    }

    public function validateCallback(Request $request): bool
    {
        $sigHeader = $request->header('Stripe-Signature');
        $endpointSecret = config('services.stripe.webhook_secret');

        try {
            Webhook::constructEvent($request->getContent(), $sigHeader, $endpointSecret);
            return true;
        } catch (Exception $e) {
            return false;
        }
    }

    public function parseCallback(Request $request): array
    {
        $payload = $request->json()->all();
        $event = $payload['data']['object'] ?? [];

        $status = 'PENDING';
        if (($payload['type'] ?? '') === 'payment_intent.succeeded') {
            $status = 'PAID';
        } elseif (($payload['type'] ?? '') === 'payment_intent.payment_failed') {
            $status = 'FAILED';
        }

        return [
            'merchant_ref' => (string) ($event['metadata']['order_id'] ?? ''),
            'status'       => $status,
            'reference'    => $event['id'] ?? null,
            'raw'          => $payload,
        ];
    }
}
```

---

## 6. Security & PCI Compliance

- **SAQ-A Eligibility**: By using Stripe Elements, checkout iframes, or Stripe Checkout, all sensitive card details bypass your server entirely. Your PCI compliance burden is restricted to the minimal self-assessment questionnaire (SAQ-A).
- **Cryptographic Webhook Signatures**: Every incoming webhook is signed with an HMAC-SHA256 signature header (`Stripe-Signature`) containing a timestamp and multiple signatures to prevent replay attacks.
- **Mutual TLS**: All API communications require TLS 1.2+ with modern cipher suites.

---

## 7. Scalability & Operational Footprint

- **Zero Infrastructure to Maintain**: Stripe handles all database scaling, PCI vaulting, and multi-region network failover.
- **Extreme Availability**: Stripe consistently maintains 99.999% uptime during major retail events (Black Friday, Cyber Monday).
- **Global Network**: Local acquiring licenses across North America, Europe, Australia, Japan, and Singapore.

---

## 8. Pros & Cons

### Pros
1. Unmatched developer experience: documentation, SDKs, error codes, and local CLI testing
2. Eliminates PCI compliance liability (SAQ-A)
3. Superior conversion rates with adaptive Apple Pay, Google Pay, and Link checkout
4. World-class machine learning fraud prevention (Stripe Radar)
5. Zero upfront, monthly, or account maintenance fees

### Cons
1. **No direct acquiring entity in Indonesia**: Cannot settle directly to Indonesian Rupiah (IDR) bank accounts without an overseas entity (Singapore/US)
2. Higher transaction costs (2.9% + $0.30) than domestic Indonesian Virtual Accounts (Rp 3,500 flat)
3. Unforgiving automated risk algorithms: known to lock accounts in high-chargeback categories with limited human recourse

---

## 9. When to Use vs. When to Avoid

### When to Use
- You sell to international customers in the US, Europe, UK, Canada, Australia, or Japan.
- You need the highest possible developer velocity and conversion rate.
- You operate an international SaaS with recurring card billing.

### When to Avoid
- **Domestic Indonesian e-commerce**: Indonesian consumers overwhelmingly prefer QRIS, GoPay, ShopeePay, and Bank Virtual Accounts (BCA, Mandiri). Stripe does not support these domestic channels natively. Stick with your active TripPay and DOKU gateways.

---

## 10. Links & Reference

- **Official Website**: https://stripe.com
- **API Reference**: https://docs.stripe.com/api
- **Laravel Cashier Docs**: https://laravel.com/docs/billing
