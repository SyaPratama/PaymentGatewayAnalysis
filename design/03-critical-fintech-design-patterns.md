# Pola Desain Kritis Sistem Pembayaran Finansial

Dokumen ini mengupas empat pola desain perangkat lunak (*software design patterns*) esensial dalam rekayasa payment gateway: *Idempotency Key Pattern*, *Deterministic Finite State Machine (FSM)*, *Strategy & Factory Pattern* untuk multi-vendor channel routing, serta *Circuit Breaker dengan Retry Backoff*.

---

## 1. Idempotency Key Pattern: Standar IETF dan Eksekusi Atomik

Dalam transaksi daring, kegagalan jaringan saat klien menunggu balasan HTTP (*network drop after processing*) sering memicu klien untuk mengirimkan ulang permintaan yang sama. Tanpa mekanisme idempotensi, kartu kredit pelanggan akan terpotong dua kali atau saldo merchant akan tercatat ganda.

### 1.1 Spesifikasi Header Idempotency (IETF Draft)

Merchant mengirimkan header HTTP wajib pada setiap operasi pembuatan pembayaran:
`Idempotency-Key: 8a7d3c2b-4e1f-4902-b21a-e7c65f903d88`

### 1.2 Diagram Alur Eksekusi Atomik Berbasis Redis

```
[ Klien / Merchant API ]
         |
         | POST /v1/payments (Header: Idempotency-Key: X)
         v
+---------------------------------------------------------------+
| Idempotency Middleware (Redis Layer)                         |
+---------------------------------------------------------------+
         |
         | 1. Hitung SHA-256 dari Request Payload
         | 2. SETNX idempotency:merchant_123:X "IN_PROGRESS:<hash>" EX 120
         |
         +-----------------------------+-----------------------------+
         | (Status: Kunci Berhasil)     | (Status: Kunci Sudah Ada)   |
         v                             v                             v
  [ Kunci Baru Diperoleh ]      [ Nilai = IN_PROGRESS ]       [ Nilai = COMPLETED ]
         |                             |                             |
         v                             v                             v
  Eksekusi Core Logic           Tolak Permintaan              Ambil Simpanan Respons
  (Payment Processing)          HTTP 409 Conflict             (Cached HTTP Status & Body)
         |                      "Permintaan sedang diproses"  Langsung kembalikan
         v                                                    HTTP 200/201 Hasil Asli
  Simpan Hasil Respons                                        (Bypass Core Logic)
  SET idempotency:X "COMPLETED:<response_json>" EX 86400
         |
         v
  Kembalikan Respons ke Klien
```

### 1.3 Penanganan Konflik Payload (Payload Hash Mismatch)
Jika merchant mengirimkan `Idempotency-Key` yang sama tetapi dengan parameter nominal uang yang berbeda dari permintaan pertama:
- **Tindakan**: Gateway wajib menolak dengan galat `HTTP 422 Unprocessable Entity` atau `HTTP 400 Bad Request` ("Idempotency key telah digunakan untuk payload yang berbeda"). Hal ini mencegah serangan injeksi atau manipulasi parameter pembayaran.

---

## 2. Finite State Machine (FSM) Status Pembayaran

Status pembayaran tidak boleh diubah secara sembarangan melalui mutasi langsung. Perubahan status hanya sah jika mengikuti diagram transisi status deterministik (*deterministic state transitions*).

### 2.1 Diagram Transisi Status Pembayaran

```
                      +-------------------+
                      |    INITIALIZED    |
                      +-------------------+
                                |
                   (Create Payment Gateway / VA)
                                v
                      +-------------------+
                      |  PENDING_PAYMENT  |
                      +-------------------+
                        /        |        \
       (Callback Sukses)         |         (Batas Waktu Habis)
              /                  |                  \
             v                   | (Bank Menolak)    v
  +-------------------+          |          +-------------------+
  |      SETTLED      |          v          |      EXPIRED      |
  +-------------------+  +----------------+ +-------------------+
          |              |     FAILED     |
   (Refund Order)        +----------------+
          v
  +-------------------+
  |     REFUNDED      |
  +-------------------+
```

### 2.2 Matriks Transisi Legal dan Ilegal

| Status Asal (*From*) | Status Tujuan Legal (*To*) | Transisi Terlarang / Ilegal (*Illegal*) |
| :--- | :--- | :--- |
| `INITIALIZED` | `PENDING_PAYMENT`, `FAILED` | `SETTLED`, `REFUNDED`, `EXPIRED` |
| `PENDING_PAYMENT` | `SETTLED`, `EXPIRED`, `FAILED` | `INITIALIZED`, `REFUNDED` |
| `SETTLED` | `REFUNDED` (Hanya jika memenuhi syarat) | `PENDING_PAYMENT`, `EXPIRED`, `FAILED` |
| `EXPIRED` | *(Final State - Tidak Ada)* | `SETTLED` (Late payment butuh review manual) |
| `FAILED` | *(Final State - Tidak Ada)* | `SETTLED`, `PENDING_PAYMENT` |
| `REFUNDED` | *(Final State - Tidak Ada)* | Segala transisi lain |

### 2.3 Implementasi FSM Anti-Skip State di Kode Domain

```go
package entity

import (
    "fmt"
)

type PaymentStatus string

const (
    StatusInitialized    PaymentStatus = "INITIALIZED"
    StatusPendingPayment PaymentStatus = "PENDING_PAYMENT"
    StatusSettled        PaymentStatus = "SETTLED"
    StatusExpired        PaymentStatus = "EXPIRED"
    StatusFailed         PaymentStatus = "FAILED"
    StatusRefunded       PaymentStatus = "REFUNDED"
)

var legalTransitions = map[PaymentStatus][]PaymentStatus{
    StatusInitialized:    {StatusPendingPayment, StatusFailed},
    StatusPendingPayment: {StatusSettled, StatusExpired, StatusFailed},
    StatusSettled:        {StatusRefunded},
    StatusExpired:        {},
    StatusFailed:         {},
    StatusRefunded:       {},
}

func (s *PaymentSession) TransitionTo(target PaymentStatus) error {
    allowedTargets, exists := legalTransitions[s.Status]
    if !exists {
        return fmt.Errorf("status asal tidak valid: %s", s.Status)
    }

    for _, allowed := range allowedTargets {
        if allowed == target {
            s.Status = target
            return nil
        }
    }

    return fmt.Errorf("ILLEGAL_STATE_TRANSITION: transisi dari %s ke %s ditolak", s.Status, target)
}
```

---

## 3. Strategy Pattern & Factory Pattern: Multi-Vendor Channel Routing

Payment gateway Tamaku harus mampu menghubungkan merchant ke berbagai saluran pembayaran: SNAP BI Bank BCA, Bank Mandiri, Duitku, Xendit, hingga QRIS Dinamis mandiri tanpa merombak logika inti.

### 3.1 Pola Strategy

```
                          +-------------------------------+
                          |     PaymentProcessingService  |
                          +-------------------------------+
                                          |
                                          v (Memanggil Strategy)
                          +-------------------------------+
                          |    PaymentGatewayStrategy     |
                          |  <<interface>>                |
                          |  + Pay(req) PaymentResult     |
                          |  + Query(ref) StatusResult    |
                          +-------------------------------+
                            /             |             \
                           /              |              \
  +--------------------------+  +--------------------+  +----------------------+
  |    BCASnapStrategy       |  |  MandiriStrategy   |  |   QRISMasterStrategy |
  +--------------------------+  +--------------------+  +----------------------+
```

### 3.2 Pola Factory dengan Registrasi Dinamis

```go
package factory

import (
    "fmt"
    "tamaku/internal/domain/entity"
)

type PaymentGatewayStrategy interface {
    Pay(session *entity.PaymentSession) (*entity.PaymentResult, error)
    VerifyWebhook(payload []byte, headers map[string]string) (bool, error)
}

type GatewayFactory struct {
    strategies map[string]PaymentGatewayStrategy
}

func NewGatewayFactory() *GatewayFactory {
    return &GatewayFactory{
        strategies: make(map[string]PaymentGatewayStrategy),
    }
}

func (f *GatewayFactory) Register(channelCode string, strategy PaymentGatewayStrategy) {
    f.strategies[channelCode] = strategy
}

func (f *GatewayFactory) GetStrategy(channelCode string) (PaymentGatewayStrategy, error) {
    strategy, exists := f.strategies[channelCode]
    if !exists {
        return nil, fmt.Errorf("metode pembayaran tidak didukung: %s", channelCode)
    }
    return strategy, nil
}
```

---

## 4. Ketahanan Outbound: Retry dengan Exponential Backoff + Jitter

Melakukan *retry* langsung ke API bank yang sedang mengalami gangguan dengan interval tetap (misalnya tiap 1 detik) akan memperparah kondisi bank (*Thundering Herd Problem*).

### 4.1 Rumus Full Jitter (AWS Architecture Standard)

Interval jeda waktu dihitung secara dinamis:
$$\text{Sleep} = \text{random}(0, \min(M, B \times 2^{\text{attempt}}))$$
- $B$: *Base delay* (misal 500 ms)
- $M$: *Max delay* (misal 10 detik)
- $\text{attempt}$: Jumlah percobaan yang telah gagal (1, 2, 3...)

```go
package resilience

import (
    "context"
    "math/rand"
    "time"
)

type RetryConfig struct {
    MaxAttempts int
    BaseDelay   time.Duration
    MaxDelay    time.Duration
}

func ExecuteWithRetry(ctx context.Context, cfg RetryConfig, operation func() error) error {
    var err error
    for attempt := 0; attempt < cfg.MaxAttempts; attempt++ {
        err = operation()
        if err == nil {
            return nil
        }

        // Hitung interval eksponensial
        backoffLimit := cfg.BaseDelay * (1 << attempt)
        if backoffLimit > cfg.MaxDelay {
            backoffLimit = cfg.MaxDelay
        }

        // Terapkan Full Jitter (acak antara 0 s.d. backoffLimit)
        sleepDuration := time.Duration(rand.Int63n(int64(backoffLimit)))

        select {
        case <-time.After(sleepDuration):
        case <-ctx.Done():
            return ctx.Err()
        }
    }
    return err
}
```
Pola ini memastikan bahwa ratusan *worker* yang mencoba menghubungi bank tidak membombardir server bank pada milidetik yang sama secara serempak.
