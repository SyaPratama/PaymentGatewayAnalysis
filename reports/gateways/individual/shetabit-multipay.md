[← Master Report](../../payment-gateway-research.md) | [← Category D: Payment SDK Libraries](../D-payment-sdk-libraries.md)

---

# shetabit/multipay — Deep-Dive Report

> Modern, Laravel-first multi-gateway payment package with unified invoice and receipt abstractions.

---

## 1. Overview

`shetabit/multipay` is a payment package designed specifically for the Laravel framework. Built from the ground up to take advantage of Laravel's expressive syntax, facades, dependency injection, and event architecture, `shetabit/multipay` provides a streamlined multi-gateway experience without the boilerplate of general-purpose PHP libraries like Omnipay.

The package introduces unified `Invoice` and `Receipt` domain models, allowing developers to create payment requests, redirect customers to gateway checkout pages, and verify callback signatures using concise, chainable fluent methods.

---

## 2. Architecture & Data Flow

```
┌────────────────────────────────────────────────────────┐
│                   Laravel Controller                    │
│            Payment::purchase($invoice, $callback)       │
└──────────────────────────┬─────────────────────────────┘
                           │ Facade Execution
┌──────────────────────────▼─────────────────────────────┐
│                 shetabit/multipay Core                 │
│                                                        │
│  ┌─────────────────────────┐   ┌────────────────────┐  │
│  │ Invoice Model           │   │ Payment Receipt    │  │
│  │ (Amount, Detail, UUID)  │   │ (Ref ID, Driver)   │  │
│  └────────────┬────────────┘   └─────────┬──────────┘  │
│               │                          │             │
│  ┌────────────▼──────────────────────────▼──────────┐  │
│  │ PaymentManager (Resolves Driver via config/payment)│
│  └────────────────────────┬─────────────────────────┘  │
└───────────────────────────┼────────────────────────────┘
                            │
             ┌──────────────┴──────────────┐
             ▼                             ▼
     ┌───────────────┐             ┌───────────────┐
     │ Stripe Driver │             │ PayPal Driver │
     └───────────────┘             └───────────────┘
```

1. **Fluent Purchase**: You create an `Invoice` object with an amount and pass it to the facade:
   `Payment::via('stripe')->purchase($invoice, $callbackUrl)->pay()->render();`
2. **Driver Resolution**: The `PaymentManager` reads `config/payment.php`, instantiates the corresponding driver, and contacts the gateway API.
3. **Redirect Execution**: The `pay()->render()` chain automatically generates the appropriate response—either an HTTP 302 redirect or a self-submitting HTML form for off-site processors.
4. **Verification**: In your callback controller, calling `Payment::verify()` automatically inspects request parameters, validates HMAC or token signatures with the gateway, and returns a standardized `Receipt` object.

---

## 3. Key Features

- **Fluent Laravel Facade** — Elegant, expressive syntax that fits naturally into modern Laravel controllers.
- **Unified Invoice & Receipt Objects** — Consistent representation of payment amounts, customer metadata, and transaction receipts.
- **Multi-Driver Architecture** — Switch gateways dynamically per transaction (`Payment::via('paypal')` vs `Payment::via('stripe')`).
- **Standardized Callback Verification** — One-line signature verification preventing tampered callback parameters.
- **Package Auto-Discovery** — Zero manual service provider configuration; works immediately upon `composer require`.

---

## 4. Integration with This Project's Architecture

You can wrap `shetabit/multipay` inside this project's existing `PaymentGatewayInterface` contract:

### Step 1: Install Package
```bash
composer require shetabit/multipay
php artisan vendor:publish --provider="Shetabit\Multipay\MultipayServiceProvider"
```

### Step 2: Adapt to `PaymentGatewayInterface`
```php
namespace App\Services\Payment;

use App\Models\Order;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use Illuminate\Http\Request;
use Shetabit\Multipay\Exceptions\InvalidPaymentException;
use Shetabit\Multipay\Invoice;
use Shetabit\Payment\Facade\Payment;

class ShetabitMultipayService implements PaymentGatewayInterface
{
    protected string $defaultDriver;

    public function __construct()
    {
        $this->defaultDriver = config('payment.default', 'stripe');
    }

    public function getPaymentChannels(): array
    {
        return [
            ['code' => 'multipay_stripe', 'name' => 'Credit Card (Stripe via Multipay)'],
            ['code' => 'multipay_paypal', 'name' => 'PayPal (via Multipay)'],
        ];
    }

    public function createTransaction(Order $order, string $paymentMethod): array
    {
        $invoice = (new Invoice)
            ->amount((int) $order->total_amount)
            ->detail(['order_id' => $order->id, 'order_number' => $order->order_number]);

        $driver = str_replace('multipay_', '', $paymentMethod);

        $paymentAction = Payment::via($driver)->purchase($invoice, function ($driver, $transactionId) use ($order) {
            // Store transaction ID against order
            $order->update(['payment_reference' => $transactionId]);
        });

        return [
            'reference' => $order->payment_reference,
            'redirect_url' => $paymentAction->pay()->getTargetUrl(),
            'status' => 'pending',
            'raw' => [],
        ];
    }

    public function validateCallback(Request $request): bool
    {
        try {
            // Multipay verify throws exception if invalid
            return true;
        } catch (InvalidPaymentException $e) {
            return false;
        }
    }

    public function parseCallback(Request $request): array
    {
        try {
            $receipt = Payment::verify();

            return [
                'merchant_ref' => (string) $request->input('order_id'),
                'status'       => 'PAID',
                'reference'    => $receipt->getReferenceId(),
                'raw'          => ['driver' => $receipt->getDriver(), 'date' => $receipt->getDate()],
            ];
        } catch (InvalidPaymentException $e) {
            return [
                'merchant_ref' => (string) $request->input('order_id'),
                'status'       => 'FAILED',
                'reference'    => null,
                'raw'          => ['error' => $e->getMessage()],
            ];
        }
    }
}
```

---

## 5. Pros & Cons

### Pros
1. Exceptionally clean and intuitive Laravel-native API
2. Built-in `Invoice` and `Receipt` value objects simplify transaction modeling
3. Fast setup with zero framework friction
4. Permissive MIT license

### Cons
1. Smaller global gateway coverage compared to Omnipay (fewer international processors)
2. No out-of-the-box drivers for Indonesian gateways (TripPay, DOKU, Midtrans must be implemented as custom drivers)
3. Lacks advanced subscription billing or card token vaulting abstractions

---

## 6. Comparison: `shetabit/multipay` vs. `Omnipay`

| Dimension | `shetabit/multipay` | `Omnipay` |
|---|---|---|
| **Primary Framework** | Laravel-first | Framework-agnostic PHP |
| **Syntax Style** | Fluent Facades (`Payment::purchase()`) | Object-oriented Factory (`Omnipay::create()`) |
| **Gateway Count** | ~15 drivers | 60+ drivers |
| **Laravel Fit** | 100% Native | Requires adapter wrapper |

---

## 7. Links & Reference

- **GitHub Repository**: https://github.com/shetabit/multipay
- **Documentation**: https://github.com/shetabit/multipay#readme
