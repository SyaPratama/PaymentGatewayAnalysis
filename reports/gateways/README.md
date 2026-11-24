# Direktori Riset Payment Gateway — Berdasarkan Kategori

[← Kembali ke Laporan Riset Utama](../payment-gateway-research.md)

Direktori ini berisi analisis komparatif terperinci dari 53 solusi gateway pembayaran yang dikelompokkan ke dalam 7 kategori operasional.

---

## Panduan Kategori

| Kategori | Berkas Laporan | Deskripsi | Gateway yang Dicakup |
|---|---|---|---|
| **A. Payment Orchestrators** | [A-payment-orchestrators.md](A-payment-orchestrators.md) | Smart routing, logika retry otomatis, failover, dan proxy multi-PSP | Hyperswitch, Hyperswitch Prism, OwnPay, PipraPay |
| **B. Self-Hosted Crypto Gateways** | [B-crypto-gateways.md](B-crypto-gateways.md) | Pemrosesan kripto peer-to-peer non-kustodian tanpa potongan biaya perantara | BTCPay Server, Bitcart, SHKeeper, CryptoPayServer, Globee |
| **C. Billing & Subscription Platforms** | [C-billing-subscription-platforms.md](C-billing-subscription-platforms.md) | Langganan berulang, prorasi, pengukuran pemakaian (metering), dan dunning | Kill Bill, Lago, OpenMeter, FOSSBilling, Invoice Ninja, Crater, SolidInvoice |
| **D. Payment SDK Libraries** | [D-payment-sdk-libraries.md](D-payment-sdk-libraries.md) | Pustaka abstraksi kode multi-gateway in-process (PHP, Ruby, Go, Elixir) | Omnipay, Payum, shetabit/multipay, Active Merchant, Gringotts, go-payment, Midtrans SDK, PayPal SDK |
| **E. E-Commerce Platforms** | [E-ecommerce-platforms.md](E-ecommerce-platforms.md) | Sistem toko online lengkap dengan modul penanganan pembayaran terintegrasi | Saleor, Medusa, Bagisto, Solidus, Spree, WooCommerce, Aimeos, Sylius, PrestaShop |
| **F. Banking & Ledger Infrastructure** | [F-banking-ledger-infrastructure.md](F-banking-ledger-infrastructure.md) | Protokol perbankan (ACH, ISO 8583) dan mesin buku besar double-entry | Moov, Apache Fineract, TigerBeetle, Formance Ledger, Blnk, jPOS, Mojaloop, Hatchet Ledger |
| **G. Commercial Free-Tier Gateways** | [G-commercial-free-tier-gateways.md](G-commercial-free-tier-gateways.md) | Gateway komersial tanpa biaya langganan bulanan ($0 / Rp 0 setup fee) | Stripe, PayPal, Square, Razorpay, Midtrans, Xendit, Adyen, Mollie, Paystack, Flutterwave, TripPay ⭐, DOKU ⭐ |

*(⭐ = Aktif dikonfigurasi dan digunakan dalam kode aplikasi ini).*

---

## Laporan Individual Mandiri

Untuk kajian mendalam dari masing-masing gateway (arsitektur, panduan integrasi Laravel, simulasi TCO, dan kepatuhan PCI), kunjungi direktori [`individual/`](individual/) yang memuat 53 berkas laporan mandiri.
