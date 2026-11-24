# Komunikasi Asinkron, Message Broker, dan Konsistensi Terdistribusi

Dokumen ini menganalisis arsitektur perpesanan terdistribusi, evaluasi komparatif *message broker*, eliminasi risiko *dual-write* melalui *Transactional Outbox Pattern*, serta penanganan *idempotency*, *distributed locking*, *dead letter queue*, dan evolusi skema pesan.

---

## 1. Evaluasi Komparatif Message Broker untuk Payment Gateway

Pemilihan tulang punggung perpesanan terdistribusi menentukan keandalan data, throughput, dan batas toleransi kegagalan sistem pembayaran.

### 1.1 Apache Kafka, RabbitMQ, Redis Streams, dan NATS

| Kriteria Teknis | Apache Kafka | RabbitMQ | Redis Streams | NATS / NATS JetStream |
| :--- | :--- | :--- | :--- | :--- |
| **Model Model Perpesanan** | Distributed Append-Only Commit Log | Smart Broker, Dumb Consumer (AMQP Queue) | In-Memory Log dengan Persistensi Disk (RDB/AOF) | High-Performance Messaging + JetStream Log |
| **Garansi Pengiriman** | At-least-once, Exactly-once (Kafka Streams/Txn) | At-least-once, At-most-once | At-least-once | At-least-once, Exactly-once (JetStream Deduplication) |
| **Throughput (Msg/Detik)** | 100.000 - 1.000.000+ per node | 20.000 - 50.000 per node | 100.000 - 500.000 per node | 500.000 - 2.000.000+ per node |
| **Latensi P99** | 5 - 15 ms | 2 - 5 ms | < 1 ms (Sub-milidetik) | < 1 ms |
| **Retensi Data** | Berbasis Waktu/Ukuran (Hari s.d. Bulan), Replay Aman | Berbasis Konsumsi (Pesan dihapus setelah ACK) | Dibatasi Kapasitas RAM Server | Berbasis Kuota Memori atau Disk |
| **Ordering Guarantee** | Mutlak per Partisi (*Partition Key*) | Parsial (Bisa rusak jika re-queued/parallel consumer) | Mutlak per Stream Entry ID | Mutlak per Stream Subject |
| **Kompleksitas Operasional** | Sangat Tinggi (KRaft / ZooKeeper, JVM tuning) | Sedang (Erlang VM, Mnesia clustering) | Rendah (Operasional Redis standar) | Sangat Rendah (Single binary Go, zero-dep) |
| **Footprint Memori** | Tinggi (RAM besar untuk page cache) | Sedang | Sangat Tinggi (Data berada di memori) | Sangat Rendah (< 50 MB binary footprint) |

### 1.2 Rekomendasi Pemilihan Berdasarkan Beban Kerja

1. **Apache Kafka**:
   - *Use Case*: Audit log finansial permanen, pelacakan analitik transaksi, agregasi rekonsiliasi akhir hari, dan *event sourcing*.
   - *Batasan*: Terlalu berat dan berlebihan (*overkill*) jika digunakan untuk pengiriman webhook atau antrean notifikasi berbobot ringan di tahap awal.
2. **RabbitMQ**:
   - *Use Case*: Perutean pesan kompleks (*exchange bindings*, *topic routing*) ke berbagai modul integrasi perbankan dengan konkurensi dinamis.
   - *Batasan*: *Message re-queueing* pada kondisi kegagalan dapat merusak urutan pesan (*out-of-order execution*), berbahaya untuk mutasi saldo.
3. **Redis Streams**:
   - *Use Case*: Pilihan ideal untuk tahap awal Modular Monolith hingga volume menengah. Mendukung *Consumer Groups*, pemulihan pesan macet (*PEL - Pending Entries List*), dengan latensi sub-milidetik.
   - *Batasan*: Dibatasi oleh kapasitas RAM fisik; data harus dibersihkan secara berkala (*capped streams* `MAXLEN`).
4. **NATS JetStream**:
   - *Use Case*: Arsitektur modern berkinerja tinggi yang membutuhkan operasional tanpa beban (*zero-ops overhead*), latensi sangat rendah, dan dedup bawaan (*inbox deduplication window*).

---

## 2. Mengatasi Dual-Write Hazard dengan Transactional Outbox Pattern

### 2.1 Masalah Bahaya Penulisan Ganda (*Dual-Write Hazard*)

Dalam aplikasi finansial tradisional, pengembang sering kali menulis ke basis data lalu langsung mengirim pesan ke broker dalam blok kode yang sama:

```
// ANTI-PATTERN: Dual-Write Hazard
func ProcessPayment(db *sql.DB, broker Broker, txData Transaction) error {
    tx, _ := db.Begin()
    // 1. Tulis ke basis data
    _, err := tx.Exec("UPDATE accounts SET balance = balance - $1 WHERE id = $2", txData.Amount, txData.AccountID)
    if err != nil {
        tx.Rollback()
        return err
    }
    _ = tx.Commit()

    // 2. Publikasi ke broker jaringan
    // BAHAYA: Jika server crash atau koneksi jaringan ke broker terputus di titik ini,
    // basis data sudah terlanjur dipotong, namun event "PaymentSuccess" tidak pernah terkirim!
    err = broker.Publish("payment.success", txData)
    return err
}
```

Jika urutannya dibalik (broker publish dulu baru commit DB), bencana yang sama terjadi: pesan sudah terkirim ke downstream, namun commit basis data lokal gagal (misalnya karena *constraint violation*).

### 2.2 Arsitektur Solusi: Transactional Outbox Pattern

Untuk menjamin atomisitas, perubahan data operasional dan catatan peristiwa yang akan diterbitkan disimpan ke dalam basis data yang sama di dalam satu transaksi lokal ACID.

```
+-------------------------------------------------------------------------------+
| Transaction Boundary (ACID Begin ... Commit)                                  |
|                                                                               |
|  1. UPDATE transactions SET status = 'SETTLED' WHERE id = 'tx_123';           |
|  2. INSERT INTO outbox_events (id, aggregate_type, aggregate_id, topic,       |
|                                payload, status, created_at)                   |
|     VALUES ('evt_abc', 'PAYMENT', 'tx_123', 'payment.events',                 |
|             '{"amount": 100000, "status": "SETTLED"}', 'PENDING', NOW());    |
+-------------------------------------------------------------------------------+
                                    |
                                    v (Committed to Storage)
                      [ Table: outbox_events ]
                                    |
               +--------------------+--------------------+
               | (Metode A)                              | (Metode B)
               v                                         v
   [ Polling Publisher Worker ]           [ Change Data Capture (CDC) ]
   (SELECT ... FOR UPDATE SKIP LOCKED)    (Debezium Engine via Postgres WAL)
               |                                         |
               +--------------------+--------------------+
                                    |
                                    v
                     +------------------------------+
                     | Distributed Event Broker     |
                     | (Kafka / Redis Streams / NATS)|
                     +------------------------------+
```

### 2.3 Implementasi Publisher: Polling vs Change Data Capture (CDC)

#### Metode A: Polling Publisher dengan `SKIP LOCKED`
Menggunakan kueri periodik dengan baris terkunci tanpa memblokir pembacaan lain:

```sql
-- Dijalankan oleh Outbox Worker setiap 100 - 500 ms
BEGIN;
SELECT id, topic, payload 
FROM outbox_events 
WHERE status = 'PENDING' 
ORDER BY created_at ASC 
LIMIT 100 
FOR UPDATE SKIP LOCKED;

-- Setelah pesan sukses di-publish ke broker:
DELETE FROM outbox_events WHERE id IN (:processed_ids);
-- Atau diubah statusnya menjadi 'PROCESSED'
COMMIT;
```
- **Kelebihan**: Sangat mudah diimplementasikan, tidak memerlukan infrastruktur tambahan.
- **Kekurangan**: Menghasilkan *read polling overhead* pada basis data jika frekuensi penarikan data terlalu rapat.

#### Metode B: Change Data Capture (Debezium + Postgres WAL)
Debezium membaca langsung berkas *Write-Ahead Log* (WAL) dari PostgreSQL melalui *logical decoding plugin* (`pgoutput`).
- **Kelebihan**: Latensi sub-detik (hampir *real-time*), nol dampak kueri polling pada basis data operasional.
- **Kekurangan**: Kompleksitas infrastruktur meningkat (membutuhkan Kafka Connect cluster, manajemen *slot replication*).

---

## 3. Idempotensi Konsumen (*Consumer Idempotency*)

Dalam jaringan terdistribusi, pengiriman pesan hanya dapat menjamin *at-least-once delivery*. Jaringan putus saat konsumen mengirimkan pengakuan (*ACK*) akan menyebabkan broker mengirim ulang pesan yang sama.

### 3.1 Skema Tabel Idempotency Consumer

Konsumen wajib memeriksa dan mencatat kunci unik pesan sebelum mengeksekusi logika mutasi finansial:

```sql
CREATE TABLE processed_messages (
    message_id VARCHAR(128) PRIMARY KEY,
    consumer_group VARCHAR(64) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    response_payload JSONB NULL
);

CREATE INDEX idx_processed_messages_group 
ON processed_messages (consumer_group, processed_at);
```

### 3.2 Pola Eksekusi Atomik Konsumen

```
               [ Pesan Diterima: Msg_ID = "evt_999" ]
                                  |
                                  v
+-------------------------------------------------------------------+
| Mulai Transaksi Basis Data Lokal (BEGIN)                          |
|                                                                   |
| 1. INSERT INTO processed_messages (message_id, consumer_group)    |
|    VALUES ('evt_999', 'ledger-worker')                            |
|    ON CONFLICT (message_id) DO NOTHING;                           |
|                                                                   |
| 2. Periksa jumlah baris yang terdampak:                           |
|    - Jika 0 baris: Pesan sudah pernah diproses (DUPLIKAT).        |
|      -> ROLLBACK & Kirim ACK ke Broker langsung. Selesai.         |
|    - Jika 1 baris: Pesan valid (BARU).                            |
|      -> Lanjut ke langkah 3.                                      |
|                                                                   |
| 3. Eksekusi mutasi saldo / posting ledger.                        |
| 4. COMMIT.                                                        |
+-------------------------------------------------------------------+
                                  |
                                  v
                  [ Kirim ACK Sukses ke Broker ]
```

---

## 4. Kunci Terdistribusi (*Distributed Locking*) dan Redlock

Saat beberapa *worker* bersaing untuk mengubah status entitas yang sama dari berbagai sumber (misalnya webhook bank dan polling status berjalan bersamaan), *distributed lock* diperlukan untuk mencegah *race condition*.

### 4.1 Algoritma Distributed Lock Berbasis Redis

Untuk instans Redis tunggal atau arsitektur primer-replika:

```
Acquire Lock:
SET lock:merchant:12345 <unique_worker_uuid> NX PX 10000

Keterangan:
- NX: Hanya buat kunci jika belum ada.
- PX 10000: Batas kadaluarsa otomatis 10 detik (mencegah deadlock jika worker mati mendadak).
- unique_worker_uuid: Pengenal unik proses untuk mencegah penghapusan kunci milik worker lain.
```

Pelepasan kunci wajib menggunakan skrip Lua atomik:

```lua
-- Release Lock Script
if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
else
    return 0
end
```

### 4.2 Bahaya Redlock pada Sistem Finansial Kritis
Algoritma Redlock (mengunci ke mayoritas node Redis terpisah) memiliki kelemahan mendasar jika sistem mengalami *stop-the-world GC pause* atau *clock drift*:
1. Worker A memperoleh *lock* pada 3 dari 5 node.
2. Worker A mengalami jeda komputasi panjang (*pause* memori / GC).
3. Batas waktu sewa (*lease time*) kunci habis di Redis.
4. Worker B berhasil memperoleh *lock* untuk entitas yang sama.
5. Worker A terbangun dari jeda dan mengeksekusi mutasi, mengakibatkan dua proses mengeksekusi operasi kritis secara bersamaan (*split-brain mutation*).

**Mitigasi**: Gunakan *Fencing Token* (angka yang selalu naik secara monotonik) di tingkat basis data untuk menolak instruksi dari pemegang *lock* kedaluwarsa.

---

## 5. Dead Letter Queue (DLQ) dan Penanganan Kesalahan Terdistribusi

### 5.1 Siklus Hidup Pesan Gagal

Pesan tidak boleh dibuang jika terjadi kesalahan. Kesalahan harus diklasifikasikan menjadi dua jenis:
1. **Transient Error** (Kesalahan Sementara): Koneksi basis data terputus sesaat, *network timeout* ke API bank.
   - *Tindakan*: *Retry* terencana dengan jeda waktu eksponensial (*Exponential Backoff with Jitter*).
2. **Permanent Error** (Kesalahan Permanen): Format JSON rusak, validasi data gagal, akun merchant dibekukan permanen.
   - *Tindakan*: Segera alihkan pesan ke *Dead Letter Queue* (DLQ) tanpa *retry* tanpa akhir.

```
[ Pesan Masuk ]
       |
       v
[ Consumer Worker ] ---> (Sukses) ---> [ ACK ke Broker ]
       |
    (Gagal)
       |
       v
[ Evaluasi Batas Retry ]
   |-- (Belum Capai Batas: Retry Count < 5) 
   |      --> Jeda Waktu (Backoff) --> Masukkan ke [ Retry Queue ]
   |
   +-- (Capai Batas Max: Retry Count >= 5 ATAU Fatal Error)
          --> Tambahkan Metadata Error
          --> Masukkan ke [ Dead Letter Queue (DLQ) ]
          --> Kirim Notifikasi PagerDuty / Sentry ke Tim Operasional
```

### 5.2 Header Metadata pada DLQ
Pesan yang dialihkan ke DLQ wajib dilengkapi atribut diagnosis:
- `x-original-topic`: Nama topik asal.
- `x-failure-reason`: Teks pesan kesalahan atau *stack trace*.
- `x-retry-count`: Jumlah percobaan yang telah dilakukan.
- `x-failed-at`: Cap waktu saat kegagalan terakhir terjadi.

---

## 6. Evolusi Skema Pesan (*Schema Evolution*)

Perubahan struktur data event di masa depan tidak boleh merusak sistem konsumen lama yang masih aktif (*forward & backward compatibility*).

### 6.1 Protobuf / Avro dengan Skema Registri

Penggunaan JSON polos tanpa validasi skema pada skala menengah ke atas sering menimbulkan *runtime crash* akibat perubahan tipe data atau penghapusan kolom secara sepihak.

```protobuf
// Contoh Skema Protobuf untuk Event Transaksi
syntax = "proto3";

package tamaku.payment.v1;

message PaymentSettledEvent {
  string transaction_id = 1;
  int64 amount = 2; // Representasi satuan terkecil (sen/rupiah)
  string currency = 3;
  string merchant_id = 4;
  int64 settled_timestamp = 5;
  
  // Penambahan atribut baru wajib menggunakan tag angka baru:
  string settlement_channel = 6; 
}
```

### 6.2 Aturan Baku Kompatibilitas Skema
1. **Dilarang Mengubah Nomor Tag**: Pada Protobuf, pengenal biner berbasis angka tag (`1, 2, 3...`), bukan nama kolom. Mengubah tag merusak deserialisasi data historis.
2. **Aturan Backward Compatibility**: Konsumen baru dengan skema baru harus dapat membaca data yang diterbitkan oleh produsen lama (nilai baru diberi nilai bawaan/default).
3. **Aturan Forward Compatibility**: Konsumen lama dengan skema lama harus dapat membaca data dari produsen baru tanpa mengalami *crash* (mengabaikan kolom baru yang belum dikenali).
