[← Master Report](../../payment-gateway-research.md) | [← Category G: Commercial Free-Tier Gateways](../G-commercial-free-tier-gateways.md)

---

# TripPay (TriPay) — Deep-Dive Report

> Comprehensive analysis of the Indonesian payment aggregator currently active in this Laravel E-Commerce application.

---

## 1. Overview

TripPay (branded as TriPay) is a leading Indonesian financial technology aggregator operated by PT TriPay Komunikasi Nusantara, based in Surakarta, Central Java. Designed to provide frictionless, low-cost digital payment acceptance for e-commerce stores, digital content publishers, and software platforms, TripPay specializes in closed-transaction payment processing across Indonesia's primary payment channels:
- **Bank Virtual Accounts**: Direct multi-bank automated VA creation (BCA, Mandiri, BNI, BRI, Permata, BSI, CIMB Niaga, Muamalat, Danamon).
- **National QR (QRIS)**: Instant static and dynamic QR code generation scanned via any Indonesian bank or e-wallet mobile application.
- **E-Wallets**: OVO, DANA, ShopeePay integration.
- **Convenience Stores (Over-The-Counter)**: Cash payment code generation at Indomaret and Alfamart retail outlets nationwide.

TripPay operates with low per-transaction flat fees on Virtual Accounts, making it one of the most cost-effective payment gateways for Indonesian domestic transactions.

---

## 2. In-Project Implementation Analysis

TripPay is **actively configured and used** in this repository.

### Configuration (`config/tripay.php`)

```php
return [
    'mode' => env('TRIPAY_MODE', 'sandbox'),

    'api_key' => env('TRIPAY_API_KEY', 'DEV-sample-api-key'),
    'private_key' => env('TRIPAY_PRIVATE_KEY', 'sample-private-key'),
    'merchant_code' => env('TRIPAY_MERCHANT_CODE', 'T12345'),

    'urls' => [
        'sandbox' => 'https://tripay.co.id/api-sandbox',
        'production' => 'https://tripay.co.id/api',
    ],

    // Default expiry duration in hours
    'expiry_hours' => (int) env('TRIPAY_EXPIRY_HOURS', 24),
];
```

### Architecture in `app/Services/Payment/TripayPaymentService.php`

The current service correctly implements `PaymentGatewayInterface`:

1. **`getPaymentChannels()`**: Queries `{$this->baseUrl}/merchant/payment-channel` with API key bearer authorization to retrieve live fees and availability per channel.
2. **`createTransaction(Order $order, string $paymentMethod)`**:
   - Computes merchant reference: `$merchantRef = 'TRX-' . $order->id . '-' . time();`
   - Generates HMAC-SHA256 signature:
     ```php
     $signature = hash_hmac('sha256', $this->merchantCode . $merchantRef . (int) $order->total_amount, $this->privateKey);
     ```
   - Dispatches payload to `{$this->baseUrl}/transaction/create` including line items and customer billing info.
3. **`validateCallback(Request $request)`**:
   - Verifies incoming callback header `X-Callback-Signature` against `hash_hmac('sha256', $jsonPayload, $this->privateKey)`.
4. **`parseCallback(Request $request)`**:
   - Maps TripPay status (`PAID`, `EXPIRED`, `FAILED`) to internal standardized statuses.

---

## 3. Security & Vulnerability Analysis for Current Implementation

While the current service is well-structured, research identifies three critical hardening opportunities:

### 1. Webhook Signature Comparison (Timing Attacks)
In `TripayPaymentService.php`, ensure callback validation uses strict constant-time hash comparison:
```php
public function validateCallback(Request $request): bool
{
    $callbackSignature = $request->header('X-Callback-Signature');
    $rawPayload = $request->getContent();
    $expectedSignature = hash_hmac('sha256', $rawPayload, $this->privateKey);

    return hash_equals($expectedSignature, (string) $callbackSignature);
}
```
*(Check: ensure `hash_equals` is used rather than loose `===` to prevent timing side-channel attacks).*

### 2. Idempotency Key Tracking
TripPay may retry webhooks if your server takes longer than 3 seconds to respond with `{"success": true}`. Currently, webhook callbacks should be guarded against race conditions where duplicate HTTP deliveries trigger double order processing or duplicate stock decrements.

---

## 4. Fee & Cost Structure

TripPay's primary commercial advantage is its **low fixed fee structure**:

| Payment Channel | TripPay Fee | Market Average (Midtrans/Xendit) |
|---|---|---|
| **BCA Virtual Account** | Rp 2,000 – Rp 4,000 flat | Rp 4,000 – Rp 4,500 flat |
| **Mandiri / BNI / BRI VA** | Rp 1,500 – Rp 3,000 flat | Rp 4,000 – Rp 4,500 flat |
| **QRIS** | 0.7% (BI Regulatory MDR) | 0.7% |
| **Alfamart / Indomaret** | Rp 2,500 – Rp 3,500 flat | Rp 5,000 flat |
| **Monthly Platform Fee** | **Rp 0** | **Rp 0** |

*Financial Impact:* On an order volume of 10,000 Virtual Account transactions per month, TripPay saves approximately **Rp 15,000,000 to Rp 20,000,000 ($1,000–$1,300 USD) monthly** compared to standard flat-rate aggregators.

---

## 5. Pros & Cons

### Pros
1. Lowest Virtual Account transaction fees among major Indonesian gateways
2. Instant automated setup with minimal corporate paperwork required for sandbox testing
3. Comprehensive coverage of Indonesian payment habits (QRIS, VA, Minimarket cash)
4. Clean REST API with predictable HMAC-SHA256 signature verification
5. Fully implemented and operational in this codebase today

### Cons
1. Aggregator model: not a direct card acquirer (settlements flow through TripPay's escrow accounts)
2. Limited international credit card acquiring capabilities
3. Webhook callback timeouts are relatively strict (requires asynchronous queue worker processing)
4. No automated recurring subscription / card tokenization engine

---

## 6. Recommendations for This Project

1. **Keep TripPay as Primary for Virtual Accounts & QRIS**: The fee savings for domestic Indonesian transactions are substantial.
2. **Add Transaction Audit Logging**: Save every raw TripPay callback payload into an append-only `transaction_events` table before processing order status changes.
3. **Queue Processing**: Dispatch order confirmation jobs to a background queue to ensure callback responses return HTTP 200 within TripPay's 3-second SLA window.

---

## 7. Links & Reference

- **Official Website**: https://tripay.co.id
- **API Documentation**: https://tripay.co.id/developer
- **Merchant Dashboard**: https://tripay.co.id/member
