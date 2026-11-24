# Kategori E — E-Commerce Platforms dengan Modul Pembayaran Bawaan

[← Kembali ke Laporan Utama](../payment-gateway-research.md)

Platform e-commerce open-source modern mengintegrasikan lapisan abstraksi gateway pembayaran, state machine pesanan, dan ekosistem plugin yang matang. Mempelajari struktur antarmuka, pencatatan log transaksi, dan listener webhook pada platform-platform ini memberikan cetak biru arsitektur yang teruji untuk aplikasi e-commerce kustom.

---

## 25. Saleor — [Lihat Laporan Deep-Dive Mandiri →](individual/saleor.md)
Platform e-commerce headless berbasis Python, Django, dan GraphQL. Menggunakan arsitektur "Apps" terisolasi berbasis webhook untuk menghubungkan Stripe, Adyen, Braintree, dan Klarna tanpa risiko plugin pihak ketiga merusak alur checkout utama.

---

## 26. Medusa — [Lihat Laporan Deep-Dive Mandiri →](individual/medusa.md)
Mesin e-commerce headless berbasis Node.js dan TypeScript. Menggunakan interface `AbstractPaymentProcessor` modular dan mesin workflow berbasis Saga pattern untuk menangani transaksi kompensasi otomatis jika pembayaran gagal.

---

## 27. Bagisto — [Lihat Laporan Deep-Dive Mandiri →](individual/bagisto.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~16.000 |
| **Lisensi** | MIT |
| **Bahasa / Stack** | PHP 8.x, Laravel, MySQL / PostgreSQL, Vue.js |
| **Situs Web** | [https://bagisto.com](https://bagisto.com) |
| **Repositori GitHub** | [https://github.com/bagisto/bagisto](https://github.com/bagisto/bagisto) |

### Gambaran Umum
Bagisto adalah platform e-commerce open-source terpopuler yang dibangun 100% menggunakan Laravel. Memiliki kelas abstraksi pembayaran `Webkul\Payment\Payment\Payment` yang menjadi referensi arsitektur produksi paling ideal untuk pengembang Laravel.

---

## 28. Solidus — [Lihat Laporan Deep-Dive Mandiri →](individual/solidus.md)
Fork Spree Commerce berbasis Ruby on Rails untuk peritel enterprise, mentenagai alur checkout multi-metode bayar dan penanganan gift card/store credit kompleks berbasis Active Merchant.

---

## 29. Spree Commerce — [Lihat Laporan Deep-Dive Mandiri →](individual/spree.md)
Framework e-commerce headless veteran berbasis Ruby on Rails dengan dukungan 30+ payment gateway global dan starter frontend Next.js.

---

## 30. WooCommerce — [Lihat Laporan Deep-Dive Mandiri →](individual/woocommerce.md)
Platform e-commerce terpopuler di dunia berbasis WordPress dan PHP. Memiliki ekosistem plugin payment gateway terbesar di dunia (termasuk plugin resmi untuk TripPay, DOKU, Midtrans, dan Xendit).

---

## 31. Aimeos — [Lihat Laporan Deep-Dive Mandiri →](individual/aimeos.md)
Framework e-commerce ultra-cepat yang dapat disematkan langsung ke dalam aplikasi Laravel (`composer require aimeos/aimeos-laravel`), memiliki jembatan bawaan ke pustaka Omnipay dan latensi sub-20ms.

---

## 32. Sylius — [Lihat Laporan Deep-Dive Mandiri →](individual/sylius.md)
Platform e-commerce Symfony enterprise yang mengadopsi Clean Architecture, Domain-Driven Design (DDD), serta mesin pembayaran Payum.

---

## 33. PrestaShop — [Lihat Laporan Deep-Dive Mandiri →](individual/prestashop.md)
Platform e-commerce open-source Eropa dengan 300+ modul pembayaran dan hooks modular untuk berbagai sistem pembayaran perbankan regional.

---

## Tabel Perbandingan Kategori E

| Platform | Stack Utama | Mesin Pembayaran | Gaya Arsitektur | Kesesuaian Kode Laravel | Lisensi |
|---|:---:|:---:|:---:|:---:|:---:|
| **Saleor** | Python / GraphQL | Apps / Webhooks | Headless | Terpisah | BSD-3 |
| **Medusa** | TypeScript / Node | Provider Modules | Headless / Sagas | Terpisah | MIT |
| **Bagisto** | PHP / Laravel | Native Base Class| Monolit / API | **100% Native** | MIT |
| **Solidus** | Ruby on Rails | Active Merchant | Modular Core | Terpisah | BSD-3 |
| **Spree** | Ruby on Rails | Gateway Adapters | Headless / Core | Terpisah | BSD-3 |
| **WooCommerce** | PHP / WordPress | `WC_Payment_Gateway` | Monolit / Plugins | Rendah (Hook WP) | GPL-2.0 |
| **Aimeos** | PHP / Laravel | Jembatan Omnipay | Embedded Library | Tinggi (Composer) | LGPL-3.0 |
| **Sylius** | PHP / Symfony | Payum | Clean / DDD | Menengah (Symfony) | MIT |
| **PrestaShop** | PHP / Symfony | Module Hooks | Monolit | Menengah | OSL-3.0 |
