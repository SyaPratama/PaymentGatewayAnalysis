[← Master Report](../../payment-gateway-research.md) | [← Category G: Commercial Free-Tier Gateways](../G-commercial-free-tier-gateways.md)

---

# Xendit — Deep-Dive Report

> The Southeast Asian payments unicorn powering digital transactions across Indonesia, the Philippines, Thailand, and Vietnam.

---

## 1. Overview

Xendit is a premier fintech unicorn backed by Y Combinator that provides modern digital payment infrastructure across Southeast Asia. Widely recognized as the "Stripe of Southeast Asia," Xendit solved the extreme payment fragmentation across emerging Asian markets by building unified, developer-first APIs that bridge traditional bank Virtual Accounts, domestic e-wallets, QR payment schemes, direct debits, and credit cards across Indonesia, the Philippines, Vietnam, and Thailand.

Xendit is an essential architectural benchmark for Indonesian applications planning regional geographic expansion: integrating Xendit allows an engineering team to use a single unified API to accept Indonesian Rupiah (via BCA, Mandiri, QRIS, GoPay, OVO, ShopeePay) and Philippine Pesos (via GCash, Maya, GrabPay, BDO) simultaneously.

---

## 2. Architecture & Data Flow

```
┌────────────────────────────────────────────────────────┐
│                   Laravel Application                   │
│         Uses official xendit/xendit-php SDK             │
└──────────────────────────┬─────────────────────────────┘
                           │ 1. POST /v2/invoices (API Secret Key)
┌──────────────────────────▼─────────────────────────────┐
│                       Xendit API                       │
│                                                        │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │ Multi-Country Router  │   │ xenPlatform Engine   │  │
│  │ (IDR, PHP, THB, VND)  │   │ (Sub-accounts/Escrow)│  │
│  └───────────┬───────────┘   └──────────┬───────────┘  │
└──────────────┼──────────────────────────┼──────────────┘
               │                          │
        Indonesian Rails           Philippine Rails
               ▼                          ▼
     ┌───────────────────┐      ┌───────────────────┐
     │ BCA VA / QRIS /   │      │ GCash / Maya /    │
     │ GoPay / OVO       │      │ BDO Unibank       │
     └───────────────────┘      └───────────────────┘
```

1. **xenInvoice**: Xendit's flagship hosted checkout page. Your Laravel app specifies the external ID, currency, amount, and customer details, and receives a hosted invoice URL (`https://checkout.xendit.co/web/...`) that dynamically adapts to the customer's country.
2. **xenPlatform**: A dedicated marketplace and sub-account infrastructure allowing platforms to split transactions, hold funds in escrow, and disburse merchant balances automatically.
3. **Automated Batch Disbursements**: Highly reliable 24/7 bank payouts via Indonesia's BI-FAST network and Philippine local clearing rails.
4. **Webhook Delivery with Verification Tokens**: Delivers JSON callbacks signed with a secret verification token configurable in the merchant dashboard.

---

## 3. Key Features

- **Pan-Southeast Asian Connectivity** — A single integration covers Indonesia, Philippines, Vietnam, and Thailand.
- **Hosted xenInvoice Page** — Responsive, localized checkout page with automated QRIS and Virtual Account countdown timers.
- **xenPlatform Sub-Accounts** — Native marketplace architecture for managing merchant vendors, split fees, and automated commission retention.
- **Direct Debit & Recurring Subscriptions** — Link bank accounts (BCA OneKlik, BRI Direct Debit) or credit cards for recurring tokenized debits.
- **24/7 Real-Time Payouts** — Instant programmatic withdrawals directly into local bank accounts via BI-FAST.

---

## 4. Pricing & Fee Structure

Xendit charges zero setup fees, zero monthly platform fees, and operates entirely on a transparent per-transaction basis:

| Payment Method | Indonesian Pricing (IDR) | Philippine Pricing (PHP) |
|---|---|---|
| **Credit / Debit Cards** | 2.9% + Rp 2,000 | 3.5% + ₱15 |
| **Virtual Accounts** | Rp 4,500 flat per paid VA | ₱20 per transaction |
| **QRIS / E-Wallets** | 0.7% (QRIS) / 1.5% (E-Wallets) | 1.8%–2.0% (GCash, Maya) |
| **Direct Debit (BCA OneKlik)** | 1.9% per transaction | ₱15 – ₱25 flat |
| **Bank Disbursements** | Rp 2,800 – Rp 5,000 per transfer | ₱10 – ₱15 per transfer |

---

## 5. Integration Guide for This Project

To add Xendit alongside this project's existing TripPay and DOKU gateways:

### Step 1: Install Official SDK
```bash
composer require xendit/xendit-php
```

### Step 2: Add Configuration (`config/xendit.php`)
```php
<?php

return [
    'secret_key'      => env('XENDIT_SECRET_KEY'),
    'webhook_token'   => env('XENDIT_WEBHOOK_VERIFICATION_TOKEN'),
    'invoice_duration'=> (int) env('XENDIT_INVOICE_DURATION', 86400), // 24 hours
];
```

### Step 3: Implement `PaymentGatewayInterface`
```php
namespace App\Services\Payment;

use App\Models\Order;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use Exception;
use Illuminate\Http\Request;
use Xendit\Configuration;
use Xendit\Invoice\CreateInvoiceRequest;
use Xendit\Invoice\InvoiceApi;

class XenditPaymentService implements PaymentGatewayInterface
{
    protected InvoiceApi $apiInstance;

    public function __construct()
    {
        Configuration::setServerKey(config('xendit.secret_key'));
        $this->apiInstance = new InvoiceApi();
    }

    public function getPaymentChannels(): array
    {
        return [
            ['code' => 'xendit_invoice', 'name' => 'All Regional Methods (Xendit Invoice)'],
            ['code' => 'xendit_qris', 'name' => 'QRIS (Xendit)'],
            ['code' => 'xendit_va', 'name' => 'Virtual Account (BCA, Mandiri, BRI)'],
        ];
    }

    public function createTransaction(Order $order, string $paymentMethod): array
    {
        $createInvoiceRequest = new CreateInvoiceRequest([
            'external_id'      => 'ORDER-' . $order->id . '-' . time(),
            'amount'           => (float) $order->total_amount,
            'description'      => "Payment for Order #{$order->order_number}",
            'invoice_duration' => config('xendit.invoice_duration', 86400),
            'customer'         => [
                'given_names' => $order->customer_name ?? 'Customer',
                'email'       => $order->customer_email ?? 'customer@example.com',
            ],
            'success_redirect_url' => route('orders.show', $order->id),
        ]);

        try {
            $invoice = $this->apiInstance->createInvoice($createInvoiceRequest);

            return [
                'reference'    => $invoice->getId(),
                'redirect_url' => $invoice->getInvoiceUrl(),
                'status'       => 'pending',
                'raw'          => (array) $invoice,
            ];
        } catch (Exception $e) {
            return [
                'status' => 'failed',
                'error'  => $e->getMessage(),
                'raw'    => [],
            ];
        }
    }

    public function validateCallback(Request $request): bool
    {
        $callbackToken = $request->header('x-callback-token');
        $expectedToken = config('xendit.webhook_token');

        return !empty($callbackToken) && hash_equals($expectedToken, $callbackToken);
    }

    public function parseCallback(Request $request): array
    {
        $payload = $request->all();
        $status = strtoupper($payload['status'] ?? '');
        $externalId = $payload['external_id'] ?? '';

        $normalizedStatus = 'PENDING';
        if ($status === 'PAID' || $status === 'SETTLED') {
            $normalizedStatus = 'PAID';
        } elseif ($status === 'EXPIRED') {
            $normalizedStatus = 'FAILED';
        }

        return [
            'merchant_ref' => $externalId,
            'status'       => $normalizedStatus,
            'reference'    => $payload['id'] ?? null,
            'raw'          => $payload,
        ];
    }
}
```

---

## 6. Comparison: Xendit vs. TripPay vs. Midtrans

| Metric | Xendit | TripPay (Current) | Midtrans |
|---|:---:|:---:|:---:|
| **Geographic Scope** | **Pan-SEA (ID, PH, VN, TH)** | Indonesia Domestic Only | Indonesia Domestic Only |
| **API Philosophy** | Stripe-like Clean REST | Pragmatic / Simple | Enterprise / Comprehensive |
| **Marketplace Support**| xenPlatform (Advanced) | Basic Split | Iris Disbursements |
| **Virtual Account Cost**| Rp 4,500 / txn | **Rp 750 – Rp 4,250** (Cheapest)| Rp 4,000 / txn |
| **International Payouts**| Real-time cross-border | Domestic IDR only | Domestic IDR only |

---

## 7. Links & Reference

- **Official Website**: https://xendit.co
- **API Reference**: https://developers.xendit.co/api-reference/
- **PHP SDK Repository**: https://github.com/xendit/xendit-php
