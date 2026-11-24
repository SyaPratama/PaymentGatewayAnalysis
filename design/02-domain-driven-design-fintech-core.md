# Domain-Driven Design (DDD) untuk Sistem Inti Fintech

Dokumen ini membedah penerapan *Domain-Driven Design* (DDD) dalam domain sistem pembayaran, mencakup *Strategic Design* (dekomposisi *Bounded Contexts*), *Tactical Design* (Entities, Value Objects, Aggregates, Domain Events), serta penegakan invarian matematika dan integritas finansial.

---

## 1. Strategic Design: Dekomposisi Bounded Contexts

Dalam sistem pembayaran skala enterprise, mencampuradukkan model data transaksi dengan pencatatan pembukuan (*ledger*) atau penarikan dana merchant (*settlement*) akan menciptakan *anemic domain model* dan ketergantungan yang kusut (*tight coupling*).

### 1.1 Pemetaan Konteks Terikat (*Bounded Contexts*)

```
+-----------------------------------------------------------------------------------+
| TAMAKU PAYMENT GATEWAY ECOSYSTEM                                                  |
|                                                                                   |
|  +-------------------------------+             +-------------------------------+  |
|  | Payment Ingestion & Routing   |             | Vendor Integration (Adapters) |  |
|  | Context                       | ----------> | Context                       |  |
|  | Ubiquitous Language:          |             | Ubiquitous Language:          |  |
|  | - PaymentIntent               |             | - SNAP BI Partner             |  |
|  | - ChargeSession               |             | - QRIS Aggregator             |  |
|  | - PaymentMethod               |             | - NetworkAcquirer             |  |
|  +-------------------------------+             +-------------------------------+  |
|                 |                                                                 |
|                 v (Domain Event: PaymentSettled)                                  |
|  +-----------------------------------------------------------------------------+  |
|  | Accounting & Double-Entry Ledger Context                                    |  |
|  | Ubiquitous Language: Account, JournalEntry, Posting, BalanceInvariant      |  |
|  +-----------------------------------------------------------------------------+  |
|          |                                                             |          |
|          v                                                             v          |
|  +-------------------------------+             +-------------------------------+  |
|  | Merchant Settlement Context   |             | Bank Reconciliation Context   |  |
|  | Ubiquitous Language:          |             | Ubiquitous Language:          |  |
|  | - SettlementBatch             |             | - BankStatement (MT940/CSV)   |  |
|  | - PayoutOrder                 |             | - MatchStatus (Matched/Diff)  |  |
|  | - HoldingPeriod / RollingRes  |             | - DiscrepancyDispute          |  |
|  +-------------------------------+             +-------------------------------+  |
+-----------------------------------------------------------------------------------+
```

### 1.2 Definisi Batas Konteks dan Ubiquitous Language

1. **Payment Ingestion & Routing Context**:
   - *Fokus*: Validasi permintaan merchant, manajemen siklus hidup transaksi pembayaran, dan pemilihan kanal bank terbaik (*least cost / highest SLA*).
   - *Entitas Inti*: `PaymentSession`, `PaymentIntent`, `PaymentMethod`.
2. **Vendor Integration Context**:
   - *Fokus*: Konversi format data internal ke spesifikasi baku perbankan (misalnya standar SNAP BI ASPI, QRIS MPM ISO 20022), penandatanganan kriptografi (SHA256withRSA), dan penanganan webhook bank.
3. **Double-Entry Ledger Context**:
   - *Fokus*: Kebenaran pembukuan finansial, pencatatan mutasi kredit/debit, penegakan saldo zero-sum, dan isolasi akun liabilitas/aset.
4. **Merchant Settlement Context**:
   - *Fokus*: Perhitungan saldo bersih yang dapat ditarik (*withdrawable balance*), pemotongan MDR (*Merchant Discount Rate*), penahanan cadangan risiko (*rolling reserve*), dan eksekusi transfer dana keluar (*disbursement*).
5. **Bank Reconciliation Context**:
   - *Fokus*: Pemadanan otomatis (*automated 3-way matching*) antara data internal Tamaku, laporan mutasi bank (*bank statement*), dan laporan merchant untuk mendeteksi selisih nominal (*discrepancy*).

---

## 2. Tactical Design: Pola Pembangun Domain

Model domain finansial harus kaya akan perilaku (*rich domain model*) dan melindungi invarian bisnis secara mandiri, bukan sekadar wadah data pasif (*anemic data bag*).

### 2.1 Entities vs Value Objects

```
+------------------------------------+      +------------------------------------+
| ENTITY                             |      | VALUE OBJECT                       |
| - Memiliki Identitas Unik (ID)     |      | - Didefinisikan dari atributnya    |
| - Identitas bertahan seiring waktu |      | - Bersifat Immutable (Kekal)       |
| - Dua objek dengan atribut sama    |      | - Dua objek dengan atribut sama    |
|   tetap berbeda jika ID berbeda.   |      |   dianggap IDENTIK.                |
| Contoh: Transaction, Merchant      |      | Contoh: Money, Currency, Address   |
+------------------------------------+      +------------------------------------+
```

#### Contoh Value Object: `Money`
Dalam sistem finansial, nilai uang dilarang keras menggunakan tipe data pecahan biner (*floating-point* seperti `float32` atau `float64`) karena bahaya *rounding error* IEEE 754. Nilai moneter harus diekspresikan sebagai bilangan bulat terkecil (*minor currency units*, e.g., Rupiah penuh atau sen) bersama kode mata uangnya.

```go
package valueobject

import (
    "errors"
    "fmt"
)

var (
    ErrCurrencyMismatch = errors.New("mata uang tidak cocok untuk operasi aritmatika")
    ErrNegativeAmount   = errors.New("nominal uang tidak boleh bernilai negatif")
)

type Currency string

const (
    IDR Currency = "IDR"
    USD Currency = "USD"
)

// Money adalah Value Object murni: Immutable dan memvalidasi diri sendiri
type Money struct {
    amount   int64    // Satuan terkecil (Rupiah penuh, bukan desimal)
    currency Currency
}

func NewMoney(amount int64, currency Currency) (Money, error) {
    if amount < 0 {
        return Money{}, ErrNegativeAmount
    }
    return Money{amount: amount, currency: currency}, nil
}

func (m Money) Amount() int64 {
    return m.amount
}

func (m Money) Currency() Currency {
    return m.currency
}

// Add menghasilkan objek Money baru tanpa memutasi objek asal
func (m Money) Add(other Money) (Money, error) {
    if m.currency != other.currency {
        return Money{}, fmt.Errorf("%w: %s vs %s", ErrCurrencyMismatch, m.currency, other.currency)
    }
    return Money{amount: m.amount + other.amount, currency: m.currency}, nil
}

func (m Money) Sub(other Money) (Money, error) {
    if m.currency != other.currency {
        return Money{}, fmt.Errorf("%w: %s vs %s", ErrCurrencyMismatch, m.currency, other.currency)
    }
    if m.amount < other.amount {
        return Money{}, errors.New("saldo tidak mencukupi untuk pengurangan")
    }
    return Money{amount: m.amount - other.amount, currency: m.currency}, nil
}
```

### 2.2 Aggregate dan Aggregate Root

*Aggregate* adalah sekelompok entitas dan objek nilai yang diperlakukan sebagai satu kesatuan atomik untuk perubahan data. Akses modifikasi dari luar hanya boleh melewati satu entitas gerbang yang disebut **Aggregate Root**.

```
+-------------------------------------------------------------------------------+
| AGGREGATE BOUNDARY: PaymentSession (Aggregate Root)                           |
|                                                                               |
|  Root Entity: PaymentSession (ID, Status, CreatedAt, ExpiredAt)               |
|                                                                               |
|  Internal Entities / Value Objects:                                           |
|  - Value Object: TotalAmount (Money)                                          |
|  - Value Object: FeeCalculation (BaseFee, Tax, TotalCharge)                   |
|  - Internal Entity: PaymentAttempt (AttemptID, Channel, GatewayRef, Status)   |
|                                                                               |
|  Internal Domain Invariant Enforcement:                                       |
|  - Tidak boleh mengubah status jika sesi sudah kadaluarsa (Expired).          |
|  - Tidak boleh melakukan Capture jika status bukan PENDING.                   |
+-------------------------------------------------------------------------------+
```

Inti aplikasi di luar batas agregat dilarang mengubah status `PaymentAttempt` secara langsung. Seluruh perintah mutasi harus melewati metode `PaymentSession.Settle(...)` atau `PaymentSession.Fail(...)`.

### 2.3 Domain Events

Domain Events merepresentasikan fakta yang telah terjadi di masa lalu (*immutable fact*). Penamaan selalu menggunakan bentuk lampau (*past-tense verb*).

```go
package event

import (
    "time"
    "tamaku/domain/valueobject"
)

type PaymentSettledEvent struct {
    EventID       string
    SessionID     string
    MerchantID    string
    Amount        valueobject.Money
    Fee           valueobject.Money
    SettledAt     time.Time
}

type PaymentFailedEvent struct {
    EventID       string
    SessionID     string
    Reason        string
    FailedAt      time.Time
}
```

### 2.4 Domain Services

Jika suatu operasi bisnis tidak cocok ditempatkan pada satu entitas tunggal karena melibatkan beberapa agregat berbeda, logika tersebut dimodelkan sebagai **Domain Service**.

*Contoh Kasus*: `FeeCalculatorService` menghitung MDR berjenjang (*tiered merchant discount rate*) berdasarkan kontrak merchant, tipe metode pembayaran (QRIS 0.7% vs VA Rp 2.000 flat), dan aturan pajak PPN 11%.

---

## 3. Invarian Kritis Domain Finansial

Model domain finansial harus memiliki pertahanan lapis baja terhadap korupsi data:

### 3.1 Pencegahan Saldo Negatif (*Negative Balance Prohibition*)
Kecuali akun tersebut secara eksplisit berjenis kredit (*credit line / overdraft*), akun saldo merchant tidak boleh bernilai negatif dalam kondisi apa pun. Validasi ini wajib ada di entitas domain sebelum instruksi debit diteruskan ke basis data.

### 3.2 Isolasi Multi-Mata Uang (*Currency Rigidity*)
Sistem dilarang keras menjumlahkan nominal dengan mata uang berbeda secara implisit. Penjumlahan `IDR 100.000` dengan `USD 10` wajib menolak eksekusi (*panic/error*), bukan mengonversi dengan kurs asumsi tanpa pesanan valuta asing terdaftar.

### 3.3 Riwayat Transaksi Kekal (*Immutable Append-Only History*)
Status transaksi yang telah final (`SETTLED`, `REFUNDED`) bersifat permanen. Kesalahan pembayaran atau koreksi dana tidak pernah dilakukan dengan menghapus atau mengubah baris transaksi lama, melainkan dengan menerbitkan transaksi pembatalan (*Reversal / Void Transaction*) yang merujuk pada referensi transaksi awal.
