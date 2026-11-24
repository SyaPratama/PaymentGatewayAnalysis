[← Master Report](../../payment-gateway-research.md) | [← Category B: Self-Hosted Crypto Gateways](../B-crypto-gateways.md)

---

# BTCPay Server — Deep-Dive Report

> The gold-standard self-hosted, open-source cryptocurrency payment processor.

---

## 1. Overview

BTCPay Server is an open-source, non-custodial cryptocurrency payment processor developed in C# (.NET Core). Created in 2017 by Nicolas Dorier as a direct, censorship-resistant alternative to commercial processors like BitPay, BTCPay Server enables merchants to accept Bitcoin on-chain and over the Lightning Network directly into their private wallets.

Unlike commercial gateways that take a percentage cut, convert funds to fiat, or hold balances in escrow, BTCPay Server acts strictly as a self-hosted transaction coordinator. It generates unique payment addresses from the merchant's extended public key (xPub), monitors the blockchain for confirmations, and notifies the e-commerce store via webhooks. Zero transaction fees, zero custodial risk, and zero third-party tracking.

---

## 2. Architecture & Data Flow

```
┌────────────────────────────────────────────────────────┐
│               E-Commerce Store (Laravel)                │
│             Creates Invoice via Greenfield API         │
└──────────────────────────┬─────────────────────────────┘
                           │ POST /api/v1/stores/{storeId}/invoices
┌──────────────────────────▼─────────────────────────────┐
│                 BTCPay Server Instance                 │
│              (ASP.NET Core / PostgreSQL)               │
│                                                        │
│  ┌─────────────────────────┐  ┌─────────────────────┐  │
│  │ Invoice State Machine   │  │ Non-Custodial Wallet│  │
│  │ (New->Paid->Settled)    │  │ (Derives Addresses) │  │
│  └────────────┬────────────┘  └──────────┬──────────┘  │
└───────────────┼──────────────────────────┼─────────────┘
                │                          │
        RPC / P2P queries          Lightning P2P
                ▼                          ▼
     ┌─────────────────────┐    ┌─────────────────────┐
     │ Bitcoin Core Node   │    │ Lightning Daemon    │
     │ (bitcoind / pruned) │    │ (LND or Core-LN)    │
     └─────────────────────┘    └─────────────────────┘
```

1. **Merchant Setup**: Merchant enters their xPub (extended public key) into BTCPay Server. The private keys remain completely offline on hardware wallets (Trezor, Ledger, Coldcard).
2. **Invoice Generation**: Customer initiates checkout. Laravel calls the BTCPay Greenfield REST API to create an invoice pegged to fiat value (e.g., IDR or USD).
3. **Address Derivation**: BTCPay Server derives a fresh unused Bitcoin address or Lightning invoice and presents an interactive checkout QR code.
4. **Node Verification**: The integrated `bitcoind` full node verifies transaction inclusion in the mempool or blockchain without trusting any third-party block explorer.
5. **Webhook Dispatch**: Once confirmed (e.g. 1 on-chain block or instant Lightning settlement), BTCPay delivers an HMAC-signed webhook to Laravel.

---

## 3. Key Features

- **Direct P2P Settlements** — Funds transfer directly from customer wallet to merchant wallet without intermediary holding.
- **Lightning Network Native** — Instant micropayments with near-zero transaction fees via embedded LND or c-lightning daemons.
- **Greenfield REST API** — Modern, OpenAPI-compliant REST API for headless integrations, invoice management, and webhook dispatch.
- **Multi-Store Management** — Run an unlimited number of isolated merchant stores from a single self-hosted server instance.
- **Built-in Apps** — Point of Sale (PoS), crowdfunding campaign tracker, and pay-button generators included in core.
- **Automated Cold Storage Sweeps** — Automatically route balances exceeding defined thresholds into multi-signature cold vaults.
- **Automated Fiat Conversions** — Optional API plugins to immediately sell incoming Bitcoin on exchanges (Kraken, Binance) to neutralize price volatility.

---

## 4. Pricing & Total Cost of Ownership (TCO)

BTCPay Server charges **0% transaction fees**. Cost is strictly limited to server hosting and network miner fees.

| Volume | BTCPay Hosting Cost | Commercial Processor (BitPay 1.5%) | Annual Savings with BTCPay |
|---|---|---|---|
| **$10,000 / mo** | ~$20 / mo (VPS) | $150 / mo | **$1,560 / year** |
| **$100,000 / mo** | ~$50 / mo (Pruned node) | $1,500 / mo | **$17,400 / year** |
| **$1,000,000 / mo** | ~$120 / mo (Dedicated server) | $15,000 / mo | **$178,560 / year** |

---

## 5. Integration Guide for Laravel

### Step 1: Configuration (`config/btcpay.php`)

```php
<?php

return [
    'host'           => env('BTCPAY_HOST', 'https://btcpay.yourdomain.com'),
    'api_key'        => env('BTCPAY_API_KEY'),
    'store_id'       => env('BTCPAY_STORE_ID'),
    'webhook_secret' => env('BTCPAY_WEBHOOK_SECRET'),
];
```

### Step 2: Implementation Class

```php
namespace App\Services\Payment;

use App\Models\Order;
use App\Services\Payment\Contracts\PaymentGatewayInterface;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class BtcpayPaymentService implements PaymentGatewayInterface
{
    protected string $host;
    protected string $apiKey;
    protected string $storeId;

    public function __construct()
    {
        $this->host = rtrim(config('btcpay.host'), '/');
        $this->apiKey = (string) config('btcpay.api_key');
        $this->storeId = (string) config('btcpay.store_id');
    }

    public function getPaymentChannels(): array
    {
        return [
            ['code' => 'btc_onchain', 'name' => 'Bitcoin (On-Chain)'],
            ['code' => 'btc_lightning', 'name' => 'Bitcoin (Lightning Network)'],
        ];
    }

    public function createTransaction(Order $order, string $paymentMethod): array
    {
        $response = Http::withHeaders([
            'Authorization' => "token {$this->apiKey}",
            'Content-Type'  => 'application/json',
        ])->post("{$this->host}/api/v1/stores/{$this->storeId}/invoices", [
            'amount'          => $order->total_amount,
            'currency'        => $order->currency ?? 'IDR',
            'metadata'        => [
                'orderId'   => (string) $order->id,
                'orderNumber' => $order->order_number,
            ],
            'checkout'        => [
                'redirectURL' => route('orders.show', $order->id),
            ],
        ]);

        $data = $response->json();

        return [
            'reference'   => $data['id'] ?? null,
            'checkout_url'=> $data['checkoutLink'] ?? null,
            'status'      => 'pending',
            'raw'         => $data,
        ];
    }

    public function validateCallback(Request $request): bool
    {
        $secret = config('btcpay.webhook_secret');
        $sigHeader = $request->header('BTCPay-Sig');

        if (!$sigHeader || !$secret) {
            return false;
        }

        $expectedSig = 'sha256=' . hash_hmac('sha256', $request->getContent(), $secret);

        return hash_equals($expectedSig, $sigHeader);
    }

    public function parseCallback(Request $request): array
    {
        $payload = $request->json()->all();
        $type = $payload['type'] ?? '';
        $invoiceId = $payload['invoiceId'] ?? null;
        $orderId = $payload['metadata']['orderId'] ?? '';

        $status = 'PENDING';
        if ($type === 'InvoiceSettled') {
            $status = 'PAID';
        } elseif ($type === 'InvoiceExpired' || $type === 'InvoiceInvalid') {
            $status = 'FAILED';
        }

        return [
            'merchant_ref' => $orderId,
            'status'       => $status,
            'reference'    => $invoiceId,
            'raw'          => $payload,
        ];
    }
}
```

---

## 6. Security & PCI Scope

- **Zero PCI Scope**: Cryptocurrencies do not fall under PCI-DSS jurisdiction. No PAN, CVV, or cardholder data is touched.
- **Private Key Isolation**: BTCPay Server does not store private spending keys by default. Even if the server is compromised, attackers cannot steal merchant funds from watch-only xPub setups.
- **Webhook Integrity**: Webhooks are verified using SHA-256 HMAC signatures.

---

## 7. Scalability & Operational Footprint

- **Pruned Node Mode**: Can run on a 2GB RAM / 50GB SSD VPS (~$15/mo) by discarding historical transaction data while preserving full cryptographic validation.
- **Full Archival Node**: Requires ~650GB NVMe storage and 4GB–8GB RAM (~$40–$60/mo).
- **Throughput**: Lightning Network handles hundreds of transactions per second off-chain; on-chain confirmation throughput is limited by Bitcoin block intervals (~10 min).

---

## 8. Pros & Cons

### Pros
1. Zero processing fees—keep 100% of top-line revenue
2. Absolute censorship resistance; immune to arbitrary merchant account suspensions
3. Eliminates fraud chargebacks completely (crypto transactions are irreversible)
4. Comprehensive Greenfield REST API and rich webhook support
5. High developer community support and active security patches

### Cons
1. Price volatility of Bitcoin requires rapid exchange liquidation if accounting in fiat
2. Maintaining a full node requires systems administration overhead
3. Low mainstream adoption compared to regional virtual accounts or credit cards
4. Customer refunds require manual payout address entry (cannot auto-refund to cards)

---

## 9. When to Use vs. When to Avoid

### When to Use
- You sell digital products, international software, or global services.
- You operate in high-risk categories that face credit card chargeback extortion.
- Cross-border remittance fees and currency conversion erode your margins.

### When to Avoid
- Domestic Indonesian retail where 98%+ of users expect QRIS, ShopeePay, or BCA Virtual Account.
- Your finance team cannot handle crypto asset accounting or tax reporting.

---

## 10. Links & Reference

- **Official Website**: https://btcpayserver.org
- **GitHub**: https://github.com/btcpayserver/btcpayserver
- **Documentation**: https://docs.btcpayserver.org
