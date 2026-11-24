# Kategori D — Payment SDK Libraries

[← Kembali ke Laporan Utama](../payment-gateway-research.md)

Pustaka SDK pembayaran menyediakan lapisan abstraksi multi-gateway langsung di dalam kode aplikasi. Dengan mendefinisikan interface tunggal untuk operasi umum pembayaran (otorisasi, capture, void, refund, dan verifikasi webhook), pustaka ini membebaskan pengembang dari vendor-lockin tanpa beban operasional memelihara microservices terpisah.

**Kapan digunakan:** Aplikasi monolitik, integrasi native di dalam framework PHP/Laravel, atau saat pengembang menginginkan pemanggilan in-process berkecepatan tinggi tanpa overhead latensi jaringan.

---

## 17. Omnipay — [Lihat Laporan Deep-Dive Mandiri →](individual/omnipay.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~5.900 |
| **Lisensi** | MIT |
| **Bahasa / Stack** | PHP 7.x / 8.x (Composer, PSR-7/18) |
| **Situs Web** | [https://omnipay.thephpleague.com](https://omnipay.thephpleague.com) |
| **Repositori GitHub** | [https://github.com/thephpleague/omnipay](https://github.com/thephpleague/omnipay) |

### Gambaran Umum
Omnipay adalah pustaka abstraksi pembayaran standar de facto di ekosistem PHP, dikelola di bawah naungan The PHP League. Terinspirasi oleh Active Merchant milik Shopify, Omnipay membungkus lebih dari 60 gateway pembayaran global ke dalam satu API berorientasi objek yang konsisten dan patuh terhadap standar PSR.

### Fitur Utama
- **Model Permintaan Terpadu** — Metode seragam: `purchase()`, `authorize()`, `capture()`, `void()`, `refund()`.
- **Ekosistem 60+ Driver** — Tersedia driver komunitas untuk Stripe, PayPal, Authorize.Net, Mollie, dll.
- **Eksekusi In-Process** — Berjalan langsung di dalam thread PHP-FPM tanpa server daemon eksternal ($0 biaya server).

---

## 18. Payum — [Lihat Laporan Deep-Dive Mandiri →](individual/payum.md)

Pustaka pembayaran enterprise untuk PHP yang mengimplementasikan pipeline aksi fungsional dan state machine. Merupakan fondasi pemrosesan pembayaran di balik framework Symfony enterprise seperti Sylius dan SolidInvoice.

---

## 19. shetabit/multipay — [Lihat Laporan Deep-Dive Mandiri →](individual/shetabit-multipay.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~1.200 |
| **Lisensi** | MIT |
| **Bahasa / Stack** | PHP 8.x, Laravel |
| **Repositori GitHub** | [https://github.com/shetabit/multipay](https://github.com/shetabit/multipay) |

### Gambaran Umum
`shetabit/multipay` adalah paket multi-gateway yang dirancang khusus untuk ekosistem Laravel. Menghadirkan sintaks facade yang sangat natural (`Payment::purchase($invoice, $callback)->pay()->render()`), model nilai `Invoice` dan `Receipt` terpadu, serta deteksi otomatis driver pembayaran.

---

## 20. Active Merchant — [Lihat Laporan Deep-Dive Mandiri →](individual/active-merchant.md)

Pustaka abstraksi pembayaran legendaris berbasis Ruby yang dibuat oleh Tobias Lütke dan tim Shopify. Mentenagai transaksi bernilai miliaran dolar setiap hari di Shopify dengan lebih dari 100 konektor gateway perbankan global.

---

## 21. Gringotts — [Lihat Laporan Deep-Dive Mandiri →](individual/gringotts.md)

Pustaka pembayaran untuk bahasa Elixir, terinspirasi oleh Active Merchant dan memanfaatkan keandalan runtime Erlang OTP untuk isolasi proses transaksi non-blocking.

---

## 22. go-payment — [Lihat Laporan Deep-Dive Mandiri →](individual/go-payment.md)

Pustaka Go ringan yang dirancang khusus membungkus gateway pembayaran Asia Tenggara (Midtrans dan Xendit) dengan tipe data strongly-typed dan eksekusi sub-milidetik.

---

## 23. Midtrans Official SDKs — [Lihat Laporan Deep-Dive Mandiri →](individual/midtrans-sdk.md)

Pustaka resmi pertama dari Midtrans (`midtrans/midtrans-php`) untuk integrasi Snap Checkout dan Core API langsung ke dalam aplikasi Laravel.

---

## 24. PayPal Official Server SDKs — [Lihat Laporan Deep-Dive Mandiri →](individual/paypal-sdk.md)

SDK resmi dari PayPal (`paypal/paypal-server-sdk-php`) untuk berinteraksi dengan API REST v2 Orders, Payments, dan Subscriptions.

---

## Tabel Perbandingan Kategori D

| Pustaka | Bahasa | Jumlah Driver | Tingkat Abstraksi | Verifikasi Webhook | Kecocokan Laravel |
|---|:---:|:---:|:---:|:---:|:---:|
| **Omnipay** | PHP | 60+ Gateway | Tinggi (API Terpadu) | Beragam per driver| Sangat Baik (Composer) |
| **Payum** | PHP | 20+ Gateway | Sangat Tinggi (State machine)| Bawaan terstandar | Menengah (Bias Symfony) |
| **shetabit/multipay** | PHP / Laravel | 15+ Gateway | Tinggi (Facade Laravel) | Terpadu bawaan | **100% Native Laravel** |
| **Active Merchant** | Ruby | 100+ Gateway | Tinggi (Standar industri) | Terstandarisasi | Butuh Microservice Ruby |
| **Gringotts** | Elixir | 5+ Gateway | Tinggi (Aktor OTP) | Berbasis Protokol | Butuh Microservice Elixir |
| **go-payment** | Go | 3 (Fokus SEA) | Menengah (Struct-based) | Manual | Butuh Microservice Go |
| **Midtrans SDK** | PHP | 1 (Midtrans) | Rendah (Vendor langsung) | Kelas Notification | Sangat Baik (Composer) |
| **PayPal SDK** | PHP | 1 (PayPal) | Rendah (Vendor langsung) | Signature Verifier | Sangat Baik (Composer) |
