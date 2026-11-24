# Pola Arsitektur Perangkat Lunak: Hexagonal, Clean, dan Layered Architecture

Dokumen ini membedah arsitektur kode mikro (*in-code design architecture*), mengevaluasi batas isolasi domain bisnis, menerapkan prinsip pembalikan ketergantungan (*Dependency Inversion Principle / DIP*), serta merancang kontrak *Ports and Adapters* untuk sistem payment gateway.

---

## 1. Perbandingan Pola Arsitektur Mikro

Keberhasilan pemeliharaan basis kode sistem finansial dalam jangka panjang ditentukan oleh seberapa murni logika bisnis terisolasi dari perubahan framework web, driver basis data, atau API vendor perbankan pihak ketiga.

### 1.1 Tinjauan Empat Pola Utama

```
A. Traditional N-Tier                B. Hexagonal / Ports & Adapters
+-------------------------+          +--------------------------------------+
| Controller / Presentation|          | Drivers: HTTP, CLI, Message Queue    |
+-------------------------+          +--------------------------------------+
             | (Tergantung)                             | Inbound Ports
             v                                          v
+-------------------------+          +--------------------------------------+
| Service / Business Logic|          | Core Domain & Application Use Cases  |
+-------------------------+          +--------------------------------------+
             | (Tergantung)                             | Outbound Ports
             v                                          v
+-------------------------+          +--------------------------------------+
| Data Access / Repository|          | Adapters: Postgres, SNAP BI, Redis   |
+-------------------------+          +--------------------------------------+
```

| Dimensi Perbandingan | N-Tier Layered (Controller-Service-Repo) | Clean Architecture (Uncle Bob) | Hexagonal Architecture (Ports & Adapters) | Onion Architecture (Jeffrey Palermo) |
| :--- | :--- | :--- | :--- | :--- |
| **Pusat Gravitasi Arsitektur** | Basis Data (*Database-Centric*) | Lingkaran Entitas & Use Case | Inti Aplikasi (*Domain & Use Case*) | Model Domain Inti (*Domain Model*) |
| **Arah Ketergantungan** | Atas ke Bawah (Bisnis bergantung ke DB) | Luar ke Dalam (Ketergantungan ke arah pusat) | Di Luar Lingkaran Mengarah ke Port Inti | Lapisan Luar Bergantung ke Lapisan Dalam |
| **Tingkat Isolasi Framework** | Lemah (Model ORM sering bocor ke controller) | Sangat Kuat | Sangat Kuat | Sangat Kuat |
| **Kemudahan Pengujian Mandiri**| Sulit tanpa mock DB atau DB in-memory | Sangat Mudah (Unit test murni tanpa IO) | Sangat Mudah (Cukup ganti Adapter dengan Mock) | Sangat Mudah |
| **Overhead Kode & Boilerplate** | Sangat Rendah | Sangat Tinggi (Banyak layer DTO & mapper) | Moderat (Definisi interface terarah) | Tinggi |
| **Kesesuaian Payment Gateway** | Buruk (Keterikatan vendor perbankan tinggi) | Baik | **Sangat Baik (Pilihan Optimal)** | Baik |

---

## 2. Penegakan Dependency Inversion Principle (DIP)

### 2.1 Masalah Tradisional pada Integrasi Perbankan

Pada arsitektur *N-Tier* konvensional, layer *Service* mengimpor langsung pustaka HTTP client atau driver basis data:

```
[ HTTP Controller ] ---> [ Payment Service ] ---> [ BCA SNAP HTTP Client ]
                                             ---> [ PostgreSQL GORM Model ]
```
- **Dampak Negatif**:
  1. Jika BCA mengubah format otentikasi dari HMAC ke Asymmetric RSA, kode di layer bisnis pembayaran terpaksa diubah.
  2. Pengujian unit pada *Payment Service* mustahil dijalankan tanpa koneksi jaringan aktif ke sandbox BCA atau database lokal, memperlambat proses *Continuous Integration* (CI).

### 2.2 Penegakan DIP: Membalik Kendali Ketergantungan

Prinsip dasar DIP menyatakan:
> *Modul tingkat tinggi tidak boleh bergantung pada modul tingkat rendah. Keduanya harus bergantung pada abstraksi (antarmuka / interface).*

```
+-------------------------------------------------------------------------------+
| CORE DOMAIN & APPLICATION LAYER (Tingkat Tinggi - Tidak Mengimpor Siapapun)   |
|                                                                               |
|   type PaymentService struct {                                                |
|       bankPort OutboundBankPort                                               |
|       repoPort PaymentRepositoryPort                                          |
|   }                                                                           |
|                                                                               |
|   type OutboundBankPort interface {                                           |
|       ChargeVirtualAccount(ctx, req VACreationRequest) (VAResponse, error)    |
|   }                                                                           |
+-------------------------------------------------------------------------------+
                                      ^
                                      | (Implementasi Interface / Mengimpor Core)
+-------------------------------------------------------------------------------+
| INFRASTRUCTURE LAYER (Tingkat Rendah - Adapter Luar)                          |
|                                                                               |
|   type BCASnapAdapter struct { ... }                                          |
|   func (b *BCASnapAdapter) ChargeVirtualAccount(...) { ... }                   |
|                                                                               |
|   type PostgresPaymentRepo struct { ... }                                     |
|   func (p *PostgresPaymentRepo) Save(...) { ... }                             |
+-------------------------------------------------------------------------------+
```

Inti aplikasi menentukan kontrak apa yang ia butuhkan untuk bekerja (`OutboundBankPort`). Pihak luar (implementasi BCA, Mandiri, atau Mock untuk pengujian) yang berkewajiban menyesuaikan diri dengan kontrak tersebut.

---

## 3. Desain Ports & Adapters pada Tamaku Payment Gateway

Hexagonal Architecture membagi gerbang sistem menjadi dua orientasi:
1. **Primary Ports (Inbound / Driving Ports)**: Dipanggil oleh pihak luar untuk memicu eksekusi logika aplikasi (misalnya HTTP API Handler, CLI Command, atau Event Consumer).
2. **Secondary Ports (Outbound / Driven Ports)**: Dipanggil oleh inti aplikasi untuk berinteraksi dengan infrastruktur eksternal (misalnya Database Persistence, External Bank API, Redis Cache, Message Publisher).

```
                      +---------------------------------------+
                      |               HEXAGON                 |
  [ Klien / Web ]     |                                       |     [ PostgreSQL ]
         |            |  +---------------------------------+  |            ^
  (HTTP JSON Request) |  | Inbound Ports                   |  |            |
         v            |  | - CreatePaymentSessionUseCase   |  |            |
  +-----------------+ |  | - ProcessWebhookCallbackUseCase |  |  +--------------------+
  | Primary Adapter | |  +---------------------------------+  |  | Secondary Adapter  |
  | (Gin / Fiber)   | |                  |                    |  | (Postgres Repo)    |
  +-----------------+ |                  v                    |  +--------------------+
                      |  +---------------------------------+  |            ^
                      |  | Pure Domain & Business Entities |  |            |
                      |  | - Invoice, PaymentSession, FSM  |  |            |
                      |  +---------------------------------+  |            |
                      |                  |                    |            |
  +-----------------+ |                  v                    |  +--------------------+
  | Primary Adapter | |  +---------------------------------+  |  | Secondary Adapter  |
  | (Kafka Consumer)| |  | Outbound Ports                  |  |  | (BCA SNAP Client)  |
  +-----------------+ |  | - PaymentRepositoryPort         |  |  +--------------------+
         ^            |  | - BankGatewayPort               |  |            |
         |            |  | - EventPublisherPort            |  |            v
  (Incoming Event)    |  +---------------------------------+  |      [ Server Bank ]
                      |                                       |
                      +---------------------------------------+
```

---

## 4. Definisi Kontrak Interface Antar-Lapisan

Berikut struktur rancangan interface (*Ports*) yang memisahkan logika aplikasi Tamaku dari dependensi teknologi:

### 4.1 Inbound Port (Primary)
Kontrak yang dieksekusi oleh Controller HTTP saat merchant membuat pesanan:

```go
package port

import (
    "context"
    "tamaku/domain/entity"
)

type CreatePaymentInput struct {
    MerchantID    string
    ReferenceID   string
    Amount        int64
    Currency      string
    PaymentMethod string
    CallbackURL   string
}

type CreatePaymentResult struct {
    SessionID   string
    PaymentURL  string
    VirtualAcc  string
    ExpiredAt   int64
    Status      entity.PaymentStatus
}

// InboundPort: Dijalankan oleh HTTP Handler / gRPC Handler
type CreatePaymentUseCase interface {
    Execute(ctx context.Context, input CreatePaymentInput) (*CreatePaymentResult, error)
}
```

### 4.2 Outbound Ports (Secondary)
Kontrak yang wajib diimplementasikan oleh adapter basis data dan adapter perbankan:

```go
package port

import (
    "context"
    "tamaku/domain/entity"
)

// Repository Port: Interaksi dengan penyimpanan permanen
type PaymentRepositoryPort interface {
    Save(ctx context.Context, session *entity.PaymentSession) error
    FindByID(ctx context.Context, sessionID string) (*entity.PaymentSession, error)
    FindByReferenceID(ctx context.Context, merchantID, refID string) (*entity.PaymentSession, error)
    UpdateStatus(ctx context.Context, sessionID string, status entity.PaymentStatus) error
}

// Bank Gateway Port: Abstraksi pihak perbankan
type BankPaymentRequest struct {
    SessionID    string
    Amount       int64
    CustomerName string
    ExpiryTime   int64
}

type BankPaymentResponse struct {
    BankReference string
    VirtualAccNo  string
    QRCodeString  string
    RawResponse   []byte
}

type BankGatewayPort interface {
    GenerateVirtualAccount(ctx context.Context, req BankPaymentRequest) (*BankPaymentResponse, error)
    GenerateQRIS(ctx context.Context, req BankPaymentRequest) (*BankPaymentResponse, error)
    QueryStatus(ctx context.Context, bankReference string) (entity.PaymentStatus, error)
}
```

---

## 5. Struktur Direktori Berbasis Hexagonal Architecture

Tata letak paket (*package layout*) Go yang mencerminkan pemisahan Ports & Adapters secara lugas:

```
tamaku-core/
├── cmd/
│   └── api/
│       └── main.go               # Injeksi dependensi (wire-up) & inisialisasi server
├── internal/
│   ├── domain/                   # Lapisan Domain Murni (Zero External Dependencies)
│   │   ├── entity/               # PaymentSession, Invoice, Transaction
│   │   ├── valueobject/          # Money, Currency, PaymentStatus
│   │   └── error.go              # Sentinel domain errors (ErrInsufficientBalance, dll)
│   │
│   ├── port/                     # Lapisan Kontrak Antarmuka (Ports)
│   │   ├── inbound.go            # Use Case Interfaces
│   │   └── outbound.go           # Repository & Gateway Interfaces
│   │
│   ├── service/                  # Lapisan Aplikasi / Orchestrator Use Case
│   │   ├── payment_usecase.go    # Implementasi CreatePaymentUseCase
│   │   └── webhook_usecase.go    # Implementasi ProcessWebhookUseCase
│   │
│   └── adapter/                  # Lapisan Infrastruktur Luar (Adapters)
│       ├── primary/              # Driving Adapters
│       │   ├── http/             # HTTP Handlers (Gin/Fiber/Echo), DTO Request/Response
│       │   └── consumer/         # Kafka/Redis Stream Consumer
│       │
│       └── secondary/            # Driven Adapters
│           ├── persistence/      # PostgreSQL GORM / pgx implementation
│           ├── bank/             # Adapter Vendor (bca_snap.go, mandiri.go, qris.go)
│           └── cache/            # Redis Idempotency & Locking adapter
```

### Aturan Kompilasi:
1. `internal/domain` dilarang mengimpor `internal/port`, `internal/service`, atau `internal/adapter`.
2. `internal/port` hanya boleh mengimpor `internal/domain`.
3. `internal/service` mengimplementasikan `internal/port/inbound.go` dan menggunakan interface dari `internal/port/outbound.go`.
4. `internal/adapter` mengimplementasikan interface dari `internal/port/outbound.go` atau memanggil `internal/port/inbound.go`.
