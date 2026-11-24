# Kategori A — Payment Orchestrators

[← Kembali ke Laporan Utama](../payment-gateway-research.md)

Payment orchestrator berada di antara aplikasi Anda dan beberapa payment processor sekaligus. Sistem ini mengarahkan transaksi berdasarkan biaya terendah, tingkat keberhasilan bank, atau wilayah geografis — bertindak sebagai smart proxy layer yang menormalisasi API berbagai PSP, menangani failover otomatis, dan menyediakan dasbor pelaporan terpadu.

**Kapan digunakan:** Anda memiliki 3 atau lebih PSP dan membutuhkan perutean otomatis (smart routing), logika retry saat gagal, atau failover. Jika hanya menggunakan 1–2 PSP, orchestrator menambah beban infrastruktur tanpa nilai tambah yang sepadan.

---

## 1. Hyperswitch — [Lihat Laporan Deep-Dive Mandiri →](individual/hyperswitch.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~12.500 |
| **Lisensi** | Apache-2.0 |
| **Bahasa / Stack** | Rust, PostgreSQL, Redis, Kafka |
| **Situs Web** | [https://hyperswitch.io](https://hyperswitch.io) |
| **Repositori GitHub** | [https://github.com/juspay/hyperswitch](https://github.com/juspay/hyperswitch) |

### Gambaran Umum
Hyperswitch adalah payment orchestrator open-source berfitur lengkap yang dibangun dengan bahasa Rust oleh Juspay (perusahaan infrastruktur pembayaran terbesar di India yang memproses lebih dari 50 juta transaksi harian). Hyperswitch menyediakan smart routing ke lebih dari 50 konektor pembayaran, percobaan ulang otomatis saat terjadi kegagalan jaringan, dan satu API terpadu.

### Fitur Utama
- **Smart Routing Engine** — Mengarahkan transaksi berdasarkan success rate, biaya transaksi terendah, latensi, atau aturan bisnis kustom.
- **50+ Konektor Pre-built** — Stripe, Adyen, PayPal, Razorpay, Braintree, Checkout.com, dan lainnya.
- **3D Secure 2.0 Native** — Penanganan autentikasi 3DS terpadu di semua konektor kartu.
- **Orkestrator Refund** — API pengembalian dana tunggal untuk seluruh processor.
- **Tersertifikasi PCI-DSS Level 1** — Brankas kartu (card vault) bawaan untuk tokenisasi aman.
- **Normalisasi Webhook** — Mengubah format webhook masing-masing PSP menjadi skema event tunggal.

### Kelebihan
- Performa tinggi bahasa Rust: latensi p95 transaksi &lt; 200ms.
- Smart routing terbukti memangkas kegagalan pembayaran sebesar 5% hingga 15%.
- Lisensi Apache-2.0 bebas royalti tanpa copyleft yang membatasi.

### Kekurangan
- Kebutuhan server cukup berat: Binary Rust + PostgreSQL + Redis + Kafka.
- Kerumitan operasional: membutuhkan tim DevOps berpengalaman.
- Kurang cocok untuk volume &lt; 50.000 transaksi/bulan.

### Estimasi Biaya
- **Perangkat Lunak**: Gratis (Apache-2.0).
- **Infrastruktur Server**: ~$200 – $500/bulan (cluster produksi).

---

## 2. Hyperswitch Prism — [Lihat Laporan Deep-Dive Mandiri →](individual/hyperswitch-prism.md)

| Informasi | Keterangan |
|---|---|
| **Lisensi** | Apache-2.0 |
| **Bahasa / Stack** | Rust |
| **Repositori GitHub** | [https://github.com/juspay/hyperswitch](https://github.com/juspay/hyperswitch) |

### Gambaran Umum
Hyperswitch Prism adalah varian penerapan ringan dari Hyperswitch untuk skenario konektor tunggal. Prism menghadirkan performa Rust tinggi dan API terpadu yang sama tanpa kerumitan cluster multi-routing dan Kafka.

### Fitur Utama
- **Proxy Konektor Tunggal** — Satu format API standar di depan satu payment gateway.
- **Performa Rust Setara** — Latensi p95 &lt; 200ms.
- **Docker-Ready** — Deployment simpel dalam satu kontainer Docker.

### Kelebihan & Kekurangan
- ✅ Jauh lebih mudah dipelihara dibanding versi kluster penuh.
- ✅ Jalur upgrade mudah ke Hyperswitch penuh saat bisnis bertumbuh.
- ❌ Tidak memiliki kemampuan multi-PSP smart routing.

---

## 3. OwnPay — [Lihat Laporan Deep-Dive Mandiri →](individual/ownpay.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~200 |
| **Lisensi** | MIT |
| **Bahasa / Stack** | Go, SQLite |
| **Repositori GitHub** | [https://github.com/ownpay](https://github.com/ownpay) |

### Gambaran Umum
OwnPay adalah proxy gateway pembayaran self-hosted minimalis yang ditulis dalam bahasa Go. OwnPay menyediakan lapisan abstraksi tipis di depan Stripe dan PayPal dengan kemampuan relay dan retry webhook otomatis, dengan ukuran biner &lt; 50MB.

### Kelebihan & Kekurangan
- ✅ Konsumsi RAM sangat kecil (&lt; 50MB); berjalan di VPS termurah ($5/bln).
- ✅ Lisensi MIT sangat permisif.
- ❌ Konektor sangat terbatas (hanya Stripe dan PayPal).
- ❌ Komunitas pengembang kecil.

---

## 4. PipraPay — [Lihat Laporan Deep-Dive Mandiri →](individual/piprapay.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~50 |
| **Lisensi** | GPL-3.0 |
| **Bahasa / Stack** | PHP / Laravel |

### Gambaran Umum
PipraPay adalah paket orkestrator pembayaran native untuk framework Laravel. PipraPay beroperasi langsung di dalam aplikasi Laravel yang ada, memanfaatkan antrean (queue) dan event dispatcher bawaan.

### Kelebihan & Kekurangan
- ✅ Stack 100% Laravel: tanpa perlu menjalankan server atau service eksternal terpisah.
- ❌ Komunitas sangat kecil; risiko pemeliharaan jangka panjang.
- ❌ Lisensi GPL-3.0 perlu diwaspadai jika digabung dalam produk proprietary.

---

## Tabel Perbandingan Kategori A

| Fitur | Hyperswitch | Prism | OwnPay | PipraPay |
|---|:---:|:---:|:---:|:---:|
| **Multi-PSP Routing** | ✅ Ya | ❌ Tidak | ❌ Tidak | ✅ Ya |
| **Smart Routing Algoritmik** | ✅ Ya | ❌ Tidak | ❌ Tidak | ❌ Tidak |
| **Jumlah Konektor** | 50+ | 1 | 2 | ~5 |
| **Self-Hosted** | ✅ Ya | ✅ Ya | ✅ Ya | ✅ Ya |
| **Sertifikasi PCI DSS** | Level 1 | ❌ | ❌ | ❌ |
| **Biaya Server Minimal** | ~$200/bln | ~$20/bln | ~$5/bln | $0 (in-app) |
| **Kesesuaian Laravel** | REST API | REST API | REST API | Native Package |
