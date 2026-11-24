# Kategori C — Billing & Subscription Platforms

[← Kembali ke Laporan Utama](../payment-gateway-research.md)

Platform penagihan dan langganan (billing & subscription) mengelola siklus hidup pendapatan berulang, pembuatan faktur otomatis, pengukuran pemakaian (usage metering), otomatisasi dunning (penagihan gagal), serta perhitungan pajak. Platform ini memisahkan logika penagihan bisnis yang kompleks dari eksekusi transaksi di tingkat payment gateway.

**Kapan digunakan:** Aplikasi SaaS, layanan berlangganan rutin, platform API berbasis konsumsi token/bandwidth, atau perusahaan yang membutuhkan portal pembayaran faktur mandiri bagi klien B2B.

---

## 10. Kill Bill — [Lihat Laporan Deep-Dive Mandiri →](individual/kill-bill.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~4.500 |
| **Lisensi** | Apache-2.0 |
| **Bahasa / Stack** | Java, OSGi, PostgreSQL / MySQL, Docker |
| **Situs Web** | [https://killbill.io](https://killbill.io) |
| **Repositori GitHub** | [https://github.com/killbill/killbill](https://github.com/killbill/killbill) |

### Gambaran Umum
Kill Bill adalah standar industri open-source untuk penagihan berulang skala enterprise. Aslinya dibangun di Groupon dan kini mentenagai infrastruktur penagihan global di Zendesk, Kill Bill menangani jutaan siklus langganan multi-mata uang dengan arsitektur plugin modular berbasis OSGi (tersedia plugin Stripe, Adyen, Braintree, dan PayPal).

### Kelebihan & Kekurangan
- ✅ Teruji di skala enterprise dengan miliaran dolar volume transaksi tahunan.
- ✅ Menghapus ketergantungan pada vendor SaaS komersial seperti Chargebee.
- ❌ Kebutuhan infrastruktur Java dan keahlian DevOps JVM yang tinggi.
- ❌ Kurva belajar XML katalog penagihan dan state machine yang terjal.

---

## 11. Lago — [Lihat Laporan Deep-Dive Mandiri →](individual/lago.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~7.500 |
| **Lisensi** | AGPL-3.0 (Community) / Komersial (Enterprise) |
| **Bahasa / Stack** | Ruby on Rails, Go, React, PostgreSQL, Redis, ClickHouse |
| **Situs Web** | [https://getlago.com](https://getlago.com) |
| **Repositori GitHub** | [https://github.com/getlago/lago](https://github.com/getlago/lago) |

### Gambaran Umum
Lago adalah alternatif open-source modern untuk Stripe Billing dan Chargebee. Dirancang khusus untuk model bisnis SaaS berbasis konsumsi (usage-based/metered), Lago mampu menelan jutaan event penggunaan realtime menggunakan worker berbasis Go dan menghitung tagihan berdasarkan formula harga berjenjang (tiered, volume, paket kredit prabayar).

### Kelebihan & Kekurangan
- ✅ Pengalaman developer (DX) dan antarmuka dasbor React yang sangat modern.
- ✅ Sangat fleksibel untuk model kombinasi langganan dasar + konsumsi pemakaian.
- ❌ Menggunakan lisensi ganda AGPL-3.0 pada edisi komunitas.
- ❌ Stack microservices (Rails + Go + Redis + Postgres + ClickHouse) membutuhkan pemantauan operasional.

---

## 12. OpenMeter — [Lihat Laporan Deep-Dive Mandiri →](individual/openmeter.md)

Platform pengukuran pemakaian (usage metering) cloud-native berbasis Go, Apache Kafka, dan ClickHouse. Berfokus pada penelanan jutaan event konsumsi per detik (misal: token AI, pemakaian CPU) dan langsung mendorong metrik teragregasi ke sistem penagih seperti Stripe Billing.

---

## 13. FOSSBilling — [Lihat Laporan Deep-Dive Mandiri →](individual/fossbilling.md)

Aplikasi penagihan dan manajemen klien open-source berbasis PHP 8.x dan MySQL. Menyediakan portal klien mandiri, ticketing bantuan, dan pembuatan faktur PDF otomatis yang disesuaikan untuk penyedia web hosting dan agensi digital.

---

## 14. Invoice Ninja — [Lihat Laporan Deep-Dive Mandiri →](individual/invoice-ninja.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~8.500 |
| **Lisensi** | Attribution Assurance License (AAL) / Elastic License 2.0 |
| **Bahasa / Stack** | PHP (Laravel), Flutter (Web, Mobile, Desktop), MySQL |
| **Situs Web** | [https://invoiceninja.com](https://invoiceninja.com) |
| **Repositori GitHub** | [https://github.com/invoiceninja/invoiceninja](https://github.com/invoiceninja/invoiceninja) |

### Gambaran Umum
Invoice Ninja adalah salah satu platform penagihan dan pembuatan faktur open-source terpopuler di dunia yang dibangun 100% menggunakan framework Laravel. Mendukung lebih dari 30 gateway pembayaran bawaan, portal klien terenkripsi, faktur berulang otomatis, serta aplikasi seluler Flutter.

### Kelebihan & Kekurangan
- ✅ Stack 100% Laravel: sangat familiar dan mudah dipelajari oleh tim developer PHP/Laravel.
- ✅ Fitur sangat lengkap out-of-the-box (invoicing, quotes, payments, expenses).
- ❌ Lisensi Elastic 2.0 / AAL membatasi penjualan kembali sebagai layanan SaaS komersial tandingan.

---

## 15. Crater — [Lihat Laporan Deep-Dive Mandiri →](individual/crater.md)

Aplikasi pembuatan faktur dan pelacakan biaya yang ramah pengguna, dibangun dengan stack Laravel dan Vue.js. Cocok untuk freelancer dan UMKM yang menginginkan aplikasi faktur bersih tanpa beban fungsionalitas enterprise yang berlebihan.

---

## 16. SolidInvoice — [Lihat Laporan Deep-Dive Mandiri →](individual/solidinvoice.md)

Aplikasi penagihan berbasis Symfony dan pustaka Payum dengan lisensi permisif MIT. Menyediakan alur penawaran (quote), konversi faktur, dan pembayaran online yang mematuhi standar enterprise PSR PHP.

---

## Tabel Perbandingan Kategori C

| Fitur | Kill Bill | Lago | OpenMeter | FOSSBilling | Invoice Ninja | Crater | SolidInvoice |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Stack Inti** | Java | Ruby / Go | Go | PHP 8.x | PHP / Laravel | PHP / Laravel | PHP / Symfony |
| **Lisensi** | Apache-2.0 | AGPL-3.0 | Apache-2.0 | Apache-2.0 | Elastic 2.0 | AGPL-3.0 | MIT |
| **Siklus Langganan** | Enterprise | Sangat Maju| ❌ | Standar | Lengkap | Dasar | Dasar |
| **Usage Metering** | Via Plugin | ✅ Realtime | ✅ Khusus | ❌ | ❌ | ❌ | ❌ |
| **Portal Klien** | Utilitarian | ❌ | ❌ | ✅ | ✅ Lengkap | Sederhana | ✅ |
| **Jumlah Gateway** | 10+ Plugin | 3+ Native | Push ke PSP | 5+ | 30+ Bawaan | 3 | Via Payum |
| **Kecocokan Laravel** | Rendah | Rendah | Rendah | Menengah | **100% Native**| **100% Native**| Menengah |
| **RAM Server Min.** | 4GB – 8GB | 2GB – 4GB | 2GB | 512MB | 1GB – 2GB | 512MB – 1GB | 512MB |
