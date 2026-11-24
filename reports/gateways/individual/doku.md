[← Master Report](../../payment-gateway-research.md) | [← Category G: Commercial Free-Tier Gateways](../G-commercial-free-tier-gateways.md)

---

# DOKU — Deep-Dive Report

> Comprehensive analysis of Indonesia's pioneer payment acquirer currently active in this Laravel E-Commerce application.

---

## 1. Overview

Founded in 2007, DOKU (PT Nusa Satu Inti Artha) is the oldest and most established electronic payment company in Indonesia. Holding official Payment System Provider (PJP) Category 1 licenses issued by Bank Indonesia, DOKU operates as a full-fledged direct acquiring payment gateway. Unlike pure resellers or aggregators, DOKU maintains direct enterprise-grade host-to-host links with major card networks (Visa, Mastercard, JCB, American Express) and domestic commercial banking consortiums.

DOKU powers mission-critical payment operations for major airlines (Garuda Indonesia, AirAsia), government agencies, utility companies, and top-tier e-commerce retailers. It offers both modern REST APIs (branded as **DOKU Jokul / Checkout**) and direct server-to-server card processing with full 3D Secure 2.0 liability shift.

---

## 2. In-Project Implementation Analysis

DOKU is **actively configured and integrated** in this repository.

### Configuration (`config/doku.php`)

```php
return [
    'mode' => env('DOKU_MODE', 'sandbox'),

    'client_id' => env('DOKU_CLIENT_ID', 'DOKU-MCH-001'),
    'secret_key' => env('DOKU_SECRET_KEY', 'doku_key_38c723c0313f489690377e75b81cde1a'),
    'public_key' => env('DOKU_PUBLIC_KEY'),
    'public_key_path' => storage_path('app/doku/public_key.pem'),

    'urls' => [
        'sandbox' => 'https://api-sandbox.doku.com',
        'production' => 'https://api.doku.com',
    ],

    // Expiry duration in minutes (e.g. 1440 for 24 hours)
    'expiry_minutes' => (int) env('DOKU_EXPIRY_MINUTES', 1440),
];
```

### Architecture in `app/Services/Payment/DokuPaymentService.php`

DOKU enforces strict cryptographic header requirements for all API calls and webhook notifications:

1. **Header Security Protocol**:
   - `Client-Id`: Merchant identifier
   - `Request-Id`: Unique UUID generated per request to enforce idempotency
   - `Request-Timestamp`: ISO 8601 UTC timestamp (e.g., `2026-10-24T12:00:00Z`)
   - `Signature`: HMAC-SHA256 digest computed across components:
     `Client-Id + "\n" + Request-Id + "\n" + Request-Timestamp + "\n" + Request-Path + "\n" + Digest(Body)`
2. **Body Digest**: The request body is hashed using SHA-256 and base64-encoded before being fed into the signature string.
3. **Public Key Verification**: DOKU supports asymmetric RSA verification for incoming callbacks using `public_key_path` (`storage/app/doku/public_key.pem`).

---

## 3. Security Hardening for DOKU Implementation

Because DOKU handles credit card acquiring and direct host-to-host bank requests, the implementation requires strict attention to detail:

### 1. Timestamp Drift Validation
DOKU callbacks must be verified against server clock drift:
```php
$requestTimestamp = $request->header('Request-Timestamp');
$callbackTime = strtotime($requestTimestamp);
if (abs(time() - $callbackTime) > 300) { // Reject if timestamp is older than 5 minutes
    Log::warning('DOKU callback rejected: timestamp drift exceeds 300 seconds.');
    return false;
}
```

### 2. Public Key Path Verification
Ensure `storage_path('app/doku/public_key.pem')` is deployed via your CI/CD pipeline and has strict read-only permissions (`0600`), and that the web server user (`www-data`) owns the file.

---

## 4. Fee & Cost Structure

DOKU operates on commercial merchant acquiring terms:

| Channel | Standard Commercial Fee |
|---|---|
| **Domestic Credit / Debit Cards** | ~2.5% – 2.9% + Rp 2,000 |
| **International Credit Cards** | ~3.5% + Rp 2,000 |
| **Bank Virtual Account** | Rp 3,500 – Rp 5,000 per transaction |
| **QRIS** | 0.7% (Regulatory MDR) |
| **Convenience Stores (Alfamart Group)** | Rp 3,500 – Rp 5,000 |
| **Annual / Monthly Account Fee** | Typically $0 for standard merchant tiers |

---

## 5. Pros & Cons

### Pros
1. Licensed direct payment acquirer with highest regulatory standing in Indonesia
2. Direct credit card processing with 3DS 2.0 liability protection
3. Enterprise reliability and institutional capacity for massive transaction spikes
4. High transaction limits suitable for enterprise ticket sizes
5. Asymmetric cryptographic signing provides superior security against payload spoofing

### Cons
1. Cryptographic header requirements make manual testing and custom API calls complex
2. Documentation spans legacy documentation and modern Jokul APIs
3. Merchant onboarding and underwriting for live credit cards requires formal corporate documentation
4. Slightly higher Virtual Account fees than pure discount aggregators like TripPay

---

## 6. Strategic Role in This Repository

In this application's dual-gateway architecture:
- **Use DOKU for Credit / Debit Cards**: DOKU's direct acquiring licenses and 3DS 2.0 support provide the highest card authorization success rates and fraud liability shift.
- **Use TripPay for Virtual Accounts & QRIS**: TripPay's lower per-transaction fee structure on VAs saves margin on domestic bank transfer orders.

---

## 7. Links & Reference

- **Official Website**: https://doku.com
- **Jokul Developer Documentation**: https://jokul.doku.com/docs
- **API Sandbox Console**: https://sandbox.doku.com
