[← Master Report](../../payment-gateway-research.md) | [← Category G: Commercial Free-Tier Gateways](../G-commercial-free-tier-gateways.md)

---

# Midtrans — Deep-Dive Report

> The premier Indonesian payment gateway powering GoTo, Tokopedia, and thousands of Southeast Asian merchants.

---

## 1. Overview

Midtrans is widely regarded as the benchmark payment gateway for developer experience, reliability, and payment channel coverage in Indonesia. Originally founded as Veritrans Indonesia in 2012, Midtrans was acquired by Gojek in 2017 and now forms the payment infrastructure backbone of GoTo (the combined tech conglomerate of Gojek and Tokopedia).

Midtrans provides Indonesian merchants with turnkey payment acceptance covering every relevant domestic payment method:
- **E-Wallets**: Native GoPay App-to-App deep linking, ShopeePay, DANA.
- **National QR**: Dynamic QRIS supporting all Indonesian bank and e-wallet scanning apps.
- **Bank Virtual Accounts**: Direct automated VA integration for BCA, Mandiri, BNI, BRI, Permata, and CIMB Niaga.
- **Over-The-Counter (OTC)**: Cash payment collection at Indomaret and Alfamart convenience stores nationwide.
- **Cards**: Full 3D Secure 2.0 Visa, Mastercard, JCB, and American Express card acquiring.

---

## 2. Architecture & How It Works

Midtrans offers two distinct integration modes:

```
┌────────────────────────────────────────────────────────┐
│                   Customer Checkout                     │
│               (Midtrans Snap Modal / Redirect)         │
└──────────────────────────┬─────────────────────────────┘
                           │ 1. Client loads Snap.js with Snap Token
                           │ 2. Customer selects GoPay / BCA VA / QRIS
┌──────────────────────────▼─────────────────────────────┐
│                 Laravel Backend Server                 │
│               (App\Services\Payment\Midtrans)          │
└──────────────────────────┬─────────────────────────────┘
                           │ 3. POST /snap/v1/transactions (ServerKey)
┌──────────────────────────▼─────────────────────────────┐
│                     Midtrans API                       │
│                                                        │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │ Core API / Snap Engine│   │ Aegis Fraud Engine   │  │
│  │ (VA, QRIS, GoPay deep)│   │ (Trained on Gojek)   │  │
│  └───────────┬───────────┘   └──────────┬───────────┘  │
└──────────────┼──────────────────────────┼──────────────┘
               │                          │
        Indonesian Banks           GoTo E-Wallet Rails
               ▼                          ▼
     ┌───────────────────┐      ┌───────────────────┐
     │ BCA / Mandiri /BNI│      │ GoPay / ShopeePay │
     └───────────────────┘      └───────────────────┘
```

1. **Midtrans Snap**: A pre-built modal pop-up or redirect checkout page. Your Laravel backend calls Midtrans with order details to get a `snap_token`, and the customer completes payment in an optimized iframe.
2. **Core API**: A fully headless, direct server-to-server API. Your Laravel backend calls endpoints like `/v2/charge` to generate raw Virtual Account numbers or dynamic QRIS image URLs, allowing you to build completely custom checkout UIs.
3. **Aegis Fraud Detection**: Built-in machine learning fraud detection specifically calibrated to Indonesian consumer purchasing patterns and card fraud vectors.
4. **Iris Payouts**: An automated API service enabling programmatic bank disbursements and marketplace payouts across 100+ Indonesian commercial banks.

---

## 3. Key Features

- **Comprehensive Indonesian Rails** — Unrivaled coverage of GoPay, ShopeePay, BCA VA, Mandiri VA, QRIS, and convenience store retail chains.
- **GoPay App-to-App Redirection** — On mobile devices, automatically opens the Gojek/GoPay app for instant biometric payment without typing account numbers.
- **Snap Drop-In UI** — Responsive checkout modal embeddable with minimal frontend JavaScript.
- **Interactive Sandbox & Simulator** — Best developer testing tools in Indonesia: simulated Virtual Account payment triggers, QRIS test scanners, and mock bank responses.
- **Aegis Fraud Shield** — Rules engine for blocking suspicious BIN ranges, velocity throttling, and risk scoring.

---

## 4. Pricing & Fee Structure

Midtrans operates on a standard commercial pay-as-you-go model with **Rp 0 monthly maintenance fee** and **Rp 0 setup fee**:

| Payment Method | Merchant Fee | Settlement Time |
|---|---|---|
| **Credit / Debit Cards** | 2.9% + Rp 2,000 per transaction | T+2 to T+7 business days |
| **Bank Virtual Account (BCA, Mandiri, BNI, BRI)** | Rp 4,000 – Rp 4,500 per transaction | T+1 business day |
| **QRIS (GoPay, OVO, BCA, etc.)** | 0.7% (Bank Indonesia standard) | T+1 to T+2 business days |
| **GoPay & ShopeePay** | 1.5% – 2.0% per transaction | T+1 business day |
| **Alfamart / Indomaret** | Rp 5,000 per transaction | T+2 business days |

---

## 5. Integration Guide for This Project

To add Midtrans as a third payment gateway alongside your active TripPay and DOKU implementations:

### Step 1: Install Official SDK
```bash
composer require midtrans/midtrans-php
```

### Step 2: Add Configuration (`config/midtrans.php`)
```php
<?php

return [
    'server_key'    => env('MIDTRANS_SERVER_KEY'),
    'client_key'    => env('MIDTRANS_CLIENT_KEY'),
    'is_production' => env('MIDTRANS_IS_PRODUCTION', false),
    'is_sanitized'  => true,
    'is_3ds'        => true,
];
```

### Step 3: Implement `PaymentGatewayInterface`
```php
namespace App\Services\Payment;

use App\Models\Order;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use Exception;
use Illuminate\Http\Request;
use Midtrans\Config;
use Midtrans\Notification;
use Midtrans\Snap;

class MidtransPaymentService implements PaymentGatewayInterface
{
    public function __construct()
    {
        Config::$serverKey = (string) config('midtrans.server_key');
        Config::$clientKey = (string) config('midtrans.client_key');
        Config::$isProduction = (bool) config('midtrans.is_production', false);
        Config::$isSanitized = (bool) config('midtrans.is_sanitized', true);
        Config::$is3ds = (bool) config('midtrans.is_3ds', true);
    }

    public function getPaymentChannels(): array
    {
        return [
            ['code' => 'midtrans_snap', 'name' => 'All Indonesian Methods (Midtrans Snap)'],
            ['code' => 'gopay', 'name' => 'GoPay / QRIS'],
            ['code' => 'bca_va', 'name' => 'BCA Virtual Account'],
        ];
    }

    public function createTransaction(Order $order, string $paymentMethod): array
    {
        $params = [
            'transaction_details' => [
                'order_id'     => 'ORDER-' . $order->id . '-' . time(),
                'gross_amount' => (int) $order->total_amount,
            ],
            'customer_details' => [
                'first_name' => $order->customer_name ?? 'Customer',
                'email'      => $order->customer_email ?? 'customer@example.com',
            ],
        ];

        try {
            $snapToken = Snap::getSnapToken($params);
            $redirectUrl = Snap::createTransaction($params)->redirect_url;

            return [
                'reference'    => $params['transaction_details']['order_id'],
                'snap_token'   => $snapToken,
                'redirect_url' => $redirectUrl,
                'status'       => 'pending',
                'raw'          => ['token' => $snapToken],
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
        $serverKey = (string) config('midtrans.server_key');
        $orderId = (string) $request->input('order_id');
        $statusCode = (string) $request->input('status_code');
        $grossAmount = (string) $request->input('gross_amount');
        $inputSignature = (string) $request->input('signature_key');

        $expectedSignature = hash('sha512', $orderId . $statusCode . $grossAmount . $serverKey);

        return hash_equals($expectedSignature, $inputSignature);
    }

    public function parseCallback(Request $request): array
    {
        $notif = $request->all();
        $transactionStatus = $notif['transaction_status'] ?? '';
        $fraudStatus = $notif['fraud_status'] ?? '';
        $orderId = $notif['order_id'] ?? '';

        $status = 'PENDING';

        if ($transactionStatus === 'capture') {
            $status = ($fraudStatus === 'accept') ? 'PAID' : 'PENDING';
        } elseif ($transactionStatus === 'settlement') {
            $status = 'PAID';
        } elseif (in_array($transactionStatus, ['cancel', 'deny', 'expire'])) {
            $status = 'FAILED';
        }

        return [
            'merchant_ref' => $orderId,
            'status'       => $status,
            'reference'    => $notif['transaction_id'] ?? null,
            'raw'          => $notif,
        ];
    }
}
```

---

## 6. Comparison: Midtrans vs. TripPay vs. DOKU

| Feature | Midtrans | TripPay (Current) | DOKU (Current) |
|---|:---:|:---:|:---:|
| **E-Wallet Depth** | Native GoPay / ShopeePay | Via QRIS aggregator | DOKU wallet / OVO |
| **Virtual Account Fee** | ~Rp 4,000 | **Rp 750 – Rp 4,250** (Cheapest) | ~Rp 3,500 – Rp 5,000 |
| **Card Acquiring** | Standard Acquirer | Reseller / Limited | **Direct Licensed Acquirer** |
| **Developer Documentation** | **Industry Gold Standard** | Clean / Simple | Moderate (Jokul API) |
| **Testing Sandbox** | Interactive Simulators | Basic Test Callback | Basic Sandbox |

---

## 7. Links & Reference

- **Official Website**: https://midtrans.com
- **Developer Documentation**: https://docs.midtrans.com
- **PHP SDK Repository**: https://github.com/Midtrans/midtrans-php
