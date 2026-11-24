# Payment Gateway Reports: Solosmartpay Review & Lean Multi-Channel Architecture

> **Ringkasan Eksekutif**: Audit komprehensif tech stack `solosmartpay.com`, dekomposisi penyedia upstream, serta panduan arsitektur untuk membangun payment gateway multi-channel dengan biaya transaksi dan infrastruktur yang jauh lebih murah (hemat 40%–80%).

---

## 📑 Daftar Laporan

| No | Laporan | Deskripsi | Dokumen |
|:---:|:---|:---|:---:|
| **01** | **Audit Tech Stack & Upstream Solosmartpay** | Reverse-engineering lengkap frontend (Livewire 3, Tailwind), backend (Laravel), pola antrean `202 Accepted`, dan pembuktian ketergantungan upstream terhadap **Duitku** serta mutasi kode unik. | [Baca Laporan 01 →](./01-solosmartpay-tech-stack-audit.md) |
| **02** | **Arsitektur Multi-Channel Gateway Lebih Murah** | Blueprint teknis memotong biaya per transaksi (adopsi SNAP BI, QRIS dinamis native tanpa bot scraper) dan memangkas biaya server >70% melalui edge validation dan event-driven push. | [Baca Laporan 02 →](./02-cheaper-multi-channel-architecture.md) |
| **03** | **Analisis Komparasi Harga: Duitku vs Solosmartpay** | Bedah paradoks mengapa Solosmartpay tampak lebih murah di QRIS padahal memarkup Duitku di semua VA dan E-Wallet; arsitektur Dual-Rail & hidden cost kode unik. | [Baca Laporan 03 →](./03-duitku-vs-solosmartpay-pricing-breakdown.md) |
| **04** | **Panduan Rekayasa Teknis: QRIS Dinamis Mandiri** | Kode lengkap memodifikasi string QRIS statis jadi dinamis (EMVCo Tag 01, 54, CRC16-CCITT), alokator kode unik Redis atomic lock, listener mutasi, dan matching engine. | [Baca Laporan 04 →](./04-building-pseudo-dynamic-qris-engine.md) |
| **05** | **Transaksi Nilai Besar (Rp 15 Juta) & Volume Tanpa Batas** | Strategi penanganan transaksi tunggal Rp 15 juta (BI-FAST disbursement s.d. Rp 250jt vs VA/QRIS), skema 0,5% laba, dan arsitektur anti-blokir tanpa batas harian. | [Baca Laporan 05 →](./05-high-ticket-transactions-and-unlimited-volume.md) |
| **06** | **Cetak Biru Gateway Non-Custodial (SaaS POS)** | Panduan teknis & bisnis lengkap model Non-Custodial: alur kerja merchant, monetisasi 0,5% via Saldo Deposit Kuota (Prepaid Credit), skema database, dan controller mutasi. | [Baca Laporan 06 →](./06-non-custodial-saas-implementation-blueprint.md) |
| **07** | **Master QRIS Terpusat & Setup Android Listener HP Bekas** | Panduan operasional gateway model kustodian: rotasi multi e-wallet (DANA, ShopeePay, GoBiz) anti-blokir, konfigurasi HP Vivo/Funtouch OS 24/7, MacroDroid HTTP forwarder, dan mitigasi baterai smart plug. | [Baca Laporan 07 →](./07-centralized-master-qris-and-android-listener-setup.md) |
| **08** | **Cetak Biru PayFac Resmi, Margin 0,5% & Mode Sandbox** | Panduan migrasi resmi tanpa HP via kemitraan PayFac/ISO Bank Acquirer, pemisahan beban biaya legal anti-surcharge (0,3% pembeli & 0,5% merchant), ekstra laba BI-FAST, serta arsitektur sandbox. | [Baca Laporan 08 →](./08-official-payfac-scaling-and-sandbox-blueprint.md) |
---

## 🔍 Ringkasan Temuan Utama Solosmartpay

1. **Pemegang Stack & Entitas**:
   - Dikelola oleh **Solo Smart Digital** (Surakarta, Jawa Tengah). Terdaftar PSE Komdigi.
   - Bertindak sebagai *Technical Facilitator* / sub-aggregator (tidak memegang lisensi PJP Kategori 1 Bank Indonesia sendiri).
2. **Ketergantungan Upstream (Upstream Provider)**:
   - **Terbukti menggunakan Duitku (PT Duitku Cyber Global)** untuk Virtual Account, E-Wallet, dan Retail. Bukti valid: seluruh kamus kode metode (`M2`, `I1`, `BR`, `BT`, `B1`, `A1`, `OV`, `SA`, `LA`, `VA`, `FT`, `AG`, `S1`, `NC`, `DM`, `BV`) identik 100% dengan spesifikasi API Duitku.
3. **Mekanisme QRIS & Mutasi Bank**:
   - Menggunakan kode unik 1–999 untuk mencocokkan mutasi rekening penampung / static QRIS merchant. Pola ini membatasi volume transaksi paralel dan rentan terhadap kesalahan transfer pengguna.
4. **Beban Komputasi Polling (`202 Accepted`)**:
   - Pembuatan invoice tidak synchronous; browser/klien dipaksa melakukan polling HTTP berulang kali ke `status_url` hingga tagihan berstatus `ready`.

---

## 💡 Strategi Membangun Gateway yang Jauh Lebih Murah

```
+----------------------------------------------------------------------------------------------------+
|  Tantangan Solosmartpay Saat Ini          |  Solusi Gateway Modern Lebih Murah                     |
+----------------------------------------------------------------------------------------------------+
|  Double-Hop Markup (Duitku -> Solosmartpay) |  Disintermediasi: Sambungkan Direct SNAP BI & Tier-1  |
|  - Fee VA Rp 3.300 - Rp 4.300             |  - Fee VA turun ke Rp 1.500 - Rp 2.200 (Hemat ~50%)    |
+----------------------------------------------------------------------------------------------------+
|  Kode Unik QRIS 1-999 + Bot Scraper Mutasi |  Native Dynamic QRIS Acquirer (EMVCo Tag 54 & 62)      |
|  - Batas 999 trx/nominal, risiko salah bayar|  - MDR 0% Mikro, 0.3% Kecil; verifikasi webhook instan  |
+----------------------------------------------------------------------------------------------------+
|  HTTP Polling Loop (202 Accepted)          |  Fast Synchronous Response + Server-Sent Events (SSE)  |
|  - Beban komputasi & koneksi DB tinggi    |  - Hemat komputasi server >70%                         |
+----------------------------------------------------------------------------------------------------+
|  Disbursement Flat Rp 2.500               |  BI-FAST Direct API via SNAP BI                        |
|  - Biaya penarikan relatif tinggi         |  - Biaya per transfer Rp 500 - Rp 1.000                |
+----------------------------------------------------------------------------------------------------+
```

---

## 🔗 Referensi Tambahan dalam Repositori
- Riset 53 Payment Gateway Global & Lokal: [`reports/payment-gateway-research.md`](../reports/payment-gateway-research.md)
- Dataset Teknis Gateway: [`reports/gateways.json`](../reports/gateways.json) & [`reports/gateways.csv`](../reports/gateways.csv)
- Modul Tripay & DOKU Eksisting: [`config/tripay.php`](../config/tripay.php) & [`config/doku.php`](../config/doku.php)
