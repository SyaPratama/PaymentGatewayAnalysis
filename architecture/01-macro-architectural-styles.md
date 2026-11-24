# Taksonomi dan Evaluasi Gaya Arsitektur Makro Sistem Payment Gateway

Dokumen ini membedah lima paradigma arsitektur makro perangkat lunak dalam konteks pemrosesan transaksi finansial berkecepatan tinggi, kepatuhan regulasi ketat, dan ketersediaan tinggi (*high availability*).

---

## 1. Dekonstruksi Lima Gaya Arsitektur Makro

### 1.1 Classic Monolith (Single Process, Single Database)

Arsitektur monolit klasik mengemas seluruh fungsionalitas sistem (autentikasi, perutean transaksi, *ledger* saldo, integrasi kanal bank, *billing*, rekonsiliasi) ke dalam satu basis kode (*single code repository*) yang berjalan dalam satu proses *runtime* (*single binary* atau *app server*) dan berinteraksi dengan satu basis data relasional terpusat.

```
[ Klien / Merchant API ]
         |
         v (HTTPS / REST)
+-------------------------------------------------------+
| Classic Monolith Application (Single Process)         |
|  - Auth & Merchant API                                |
|  - Payment Router & Orchestration                     |
|  - Core Accounting & Ledger Engine                    |
|  - Bank Connector Adapters (SNAP BI, QRIS, dll)       |
|  - Settlement & Reconciliation Engine                 |
+-------------------------------------------------------+
         |
         v (Single DB Connection Pool / ACID)
+-------------------------------------------------------+
| Relational Database (PostgreSQL / MySQL)              |
+-------------------------------------------------------+
```

#### Karakteristik Teknis
- **Komunikasi Internal**: Pemanggilan fungsi memori (*in-process memory invocation*). Latensi pemanggilan internal berkisar antara 10 hingga 50 nanodetik.
- **Konsistensi Data**: Menjamin transaksi ACID (*Atomicity, Consistency, Isolation, Durability*) penuh via *native database transactions* (`BEGIN ... COMMIT`).
- **Penyebaran (*Deployment*)**: Bersifat *all-or-nothing*. Kegagalan *panic* atau kebocoran memori pada modul rekonsiliasi berisiko mematikan proses penerimaan transaksi masuk.

#### Kelemahan Utama pada Pemrosesan Finansial
- Batasan *scaling* vertikal pada basis data terpusat ketika volume transaksi melonjak drastis.
- Kegagalan isolasi kesalahan (*fault isolation*): lonjakan komputasi pada pemrosesan laporan akhir hari (*end-of-day reconciliation*) menyedot *connection pool* basis data, memperlambat *inbound payment capture*.

---

### 1.2 Modular Monolith (Strict Domain Boundaries, In-Process IPC)

Modular Monolith mempertahankan penyebaran *single deployment unit*, namun memaksakan batas modul (*domain boundaries*) yang kedap secara struktural di tingkat kompilasi. Modul antardomain dilarang keras melakukan kueri langsung ke tabel basis data milik modul lain (*zero cross-module database joins*). Komunikasi antarmodul hanya diizinkan melalui *interface* publik terdaftar atau *in-memory event bus*.

```
+-------------------------------------------------------------------+
| Modular Monolith Runtime (Single Deployable Binary)               |
|                                                                   |
| +---------------------+ In-Memory   +---------------------------+ |
| | Module: Payment Core| Events/API  | Module: Ledger & Balance  | |
| | (Domain & Logic)    | <---------> | (Double-Entry Invariants) | |
| +---------------------+             +---------------------------+ |
|            |                                      |               |
|            | Isolated Schema                      | Isolated      |
|            v                                      v Schema        |
|   [ Schema: payment ]                    [ Schema: ledger ]       |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
| PostgreSQL Instance (Logical Schema Separation / Row Security)    |
+-------------------------------------------------------------------+
```

#### Karakteristik Teknis
- **Struktur Kode**: Menggunakan enkapsulasi internal bahasa pemrograman (misalnya package internal Go, modul Rust, atau *access modifiers* C# / Java).
- **Skema Basis Data**: Pemisahan skema logis (contoh: PostgreSQL `payment.*` dan `ledger.*`). Akses antarskema dibatasi melalui peran basis data terpisah.
- **Integritas Transaksi**: Mampu mengeksekusi transaksi ACID lintas modul saat dibutuhkan menggunakan transaksi basis data lokal yang sama, tanpa perlu *distributed two-phase commit* (2PC).

---

### 1.3 Microservices (Polyglot/Independent Deployments, Network IPC)

Microservices memecah domain bisnis menjadi layanan-layanan independen yang berjalan di atas proses fisik terpisah, memiliki basis data privat masing-masing (*Database-per-Service*), dan berkomunikasi melalui protokol jaringan seperti gRPC (HTTP/2) atau REST (HTTP/1.1 / JSON).

```
[ Merchant Client ]
        |
        v
+-------------------------------------------------------+
| API Gateway (Envoy / Kong)                            |
+-------------------------------------------------------+
   | (gRPC)                     | (gRPC)             | (gRPC)
   v                            v                    v
+------------------+    +------------------+    +-------------------+
| Payment Routing  |    | Ledger Service   |    | Settlement Worker |
| Service          |    |                  |    |                   |
+------------------+    +------------------+    +-------------------+
   |                            |                         |
   v (DB Pool)                  v (DB Pool)               v (DB Pool)
+------------------+    +------------------+    +-------------------+
| DB Payment       |    | DB Ledger        |    | DB Settlement     |
+------------------+    +------------------+    +-------------------+
```

#### Karakteristik Teknis
- **Komunikasi Jaringan**: Setiap interaksi lintas domain membayar biaya latensi jaringan (serialisasi JSON/Protobuf, TCP handshake, TLS, perutean jaringan) berkisar antara 1 hingga 5 milidetik per *hop*.
- **Hilangnya Transaksi ACID**: Tidak ada transaksi basis data global. Pembaruan data lintas layanan harus menggunakan koordinasi BASE (*Basically Available, Soft state, Eventual consistency*) melalui pola Saga (*Choreography* atau *Orchestration*).
- **Independensi Operasional**: Tim terpisah dapat menguji dan memperbarui *bank adapter* tanpa menyentuh *ledger engine*.

---

### 1.4 Event-Driven Architecture (EDA, Choreography & Orchestration)

EDA menempatkan pertukaran pesan asinkron (*asynchronous event streams*) melalui *distributed commit log* (seperti Apache Kafka) atau *broker* antrean berkinerja tinggi sebagai tulang punggung sistem. Alur pemrosesan digerakkan oleh penerbitan peristiwa (*events*) yang tidak dapat diubah (*immutable*).

```
[ Payment API Service ]
        |
        | 1. Append Intent & Write Outbox (ACID)
        v
[ Transactional Outbox Engine ]
        |
        | 2. Publish Event "PaymentCreated"
        v
+-----------------------------------------------------------------------+
| Event Broker (Apache Kafka Partitioned Topic: payment.transactions)   |
+-----------------------------------------------------------------------+
        |                                       |
        | (Consumer Group A)                    | (Consumer Group B)
        v                                       v
+----------------------------------+    +-------------------------------+
| Fraud Analysis Engine            |    | Bank Dispatcher Engine        |
| - Evaluate risk score            |    | - Call BCA / Mandiri API      |
| - Produce "PaymentFraudChecked"  |    | - Produce "BankCallbackRecv"  |
+----------------------------------+    +-------------------------------+
```

#### Karakteristik Teknis
- **Decoupling Temporal**: Penerbit (*producer*) dan penerima (*consumer*) tidak perlu aktif pada waktu yang bersamaan. Jika layanan bank mengalami perlambatan, antrean pesan menampung lonjakan tanpa mematikan API penerimaan pembayaran.
- **Pola Integrasi**:
  - *Choreography*: Komponen mendengarkan peristiwa dan memutuskan aksi mandiri tanpa pengendali sentral. Rentan menghasilkan logika bisnis implisit yang sulit dilacak.
  - *Orchestration*: Menggunakan koordinator terpusat (State Machine / Workflow Engine seperti Temporal) untuk mengeksekusi kompensasi langkah demi langkah.
- **Idempotensi Wajib**: Konsumsi pesan mengandalkan garansi pengiriman *at-least-once*, menuntut penerapan idempotensi ketat pada setiap konsumen untuk mencegah pencatatan transaksi ganda.

---

### 1.5 Serverless / Edge Computing

Pengeksekusian kode berbasis fungsi terisolasi (*Function-as-a-Service*) yang beroperasi tanpa server terkelola (contoh: AWS Lambda, Cloudflare Workers). Fungsi dihidupkan berdasarkan pemicu HTTP atau pesan antrean, lalu dimatikan secara instan saat eksekusi selesai.

#### Karakteristik Teknis
- **Cold Start Latency**: Penambahan latensi inisialisasi lingkungan eksekusi (50 ms hingga 1.500 ms), berisiko melanggar *Service Level Agreement* (SLA) latensi pembayaran.
- **Keterbatasan Database Connection Pooling**: Ribuan instans fungsi yang aktif bersamaan dapat membanjiri batas *connection pool* basis data relasional, mewajibkan penggunaan perantara seperti AWS RDS Proxy atau PgBouncer.
- **Use Case Optimal**: Efektif untuk *Edge Webhook Receiver* atau *signature validation proxy* di lapisan terluar sebelum dialirkan ke *backbone* utama.

---

## 2. Matriks Komparasi Objektif Arsitektur Makro

| Dimensi Evaluasi | Classic Monolith | Modular Monolith | Microservices | Event-Driven (EDA) | Serverless / Edge |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Throughput (Peak TPS)** | 1.000 - 3.000 TPS | 5.000 - 15.000 TPS | 20.000+ TPS (Tergantung Node) | 50.000+ TPS (Tinggi) | Variatif (Dibatasi Concurrency DB) |
| **Latensi Pemrosesan Internal** | < 1 ms (In-Memory) | < 1 ms (In-Memory) | 5 - 25 ms (Multi-hop Network) | Asinkron (50 - 500 ms end-to-end) | 50 - 800 ms (Tergantung Cold Start) |
| **Kompleksitas Operasional** | Sangat Rendah | Rendah | Sangat Tinggi (K8s, Mesh, Tracing) | Tinggi (Kafka Cluster, Schema Reg) | Sedang (Terkelola, Observability rumit) |
| **Biaya Infrastruktur Awal** | Rendah ($50 - $200/bln) | Rendah ($100 - $500/bln) | Tinggi ($2.000+/bln) | Tinggi ($1.500+/bln) | Bayar per Eksekusi |
| **Konsistensi Transaksi** | Kuat (ACID Native) | Kuat (ACID Terkendali) | Akhir (BASE / Saga) | Akhir (BASE / Eventual) | Lemah (Perlu External Lock) |
| **Kemudahan Debugging & Audit** | Sangat Mudah (Stack Trace Lokal) | Mudah (Log Terpusat Terstruktur) | Sangat Sulit (Distributed Tracing) | Sulit (Async Message Tracking) | Sedang (Log Tersebar) |
| **Isolasi Kegagalan (Blast Radius)** | Buruk (Satu modul crash = mati total) | Sedang (Bisa dicegah di layer bahasa) | Sangat Baik (Per Service Terisolasi) | Sangat Baik (Isolasi Antrean) | Sangat Baik (Per Request) |

---

## 3. Batasan Transaksi: ACID vs BASE (Saga vs Two-Phase Commit)

Dalam arsitektur finansial, pemilihan model konsistensi menentukan kebenaran data saldo merchant dan riwayat transaksi.

### 3.1 Two-Phase Commit (2PC) - Mengapa Harus Dihindari pada Skala Tinggi
2PC menyediakan transaksi ACID lintas basis data terdistribusi melalui dua fase: *Prepare Phase* dan *Commit Phase*, di bawah koordinasi *Transaction Coordinator*.

```
Coordinator          Participant A (DB-Payment)       Participant B (DB-Ledger)
    |                             |                               |
    |--- 1. PREPARE ------------->|                               |
    |--- 1. PREPARE --------------------------------------------->|
    |                             |                               |
    |<-- VOTE_COMMIT -------------|                               |
    |<-- VOTE_COMMIT ---------------------------------------------|
    |                             |                               |
    |--- 2. GLOBAL_COMMIT ------->| (Holding Row Locks)           |
    |--- 2. GLOBAL_COMMIT --------------------------------------->| (Holding Row Locks)
    |                             |                               |
```

- **Alasan Kegagalan di Skala Tinggi**:
  1. *Blocking Protocol*: Jika koordinator atau salah satu peserta mengalami gangguan jaringan saat fase *prepare*, semua peserta lain menahan kunci baris (*row lock*). Hal ini memicu penumpukan antrean koneksi basis data (*thread exhaustion*).
  2. *Latensi Berlipat*: Mengharuskan minimal dua putaran jaringan (*two network round-trips*) yang meningkatkan latensi P99 secara eksponensial.

### 3.2 Saga Pattern (Choreography vs Orchestration)
Saga memecah transaksi terdistribusi menjadi serangkaian transaksi lokal atomik di setiap layanan. Jika salah satu langkah gagal, serangkaian transaksi kompensasi (*compensating transactions*) dieksekusi untuk membatalkan perubahan sebelumnya.

#### Saga Orchestration untuk Transaksi Pembayaran
Pola orkestrator terbukti lebih aman untuk pembayaran karena menjaga kendali alur di satu tempat yang dapat diaudit.

```
+-----------------------------------------------------------------------------+
|                          Payment Saga Orchestrator                          |
+-----------------------------------------------------------------------------+
       |                           |                               |
       | 1. Authorize              | 2. Post Journal               | 3. Notify
       v                           v                               v
+------------------+      +------------------+           +--------------------+
|  Payment Router  |      |  Ledger Service  |           | Notification Svc   |
+------------------+      +------------------+           +--------------------+
       |                           |                               |
       | GAGAL: Saldo Bank Kurang  | (Kompensasi: Reversal Void)   | (Kompensasi: Alert)
       v                           v                               v
[Batalkan Intent] --------> [Buku Jurnal Pembalik] -------> [Kirim Notifikasi]
```

- **Aturan Transaksi Kompensasi**:
  - Transaksi kompensasi harus dirancang **idempoten** dan **pasti berhasil** (*cannot fail*). Jika terjadi kegagalan jaringan saat kompensasi, orkestrator wajib melakukan *retry* terus-menerus hingga berhasil atau masuk ke antrean investigasi manual (*Dead Letter Queue*).
  - Data tidak pernah dihapus secara fisik (`DELETE`), melainkan dinetralkan melalui pencatatan transaksi pembalik (*journal reversal*).

---

## 4. Analisis Rekomendasi Arsitektur untuk Tamaku Payment Gateway

### 4.1 Tahap Awal hingga Menengah (0 - 10.000 TPS): Pilihan Optimal Adalah Modular Monolith

Membangun arsitektur terdistribusi (microservices/EDA penuh) di awal proyek pembayaran adalah bentuk pemborosan sumber daya dan pencipta risiko kegagalan sistem tersembunyi.

#### Justifikasi Teknis
1. **Integritas Mutlak Double-Entry**: Saldo merchant dan mutasi pembukuan dapat dikunci dan diperbarui menggunakan transaksi lokal PostgreSQL dengan isolasi tingkat `SERIALIZABLE` atau `REPEATABLE READ`. Tidak ada risiko uang melayang akibat kegagalan sinkronisasi jaringan antar-layanan.
2. **Latensi Minimal**: Pemanggilan modul antar-*router*, *fee calculator*, dan *ledger engine* terjadi di dalam memori proses (< 1 milidetik). Penghematan waktu ini memberikan ruang bernapas yang besar untuk waktu respons API bank upstream yang lambat (1.000 - 3.000 ms).
3. **Efisiensi Operasional**: Satu unit *binary* Go atau Rust yang dikemas dalam Docker container dapat menangani ribuan TPS pada satu server bare-metal atau instans cloud berukuran sedang, memangkas biaya server dari ribuan dolar menjadi kurang dari $200 per bulan.
4. **Refaktorisasi Tanpa Hambatan**: Batas modul (*bounded context*) dapat didefinisikan dan digeser tanpa harus melakukan migrasi skema basis data terdistribusi atau mengelola versi protokol API.

### 4.2 Ambang Batas Transisi ke Event-Driven / Microservices

Transisi dari Modular Monolith ke sistem terdistribusi hanya dibenarkan jika kondisi berikut terpenuhi:

1. **Konkurensi Basis Data Menemui Dinding Skala Vertikal**: Basis data relasional utama mencapai titik jenuh penulisan (*write contention* pada baris akun *ledger* utama) meskipun partisi tabel, *read replica*, dan optimasi indeks telah dioptimalkan secara maksimal (> 10.000 TPS stabil).
2. **Skala Organisasi Tim Rekayasa**: Jumlah tim rekayasa perangkat lunak melebihi 25 - 30 insinyur, di mana proses rilis *single binary* mulai terhambat oleh antrean pengujian integrasi dan koordinasi rilis antar-subtim.
3. **Kebutuhan Isolasi Kegagalan Ekstrem**: Modul pengiriman webhook merchant atau pemrosesan batch data settlement bank yang sering mengalami *spike* beban tinggi mulai mengancam stabilitas penerimaan API transaksi utama.

### 4.3 Cetak Biru Arsitektur Hibrida Masa Depan (Transisi Mulus)

Ketika transisi diperlukan, Modular Monolith dipecah bukan menjadi puluhan microservices granular, melainkan menjadi tiga subsistem otonom:
1. **Core Payment Ingestion & Routing**: Bertanggung jawab menerima API masuk, verifikasi tanda tangan merchant, idempotensi, dan komunikasi ke bank (berorientasi latensi rendah).
2. **Transactional Ledger Engine**: Khusus mengelola pencatatan akuntansi double-entry berbasis append-only.
3. **Async Settlement & Reconciliation Worker**: Berjalan di atas arsitektur Event-Driven untuk mengonsumsi peristiwa settlement, agregasi laporan berkala, dan penembakan webhook merchant.
