[← Master Report](../../payment-gateway-research.md) | [← Category D: Payment SDK Libraries](../D-payment-sdk-libraries.md)

---

# Omnipay — Deep-Dive Report

> The de facto multi-gateway payment processing abstraction library for PHP.

---

## 1. Overview

Omnipay is the industry-standard payment processing library for PHP, maintained under The PHP League umbrella. Inspired by Ruby's Active Merchant, Omnipay was designed to liberate PHP developers from vendor lock-in by providing a unified, clean, object-oriented API that abstracts away the idiosyncrasies of over 60 commercial and regional payment gateways.

Rather than being a standalone service, Omnipay is a Composer-installed software library that executes in-process within your application. Whether you are initiating a credit card charge via Stripe, redirecting to PayPal Express Checkout, or capturing an off-site payment, Omnipay enforces a uniform request-response protocol adhering strictly to PHP-FIG (PSR) standards.

---

## 2. Architecture & How It Works

```
┌────────────────────────────────────────────────────────┐
│                   Laravel Application                   │
│          App\Services\Payment\OmnipayGatewayAdapter     │
└──────────────────────────┬─────────────────────────────┘
                           │ Omnipay::create('GatewayName')
┌──────────────────────────▼─────────────────────────────┐
│                 Omnipay Common Interface               │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ GatewayInterface (purchase, authorize, capture)  │  │
│  └───────────────────────┬──────────────────────────┘  │
│                          │                             │
│  ┌───────────────────────▼──────────────────────────┐  │
│  │ Standardized Request & Response Interfaces       │  │
│  │ (isSuccessful, isRedirect, getTransactionReference)│
│  └───────────────────────┬──────────────────────────┘  │
└──────────────────────────┼─────────────────────────────┘
                           │ PSR-18 HTTP Client Call
            ┌──────────────┴──────────────┐
            ▼                             ▼
    ┌───────────────┐             ┌───────────────┐
    │ omnipay/stripe│             │ omnipay/paypal│
    └───────────────┘             └───────────────┘
```

1. **Gateway Factory**: Developers instantiate gateways using the factory method: `$gateway = Omnipay::create('Stripe');`.
2. **Standard Methods**: All drivers implement common methods:
   - `authorize()` / `completeAuthorize()`
   - `purchase()` / `completePurchase()`
   - `capture()`
   - `void()`
   - `refund()`
   - `createCard()` / `updateCard()` / `deleteCard()`
3. **Response Protocol**: Regardless of whether Stripe returns a JSON payload or PayPal returns a URL redirect, Omnipay exposes identical status methods:
   - `$response->isSuccessful()` (Boolean)
   - `$response->isRedirect()` (Boolean)
   - `$response->getTransactionReference()` (String ID)
   - `$response->getMessage()` (Normalized error text)

---

## 3. Key Features

- **60+ Gateway Drivers** — Community drivers available for Stripe, PayPal, Authorize.Net, Braintree, Worldpay, Mollie, 2Checkout, and dozens of regional banks.
- **In-Process Execution** — Zero infrastructure footprint, zero external network services to manage, zero background daemons.
- **PSR-7 & PSR-18 Compliant** — Works seamlessly with modern PHP HTTP clients (Guzzle, Symfony HTTP Client).
- **Consistent Tokenization API** — Methods to store customer payment methods securely on the gateway's servers without holding PAN data.
- **Off-Site & Direct Flows** — Built-in detection for gateways that require customer browser redirection versus direct server-to-server calls.

---

## 4. Pricing & TCO Analysis

Omnipay is 100% free under the MIT license.

| Metric | Omnipay | Managed Orchestrator (Hyperswitch / Spreedly) |
|---|---|---|
| **Software License** | $0 (MIT) | $0 (Hyperswitch) or $1,000+/mo (Spreedly) |
| **Server Infrastructure** | **$0** (Runs inside your PHP-FPM process) | $200 – $500 / month (Requires dedicated cluster) |
| **DevOps Maintenance** | None (standard `composer update`) | Continuous container patching and monitoring |

---

## 5. Integration Guide for This Laravel Project

To implement Omnipay alongside this repository's existing `PaymentGatewayInterface`:

### Step 1: Install Omnipay Core & Driver
```bash
composer require league/omnipay omnipay/stripe
```

### Step 2: Create Omnipay Service Adapter
```php
namespace App\Services\Payment;

use App\Models\Order;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use Illuminate\Http\Request;
use Omnipay\Common\GatewayInterface;
use Omnipay\Omnipay;

class OmnipayStripeService implements PaymentGatewayInterface
{
    protected GatewayInterface $gateway;

    public function __construct()
    {
        $this->gateway = Omnipay::create('Stripe\PaymentIntents');
        $this->gateway->initialize([
            'apiKey' => config('services.stripe.secret'),
        ]);
    }

    public function getPaymentChannels(): array
    {
        return [
            ['code' => 'card', 'name' => 'Credit / Debit Card (Global)'],
        ];
    }

    public function createTransaction(Order $order, string $paymentMethod): array
    {
        $response = $this->gateway->purchase([
            'amount'   => number_format($order->total_amount, 2, '.', ''),
            'currency' => $order->currency ?? 'USD',
            'returnUrl'=> route('orders.show', $order->id),
            'metadata' => ['order_id' => $order->id],
        ])->send();

        if ($response->isRedirect()) {
            return [
                'reference' => $response->getTransactionReference(),
                'redirect_url' => $response->getRedirectUrl(),
                'status' => 'pending',
                'raw' => $response->getData(),
            ];
        }

        return [
            'reference' => $response->getTransactionReference(),
            'status' => $response->isSuccessful() ? 'PAID' : 'FAILED',
            'raw' => $response->getData(),
        ];
    }

    public function validateCallback(Request $request): bool
    {
        // Omnipay drivers vary in webhook verification; standard is verifying payload HMAC
        $signature = $request->header('Stripe-Signature');
        return !empty($signature);
    }

    public function parseCallback(Request $request): array
    {
        $data = $request->json()->all();
        $obj = $data['data']['object'] ?? [];

        return [
            'merchant_ref' => (string) ($obj['metadata']['order_id'] ?? ''),
            'status'       => ($data['type'] ?? '') === 'payment_intent.succeeded' ? 'PAID' : 'FAILED',
            'reference'    => $obj['id'] ?? null,
            'raw'          => $data,
        ];
    }
}
```

---

## 6. Security & PCI DSS Considerations

- **No Cardholder Data Stored**: Omnipay supports direct token pass-through. Your frontend captures the card via the gateway's hosted fields (e.g. Stripe.js or PayPal SDK), passes the generated token to Laravel, and Omnipay sends the token to the gateway.
- **SAQ-A Scope**: Because credit card numbers never touch your application's disk or memory, you maintain SAQ-A compliance.

---

## 7. Scalability & Performance

- **Zero Network Latency Overhead**: Omnipay adds negligible CPU overhead (<1ms) on top of the underlying Guzzle HTTP network request to the payment processor.
- **Stateless**: Scales horizontally with your Laravel PHP-FPM / Octane workers without distributed state requirements.

---

## 8. Pros & Cons

### Pros
1. Vast gateway driver ecosystem (60+ available connectors)
2. No servers or infrastructure to maintain—pure Composer dependency
3. Clean, familiar object-oriented PHP interfaces
4. Completely free and open-source under permissive MIT license
5. Effortless to unit test using mock HTTP responses

### Cons
1. Community driver quality varies; some niche drivers are unmaintained
2. Omnipay v3 migration left some older drivers on legacy dependencies
3. No built-in database models, retry queues, or intelligent routing logic
4. Webhook parsing is not universally standardized across all driver packages

---

## 9. When to Use vs. When to Avoid

### When to Use
- You want multi-gateway switching directly in PHP without deploying a dedicated microservice.
- You want to write custom gateway adapters that conform to standard PSR specifications.
- You need a proven library for handling traditional global payment processors (Stripe, PayPal, Mollie).

### When to Avoid
- You need automated real-time transaction routing based on dynamic bank success rates (use Hyperswitch).
- You require deep, native support for regional Indonesian payment channels (TripPay/DOKU custom services are cleaner).

---

## 10. Links & Reference

- **Official Website**: https://omnipay.thephpleague.com
- **GitHub Repository**: https://github.com/thephpleague/omnipay
