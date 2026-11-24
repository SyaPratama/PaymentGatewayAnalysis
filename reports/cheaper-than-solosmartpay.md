# Rekomendasi Payment Gateway Lebih Murah dari Solosmartpay

> **Analisis Biaya & Komparasi Pasar FinTech Indonesia**  
> Laporan perbandingan alternatif payment gateway multi-channel yang lebih murah dari Solosmartpay untuk Virtual Account, QRIS, E-Wallet, dan Penarikan Dana (Disbursement).

---

## 1. Ringkasan Tarif Solosmartpay Saat Ini (Baseline)

Solosmartpay membebankan biaya transaksi sebagai berikut:
- **Bank Virtual Account (VA)**:
  - Bank Mandiri: **Rp 4.300 / transaksi**
  - BNI, BRI, Permata, CIMB, Danamon, BSI, Maybank, ATM Bersama: **Rp 3.300 / transaksi**
  - Artha Graha, Sahabat Sampoerna: **Rp 1.800 / transaksi**
- **QRIS**:
  - Transaksi ≤ Rp 500.000: **Rp 300 flat + kode unik (1–999)**
  - Transaksi > Rp 500.000: **0,5%** (0,3% QRIS + 0,2% platform)
- **E-Wallet**:
  - ShopeePay: **4,25%** *(sangat tinggi)*
  - OVO: **3,28%** *(sangat tinggi)*
- **Penarikan Saldo (Disbursement)**: **Rp 2.500 / penarikan**

---

## 2. Tabel Komparasi Harga: Solosmartpay vs Gateway Alternatif

| Provider / Channel | Bank Mandiri VA | Bank Lain (BNI/BRI/Permata/BCA) | VA Second-Tier (Sampoerna/AG) | E-Wallet (Shopee/OVO) | QRIS Dinamis | Payout / WD | Skema Lisensi |
|---|---|---|---|---|---|---|---|
| **Solosmartpay** | **Rp 4.300** | **Rp 3.300** | **Rp 1.800** | **3.28% – 4.25%** | Rp 300 flat* / 0.5% | Rp 2.500 | Sub-Aggregator (Duitku reseller) |
| **Duitku (Direct)** | **Rp 4.000** | **Rp 3.000** | **Rp 1.500** | **1.5% – 2.0%** | 0.7% | Rp 2.500 | PJP Berlisensi BI |
| **Oy! Bisnis** | **Rp 2.000 – 2.500** | **Rp 2.000 – 2.500** | **Rp 1.500** | **1.5%** | 0.7% (0% Mikro) | **Rp 1.000 – 1.500** | PJP Berlisensi BI |
| **Winpay / Faspay** | **Rp 2.000 – 3.000** | **Rp 2.000 – 3.000** | **Rp 1.200 – 1.500** | **1.5% – 1.8%** | 0.7% | **Rp 1.500** | PJP Berlisensi BI |
| **Tripay** | Rp 4.250 | Rp 4.250 (BCA Rp 5.500) | N/A | 2.0% – 3.0% | Rp 750 + 0.7% | Rp 2.500 – 4.000 | Agregator Retail |
| **Midtrans** | Rp 4.000 | Rp 4.000 (BCA Rp 4.000) | N/A | 1.5% – 2.0% | 0.7% (0% Mikro) | Rp 5.000 (Iris) | PJP GoTo Group |
| **Direct Bank (SNAP BI)** | **Rp 1.000 – 1.500** | **Rp 1.000 – 1.500** | N/A | N/A | 0.3% – 0.7% | **Rp 500 – 1.000** | Host-to-Host Bank Resmi |
| **Moota / Cekmutasi (SaaS Mutasi)** | **Rp 0 / trx** (Rp 150rb/bln) | **Rp 0 / trx** (Rp 150rb/bln) | N/A | N/A | **Rp 0 / trx** | Rp 0 (Manual / auto) | Software Otomasi Mutasi |

*\*Catatan: QRIS Solosmartpay ≤ Rp 500.000 mengenakan Rp 300 flat, tetapi mewajibkan kode unik 1–999 yang dibayar oleh pelanggan.*

---

## 3. Analisis 4 Pilihan Alternatif Terbaik

### Opsi 1: Duitku Direct (Paling Mudah, Paling Minim Risiko Migrasi)
Karena Solosmartpay dibangun 100% di atas Duitku (terbukti dari kamus kode metode `M2`, `I1`, `BT`, dll.):
- **Keuntungan**:
  - Format payload dan struktur flow transaksi hampir identik.
  - VA Mandiri turun dari **Rp 4.300 → Rp 4.000** (hemat Rp 300 per transaksi).
  - VA BNI, BRI, Permata, CIMB turun dari **Rp 3.300 → Rp 3.000** (hemat Rp 300 per transaksi).
  - VA Sampoerna / Artha Graha turun dari **Rp 1.800 → Rp 1.500** (hemat Rp 300 per transaksi).
  - **E-Wallet hemat besar**: ShopeePay dari **4,25% → ~1,5% – 2,0%** (hemat > 50% potongan biaya).
- **Kekurangan**: Belum memotong biaya ke tingkat wholesale tier-1 perbankan.

---

### Opsi 2: Oy! Bisnis (PT Dompet Harapan Bangsa) — Rekomendasi Agregator Termurah
Oy! Bisnis adalah PJP Kategori 1 berizin Bank Indonesia yang fokus pada infrastruktur pembayaran wholesale B2B.
- **Biaya**:
  - Virtual Account: **Rp 2.000 – Rp 2.500** flat untuk BCA, Mandiri, BNI, BRI, dan Permata (hemat **Rp 800 – Rp 1.800 per transaksi** dibanding Solosmartpay).
  - Disbursement (BI-FAST API): **Rp 1.000 – Rp 1.500** per penarikan (Solosmartpay Rp 2.500, hemat 40%–60%).
  - QRIS Dinamis: MDR 0% untuk transaksi mikro (< Rp 100.000) dan 0,7% reguler.
- **Keunggulan**: API modern, dokumentasi lengkap, dashboard rekonsiliasi otomatis, SLA > 99,9%.

---

### Opsi 3: Moota / Cekmutasi (SaaS Mutasi Flat — Untuk Volume Tinggi)
Jika alasan memakai Solosmartpay adalah sistem **Kode Unik Otomatis** untuk transfer bank atau QRIS statis:
- **Biaya**:
  - Membayar biaya langganan bulanan flat: **Rp 100.000 – Rp 200.000 / bulan (unlimited transaksi)**.
  - Biaya per transaksi: **Rp 0**.
- **Perbandingan Finansial**:
  - Pada 5.000 transaksi QRIS mikro di Solosmartpay: 5.000 × Rp 300 = **Rp 1.500.000 / bulan**.
  - Pada Moota: **Rp 150.000 / bulan**.
  - **Penghematan: Rp 1.350.000 / bulan (hemat 90%)**.
- **Kelemahan**: Memerlukan rekening bank penampung sendiri dan scraping internet banking (kurang cocok untuk enterprise yang membutuhkan VA instan berizin PJP).

---

### Opsi 4: Direct SNAP BI Host-to-Host (Untuk Bisnis Skala Menengah–Besar)
Integrasi langsung ke Bank Mandiri (Mandiri API), BRI (BRIVA), BNI (BNI Open API), atau BCA melalui standar **SNAP BI (Standar Nasional Open API Pembayaran)**:
- **Biaya**:
  - Virtual Account: **Rp 1.000 – Rp 1.500** flat per transaksi (tidak ada perantara gateway sama sekali).
  - Disbursement BI-FAST: **Rp 500 – Rp 1.000** per transfer.
- **Kelemahan**: Memerlukan legalitas PT, rekening giro bisnis di masing-masing bank, dan proses integrasi teknis 1–2 bulan per bank.

---

## 4. Simulasi Penghematan Finansial Riil

### Skenario Bisnis: 5.000 Transaksi / Bulan
*Komposisi: 3.000 VA (rata-rata), 1.500 QRIS (≤ Rp 100.000), 500 E-Wallet (rata-rata Rp 100.000), 50 kali Penarikan Saldo.*

| Pos Biaya | Solosmartpay | Duitku Direct | Oy! Bisnis | Penghematan Bersih / Bulan |
|---|---|---|---|---|
| **Virtual Account (3.000 trx)** | Rp 9.900.000 | Rp 9.000.000 | Rp 6.600.000 | **+ Rp 3.300.000** (via Oy!) |
| **QRIS Mikro (1.500 trx)** | Rp 450.000 | Rp 525.000 (0.7%) | Rp 0 (MDR 0% BI) | **+ Rp 450.000** (via Oy! / Acquirer) |
| **E-Wallet (500 trx @ Rp 100rb = Rp 50jt)** | Rp 2.125.000 (4.25%) | Rp 1.000.000 (2.0%) | Rp 800.000 (1.6%) | **+ Rp 1.325.000** (via Oy!) |
| **Penarikan Saldo (50x)** | Rp 125.000 | Rp 125.000 | Rp 60.000 | **+ Rp 65.000** |
| **TOTAL BIAYA PER BULAN** | **Rp 12.600.000** | **Rp 10.650.000** | **Rp 7.460.000** | **HEMAT Rp 5.140.000 / bulan** |
| **TOTAL BIAYA PER TAHUN** | **Rp 151.200.000** | **Rp 127.800.000** | **Rp 89.520.000** | **HEMAT Rp 61.680.000 / tahun (~41%)** |

---

## 5. Rekomendasi Eksekusi & Langkah Selanjutnya

1. **Jangka Pendek (1–2 Minggu) — Langsung Cutover ke Duitku Direct**:
   - Karena API Duitku adalah upstream dari Solosmartpay, migrasi teknis hanya memerlukan perubahan endpoint URL dan format hashing signature tanpa perombakan alur bisnis.
   - Langsung menghemat 50% biaya MDR e-wallet dan Rp 300 per Virtual Account.
2. **Jangka Menengah (1 Bulan) — Buka Akun Oy! Bisnis / Winpay**:
   - Dapatkan tarif VA wholesale Rp 2.000 – Rp 2.500 dan disbursement BI-FAST Rp 1.000.
   - Memotong biaya gateway hingga >40%.
3. **Volume Besar (> 10.000 trx/bulan) — Implementasikan SNAP BI Direct**:
   - Integrasikan langsung ke BRIVA (BRI) dan BNI VA untuk memangkas fee ke Rp 1.000 – Rp 1.500 per transaksi.
