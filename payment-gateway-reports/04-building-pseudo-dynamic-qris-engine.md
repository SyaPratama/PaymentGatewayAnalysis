# Panduan Rekayasa Teknis: Membangun Sistem QRIS Dinamis Mandiri ala Solosmartpay

> **Cetak Biru Teknis**: Panduan end-to-end membangun sistem QRIS dinamis berbasis modifikasi payload EMVCo, alokasi kode unik Redis, penangkap mutasi (mutation listener), dan webhook rekonsiliasi otomatis tanpa biaya per transaksi.

---

## 1. Arsitektur Sistem

Solosmartpay memodifikasi QRIS statis biasa menjadi QRIS dinamis secara on-the-fly, mengunci nominal pada aplikasi m-Banking pembeli, lalu memverifikasi mutasi masuk menggunakan kode unik (1–999).

```
[ Merchant Order: Rp 50.000 ]
              │
              ▼
[ Redis Atomic Code Allocator ] ──> Kunci Kode Unik (misal: +Rp 7 -> Rp 50.007)
              │
              ▼
[ EMVCo Dynamic Injector ]
  ├── 1. Baca master payload QRIS statis
  ├── 2. Ubah Tag 01 (Point of Initiation) menjadi "12" (Dynamic)
  ├── 3. Sisipkan Tag 54 (Nominal tagihan: 50007)
  └── 4. Hitung ulang Checksum CRC16-CCITT (Tag 63)
              │
              ▼
[ Render QR Code (PNG / SVG) ] ──> Ditampilkan ke pembeli
              │
              ▼
[ Pembeli Scan di BCA / Livin / Dana / GoPay ]
(Nominal Rp 50.007 terkunci otomatis di layar m-banking pembeli)
              │
              ▼
[ Saldo Masuk ke Rekening Penampung ]
              │
              ▼
[ Ingestion Layer (Notification Scraper / Webhook Mutasi) ]
              │
              ▼
[ Core Matching Engine ] ──> Cari order dengan total_amount = 50007
              │
              ▼
[ Update Status Order "PAID" & Dispatch Webhook Merchant ]
```

---

## 2. Bedah Spesifikasi EMVCo QRIS (ISO/IEC 18004) & Mekanisme Injeksi

String QRIS nasional di Indonesia mengikuti format EMVCo MPM (Merchant-Presented Mode) berbasis struktur **TLV (Tag - Length - Value)**:

| Tag | Panjang | Nama Field | Deskripsi & Nilai |
|:---:|:---:|:---|:---|
| **00** | 02 | Payload Format Indicator | Selalu `01` |
| **01** | 02 | Point of Initiation Method | `11` = Statis (pembeli ketik nominal); **`12` = Dinamis (nominal terkunci dari payload QR)** |
| **26–45** | var | Merchant Account Information | Data acquirer, NMID, MPAN, dan identitas merchant penerima dana |
| **52** | 04 | Merchant Category Code (MCC) | Contoh: `5812` (Restoran/F&B), `5411` (Grocery) |
| **53** | 03 | Transaction Currency | `360` (Kode ISO mata uang Rupiah / IDR) |
| **54** | var | **Transaction Amount** | **Nominal tagihan yang disuntikkan (Format TLV: Tag 54 + 2-digit panjang + nominal)** |
| **58** | 02 | Country Code | `ID` (Indonesia) |
| **59** | var | Merchant Name | Nama merchant terdaftar |
| **60** | var | Merchant City | Kota merchant terdaftar |
| **63** | 04 | **CRC Checksum** | **Checksum CRC16-CCITT (4 karakter heksadesimal huruf kapital)** |

### Detail Alur Injeksi String TLV
Contoh string QRIS statis bawaan stiker merchant:
```text
00020101021126580016ID.CO.SHOPEE.WWW01189360091800000000005204581253033605802ID5913Kopi Selo Solo6009Surakarta6304ABCD
```

Langkah mutasi menjadi dinamis untuk nominal Rp 100.007:
1. **Mutasi Tag 01**: Ubah sub-string `010211` menjadi `010212` (panjang tetap 2 karakter, nilai beralih dari statis ke dinamis).
2. **Penyusunan Tag 54**:
   - Nilai nominal: `100007` (panjang 6 karakter).
   - Format TLV Tag 54: `54` (Tag) + `06` (Length) + `100007` (Value) = `5406100007`.
3. **Penyisipan TLV**: Tag 54 disisipkan tepat sebelum Tag `58` (Country Code `5802ID`).
4. **Rekalkulasi CRC16 (Tag 63)**:
   - Buang 4 digit CRC lama di ekor string.
   - Ambil seluruh string payload baru hingga `...6304`.
   - Hitung ulang nilai CRC16-CCITT (Polynomial `0x1021`, Initial `0xFFFF`).
   - Tempelkan 4 digit heksadesimal baru di akhir string (misal: `6304E2F1`).

### Mengapa Semua Aplikasi Perbankan Mengunci Nominal?
Seluruh aplikasi m-Banking (BCA Mobile, Livin' Mandiri, BRImo, BNI Mobile) dan e-Wallet (GoPay, DANA, OVO, ShopeePay) terikat regulasi ASPI:
- Saat parser QR membaca Tag `01 = 12` dan mendeteksi adanya Tag `54`, **aplikasi secara otomatis menonaktifkan keyboard input nominal pada layar nasabah** dan menampilkan total tagihan terkunci (Rp 100.007).
- Hal ini menjamin pembeli membayar persis dengan kode unik tanpa risiko salah ketik.

## 3. Implementasi Lengkap Generator EMVCo (PHP & Go)

### A. Generator Dinamis & CRC16 dalam PHP

```php
<?php

namespace App\Services\Payment;

class QrisDynamicGenerator
{
    /**
     * Mengubah QRIS Statis menjadi QRIS Dinamis dengan nominal terkunci.
     */
    public static function makeDynamic(string $staticQris, int $amount): string
    {
        // 1. Ubah Tag 01 dari '11' (statis) menjadi '12' (dinamis)
        $qris = preg_replace('/(0102)11/', '${1}12', $staticQris);

        // 2. Bersihkan Tag 54 lama (jika ada) dan Tag 63 (CRC lama)
        $qris = preg_replace('/54\d{2}\d+/', '', $qris);
        $qris = preg_replace('/6304[0-9A-Fa-f]{4}$/', '', $qris);

        // 3. Susun Tag 54 (Nominal)
        $amountStr = (string) $amount;
        $tag54Length = sprintf('%02d', strlen($amountStr));
        $tag54 = '54' . $tag54Length . $amountStr;

        // 4. Sisipkan Tag 54 tepat sebelum Tag 58 (Country Code '5802ID')
        $pos58 = strpos($qris, '5802ID');
        if ($pos58 === false) {
            throw new \InvalidArgumentException('Format QRIS statis tidak valid.');
        }

        $payloadWithoutCrc = substr($qris, 0, $pos58) . $tag54 . substr($qris, $pos58) . '6304';

        // 5. Hitung CRC16-CCITT dan tempelkan di ujung payload
        $crc = self::calculateCRC16($payloadWithoutCrc);

        return $payloadWithoutCrc . $crc;
    }

    /**
     * Menghitung CRC16-CCITT (Polynomial 0x1021, Initial 0xFFFF).
     */
    public static function calculateCRC16(string $str): string
    {
        $crc = 0xFFFF;
        $length = strlen($str);

        for ($i = 0; $i < $length; $i++) {
            $crc ^= (ord($str[$i]) << 8);
            for ($j = 0; $j < 8; $j++) {
                if ($crc & 0x8000) {
                    $crc = (($crc << 1) ^ 0x1021) & 0xFFFF;
                } else {
                    $crc = ($crc << 1) & 0xFFFF;
                }
            }
        }

        return strtoupper(sprintf('%04X', $crc));
    }
}
```

---

## 4. Alokator Kode Unik Berbasis Redis Atomic Locks

Agar 2 transaksi dengan nominal pokok sama (misal Rp 100.000) tidak bertabrakan, sistem mencari kode unik bebas (1–999) menggunakan perintah atomic Redis:

```php
namespace App\Services\Payment;

use Illuminate\Support\Facades\Redis;

class UniqueCodeAllocator
{
    /**
     * Mengalokasikan kode unik bebas antara 1 - 999.
     * Mengunci nominal total selama $ttlSeconds (misal 15 menit).
     */
    public function allocate(int $baseAmount, int $ttlSeconds = 900): array
    {
        for ($code = 1; $code <= 999; $code++) {
            $totalAmount = $baseAmount + $code;
            $lockKey = "qris:lock:amount:{$totalAmount}";

            // SET key value NX EX -> atomic lock
            $acquired = Redis::set($lockKey, 'locked', 'EX', $ttlSeconds, 'NX');

            if ($acquired) {
                return [
                    'unique_code'  => $code,
                    'total_amount' => $totalAmount,
                    'expires_in'   => $ttlSeconds,
                ];
            }
        }

        throw new \RuntimeException('Antrean transaksi penuh untuk nominal ini. Silakan coba beberapa saat lagi.');
    }

    public function release(int $totalAmount): void
    {
        Redis::del("qris:lock:amount:{$totalAmount}");
    }
}
```

---

## 5. Saluran Penangkap Mutasi (Mutation Ingestion)

Terdapat 3 metode untuk menangkap dana masuk ke rekening/e-wallet merchant:

| Metode | Biaya | Keandalan | Kerumitan |
|---|---|---|---|
| **1. Push Notification Scraper (Android Device)** | Sangat Murah (HP Bekas + MacroDroid/App kustom) | Sedang (Tergantung koneksi HP) | Rendah |
| **2. SaaS Webhook Mutasi (Moota / Cekmutasi)** | Rp 100.000 – Rp 150.000 / bulan | Tinggi | Sangat Rendah |
| **3. Webhook PJP Resmi Acquirer (Nobu / Finnet)** | MDR 0% (Mikro) / 0,3% – 0,7% | Sangat Tinggi (SLA 99,99%) | Menengah |

### Implementasi Listener Notifikasi Android (Contoh: MacroDroid Webhook Forwarder)
Aplikasi listener membaca notifikasi dari bank (contoh: Livin' by Mandiri, BCA Mobile, atau ShopeePay Merchant) lalu mengirimkan payload ke API gateway:

```json
POST /api/v1/internal/incoming-mutation
Headers:
  X-Internal-Secret: secret_cluster_key_123
Body:
{
  "raw_notification": "Transfer Masuk Rp 100.007 dari MOHAMMAD ARIF",
  "amount": 100007,
  "source_app": "com.bca",
  "received_at": "2026-10-24T16:30:15Z"
}
```

---

## 6. Core Matching Engine & Webhook Dispatch

```php
namespace App\Http\Controllers\Api;

use App\Models\Invoice;
use App\Services\Payment\UniqueCodeAllocator;
use App\Jobs\DispatchMerchantWebhookJob;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class MutationController extends Controller
{
    public function handle(Request $request, UniqueCodeAllocator $allocator): JsonResponse
    {
        $amount = (int) $request->input('amount');

        // 1. Cari invoice pending yang memiliki total_amount persis sama
        $invoice = Invoice::where('total_amount', $amount)
            ->where('status', 'pending')
            ->where('expires_at', '>', now())
            ->lockForUpdate()
            ->first();

        if (!$invoice) {
            // Catat mutasi tidak cocok untuk audit rekonsiliasi manual
            \Log::warning("Unmatched mutation received: Rp {$amount}");
            return response()->json(['message' => 'Logged as unmatched'], 200);
        }

        // 2. Tandai tagihan Lunas
        $invoice->update([
            'status'  => 'paid',
            'paid_at' => now(),
        ]);

        // 3. Lepaskan lock kode unik di Redis
        $allocator->release($amount);

        // 4. Kirim Webhook ke URL merchant secara asinkron
        dispatch(new DispatchMerchantWebhookJob($invoice));

        return response()->json([
            'status'     => 'success',
            'invoice_id' => $invoice->id,
            'reference'  => $invoice->reference,
        ]);
    }
}
```

---

## 7. Analisis Risiko & Strategi Mitigasi

| Risiko | Dampak | Solusi Mitigasi |
|---|---|---|
| **Human Error (Salah Nominal)** | Pembeli mentransfer nominal bulat tanpa kode unik (misal Rp 100.000 bukan Rp 100.007). | Berikan peringatan tegas berwarna merah pada UI checkout; buat tombol *"Cek Bukti Transfer Manual"* di dashboard merchant untuk rekonsiliasi. |
| **Keterbatasan Kapasitas Konkurensi** | Maksimal hanya 999 transaksi aktif bersamaan untuk nominal tagihan yang persis sama. | Turunkan masa aktif tagihan dari 15 menit menjadi 5–10 menit; gunakan rentang kode unik dinamis (contoh: 1–1999 jika diperlukan). |
| **Pemblokiran Akun Rekening Bank** | Rekening penampung dibekukan jika traffic transaksi terlalu padat dan terdeteksi sebagai aktivitas agregator tidak berizin oleh bank. | Gunakan rekening Giro Bisnis resmi atau gunakan agregator resmi untuk transaksi di atas batas UMKM. |
| **Regulasi PJP Bank Indonesia** | Mengumpulkan dana pihak ketiga tanpa izin PJP Kategori 1/3 melanggar PBI (Peraturan Bank Indonesia). | Posisikan layanan sebagai *Technical Enabler / Software Kasir* atau ajukan izin PJP Kategori 3 jika mengelola penampungan dana pihak ketiga. |

---

## 8. Strategi Anti-Blokir, Kepatuhan Regulasi & Biaya 0,5%

### A. Mengapa Rekening Sering Diblokir Bank?
1. **Velocity Anomaly**: Rekening tabungan pribadi menerima ratusan mutasi kecil per hari -> terdeteksi sistem FDP (Fraud Detection Platform) bank sebagai indikasi judi online / money mule.
2. **Custody Pelanggaran UU PPSK / PBI**: Mengumpulkan uang milik merchant lain di satu rekening penampung tanpa izin PJP Kategori 1/3 adalah tindak pidana perbankan.
3. **Static QR Tampering Detection**: Bank acquirer mendeteksi string statis yang disuntikkan Tag 54 secara tidak wajar melalui aplikasi m-banking tertentu.

### B. Cara Legal & Berizin: Model Non-Custodial (Technical Enabler / SaaS POS)

#### 1. Jebakan Regulasi PJP Bank Indonesia (Model Kustodian Ilegal)
Mengapa model bisnis penampungan dana pihak ketiga rawan pidana perbankan dan penyitaan aset oleh OJK/BI?
- **Dasar Hukum**: **PBI No. 23/6/PBI/2021** (Penyelenggara Jasa Pembayaran) dan **UU PPSK No. 4/2023** (Pengembangan dan Penguatan Sektor Keuangan).
- **Ketentuan**: Setiap entitas yang **menghimpun, menampung, atau memegang dana milik merchant/pihak ketiga di satu rekening penampung bersama (*escrow pool*)** wajib mengantongi izin **PJP Kategori 1 atau 3** dari Bank Indonesia dengan modal disetor minimal **Rp 15.000.000.000 (Rp 15 Miliar)**.
- Jika platform menampung pembayaran pembeli di rekening sendiri lalu melakukan transfer pencairan (withdrawal) ke rekening toko merchant di kemudian hari tanpa izin PJP, platform tersebut secara hukum menjalankan **Payment Gateway Ilegal / Penggelapan Dana**.

#### 2. Arsitektur Non-Custodial (SaaS POS / Technical Enabler)
Model Non-Custodial memposisikan platform Anda murni sebagai **Penyedia Perangkat Lunak (Software Provider / SaaS)**, bukan perantara keuangan:

```
[ Pelanggan Toko ]
       │
       │ 1. Scan Dynamic QRIS (Rp 100.007)
       ▼
[ Rekening / E-Wallet Milik Merchant Sendiri ] <── Dana masuk 100% langsung
       │                                           (Platform menyentuh Rp 0)
       │ 2. Mutasi Masuk Terdeteksi
       ▼
[ Listener Notifikasi / Webhook Merchant ]
       │
       │ 3. Notifikasi Mutasi Diteruskan
       ▼
[ Server Gateway Platform Anda ]
       │
       ├── 4. Kirim Webhook Status "PAID" ke Web/App Merchant
       └── 5. Potong Biaya Layanan 0,5% dari "Saldo Kuota Deposit" Merchant
```

#### 3. Tiga Pilar Legalitas Non-Custodial:
1. **Zero Custody (Nol Penampungan Uang)**:
   - Rekening operasional platform Anda tidak pernah menerima sepeser pun uang pembayaran dari pembeli toko.
   - Uang pembayaran mengalir langsung dari bank/e-wallet pembeli ke rekening bank/QRIS milik merchant masing-masing (*Direct-to-Merchant Settlement*).
2. **Legalitas Izin Cukup PSE Komdigi (Tanpa Modal Rp 15 Miliar)**:
   - Klasifikasi Baku Lapangan Usaha Indonesia: **KBLI 62012 (Aktivitas Pengembangan Aplikasi Perdagangan Elektronik)** atau **KBLI 62090 (Aktivitas Teknologi Informasi dan Jasa Komputer Lainnya)**.
   - Perizinan: **Tanda Daftar Penyelenggara Sistem Elektronik (TDPSE) Lingkup Privat** di Kementerian Komunikasi dan Digital (Komdigi).
   - Proses pendaftaran: 100% online melalui OSS (`oss.go.id`), gratis (Rp 0), dan terbit dalam 1–3 hari kerja.
   - Perusahaan SaaS kasir seperti Moka POS, Pawoon, dan software mutasi Moota beroperasi secara legal di bawah payung hukum ini.
3. **Mekanisme Penarikan Fee 0,5% Menggunakan Saldo Kuota Deposit (Prepaid Fee)**:
   - Karena platform tidak menyentuh uang transaksi, platform tidak bisa melakukan autodebet dari rekening bank merchant secara sepihak.
   - **Mekanisme Operasional**:
     1. Merchant wajib mengisi **"Saldo Kuota Layanan"** di dashboard (misal: deposit Rp 50.000 via transfer bank/QRIS ke platform).
     2. Setiap kali ada transaksi sukses di toko merchant senilai Rp 100.000:
        - Merchant menerima dana Rp 100.007 utuh di rekening bank mereka sendiri.
        - Server platform secara otomatis mendebit **Rp 500 (0,5%)** dari Saldo Kuota Layanan merchant di database platform.
     3. Jika Saldo Kuota Layanan merchant habis (mencapai Rp 0), sistem otomatis menjeda (*pause*) pembuatan QRIS dinamis toko tersebut sampai merchant melakukan top-up kuota kembali.

#### 4. Matriks Komparasi: Kustodian Ilegal vs Non-Custodial Legal

| Parameter | Model Kustodian (Solosmartpay / Aggregator Ilegal) | Model Non-Custodial (SaaS POS / Technical Enabler) |
|---|---|---|
| **Aliran Dana Transaksi** | Pembeli -> Rekening Penampung Gateway -> Pencairan ke Merchant | Pembeli -> **Langsung ke Rekening/QRIS Milik Merchant** |
| **Penampungan Dana (Custody)** | Ya (Menampung dana pihak ketiga) | **Tidak (Zero Custody)** |
| **Izin yang Wajib Dimiliki** | Izin PJP Kategori 1 / 3 Bank Indonesia | **Tanda Daftar PSE Komdigi (OSS Gratis)** |
| **Beban Modal Disetor** | **Rp 15.000.000.000 (Rp 15 Miliar)** | **Rp 0 (Sesuai modal usaha normal)** |
| **Risiko Pemblokiran Bank** | Sangat Tinggi (Rekening penampung disita AML bank) | **Nol pada rekening platform** |
| **Mekanisme Pungutan Fee 0,5%** | Dipotong langsung saat settlement manual/otomatis | **Sistem Saldo Deposit Kuota Layanan (Prepaid Credit)** |
| **Status Hukum Nasional** | Melanggar UU PPSK & PBI jika tanpa izin BI | **100% Sah dan Berizin sebagai Penyedia Software** |

### C. Cara Mendapatkan Biaya 0,5% Flat Resmi Tanpa Scraper
Skema MDR resmi Bank Indonesia (Peraturan BI No. 25/7/PBI/2023):
- **Usaha Mikro (UMI) nominal ≤ Rp 100.000**: **MDR 0%**.
- **Usaha Mikro (UMI) nominal > Rp 100.000**: **MDR 0,3%**.
- **Usaha Kecil/Menengah (UKE/UME)**: **MDR 0,7%**.

**Strategi Wholesale Acquirer (Sangat Murah & Legal)**:
1. Daftar menjadi **Payment Facilitator (PayFac) / Mitra ISO** resmi ke Acquirer QRIS yang ramah aggregator (contoh: **Bank Nobu**, **Netzme**, atau **Finnet**).
2. Acquirer memberikan wholesale MDR **0,3%**.
3. Anda memasang harga ke merchant **0,5%**.
4. **Margin bersih Anda = 0,2%** per transaksi.
5. **Keuntungan**: 100% legal, ada webhook resmi dari bank, QRIS dinamis asli EMVCo (bukan suntikan), tanpa kode unik, dan **rekening tidak akan pernah diblokir**.

### D. Trik Teknis Anti-Blokir (Jika Tetap Menggunakan Bot Mutasi)
Jika tetap menggunakan jalur mutasi kode unik mandiri:
1. **Wajib Rekening Giro Badan Usaha (PT/CV)**:
   - Jangan pakai rekening tabungan perseorangan.
   - Buka Rekening Giro Bisnis (BCA Giro Bisnis / Mandiri Giro). Giro didesain untuk transaksi volume tinggi dan tidak mudah ter-flag sistem otomatis anti-fraud.
2. **Cluster Multi-Rekening (Round-Robin Pool)**:
   - Siapkan minimal 3–5 rekening QRIS berbeda.
   - Batasi traffic: Maksimal 100 transaksi atau Rp 15.000.000 per rekening per hari.
   - Sistem otomatis mengalihkan tagihan baru ke rekening berikutnya (load balancing).
3. **Auto-Sweeping Harian (Zero Overnight Balance)**:
   - Jangan biarkan saldo mengendap di rekening penampung.
   - Pasang bot auto-transfer via BI-FAST API setiap kali saldo mencapai Rp 5.000.000 untuk memindahkan dana ke rekening operasional utama.
4. **White-Listing Kategori Merchant**:
   - Hanya layani merchant dengan transaksi fisik / legal (hindari produk digital rawan chargeback, voucher game tidak resmi, dan pulsa).
