# Cetak Biru Skalabilitas Resmi (PayFac), Rekayasa Laba 0,5% Bersih & Arsitektur Sandbox

> **Panduan Transisi Enterprise**: Strategi migrasi dari bot mutasi HP ke kemitraan Payment Facilitator (PayFac) resmi Bank Acquirer, rekayasa pemisahan beban biaya (0,3% pembeli & 0,5% merchant) secara legal anti-surcharge, serta arsitektur mode sandbox multi-environment.

---

## 1. Transisi Jalur Resmi: Payment Facilitator (PayFac / ISO)

Ketika platform memiliki modal operasional dan ingin meniadakan ketergantungan pada perangkat HP fisik / bot scraper, jalur resmi berbiaya terendah di Indonesia adalah menjadi **Payment Facilitator (PayFac) / Mitra ISO Resmi Acquirer** (seperti Bank Nobu, Netzme, Finnet, atau DOKU Wholesale).

```
[ Merchant Daftar di Portal Anda ]
                 │
                 ▼
[ API Gateway Tembak Acquirer ] ──> Terbit Sub-NMID QRIS Toko Resmi (Instan)
                 │
                 ▼
[ Pembeli Scan QRIS Dinamis Asli ] (Nominal Bulat, Tanpa Kode Unik)
                 │
                 ▼
[ Server Bank Acquirer Kirim Webhook Resmi ke Cloud Anda ] (< 500 ms)
                 │
                 ▼
[ Server Otomatis Split Dana, Catat Saldo & Dispatch Webhook Toko ]
```

### Keunggulan Jalur PayFac Resmi:
1. **Zero Hardware Maintenance**: Tidak ada lagi HP fisik, baterai, kartu SIM, atau aplikasi MacroDroid.
2. **Tanpa Kode Unik (Nominal Bulat)**: Pembeli membayar tepat Rp 200.000, bukan Rp 200.007. Menghilangkan 100% kegagalan transaksi akibat salah nominal.
3. **Keandalan SLA 99,99%**: Webhook dikirim langsung dari data center bank/acquirer resmi secara instan.
4. **Kapasitas Skalabilitas Tanpa Batas**: Mampu memproses puluhan ribu transaksi per detik (*high-concurrency*).

---

## 2. Rekayasa Finansial Laba Bersih 0,5% Penuh (Pemisahan Beban Biaya)

Tantangan utama transaksi di atas Rp 100.000 adalah potongan MDR bank sebesar **0,3%**. Jika Anda hanya memotong 0,5% dari merchant, laba bersih Anda tersisa 0,2%.

Solusi industri finTech untuk mempertahankan **laba bersih 0,5% utuh tanpa menaikkan tarif merchant**:

```
[ Harga Barang di Toko Merchant: Rp 200.000 ]
                     │
                     ▼
1. SISI PEMBELI (Dikenakan 0,3% "Biaya Layanan Sistem")
   - Pembeli membayar total di kasir QRIS: Rp 200.600
                     │
                     ▼
2. SISI BANK ACQUIRER (Potong MDR Resmi 0,3%)
   - Bank Acquirer memotong MDR 0,3%: Rp 600
   - Uang bersih yang diteruskan bank ke platform: Rp 200.000 utuh
     (Biaya MDR bank tertutup 100% oleh biaya layanan pembeli)
                     │
                     ▼
3. SISI MERCHANT (Dipotong Fee Platform 0,5% Otomatis)
   - Sistem gateway memotong fee platform 0,5%: Rp 1.000
   - Saldo bersih masuk ke dompet merchant: Rp 199.000
                     │
                     ▼
4. SISI OWNER GATEWAY (LABA BERSIH PENUH)
   - Laba bersih masuk ke rekening platform Anda: Rp 1.000 utuh (0,5% bersih)
```

### Matriks Arus Kas Transaksi Rp 200.000:

| Entitas | Arus Kas Masuk / Keluar | Keterangan |
|---|---|---|
| **Pembeli** | Bayar **Rp 200.600** | Rp 200.000 pokok + Rp 600 Biaya Layanan Sistem |
| **Bank Acquirer** | Ambil **Rp 600** | MDR 0,3% resmi terbayar lunas tanpa membebani merchant |
| **Toko Merchant** | Terima **Rp 199.000** | Hanya dipotong 0,5% fee platform transparan sesuai janji |
| **Owner Gateway** | Laba **Rp 1.000** | **0,5% laba bersih utuh tanpa tergerus interchange fee** |

---

## 3. Kepatuhan Regulasi & Aspek Hukum Penambahan Biaya Pembeli

### A. Larangan Surcharging Bank Indonesia
- **Dasar Hukum**: Pasal 52 PADG Bank Indonesia No. 21/18/PADG/2019 tentang Implementasi Standar Nasional QRIS.
- **Isi Ketentuan**: Merchant dan penyedia jasa pembayaran dilarang mengenakan biaya tambahan (*surcharge*) kepada pengguna/pembeli atas transaksi QRIS.
- **Sanksi**: Pencabutan izin QRIS dan pemblokiran merchant jika terbukti membebankan MDR kepada konsumen.

### B. Solusi Legal: "Biaya Layanan / Convenience Fee"
Seluruh platform e-commerce nasional (Tokopedia, Shopee, Blibli, Duitku) menggunakan konstruksi hukum **Biaya Penanganan / Jasa Sistem Elektronik**:

| Terminologi Ilegal (Dilarang Keras BI) | Terminologi Legal (100% Sah & Diizinkan) |
|---|---|
| ❌ *Biaya Admin QRIS: Rp 600* | ✅ **Biaya Layanan: Rp 600** |
| ❌ *Surcharge MDR 0,3%: Rp 600* | ✅ **Biaya Penanganan Sistem: Rp 600** |
| ❌ *Potongan Bank QR: Rp 600* | ✅ **Convenience Fee: Rp 600** |

- **Payung Hukum**: UU Perlindungan Konsumen No. 8/1999 memperbolehkan biaya penanganan sistem selama **dicantumkan secara transparan pada rincian tagihan sebelum konsumen menekan tombol bayar**.

---

## 4. Ekstra Sumber Profit & Blended Margin

Selain margin 0,5% pada transaksi, platform memiliki 2 sumber keuntungan pelengkap:

1. **Biaya Penarikan Saldo (Disbursement Margin)**:
   - Biaya modal transfer antar-bank BI-FAST H2H: **Rp 500 – Rp 1.000**.
   - Biaya penarikan yang dibebankan ke merchant: **Rp 2.500 flat**.
   - **Laba bersih ekstra**: **Rp 1.500 – Rp 2.000 per penarikan dana**.
2. **Subsidi Silang Keranjang Belanja (Blended Margin Mikro)**:
   - Berdasarkan data ASPI, ~70% transaksi QRIS ritel bernilai **≤ Rp 100.000**.
   - Pada transaksi ini, MDR Bank resmi adalah **0% (Rp 0)**.
   - Platform mengantongi 0,5% murni (100% profit) tanpa perlu membebankan biaya layanan apa pun kepada pembeli.

---

## 5. Kebutuhan Modal & Dokumen Transisi PayFac Resmi

| Pos Kebutuhan | Spesifikasi | Estimasi Biaya |
|---|---|---|
| **Badan Usaha** | Pendirian **PT (Perseroan Terbatas)** biasa atau PT Perorangan dengan KBLI 62012 & 62090 | Rp 5.000.000 – Rp 8.000.000 |
| **Izin Pemerintah** | Tanda Daftar Penyelenggara Sistem Elektronik (**TDPSE Komdigi**) Lingkup Privat | **Rp 0 (Gratis via OSS)** |
| **Security Deposit Acquirer** | Dana jaminan mengendap (*Escrow Guarantee Float*) di Bank Acquirer mitra | Rp 20.000.000 – Rp 50.000.000 (Dana tetap milik PT Anda) |
| **Infrastruktur Cloud** | Cloud VPS regional Indonesia (AWS Jakarta, GCP, Alibaba Cloud) dengan sertifikasi ISO 27001 | Rp 750.000 – Rp 1.500.000 / bulan |
| **Total Modal Awal** | Siap beroperasi resmi tanpa perlu izin modal PJP Rp 15 Miliar | **~Rp 30.000.000 – Rp 60.000.000** |

---

## 6. Arsitektur Mode Sandbox (Lingkungan Pengujian)

Mode Sandbox memungkinkan calon merchant menguji integrasi REST API, popup checkout, dan penanganan webhook tanpa uang sungguhan dan tanpa menunggu verifikasi KYC selesai.

```
                  [ Merchant API Request ]
                             │
                             ▼
              [ Header Auth: X-API-Token ]
                             │
            ┌────────────────┴────────────────┐
            ▼                                 ▼
   Prefix "gw_test_..."              Prefix "gw_live_..."
   [ Mode Sandbox ]                  [ Mode Produksi ]
   - Data isolasi (Uang palsu)       - Transaksi uang sungguhan
   - Simulator bayar instan          - Terhubung ke Acquirer Bank
   - Header X-Gateway-Sandbox        - Rekening & saldo riil
```

### A. Format Kunci Autentikasi
- **Kunci Produksi**: `gw_live_xxxxxxxxxxxxxxxxxxxxxxxx`
- **Kunci Sandbox**: `gw_test_xxxxxxxxxxxxxxxxxxxxxxxx`

### B. Simulator Checkout & API Simulasi
1. **Banner Simulator Checkout**:
   Di halaman checkout sandbox (`/pay/{invoice_id}`), tampilkan banner pengujian kuning dengan 3 tombol interaktif:
   - `[Bayar Berhasil]` -> Mengubah status menjadi `paid` dan menembak webhook.
   - `[Simulasikan Gagal]` -> Mengubah status menjadi `failed`.
   - `[Simulasikan Kedaluwarsa]` -> Mengubah status menjadi `expired`.
2. **Endpoint REST API Simulasi**:
   ```http
   POST /v1/sandbox/payments/{id}/simulate
   Headers:
     X-API-Token: gw_test_xxxxxxxxxxxx
     Content-Type: application/json
   Body:
     {"result": "paid"}
   ```

### C. Keamanan Webhook Sandbox
Untuk mencegah toko merchant memproses pesanan asli secara tidak sengaja dari tagihan uji coba:
1. **Header Webhook Khusus**: `X-Gateway-Sandbox: true`.
2. **Payload Tag**: Menyertakan parameter `"sandbox": true` di root body webhook:
   ```json
   {
     "id": "evt_test_90218401",
     "type": "payment.paid",
     "sandbox": true,
     "created_at": "2026-10-25T10:00:00Z",
     "data": {
       "reference": "ORDER-DEMO-001",
       "amount": 100000,
       "status": "paid"
     }
   }
   ```

### D. Isolasi Saldo Dompet & Auto-Pruning
- Transaksi sandbox disimpan pada tabel invoice dengan penanda flag `is_sandbox = TRUE`.
- **Aturan Ketat**: Sistem dilarang menambahkan saldo riil dompet merchant jika transaksi berstatus sandbox.
- **Pembersihan Rutin**: Jadwalkan cron job harian untuk menghapus tagihan sandbox yang berumur lebih dari 30 hari guna mencegah membengkaknya ukuran database:
  ```php
  // routes/console.php
  Schedule::call(function () {
      Invoice::where('is_sandbox', true)
          ->where('created_at', '<', now()->subDays(30))
          ->delete();
  })->daily();
  ```
