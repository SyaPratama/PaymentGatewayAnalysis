# Cetak Biru Implementasi Kode Rujukan (Go & TypeScript)

Dokumen ini menyediakan implementasi kode rujukan produksi (*production-grade reference code*) untuk modul-modul kritis payment gateway: *Value Object Money*, *Adapter SNAP BI BCA*, *State Machine Pembayaran Konkuren*, dan *Middleware Idempotensi Redis*.

---

## 1. Value Object `Money` Anti-Floating-Point Error (Go & TypeScript)

### 1.1 Implementasi Go Murni

```go
package money

import (
    "encoding/json"
    "errors"
    "fmt"
)

var (
    ErrNegativeValue    = errors.New("nominal tidak boleh bernilai negatif")
    ErrCurrencyMismatch = errors.New("mata uang tidak sesuai")
    ErrOverflow         = errors.New("terjadi aritmatika integer overflow")
)

type Money struct {
    amount   int64  // Nilai nominal dalam satuan terkecil (Rupiah utuh / sen)
    currency string // ISO 4217 (e.g. "IDR", "USD")
}

func New(amount int64, currency string) (Money, error) {
    if amount < 0 {
        return Money{}, ErrNegativeValue
    }
    if len(currency) != 3 {
        return Money{}, errors.New("kode mata uang wajib 3 karakter alfabet ISO 4217")
    }
    return Money{amount: amount, currency: currency}, nil
}

func (m Money) Amount() int64    { return m.amount }
func (m Money) Currency() string { return m.currency }

func (m Money) Add(other Money) (Money, error) {
    if m.currency != other.currency {
        return Money{}, fmt.Errorf("%w: %s vs %s", ErrCurrencyMismatch, m.currency, other.currency)
    }
    // Proteksi Integer Overflow
    if other.amount > 0 && m.amount > (1<<63-1)-other.amount {
        return Money{}, ErrOverflow
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

// MarshalJSON memastikan format serialisasi aman untuk API JSON
func (m Money) MarshalJSON() ([]byte, error) {
    return json.Marshal(map[string]interface{}{
        "amount":   m.amount,
        "currency": m.currency,
    })
}
```

### 1.2 Padanan TypeScript Murni (Anti-Floating-Point Error)

```typescript
export class Money {
  private readonly amount: bigint; // BigInt bawaan JavaScript/TS
  private readonly currency: string;

  constructor(amount: bigint | number, currency: string) {
    const parsedAmount = typeof amount === 'number' ? BigInt(Math.floor(amount)) : amount;
    if (parsedAmount < 0n) {
      throw new Error("Nominal uang tidak boleh negatif");
    }
    if (currency.length !== 3) {
      throw new Error("Mata uang harus 3 karakter ISO 4217");
    }
    this.amount = parsedAmount;
    this.currency = currency.toUpperCase();
  }

  public getAmount(): bigint {
    return this.amount;
  }

  public getCurrency(): string {
    return this.currency;
  }

  public add(other: Money): Money {
    this.assertSameCurrency(other);
    return new Money(this.amount + other.amount, this.currency);
  }

  public sub(other: Money): Money {
    this.assertSameCurrency(other);
    if (this.amount < other.amount) {
      throw new Error("Saldo tidak mencukupi untuk pengurangan");
    }
    return new Money(this.amount - other.amount, this.currency);
  }

  private assertSameCurrency(other: Money): void {
    if (this.currency !== other.currency) {
      throw new Error(`Mata uang tidak cocok: ${this.currency} vs ${other.currency}`);
    }
  }

  public toJSON() {
    return {
      amount: this.amount.toString(), // Kirim sebagai string untuk mencegah truncate di klien JSON
      currency: this.currency,
    };
  }
}
```

---

## 2. Port Interface dan Adapter Implementasi SNAP BI BCA (Go)

Standar Nasional Open API Pembayaran (SNAP BI) mewajibkan otentikasi simetris/asimetris dan pembuatan Virtual Account melalui format baku.

### 2.1 Definisi Port (Outbound Secondary Port)

```go
package port

import (
    "context"
    "time"
)

type CreateVARequest struct {
    PartnerServiceId   string
    CustomerNo         string
    VirtualAccountNo   string
    VirtualAccountName string
    Amount             int64
    Currency           string
    TrxId              string
    ExpiredDate        time.Time
}

type CreateVAResponse struct {
    ResponseCode    string
    ResponseMessage string
    VirtualAccount  string
    TrxId           string
}

type SnapBIAdapterPort interface {
    CreateVirtualAccount(ctx context.Context, req CreateVARequest) (*CreateVAResponse, error)
}
```

### 2.2 Implementasi Adapter BCA SNAP BI

```go
package bank

import (
    "bytes"
    "context"
    "crypto/hmac"
    "crypto/sha256"
    "crypto/sha512"
    "encoding/hex"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "strings"
    "time"
    "tamaku/internal/port"
)

type BCASnapAdapter struct {
    baseURL       string
    clientSecret  string
    partnerID     string
    channelID     string
    httpClient    *http.Client
}

func NewBCASnapAdapter(baseURL, clientSecret, partnerID, channelID string) *BCASnapAdapter {
    return &BCASnapAdapter{
        baseURL:      baseURL,
        clientSecret: clientSecret,
        partnerID:    partnerID,
        channelID:    channelID,
        httpClient:   &http.Client{Timeout: 10 * time.Second},
    }
}

// GenerateSymSignature menghitung SNAP BI Symmetric Signature:
// HMAC-SHA512(clientSecret, HTTPMethod + ":" + EndpointUrl + ":" + AccessToken + ":" + Lowercase(HexEncode(SHA256(Body))) + ":" + Timestamp)
func (b *BCASnapAdapter) GenerateSymSignature(method, path, accessToken, body string, timestamp string) string {
    bodyHash := sha256.Sum256([]byte(body))
    minifiedHash := strings.ToLower(hex.EncodeToString(bodyHash[:]))

    stringToSign := fmt.Sprintf("%s:%s:%s:%s:%s", method, path, accessToken, minifiedHash, timestamp)
    h := hmac.New(sha512.New, []byte(b.clientSecret))
    h.Write([]byte(stringToSign))
    return hex.EncodeToString(h.Sum(nil))
}

func (b *BCASnapAdapter) CreateVirtualAccount(ctx context.Context, req port.CreateVARequest) (*port.CreateVAResponse, error) {
    endpoint := "/v1.0/transfer-va/create-va"
    fullURL := b.baseURL + endpoint
    timestamp := time.Now().UTC().Format(time.RFC3339)

    payloadData := map[string]interface{}{
        "partnerServiceId":   req.PartnerServiceId,
        "customerNo":         req.CustomerNo,
        "virtualAccountNo":   req.VirtualAccountNo,
        "virtualAccountName": req.VirtualAccountName,
        "totalAmount": map[string]interface{}{
            "value":    fmt.Sprintf("%.2f", float64(req.Amount)),
            "currency": req.Currency,
        },
        "trxId":       req.TrxId,
        "expiredDate": req.ExpiredDate.Format(time.RFC3339),
    }

    bodyBytes, _ := json.Marshal(payloadData)
    // Asumsi token bearer telah di-cache
    accessToken := "dummy_bca_token"
    signature := b.GenerateSymSignature(http.MethodPost, endpoint, accessToken, string(bodyBytes), timestamp)

    httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, fullURL, bytes.NewBuffer(bodyBytes))
    if err != nil {
        return nil, err
    }

    httpReq.Header.Set("Content-Type", "application/json")
    httpReq.Header.Set("X-TIMESTAMP", timestamp)
    httpReq.Header.Set("X-SIGNATURE", signature)
    httpReq.Header.Set("X-PARTNER-ID", b.partnerID)
    httpReq.Header.Set("CHANNEL-ID", b.channelID)
    httpReq.Header.Set("X-EXTERNAL-ID", req.TrxId)
    httpReq.Header.Set("Authorization", "Bearer "+accessToken)

    resp, err := b.httpClient.Do(httpReq)
    if err != nil {
        return nil, fmt.Errorf("koneksi ke BCA gagal: %w", err)
    }
    defer resp.Body.Close()

    respBytes, _ := io.ReadAll(resp.Body)
    if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
        return nil, fmt.Errorf("BCA mengembalikan HTTP %d: %s", resp.StatusCode, string(respBytes))
    }

    var result struct {
        ResponseCode    string `json:"responseCode"`
        ResponseMessage string `json:"responseMessage"`
        VirtualAccount  string `json:"virtualAccountData.virtualAccountNo"`
    }
    _ = json.Unmarshal(respBytes, &result)

    return &port.CreateVAResponse{
        ResponseCode:    result.ResponseCode,
        ResponseMessage: result.ResponseMessage,
        VirtualAccount:  result.VirtualAccount,
        TrxId:           req.TrxId,
    }, nil
}
```

---

## 3. State Machine Pembayaran dengan Proteksi Concurrency (Go)

Menghindari *race condition* saat webhook pembayaran dan pengecekan manual merchant tiba di waktu yang sama. Menggunakan kueri bersyarat (*optimistic concurrency control* berbasis nomor versi) atau *pessimistic row locking*.

```go
package entity

import (
    "context"
    "database/sql"
    "errors"
    "fmt"
    "time"
)

type PaymentSession struct {
    ID        string
    Version   int64 // Kolom untuk Optimistic Concurrency Control
    Status    PaymentStatus
    Amount    int64
    UpdatedAt time.Time
}

// SettleOptimistic memperbarui status hanya jika nomor versi sesuai saat dibaca
func SettleOptimistic(ctx context.Context, db *sql.DB, sessionID string, currentVersion int64) error {
    query := `
        UPDATE payment_sessions 
        SET status = 'SETTLED', 
            version = version + 1, 
            updated_at = NOW() 
        WHERE id = $1 AND version = $2 AND status = 'PENDING_PAYMENT';
    `
    res, err := db.ExecContext(ctx, query, sessionID, currentVersion)
    if err != nil {
        return err
    }

    rowsAffected, err := res.RowsAffected()
    if err != nil {
        return err
    }

    if rowsAffected == 0 {
        return errors.New("CONFLICT_OPTIMISTIC_LOCK: Sesi pembayaran telah diubah oleh transaksi lain atau status tidak valid")
    }

    return nil
}
```

---

## 4. Idempotency Middleware dengan Redis Atomic Lock (Go)

Middleware HTTP yang melindungi endpoint pembuatan transaksi dari pengiriman berulang:

```go
package middleware

import (
    "bytes"
    "context"
    "crypto/sha256"
    "encoding/hex"
    "io"
    "net/http"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/redis/go-redis/v9"
)

type responseBodyWriter struct {
    gin.ResponseWriter
    body *bytes.Buffer
}

func (w responseBodyWriter) Write(b []byte) (int, error) {
    w.body.Write(b)
    return w.ResponseWriter.Write(b)
}

func IdempotencyMiddleware(rdb *redis.Client, lockTTL time.Duration) gin.HandlerFunc {
    return func(c *gin.Context) {
        idempotencyKey := c.GetHeader("Idempotency-Key")
        if idempotencyKey == "" {
            c.Next()
            return
        }

        merchantID := c.GetString("MerchantID") // Diisi oleh Auth Middleware
        redisKey := "idemp:" + merchantID + ":" + idempotencyKey

        // 1. Baca payload dan hitung hash
        bodyBytes, err := io.ReadAll(c.Request.Body)
        if err != nil {
            c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": "Gagal membaca body"})
            return
        }
        c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes)) // Reset body

        hasher := sha256.New()
        hasher.Write(bodyBytes)
        payloadHash := hex.EncodeToString(hasher.Sum(nil))

        ctx := context.Background()

        // 2. Kunci Redis secara atomik (SETNX)
        // Nilai awal: IN_PROGRESS:<hash>
        acquired, err := rdb.SetNX(ctx, redisKey, "IN_PROGRESS:"+payloadHash, lockTTL).Result()
        if err != nil {
            c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "Gangguan lock Redis"})
            return
        }

        if !acquired {
            // Kunci sudah ada, periksa isinya
            val, err := rdb.Get(ctx, redisKey).Result()
            if err == nil {
                if val == "IN_PROGRESS:"+payloadHash {
                    c.AbortWithStatusJSON(http.StatusConflict, gin.H{
                        "error": "Permintaan dengan Idempotency-Key ini sedang dalam proses",
                    })
                    return
                }
                if len(val) > 10 && val[:10] == "COMPLETED:" {
                    // Kembalikan respons yang disimpan sebelumnya
                    c.Header("X-Cache-Lookup", "HIT-IDEMPOTENT")
                    c.Data(http.StatusOK, "application/json", []byte(val[10:]))
                    c.Abort()
                    return
                }
            }
            c.AbortWithStatusJSON(http.StatusUnprocessableEntity, gin.H{
                "error": "Idempotency-Key telah digunakan untuk parameter request yang berbeda",
            })
            return
        }

        // 3. Tangkap respons output
        writer := &responseBodyWriter{body: bytes.NewBufferString(""), ResponseWriter: c.Writer}
        c.Writer = writer

        c.Next()

        // 4. Jika eksekusi sukses (200 - 299), simpan respons ke Redis selama 24 jam
        if c.Writer.Status() >= 200 && c.Writer.Status() < 300 {
            rdb.Set(ctx, redisKey, "COMPLETED:"+writer.body.String(), 24*time.Hour)
        } else {
            // Jika gagal, hapus kunci agar klien dapat mencoba kembali
            rdb.Del(ctx, redisKey)
        }
    }
}
```
