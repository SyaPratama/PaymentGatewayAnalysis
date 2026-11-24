[← Master Report](../../payment-gateway-research.md) | [← Category C: Billing & Subscription Platforms](../C-billing-subscription-platforms.md)

---

# Invoice Ninja — Deep-Dive Report

> The premier open-source invoicing, billing, and payment platform built natively on Laravel.

---

## 1. Overview

Invoice Ninja is one of the most mature, widely-deployed open-source invoicing and payment management systems in the world. Built 100% on the PHP/Laravel framework on the backend with client interfaces written in Flutter, Invoice Ninja allows freelancers, small businesses, and enterprise platforms to send invoices, track payments, manage client portals, and accept payments across more than 30 supported gateways.

Because Invoice Ninja is built entirely on Laravel, it holds unique value for Laravel engineering teams: its database schemas, Eloquent models, and payment adapter patterns represent an authentic production reference architecture for how enterprise payment workflows should be structured within Laravel.

---

## 2. Architecture & Data Flow

```
┌────────────────────────────────────────────────────────┐
│              Client Portal / Mobile Apps               │
│          (Flutter Web, iOS, Android, Desktop)          │
└──────────────────────────┬─────────────────────────────┘
                           │ REST API (Bearer Token)
┌──────────────────────────▼─────────────────────────────┐
│                 Invoice Ninja Backend                  │
│                     (Laravel 10+)                      │
│                                                        │
│  ┌───────────────────────┐   ┌──────────────────────┐  │
│  │ Eloquent Invoicing    │   │ Payment Drivers      │  │
│  │ (Quotes, Invoices)    │   │ (Omnipay + Custom)   │  │
│  └───────────┬───────────┘   └──────────┬───────────┘  │
│              │                          │              │
│  ┌───────────▼──────────────────────────▼───────────┐  │
│  │ Laravel Queues & PDF Engine (Snappy / Chromium)   │  │
│  └───────────────────────┬──────────────────────────┘  │
└──────────────────────────┼─────────────────────────────┘
                           │ API Call
            ┌──────────────┴──────────────┐
            ▼                             ▼
    ┌───────────────┐             ┌───────────────┐
    │ Stripe Charge │             │ PayPal Capture│
    └───────────────┘             └───────────────┘
```

1. **Eloquent Core**: Centralizes entities (`Company`, `Client`, `Invoice`, `Payment`, `PaymentMethod`, `Credit`) within clean Laravel Eloquent relationships.
2. **Payment Layer**: Built on top of an internal gateway abstraction layer that leverages Omnipay drivers and custom vendor SDKs to execute charges.
3. **Client Portal**: A passwordless or authenticated self-service portal where customers can review statements, store tokenized credit cards, and execute payments.
4. **Queue Worker & PDF Dispatch**: Heavy tasks (PDF invoice compilation via Headless Chrome, email delivery, webhook fan-out) are handled asynchronously via standard Laravel queues.

---

## 3. Key Features

- **30+ Payment Gateways Supported** — Out-of-the-box drivers for Stripe, PayPal, Authorize.Net, Checkout.com, Mollie, Razorpay, Payfast, and more.
- **Client Billing Portal** — Dedicated portal for clients to review payment history, pay outstanding balances, and download tax receipts.
- **Auto-Billing & Recurring Invoices** — Automatic debiting of stored customer payment methods on predetermined schedule cycles.
- **RESTful API with OpenAPI Spec** — Full programmatic control over every entity via modern REST endpoints.
- **Multi-Tenant & Multi-Currency** — Run multiple discrete company profiles with distinct currency formats and local tax configurations from one instance.
- **Customizable Invoicing Engine** — High-fidelity PDF rendering with custom templates, QR codes, and legal compliance footers.

---

## 4. Pricing & TCO Analysis

Invoice Ninja uses a dual-licensing model (Attribution Assurance License / Elastic License 2.0).

| Edition | License Cost | Key Capabilities |
|---|---|---|
| **Self-Hosted Community** | **$0** (Free forever) | Full functionality, includes small footer link |
| **Self-Hosted White-Label** | **$30 / year** | Removes all Invoice Ninja branding |
| **Hosted Cloud Pro** | $120 / year | Fully managed cloud hosting by Invoice Ninja team |
| **Hosted Cloud Enterprise** | $400 / year | Multi-user seats, advanced roles and permissions |

*Self-Hosted Infrastructure:* Runs comfortably on a standard $10–$25/month Linux VPS running PHP 8.2+ and MySQL 8.x.

---

## 5. Laravel Integration Architecture

Invoice Ninja provides an official PHP SDK (`invoiceninja/sdk-php`) to interact with its REST API from any external Laravel app.

### Step 1: Install SDK
```bash
composer require invoiceninja/sdk-php
```

### Step 2: Programmatically Generate an Invoice
```php
namespace App\Services\Billing;

use InvoiceNinja\Sdk\InvoiceNinja;

class InvoiceNinjaService
{
    protected InvoiceNinja $ninja;

    public function __construct()
    {
        $this->ninja = new InvoiceNinja(config('services.invoiceninja.token'));
        $this->ninja->setUrl(config('services.invoiceninja.url', 'https://invoicing.mycompany.com'));
    }

    public function createInvoiceForOrder($order): array
    {
        // 1. Find or create client
        $client = $this->ninja->clients->create([
            'name'  => $order->customer_name,
            'email' => $order->customer_email,
        ]);

        // 2. Create invoice with line items
        $invoice = $this->ninja->invoices->create([
            'client_id'   => $client['data']['id'],
            'date'        => date('Y-m-d'),
            'due_date'    => date('Y-m-d', strtotime('+7 days')),
            'line_items'  => [
                [
                    'product_key' => $order->product_title,
                    'cost'        => $order->total_amount,
                    'quantity'    => 1,
                ]
            ],
            'auto_bill'   => 'optin',
        ]);

        return $invoice['data'];
    }
}
```

---

## 6. Security & PCI Compliance

- **Tokenized Vaulting**: Card numbers entered in the client portal are vaulted directly with Stripe or Authorize.net; Invoice Ninja stores token identifiers and card metadata (last 4, expiry) only.
- **Laravel Security Foundations**: Inherits standard Laravel CSRF token verification, parameterized PDO queries preventing SQL injection, and hashed API tokens.
- **Compliance Footprint**: Merchants deploying hosted fields inside Invoice Ninja operate at the minimal **SAQ-A** compliance scope.

---

## 7. Scalability & Operational Footprint

- **Database Structure**: Clean relational schema optimized with composite foreign keys and indexes.
- **Resource Footprint**: Minimal; runs on identical server infrastructure as standard Laravel applications (PHP-FPM + Nginx + MySQL + Redis).
- **Throughput**: Adequately handles hundreds of invoice dispatches and webhook receptions per minute using Laravel Horizon queues.

---

## 8. Pros & Cons

### Pros
1. 100% Laravel-native codebase: completely transparent and familiar to your development team
2. Ready-to-use client payment portal and automated recurring billing
3. 30+ turnkey payment gateway integrations built-in
4. Beautiful cross-platform mobile and desktop management apps (Flutter)
5. Highly economical ($0 or $30/yr white-label)

### Cons
1. Elastic License 2.0 / AAL prevents reselling Invoice Ninja as a competing multi-tenant SaaS without a commercial license
2. Admin web interface uses Flutter, which has a distinct feel compared to native web HTML/Blade
3. Not designed for real-time sub-second payment routing (like Hyperswitch)
4. Monolithic database structure containing both CRM, invoicing, and payment records

---

## 9. When to Use vs. When to Avoid

### When to Use
- You need a full-featured, self-hosted invoicing system with a customer portal and multi-gateway support.
- Your engineering team is centered around PHP/Laravel.
- You want to study production-grade Laravel payment modeling.

### When to Avoid
- High-frequency low-latency micro-transactions (e.g. streaming API calls or in-game micropayments).
- Applications needing a tiny, invisible, headless payment proxy.

---

## 10. Links & Reference

- **Official Website**: https://www.invoiceninja.com
- **GitHub Repository**: https://github.com/invoiceninja/invoiceninja
- **API Documentation**: https://invoiceninja.github.io
