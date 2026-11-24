# Panduan Operasional: Master QRIS Terpusat, Rotasi Multi E-Wallet, & Setup Android Listener HP Bekas

> **Cetak Biru Operasional Praktis**: Panduan mendirikan payment gateway mandiri menggunakan Master QRIS terpusat milik sendiri, strategi rotasi multi e-wallet (DANA, ShopeePay, GoBiz) untuk menghindari pemblokiran, komparasi emulator vs HP fisik, dan panduan konfigurasi Android listener 24/7 pada HP bekas (Vivo/Funtouch OS).

---

## 1. Arsitektur Model Kustodian Terpusat (Owner sebagai Penampung)

Pada model ini, Anda berperan persis seperti **Solosmartpay**: seluruh pembayaran pembeli masuk ke rekening/e-wallet Anda terlebih dahulu, saldo dicatat di database sistem, dan merchant mencairkan saldo melalui dashboard (*withdrawal*).

```
[ Pembeli di Toko Merchant ]
               │
               │ 1. Scan Dynamic QR (Master QRIS Milik ANDA)
               ▼
[ REKENING / E-WALLET ANDA ] <── 2. Uang masuk 100% detik itu juga ke akun Anda
               │
               │ 3. Notifikasi Saldo Masuk Terkirim ke HP Listener Anda
               ▼
[ HP Listener (Vivo / Android Service) ]
               │
               │ 4. Tangkap Notifikasi & Ekstrak Nominal (< 1 detik)
               ▼
[ Server Backend Gateway Anda ]
  ├── 5. Cocokkan Tagihan & Toko Merchant Pemilik Order
  ├── 6. Potong Fee 0,5% Otomatis:
  │      Contoh transaksi Rp 100.000:
  │      - Fee Platform Anda (0,5%): Rp 500
  │      - Masuk Saldo Dompet Merchant: Rp 99.500
  └── 7. Kirim Webhook Status "PAID" ke Web Toko Merchant
               │
               ▼
[ Merchant Minta Pencairan Saldo (Withdrawal) di Dashboard ]
               │
               ▼
[ Anda Transfer Saldo Bersih via BI-FAST API ke Rekening Merchant ]
  (Potong biaya penarikan flat Rp 2.500 per pencairan)
```

### Dua Sumber Keuntungan (Double Profit Stream):
1. **Fee Transaksi 0,5%**: Dipotong otomatis saat uang masuk (Rp 500 per transaksi Rp 100.000 + hak kode unik).
2. **Biaya Penarikan (Withdrawal Fee)**: Membebankan biaya penarikan Rp 2.500 per transfer ke rekening bank merchant (modal transfer BI-FAST Rp 1.000 -> laba bersih Rp 1.500 per penarikan).

---

## 2. Strategi Rotasi Multi E-Wallet (DANA + ShopeePay + GoBiz)

Jika ribuan transaksi masuk ke 1 akun perorangan dalam 1 hari, akun tersebut akan dibekukan oleh sistem Anti-Money Laundering (AML) bank/e-wallet. Solusinya adalah membagi beban ke **3 akun merchant e-wallet berbeda secara bergantian (Round-Robin)**:

```
[ Request Checkout Rp 50.000 ]
               │
               ▼
[ Engine Pemilih Channel (Weighted Round-Robin) ]
  ├── Cek kuota kode unik DANA -> Jika kosong, pakai Master QRIS DANA
  ├── Cek kuota kode unik ShopeePay -> Jika DANA penuh, pakai ShopeePay
  └── Cek kuota kode unik GoPay -> Jika ShopeePay penuh, pakai GoBiz
               │
               ▼
[ Suntik Dinamis ke Master QRIS Terpilih ]
  - Misal terpilih ShopeePay: Suntik Rp 50.004 ke Master QRIS ShopeePay
  - Lock Redis: qris:lock:shopee:50004
```

### Keuntungan Rotasi:
1. **Beban Terbagi (Anti-Blokir Alami)**: 300 transaksi/hari dipecah menjadi 100 transaksi per akun (lolos radar AML e-wallet).
2. **Kapasitas Kode Unik Melonjak 3× Lipat**: Kapasitas transaksi nominal sama bersamaan meningkat dari 999 menjadi **2.997 transaksi aktif**.
3. **Failover Otomatis**: Jika DANA sedang gangguan, sistem otomatis memindahkan 100% rute transaksi ke ShopeePay dan GoPay tanpa disadari oleh merchant.

---

## 3. Komparasi Saluran Listener: Emulator PC vs Cloud Phone vs HP Bekas

| Parameter | Emulator PC Biasa (LDPlayer/BlueStacks) | Cloud Phone ARM (Redfinger/LDCloud) | HP Fisik Bekas (Vivo Y15s / Android Lain) |
|---|---|---|---|
| **Biaya Investasi** | Server VPS CPU Tinggi ($20–40/bln) | Rp 80.000 – Rp 150.000 / bulan | **Rp 0 (Menggunakan HP lama yang ada)** |
| **Proteksi SafetyNet / Play Integrity** | **Gagal / Sering Terdeteksi Root** | Lolos (Arsitektur Chipset ARM Asli) | **100% Lolos (Perangkat Fisik Resmi)** |
| **Kestabilan Sinyal** | Sangat Tinggi (Jaringan Data Center) | Sangat Tinggi | Tergantung Stabilitas Wi-Fi Rumah/Kantor |
| **Risiko Hardware** | Nol (Virtual) | Nol (Cloud) | Risiko baterai kembung jika dicolok terus |

**Kesimpulan Praktisi**: HP fisik bekas adalah solusi termurah, paling stabil, dan 100% aman dari blokir deteksi emulator aplikasi perbankan.

---

## 4. Panduan Setup HP Bekas 24/7 (Studi Kasus: Vivo / Funtouch OS)

Sistem operasi Vivo (Funtouch OS) memiliki sistem penghemat daya agresif yang sering mematikan aplikasi di latar belakang. Lakukan 3 langkah konfigurasi wajib berikut:

### Langkah 1: Aktifkan "Mulai Otomatis" (Autostart)
1. Buka menu `Pengaturan` -> `Aplikasi dan Izin` -> `Pengelola Izin`.
2. Pilih menu **Mulai Otomatis (Autostart)**.
3. Aktifkan sakelar (toggle ON) untuk **MacroDroid**, **DANA**, **ShopeePay Merchant**, dan **GoBiz**.

### Langkah 2: Izinkan Konsumsi Baterai Tinggi di Latar Belakang
1. Buka `Pengaturan` -> `Baterai`.
2. Masuk ke **Konsumsi Daya Latar Belakang Tinggi**.
3. Cari aplikasi MacroDroid, DANA, ShopeePay, dan GoBiz.
4. Ubah status menjadi **"Izinkan konsumsi daya latar belakang tinggi"** (Jangan pilih "Batasi / Smart Control").

### Langkah 3: Gembok Aplikasi di Layar Recent Apps (Lock RAM)
1. Buka aplikasi MacroDroid, DANA, ShopeePay, dan GoBiz satu per satu.
2. Buka menu *Recent Apps* (usap layar dari bawah atau tekan tombol navigasi kotak).
3. Tahan jendela aplikasi MacroDroid hingga muncul menu pop-up, lalu tekan **ikon Gembok (Lock)**.
4. Pastikan ada ikon gembok kecil di sudut aplikasi agar aplikasi tidak terbunuh saat tombol *Bersihkan Semua* ditekan.

---

## 5. Konfigurasi Otomasi Notifikasi dengan MacroDroid

MacroDroid bertindak sebagai jembatan yang menangkap push notification e-wallet lalu menembakkannya ke API backend Anda:

1. **Trigger (Pemicu)**:
   - Pilih `Pemberitahuan` -> `Pemberitahuan Diterima`.
   - Pilih opsi **Pilih Aplikasi** -> Centang:
     - `DANA` (`id.dana`)
     - `ShopeePay / Shopee` (`com.shopee.merchant` / `com.shopee.id`)
     - `GoBiz / Gojek` (`com.gojek.gopartner`)
2. **Action (Tindakan)**:
   - Pilih `Konektivitas` -> `Permintaan HTTP (HTTP Request)`.
   - Metode: `POST`.
   - URL: `https://api.gatewayanda.com/api/v1/internal/incoming-mutation`.
   - Content-Type: `application/json`.
   - Request Body:
     ```json
     {
       "secret_key": "kunci_rahasia_internal_gateway_anda",
       "package_name": "{notification_package_name}",
       "title": "{notification_title}",
       "content": "{notification_text}",
       "received_at": {system_time}
     }
     ```
3. Berikan izin **Akses Pemberitahuan (Notification Listener Access)** pada setelan Android saat diminta.

### Regex Pembersih Nominal di Controller Backend (PHP/Laravel)

```php
public function ingest(Request $request): JsonResponse
{
    // Validasi token rahasia HP listener
    if ($request->input('secret_key') !== config('services.listener.secret')) {
        return response()->json(['error' => 'Forbidden'], 403);
    }

    $rawText = $request->input('content'); // Contoh: "Pembayaran diterima: Rp 50.004 dari MOHAMMAD"

    // Ekstrak angka setelah string "Rp" atau "sebesar"
    if (!preg_match('/(?:Rp\.?|sebesar)\s*([\d\.]+)/i', $rawText, $matches)) {
        return response()->json(['message' => 'Format notifikasi tidak memuat nominal'], 200);
    }

    // Bersihkan titik ribuan: "50.004" -> 50004
    $amount = (int) str_replace(['.', ','], '', $matches[1]);

    // Jalankan Core Matching Engine Laporan 04 & 06
    return app(MutationMatchingService::class)->process($amount);
}
```

---

## 6. Mitigasi Keamanan Baterai 24/7 (Cegah Baterai Kembung)

Ponsel Android yang terhubung ke charger selama berbulan-bulan berisiko mengalami baterai kembung (*bloated battery*) yang dapat merusak layar atau memicu korsleting.

### Trik Mitigasi Murah (Smart Plug Wi-Fi):
1. Pasang adaptor charger HP ke **Smart Plug Wi-Fi** (contoh: Bardi / Tuya seharga Rp 50.000 – Rp 70.000).
2. Buat jadwal charging berkala di aplikasi Smart Life / Bardi:
   - **Pukul 08.00 – 09.00**: Charger ON (isi baterai s.d. 80%).
   - **Pukul 09.00 – 13.00**: Charger OFF (baterai turun alami s.d. 30%).
   - Ulangi siklus 4 jam sekali sepanjang hari.
3. Baterai ponsel akan tetap sehat dan dingin bertahun-tahun.

---

## 7. Skema Database Dompet & Withdrawal Merchant

```sql
-- 1. Penambahan Kolom Saldo Dompet Merchant
ALTER TABLE merchants ADD COLUMN balance BIGINT DEFAULT 0;

-- 2. Tabel Antrean Penarikan Dana (Withdrawal)
CREATE TABLE withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID REFERENCES merchants(id) ON DELETE RESTRICT,
    bank_name VARCHAR(50) NOT NULL,              -- BCA, Mandiri, BRI, BNI
    account_number VARCHAR(50) NOT NULL,         -- Nomor rekening tujuan
    account_holder VARCHAR(100) NOT NULL,        -- Nama buku tabungan merchant
    amount BIGINT NOT NULL,                      -- Saldo yang ditarik (misal Rp 1.000.000)
    fee BIGINT DEFAULT 2500,                     -- Biaya admin WD Rp 2.500
    net_disbursed BIGINT NOT NULL,               -- Saldo cair bersih (Rp 997.500)
    status VARCHAR(20) DEFAULT 'pending',        -- pending, processing, completed, rejected
    disbursed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 8. Checklist Kepatuhan Anti-Fraud (Penting)

1. **Wajib KYC Dokumen Toko**: Wajibkan merchant mengunggah KTP asli, foto selfie dengan KTP, dan bukti toko/katalog jualan sebelum akun diaktifkan.
2. **Aturan Settlement H+1 (T+1 Holding Period)**: Jangan izinkan merchant menarik dana di detik yang sama transaksi terjadi (*instant payout*). Tahan dana selama minimal **24 jam**. Jika pembeli melaporkan penipuan, saldo toko masih berada di sistem Anda untuk proses pengembalian dana (*refund*).
3. **Whitelist Kategori Transaksi**: Tolak pendaftaran merchant produk digital berisiko tinggi (judi online, voucher game ilegal, dan skema investasi cepat kaya) agar nomor rekening dan akun e-wallet Anda tidak dibekukan aparat hukum.
