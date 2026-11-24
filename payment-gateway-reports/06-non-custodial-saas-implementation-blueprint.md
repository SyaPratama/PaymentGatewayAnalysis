# Cetak Biru Implementasi Gateway Non-Custodial (SaaS POS & Technical Enabler)

> **Panduan Teknis & Model Bisnis**: Alur kerja merchant, mekanisme penarikan profit 0,5% berbasis Saldo Deposit Kuota (Prepaid Credit), skema database, dan implementasi controller mutasi.

---

## 1. Konsep Non-Custodial bagi Merchant

Pada model **Non-Custodial**, Anda tidak berperan sebagai bank penampung dana, melainkan sebagai **Penyedia Software Otomasi Kasir (SaaS / Technical Enabler)**:

| Aspek | Realitas Operasional |
|---|---|
| **Aliran Dana Pembeli** | **100% masuk langsung ke rekening bank / QRIS toko milik merchant sendiri**. Server atau rekening Anda menyentuh Rp 0 dana penjualan toko. |
| **Nilai Tambah untuk Merchant** | 1. Merchant tidak perlu beli mesin EDC mahal atau bayar biaya bulanan jutaan.<br>2. QRIS statis toko mereka otomatis menjadi dinamis dengan nominal pas.<br>3. Verifikasi pembayaran otomatis tanpa perlu staf mengecek mutasi manual.<br>4. Uang penjualan cair seketika (*instant settlement*) ke rekening mereka sendiri tanpa masa tunggu H+1/H+2. |
| **Legalitas Hukum Platform** | **Cukup Tanda Daftar PSE Komdigi (KBLI 62012 / 62090)**. Bebas dari kewajiban modal disetor Rp 15 Miliar PJP Bank Indonesia karena tidak ada penampungan dana pihak ketiga (*zero custody*). |

---

## 2. Cara Mengambil Profit 0,5% (Sistem Saldo Kuota Deposit / Prepaid Credit)

Karena dana pembeli tidak mampir ke rekening platform, pemotongan fee tidak bisa dilakukan secara langsung saat pembeli membayar. Solusinya adalah sistem **Deposit Saldo Kuota Layanan** (mirip sistem pulsa seluler atau kuota token API):

```
[ Merchant Top-Up Deposit Kuota Rp 50.000 ] ──> Masuk ke Rekening Bank Platform Anda
                       │                        (Ini adalah Uang Tunai Talangan Fee)
                       ▼
[ Saldo Kuota di Database: Rp 50.000 ]
                       │
                       ▼
[ Terjadi Transaksi Rp 100.000 di Toko Merchant ]
  - Pembeli transfer Rp 100.007 ──> 100% langsung masuk ke Rekening Merchant
  - Nilai Fee 0,5% = Rp 500
                       │
                       ▼
[ Server Platform Mendebit Saldo Kuota di Database ]
  - Saldo kuota merchant berkurang: Rp 50.000 - Rp 500 = Rp 49.500
  - Uang tunai Rp 500 di rekening Anda otomatis SAH menjadi KEUNTUNGAN BERSIH Anda.
```

### Keunggulan Finansial Sistem Deposit:
1. **Nol Risiko Piutang (Zero Bad Debt)**: Platform telah menerima uang tunai di depan sebelum transaksi diproses.
2. **Arus Kas Positif (Positive Cashflow)**: Platform memegang dana mengendap (*float*) dari deposit seluruh merchant.
3. **Otomatisasi Penagihan**: Jika deposit habis, API tagihan toko dijeda otomatis sampai merchant melakukan top-up kembali.

---

## 3. Alur Kerja End-to-End (Sequence Workflow)

```
┌──────────────┐          ┌───────────────────────┐          ┌──────────────────────┐
│   Merchant   │          │  Platform Gateway     │          │  Pelanggan / Bank    │
└──────┬───────┘          └──────────┬────────────┘          └──────────┬───────────┘
       │                             │                                  │
       │ 1. Registrasi & Upload      │                                  │
       │    Master QRIS Toko         │                                  │
       │────────────────────────────>│                                  │
       │ 2. Top-Up Saldo Kuota       │                                  │
       │    Deposit (misal: Rp 50rb) │                                  │
       │────────────────────────────>│                                  │
       │                             │                                  │
       │                             │ 3. Pembeli Checkout Rp 100.000   │
       │                             │<─────────────────────────────────│
       │                             │ 4. Suntik Dinamis (+Rp 7):       │
       │                             │    Generate QRIS Rp 100.007      │
       │                             │    (Pakai QR Master Toko tsb)    │
       │                             │─────────────────────────────────>│
       │                             │                                  │
       │                             │                                  │ 5. Scan & Bayar Rp 100.007
       │ 6. Uang Rp 100.007 MASUK    │                                  │    via BCA/Mandiri/Dana
       │    UTUH ke Rekening Toko    │<─────────────────────────────────│
       │                             │                                  │
       │ 7. Listener HP Toko Baca    │                                  │
       │    Notifikasi & Forward     │                                  │
       │────────────────────────────>│                                  │
       │                             │ 8. Cocokkan Nominal Rp 100.007:  │
       │                             │    - Tandai Order "PAID"         │
       │                             │    - Potong Saldo Kuota Rp 500   │
       │ 9. Terima Webhook Status    │      (0,5% dari Rp 100.000)      │
       │    "PAID" ke Web Toko       │                                  │
       │<────────────────────────────│                                  │
```

---

## 4. Skema Database Relasional

Cukup 3 tabel relasional untuk mengelola seluruh ekosistem:

```sql
-- 1. Data Toko Merchant & Master QRIS Asli
CREATE TABLE merchants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    static_qris_payload TEXT NOT NULL,       -- Payload string EMVCo asli milik toko
    fee_balance BIGINT DEFAULT 0,            -- Saldo kuota fee merchant dalam Rupiah
    api_key VARCHAR(64) UNIQUE NOT NULL,     -- Kunci otentikasi REST API toko
    webhook_url TEXT,                        -- Endpoint callback tujuan order toko
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Riwayat Top-Up Saldo Deposit Kuota Fee
CREATE TABLE deposit_topups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    amount BIGINT NOT NULL,                  -- Nominal top-up (misal Rp 100.000)
    payment_method VARCHAR(50),              -- QRIS, Bank Transfer
    status VARCHAR(20) DEFAULT 'pending',    -- pending, paid, expired
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Data Transaksi Tagihan Pembeli Toko
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    reference VARCHAR(50) NOT NULL,          -- ID invoice dari web merchant
    base_amount BIGINT NOT NULL,             -- Nominal pokok (misal Rp 100.000)
    unique_code INT NOT NULL,                -- Kode unik (1 - 999)
    total_amount BIGINT NOT NULL,            -- Total tagihan (Rp 100.007)
    fee_deducted BIGINT DEFAULT 0,           -- 0,5% fee yang dipotong (Rp 500)
    status VARCHAR(20) DEFAULT 'pending',    -- pending, paid, expired
    qris_payload TEXT,                       -- String QR dinamis yang di-generate
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    paid_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_invoices_matching ON invoices (total_amount, status, expires_at);
```

---

## 5. Implementasi Logika Controller Mutasi (PHP/Laravel)

```php
namespace App\Http\Controllers\Api;

use App\Models\Invoice;
use App\Models\Merchant;
use App\Jobs\DispatchMerchantWebhookJob;
use App\Jobs\SendLowBalanceAlertJob;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

class MutationIngestionController extends Controller
{
    public function handle(Request $request): JsonResponse
    {
        // 1. Validasi Autentikasi Pengirim Listener
        $secret = $request->header('X-Listener-Secret');
        if ($secret !== config('services.listener.secret')) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $incomingAmount = (int) $request->input('amount'); // contoh: 100007

        // 2. Transaksi Database dengan Row-Locking Mencegah Double-Credit
        return DB::transaction(function () use ($incomingAmount) {
            $invoice = Invoice::where('total_amount', $incomingAmount)
                ->where('status', 'pending')
                ->where('expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if (!$invoice) {
                \Log::info("Mutasi tidak terikat invoice aktif: Rp {$incomingAmount}");
                return response()->json(['message' => 'Logged as unmatched'], 200);
            }

            $merchant = Merchant::where('id', $invoice->merchant_id)
                ->lockForUpdate()
                ->first();

            // 3. Hitung Potongan Fee 0,5% (Minimal Rp 100)
            $fee = (int) max(100, round($invoice->base_amount * 0.005));

            // 4. Update Status Tagihan
            $invoice->update([
                'status'       => 'paid',
                'paid_at'      => now(),
                'fee_deducted' => $fee,
            ]);

            // 5. Potong Saldo Kuota Deposit Merchant
            $merchant->decrement('fee_balance', $fee);

            // 6. Lepas Kunci Kode Unik di Redis
            Redis::del("qris:lock:amount:{$incomingAmount}");

            // 7. Dispatch Webhook "PAID" ke Web Toko Merchant
            dispatch(new DispatchMerchantWebhookJob($invoice));

            // 8. Cek Ambang Batas Saldo Kuota Menipis (< Rp 5.000)
            if ($merchant->fee_balance < 5000) {
                dispatch(new SendLowBalanceAlertJob($merchant));
            }

            return response()->json([
                'status'       => 'success',
                'invoice_id'   => $invoice->id,
                'fee_deducted' => $fee,
                'balance_left' => $merchant->fee_balance,
            ]);
        });
    }
}
```

---

## 6. Penanganan Saldo Kuota Habis (Auto-Pause Guard)

Sebelum API menerbitkan tagihan dinamis baru untuk merchant, middleware backend memeriksa ketersediaan saldo kuota fee:

```php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class EnsureMerchantHasFeeBalance
{
    public function handle(Request $request, Closure $next)
    {
        $merchant = $request->user('merchant');

        // Batas minimal deposit Rp 1.000 untuk bisa menerima tagihan baru
        if ($merchant->fee_balance < 1000) {
            return response()->json([
                'error'   => 'insufficient_fee_balance',
                'message' => 'Saldo kuota layanan Anda habis. Silakan top-up deposit di dashboard.',
            ], 402);
        }

        return $next($request);
    }
}
```

---

## 7. Rangkuman Keuntungan Platform

1. **Investasi Modal Awal Rp 0**: Tidak perlu modal Rp 15 Miliar PJP BI.
2. **Nol Tanggung Jawab Chargeback**: Komplain dana pembeli diselesaikan langsung antara pembeli dan toko, bukan platform Anda.
3. **Skalabilitas Tanpa Batas**: Setiap toko memiliki akun rekening sendiri, sehingga transaksi terdistribusi alami (*decentralized load*) dan bebas dari risiko pemblokiran rekening terpusat.
