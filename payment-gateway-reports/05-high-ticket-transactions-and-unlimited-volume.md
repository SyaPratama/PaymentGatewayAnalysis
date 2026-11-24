# Analisis Transaksi Nilai Besar (Rp 15 Juta) & Arsitektur Volume Tanpa Batas

> **Cetak Biru Skalabilitas Finansial**: Strategi penanganan transaksi tunggal nominal besar (Rp 15.000.000), pencairan dana instan (BI-FAST), serta arsitektur gateway tanpa batas harian yang aman dari pemblokiran sistem anti-fraud perbankan.

---

## 1. Analisis Transaksi Tunggal Rp 15.000.000

Transaksi senilai Rp 15 juta memerlukan penanganan terpisah antara sisi pencairan dana (Money-Out) dan sisi pembayaran masuk (Money-In).

```
                            [ Transaksi Rp 15.000.000 ]
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │                                               │
                 ▼                                               ▼
      [ Sisi Money-Out (Penarikan) ]                  [ Sisi Money-In (Pembayaran) ]
      - Rel: BI-FAST API resmi Bank Indonesia        - Pilihan 1: Virtual Account (Rekomendasi Utama)
      - Limit: s.d. Rp 250.000.000 / transaksi         - Pilihan 2: QRIS Dinamis (Limit s.d. Rp 20 Jt)
      - Biaya Modal: Rp 1.000 – Rp 2.500 flat          - Peringatan: Hindari Bot Mutasi Kode Unik!
      - Margin pada Fee 0,5%: Rp 72.500 / penarikan
```

---

## 2. Penarikan Dana (Money-Out / Disbursement Rp 15 Juta)

Menarik saldo Rp 15 juta dalam satu kali penarikan sangat aman dan didukung penuh oleh infrastruktur nasional:

| Parameter | Spesifikasi & Regulasi |
|---|---|
| **Protokol Rel** | **BI-FAST** (Bank Indonesia Fast Payment) via API SNAP |
| **Batas Maksimal Transfer** | **Rp 250.000.000 per transaksi** (PADG Bank Indonesia No. 23/25/PADG/2021) |
| **Waktu Penyelesaian** | Instan (1–5 detik), operasional 24/7/365 |
| **Biaya Modal (COGS)** | **Rp 1.000 – Rp 2.500 flat** (via Oy! Bisnis, Duitku, atau direct perbankan) |
| **Model Monetisasi (0,5%)** | Fee 0,5% dari Rp 15 juta = **Rp 75.000**<br>Laba bersih platform per penarikan = **Rp 72.500 – Rp 74.000** |

---

## 3. Pembayaran Masuk (Money-In Rp 15 Juta): VA vs QRIS

### A. Virtual Account (Sangat Direkomendasikan untuk Nilai Besar)
Untuk nominal Rp 15 juta, Virtual Account adalah instrumen pembayaran paling ideal:
- **Limit Transaksi**: Rp 50.000.000 s.d. Rp 1.000.000.000 per transaksi.
- **Biaya Modal**: Flat **Rp 1.500 – Rp 3.000** per transaksi (bukan persentase).
- **Profitabilitas**: Jika merchant/pelanggan dibebankan fee 0,5% (Rp 75.000), margin keuntungan bersih platform mencapai **> Rp 72.000 per transaksi**.
- **Tingkat Keberhasilan (Success Rate)**: Mendekati 100%, karena nasabah transfer melalui menu transfer bank standar.

### B. QRIS Dinamis (Dapat Digunakan dengan Catatan)
- **Limit Resmi Bank Indonesia**: Batas maksimal transaksi QRIS reguler adalah **Rp 20.000.000 per transaksi** (Keputusan Dewan Gubernur BI No. 24/1/KEP.DsG/2022). Nominal Rp 15 juta masih berada di dalam batas resmi.
- **Kendala Limit Aplikasi Pembeli**: Banyak bank/e-wallet (seperti BCA Mobile, GoPay, OVO) menerapkan limit harian scan QRIS nasabah perorangan sebesar Rp 5.000.000 s.d. Rp 10.000.000 secara default. Pembayaran pembeli dapat ditolak oleh aplikasi bank mereka jika belum menaikkan limit akun.
- **Kategori Merchant Wajib**: Akun merchant QRIS harus terdaftar pada tier **Usaha Kecil (UKE)** atau **Usaha Menengah (UME)** di acquirer. Akun Usaha Mikro (UMI) dilarang menerima transaksi satuan Rp 15 juta.

### C. Bahaya Bot Mutasi Kode Unik pada Nominal Rp 15 Juta
**Dilarang keras menggunakan QRIS statis modifikasi kode unik (+Rp 7 -> Rp 15.000.007) pada rekening tabungan pribadi**:
- Sistem anti-fraud (AML/CFT) perbankan memantau mutasi di atas Rp 10 juta yang masuk ke rekening tabungan perorangan.
- Penerimaan dana Rp 15.000.007 dari pihak ketiga tanpa nomor VA resmi akan langsung memicu freeze/blokir otomatis rekening oleh bank dalam 1×24 jam karena anomali profil rekening.

---

## 4. Solusi Gateway "Tanpa Batas Harian" & Bebas Blokir

Jika platform memproses volume transaksi harian tanpa batas (unlimited frequency & volume), sistem bot mutasi rekening perorangan pasti kolaps karena limit collision kode unik (maksimal 999 transaksi aktif bersamaan) dan pemblokiran otomatis bank.

Tiga arsitektur solusi untuk mencapai kapasitas tanpa batas:

```
[ Pilihan Arsitektur Skala Besar Tanpa Batas ]
  │
  ├── 1. Kemitraan Sub-Merchant Acquirer (Payment Facilitator / ISO)
  │      └── Terbitkan Sub-NMID per toko via Bank Nobu / Netzme / Finnet
  │      └── Modal MDR 0,3% -> Jual 0,5% -> Laba 0,2% (100% Legal & Unlimited)
  │
  ├── 2. Rekening Giro Korporasi Whitelisted (Corporate Cash Management)
  │      └── Giro Bisnis PT (BCA/Mandiri) dengan formulir High-Velocity Merchant
  │      └── Menggunakan integrasi SNAP BI resmi tanpa batas transfer harian
  │
  └── 3. Model Non-Custodial Multi-Tenant (Technical Enabler SaaS)
         └── Dana langsung ke rekening masing-masing merchant
         └── Izin cukup PSE Komdigi, fee 0,5% ditarik via saldo deposit kuota
```

### 1. Sub-Merchant Acquirer (Payment Facilitator / ISO) — Jalur Terbaik
- Menjadi mitra resmi Acquirer berizin PJP Kategori 1 (seperti **Bank Nobu**, **Netzme**, atau **Finnet**).
- Platform Anda menerbitkan Sub-Merchant (NMID unik) untuk setiap toko secara programmatic via API.
- **Kapasitas**: Tanpa batas harian total platform. Setiap toko memiliki limit transaksi mandiri.
- **Finansial**: Modal MDR dari Acquirer **0,3%**. Anda menjual ke merchant **0,5%**.
- **Kepatuhan**: 100% legal di bawah payung hukum izin PJP Acquirer resmi. Anti-blokir selamanya.

### 2. Rekening Giro Korporasi "High-Velocity" Terdaftar
Jika platform menampung dana transaksi:
- Wajib menggunakan **Rekening Giro Badan Usaha (PT)** dengan fasilitas Corporate Cash Management (BCA KlikBCA Bisnis / Mandiri Cash Management).
- Tanda tangani addendum *high-velocity merchant acquiring* dengan Divisi Corporate Banking.
- Rekening masuk daftar *whitelisted* sistem AML bank sehingga volume transaksi puluhan miliar per hari tidak dibekukan secara sepihak.

### 3. Model Non-Custodial Multi-Tenant (SaaS POS / Technical Enabler)
- Platform hanya berperan sebagai penyedia software orkestrasi dan webhook notifier.
- Setiap merchant menautkan rekening/QRIS mereka sendiri (*Bring Your Own Account*).
- Dana pembayaran mengalir langsung dari pelanggan ke rekening merchant.
- Platform tidak menampung uang merchant (*zero custody*), sehingga **tidak memerlukan izin PJP Bank Indonesia (cukup PSE Komdigi)**.
- Monetisasi fee 0,5% dipotong dari saldo deposit kuota merchant (*prepaid balance*) setiap kali transaksi berhasil.

---

## 5. Matriks Rekomendasi Eksekusi

| Kebutuhan Bisnis | Solusi yang Direkomendasikan | Legalitas & Izin | Estimasi Biaya Modal |
|---|---|---|---|
| **Penarikan Rp 15 Juta Instan** | API BI-FAST (Duitku / Oy! Bisnis / SNAP BI) | PJP Payout Resmi | Rp 1.000 – Rp 2.500 / penarikan |
| **Pembayaran Masuk Rp 15 Juta** | Virtual Account Bank (BCA, Mandiri, BRI, BNI) | PJP VA Resmi | Rp 1.500 – Rp 3.000 flat |
| **QRIS Dinamis Volume Unlimited** | Sub-Merchant PayFac (Bank Nobu / Netzme) | Lisensi Acquirer PJP 1 | MDR 0,3% (Jual 0,5%) |
| **Hindari Syarat Modal PJP Rp 15 M** | Arsitektur Non-Custodial (SaaS POS) | PSE Komdigi | Biaya Server Cloudflare / VPS |
