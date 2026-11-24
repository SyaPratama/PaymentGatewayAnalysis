# Ketersediaan Tinggi, Manajemen Lalu Lintas, dan Ketahanan Sistem

Dokumen ini mengkaji topologi ketersediaan tinggi (*High Availability / HA*), strategi pemulihan bencana (*Disaster Recovery / DR*), algoritma pembatasan laju (*Rate Limiting*), mitigasi kelebihan beban (*Overload Protection*), serta isolasi kegagalan perbankan melalui *Circuit Breaker*.

---

## 1. Topologi Ketersediaan Tinggi dan Strategi Pemulihan Bencana

Payment gateway beroperasi di bawah mandat kepatuhan finansial dengan target ketersediaan 99.99% (maksimal *downtime* 52,6 menit per tahun).

```
                            [ Klien Merchant / Pembeli ]
                                         |
                                         v
                         +-------------------------------+
                         | Global Anycast DNS / CDN      |
                         | (Cloudflare Enterprise / AWS) |
                         +-------------------------------+
                                  /             \
                   (Primary Active)             (Secondary Standby)
                                /                 \
  +-------------------------------+             +-------------------------------+
  | REGION JAKARTA (Active DC)    |             | REGION SURABAYA (Standby DC)  |
  |                               |             |                               |
  |  [ Edge Envoy Proxy / LB ]    |             |  [ Edge Envoy Proxy / LB ]    |
  |              |                |             |              |                |
  |  [ Core Payment Services ]    |             |  [ Core Payment Services ]    |
  |              |                |             |              |                |
  |  [ Primary PostgreSQL ]       |             |  [ Standby PostgreSQL ]       |
  +-------------------------------+             +-------------------------------+
                 |                                             ^
                 |====== Synchronous / Semi-Sync Streaming ====|
                 |====== Replication (Patroni / Raft) =========|
```

### 1.1 Active-Passive (Hot Standby) vs Active-Active Multi-Region

| Dimensi | Active-Passive (Hot Standby) | Active-Active Multi-Region |
| :--- | :--- | :--- |
| **Model Replikasi DB** | Satu Primer (Write/Read), Replika Siaga (Read-only) | Multi-Primary (CockroachDB / Spanner) atau Partisi Regional |
| **Konsistensi Data** | Konsistensi Kuat (Linearizable ACID di Primer) | Konsistensi Terdistribusi (Konsensus Raft/Paxos lintas region) |
| **Latensi Write** | Sangat Rendah (< 1 ms lokal di DC utama) | Tinggi (15 - 40 ms karena RTT jaringan lintas pulau) |
| **Risiko Split-Brain** | Rendah (Dikelola dengan quorum failover terpusat) | Sangat Tinggi jika koneksi antar-pulau terputus |
| **Kompleksitas Biaya** | Moderat (Infrastruktur cadangan 1:1) | Sangat Mahal (Minimal 3 Region untuk quorum) |

**Rekomendasi Tamaku**:
Gunakan **Active-Passive (Hot Standby) dengan Patroni**. Pada sistem finansial yang memerlukan kepatuhan regulasi Bank Indonesia, latensi *write* transaksi harus sekecil mungkin dan bebas dari anomali *write-skew*. Active-Active lintas pulau di Indonesia menimbulkan latensi jaringan antar-datacenter (misalnya Jakarta-Surabaya 12-18 ms RTT) yang membebani setiap *commit* transaksi.

### 1.2 Target RPO dan RTO Finansial

- **Recovery Point Objective (RPO = 0)**:
  - *Makna*: Tidak ada data transaksi yang boleh hilang akibat kegagalan perangkat keras (*zero data loss*).
  - *Implementasi*: Menggunakan PostgreSQL *Synchronous Replication* (`synchronous_commit = on` atau `remote_write`) dengan minimal satu replika siaga lokal.
- **Recovery Time Objective (RTO < 60 Detik)**:
  - *Makna*: Waktu pemulihan saat server primer padam hingga server cadangan mengambil alih lalu lintas transaksi tidak boleh melebihi 60 detik.
  - *Implementasi*: Kluster *Patroni* berbasis konsensus distributed configuration store (DCS) seperti *etcd*. *Health-check agent* mendeteksi matinya primer dalam 5-10 detik dan mempromosikan standby menjadi primer secara otomatis.

---

## 2. Algoritma Rate Limiting di Lapisan Gateway Edge

Serangan DDoS, skrip *credential stuffing*, atau kesalahan *infinite loop* pada sistem merchant dapat membanjiri gateway pembayaran. Pembatasan laju (*rate limiting*) diterapkan secara berlapis.

### 2.1 Perbandingan Algoritma Pembatasan

```
1. Token Bucket:
   Kapasitas: B token. Token ditambahkan secara konstan (r token/detik).
   Bisa menangani lonjakan sesaat (burst) selama token masih ada.

2. Leaky Bucket:
   Lalu lintas masuk ditampung di ember berkapasitas tetap, dikeluarkan dengan laju konstan.
   Menghaluskan lonjakan (traffic smoothing), tidak mendukung burst.

3. Sliding Window Counter:
   Membagi waktu ke dalam sub-jendela halus. Menghitung jumlah panggilan 
   pada jendela berjalan untuk akurasi tinggi tanpa lonjakan di batas detik.
```

| Algoritma | Toleransi Lonjakan (*Burst*) | Kebutuhan Memori | Kelemahan Utama |
| :--- | :--- | :--- | :--- |
| **Token Bucket** | Ya (Sangat baik) | Rendah (1 angka counter + 1 timestamp) | Perlu sinkronisasi waktu akurat |
| **Leaky Bucket** | Tidak (Dipaksa konstan) | Sedang (Perlu antrean request) | Menolak request valid saat burst wajar |
| **Sliding Window Counter**| Ya | Moderat (Simpan sub-jendela counter) | Agak kompleks dalam skrip Redis |

### 2.2 Implementasi Sliding Window Counter dengan Redis Lua Script

Pola atomik untuk membatasi pemanggilan API Merchant per menit:

```lua
-- KEYS[1]: Identitas pembatasan (e.g., "ratelimit:merchant:mch_123:minute")
-- ARGV[1]: Cap waktu saat ini dalam milidetik
-- ARGV[2]: Ukuran jendela dalam milidetik (misal 60000 untuk 1 menit)
-- ARGV[3]: Kuota maksimum per jendela (misal 1000 request)

local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])
local clear_before = now - window

-- 1. Bersihkan request di luar jendela waktu
redis.call('ZREMRANGEBYSCORE', key, 0, clear_before)

-- 2. Hitung jumlah request tersisa di jendela saat ini
local current_requests = redis.call('ZCARD', key)

if current_requests < limit then
    -- Tambahkan entri request saat ini
    redis.call('ZADD', key, now, now)
    -- Pasang TTL agar memori otomatis bersih
    redis.call('PEXPIRE', key, window)
    return 1 -- DIIZINKAN (HTTP 200)
else
    return 0 -- DITOLAK (HTTP 429 Too Many Requests)
end
```

---

## 3. Perlindungan Kelebihan Beban: Load Shedding dan Graceful Degradation

Saat beban lalu lintas melebihi kapasitas komputasi CPU dan basis data, sistem pembayaran yang buruk akan mengalami *cascading failure* (semua request melambat, antrean menumpuk, server kehabisan memori dan mati).

### 3.1 Load Shedding Berbasis Antrean dan Latensi

*Load Shedding* secara proaktif menolak request non-kritis sebelum CPU server mencapai 100%.

```
[ Request Masuk ]
        |
        v
+---------------------------------------------------------------+
| Adaptive Concurrency Limiter (Little's Law Engine)            |
| Memantau: Latensi P99 & Waktu Antrean CPU                     |
+---------------------------------------------------------------+
        |
        +---> Apakah sistem kelebihan beban? (Latensi > 500 ms)
        |        |
        |        +--> YA: Tolak request non-esensial (HTTP 503)
        |                 (Prioritas Rendah: Laporan CSV, Webhook Query)
        |
        v TIDAK
+---------------------------------------------------------------+
| Eksekusi Transaksi Finansial Kritis (Penerimaan Pembayaran)   |
+---------------------------------------------------------------+
```

### 3.2 Tingkatan Prioritas Permintaan (*Request Priority Hierarchy*)

1. **Prioritas 1 (Kritis / Non-Negotiable)**: Webhook Callback dari Bank (SNAP BI, QRIS) dan *Payment Status Check*. Kegagalan pada lapisan ini mengakibatkan status transaksi menggantung (*pending timeout*).
2. **Prioritas 2 (Tinggi)**: API Pembayaran Masuk dari Merchant (`POST /v1/payments`).
3. **Prioritas 3 (Sedang)**: Penarikan Dana Merchant (*Payout / Disbursement Request*).
4. **Prioritas 4 (Rendah / Dapat Dikorbankan)**: Pengunduhan laporan settlement bulanan, pencarian mutasi lama di Dashboard Merchant.

---

## 4. Circuit Breaker dan Penanganan Gangguan Bank Upstream

Konektivitas ke bank sering kali mengalami penurunan performa mendadak: waktu respons melonjak dari 500 ms menjadi 30 detik tanpa mengembalikan *error response* definitif. Hal ini menyebabkan *thread pool* payment gateway habis tertahan (*thread starvation*).

### 4.1 State Machine Circuit Breaker

```
               +--------------------------------------+
               |               CLOSED                 |
               | (Normal: Permintaan dialirkan terus) |
               +--------------------------------------+
                 |                                  ^
     Tingkat Kegagalan > 50%                        | Reset Timeout Tercapai
     (Threshold Terlampaui)                         | & Pengujian Berhasil
                 v                                  |
               +--------------------------------------+
               |                OPEN                  |
               | (Blokir total: Tolak instan HTTP 503)|
               +--------------------------------------+
                 |                                  ^
     Durasi Istirahat Selesai                       | Pengujian Gagal
     (e.g., 30 Detik Berakhir)                      |
                 v                                  |
               +--------------------------------------+
               |              HALF-OPEN               |
               | (Uji coba: Lewatkan 5 request acak)  |
               +--------------------------------------+
```

### 4.2 Parameter Operasional Circuit Breaker Fintech

- **Minimum Request Volume**: 20 request per jendela 10 detik (mencegah pemicuan *false-positive* pada lalu lintas rendah).
- **Error Threshold Percentage**: 50% (jika 10 dari 20 request gagal atau mengalami *timeout* > 5 detik, sirkuit langsung beralih ke status `OPEN`).
- **Sleep Window (Durasi Isolasi)**: 30 detik. Selama periode ini, permintaan ke bank tersebut langsung dibelokkan (*fail-fast*) ke kanal bank cadangan (*smart routing fallback*).
- **Graceful Fallback**: Jika BCA VA *down*, gateway secara cerdas menyarankan merchant/klien untuk mengalihkan rute ke Mandiri VA atau QRIS tanpa memunculkan layar galat teknis pada pelanggan akhir.
