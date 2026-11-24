# Blueprint Arsitektur: Membangun Multi-Channel Payment Gateway yang Jauh Lebih Murah

> **Tujuan**: Menghilangkan margin perantara ganda (double-hop margin), memangkas biaya komputasi server hingga >70%, menghilangkan keterbatasan kode unik, dan meningkatkan keandalan transaksi melalui smart multi-routing.

---

## 1. Analisis Struktur Biaya: Solosmartpay vs Arsitektur Lean

| Kanal Pembayaran | Biaya Merchant Solosmartpay Saat Ini | Biaya Modal (COGS) Tier-1 Direct | Penghematan per Transaksi |
|---|---|---|---|
| **Bank Virtual Account (BCA, Mandiri, BRI, BNI)** | Rp 3.300 – Rp 4.300 / trx | Rp 1.500 – Rp 2.200 / trx (via SNAP BI / Direct Tier-1) | **Hemat Rp 1.100 – Rp 2.100 per trx (~40–50%)** |
| **Virtual Account Second-tier (Sampoerna, Artha Graha)** | Rp 1.800 / trx | Rp 800 – Rp 1.000 / trx | **Hemat Rp 800 – Rp 1.000 per trx (~45%)** |
| **QRIS Dinamis (≤ Rp 500.000)** | Rp 300 flat + kode unik | 0% – 0.3% MDR resmi BI (tanpa kode unik) | **Nol risiko gagal bayar kode unik; 0% untuk Usaha Mikro** |
| **QRIS Dinamis (> Rp 500.000)** | 0.5% (0.3% switching + 0.2% markup) | 0.3% – 0.4% MDR resmi | **Hemat 0.1% – 0.2% volume total** |
| **E-Wallet (ShopeePay, OVO)** | 3.28% – 4.25% | 1.5% – 2.0% (Direct Aggregator Contract) | **Hemat > 50% biaya MDR e-wallet** |
| **Disbursement / Penarikan Bank** | Rp 2.500 / penarikan | Rp 500 – Rp 1.000 (BI-FAST via API SNAP) | **Hemat Rp 1.500 – Rp 2.000 per penarikan (~60–80%)** |

---

## 2. Lima Pilar Arsitektur Gateway Hemat Biaya

```
                 [ Merchant / Frontend Store / SDK ]
                                |
                    HTTPS / JSON RESTful API
                                v
               +----------------------------------+
               |   Edge Layer: Cloudflare Workers |  <- Webhook validation &
               |   - Rate Limiting (Token Bucket) |     signature verification
               |   - DDoS & SSL Termination       |     (Zero server compute cost)
               +----------------------------------+
                                |
                                v
               +----------------------------------+
               |     Core Gateway Orchestrator    |
               |     (Go / Rust / Swoole-PHP)     |  <- Sub-millisecond routing
               |  - Idempotency & Order Manager   |  <- Direct Synchronous Creation
               |  - Multi-Provider Smart Router   |     (No 202 polling loop)
               +----------------------------------+
                     /          |          \
                    /           |           \
                   v            v            v
           [ SNAP BI Direct ]  [ Tier-1 PG ]  [ Native QRIS Acquirer ]
           (BCA, Mandiri, BRI) (Oy! / Winpay) (Nobu / CIMB / Netizen)
                   \            |            /
                    \           |           /
                     v          v          v
               +----------------------------------+
               |     Immutable Ledger & Events    |
               |  - Double-Entry Engine (SQL)     |  <- Zero balance drift
               |  - Push Notifications via SSE    |  <- Instant checkout updates
               +----------------------------------+
```

### Pilar 1: Adopsi Standar SNAP BI (Standar Nasional Open API Pembayaran)
*Bank Indonesia telah mewajibkan seluruh perbankan menggunakan format SNAP BI.*
- **Keuntungan**:
  - Satu format request terstandarisasi untuk BCA, Bank Mandiri, BRI, BNI, dan Permata.
  - Menghilangkan vendor-lockin ke format kepemilikan (seperti format Duitku atau Tripay).
  - Bisa beralih ke channel bank direct kapan saja tanpa mengubah kontrak API merchant.
- **Biaya**: Menggunakan BI-FAST direct API untuk disbursement memangkas biaya transfer antar-bank dari Rp 2.500 menjadi **Rp 500 – Rp 1.000**.

### Pilar 2: Native Dynamic QRIS (Menghilangkan Kode Unik & Scraper Mutasi)
Solosmartpay menggunakan kode unik 1–999 untuk mencocokkan mutasi rekening/QRIS statis. Pola ini rapuh, membatasi volume transaksi bersamaan, dan sering gagal jika pelanggan lupa menyertakan kode unik.
- **Solusi**: Integrasikan langsung ke **Acquirer QRIS berizin BI** (misal: Nobu Bank, CIMB Niaga, atau Finnet) via API EMVCo Dynamic QRIS.
- **Mekanisme**:
  - API mengembalikan string QRIS EMVCo dengan Tag `54` (Transaction Amount) dan Tag `62` (Reference Label / RRN internal) sudah terkunci.
  - Pelanggan membayar nominal pas (misal: Rp 100.000, bukan Rp 100.007).
  - Acquirer langsung menembak Webhook callback berbasis RRN / invoice ID.
  - MDR untuk Usaha Mikro adalah **0% (transaksi s.d. Rp 100.000)** dan **0.3%** di atasnya sesuai regulasi BI — jauh lebih murah dibanding memelihara server scraper mutasi bank.

### Pilar 3: Menghapus Pola Async Polling (`202 Accepted`) Menjadi Synchronous / Push
Pada Solosmartpay, `POST /v1/payments` mengembalikan status `202 Accepted` dan menuntut klien melakukan polling HTTP setiap 1–2 detik sampai `provisioning_status = ready`.
- **Dampak Buruk Polling**:
  - 1 transaksi membutuhkan 5 hingga 10 request HTTP redundant.
  - Menguras worker PHP-FPM, pool koneksi database, dan bandwidth server.
- **Pola Lebih Murah**:
  1. **Direct Fast-Path (Synchronous)**: Jika upstream API merespons < 800ms, langsung kembalikan respons `200 OK` berisi nomor VA / QR image pada pemanggilan pertama.
  2. **Push Event via Server-Sent Events (SSE) atau WebSocket**: Jika tagihan memerlukan persiapan pihak ketiga, buka 1 koneksi SSE ringan untuk mengabari browser secara realtime saat status berubah, tanpa ratusan HTTP polling.

### Pilar 4: Edge Verification & Serverless Offloading
- Validasi signature HMAC dan anti-replay timestamp dilakukan di **Cloudflare Workers** (biaya gratis s.d. 100.000 request/hari, atau $5/bulan untuk 10 juta request).
- Permintaan tidak valid ditolak di edge sebelum menyentuh server utama (PHP-FPM/MySQL), menghemat kapasitas CPU server hingga >60%.

### Pilar 5: Smart Fallback & Multi-Routing
Jangan pernah bergantung pada 1 aggregator upstream:
- Buat router berbasis tabel konfigurasi:
  - **Route Utama (Primary)**: Provider dengan MDR terendah (misal: Direct Bank SNAP / Tier-1 Wholesale).
  - **Route Cadangan (Secondary)**: Fallback otomatis dalam waktu < 2 detik jika route utama timeout atau maintenance.
  - Konversi transaksi meningkat menjadi > 99.8% tanpa kehilangan pelanggan akibat downtime aggregator tunggal.

---

## 3. Skema Perbandingan Biaya Infrastruktur Bulanan

| Komponen | Setup Solosmartpay Tradisional | Setup Lean Gateway Modern |
|---|---|---|
| **Web Server & App** | Multi-VPS besar (Laravel + Nginx + Redis + Queue Workers) ≈ $80 – $150 / bln | 1x Cloudflare Workers (Edge) + 1x Hetzner/VPS Go/Roadrunner (4 vCPU, 8GB RAM) ≈ $12 – $25 / bln |
| **Realtime Updates** | Commercial Pusher / Dedicated WebSocket Server ≈ $49 / bln | Server-Sent Events (SSE) native atau self-hosted Centrifugo / Reverb ≈ $0 |
| **Database & Ledger** | MySQL RDS dengan locking berat akibat polling ≈ $50 – $100 / bln | PostgreSQL + Partitioned Tables + Redis Cache Lock ≈ $15 – $30 / bln |
| **Scraper Bank Maintenance** | Proxy perumahan, akun bank gantung, maintenance bot mutasi ≈ Rp 500.000 – Rp 1.500.000 / bln | **Rp 0** (Full API resmi via PJP / SNAP BI) |
| **Total Estimasi Biaya Server** | **$180 – $300 / bulan** | **$30 – $55 / bulan** |

---

## 4. Rencana Implementasi Bertahap (Roadmap)

```
[ Fase 1: Optimasi Gateway Wrapper Saat Ini (Quick Wins) ]
  ├── 1. Hapus HTTP Polling: Tambahkan cache pre-generation & instant VA return.
  ├── 2. Gunakan Server-Sent Events (SSE) untuk update checkout popup modal.
  └── 3. Pasang Cloudflare Worker di depan untuk throttle & HMAC validation.

[ Fase 2: Disintermediasi Upstream Channel ]
  ├── 1. Ajukan pendaftaran Direct PJP Tier-1 (misal: Winpay / Oy! / Faspay / Bank Nobu).
  ├── 2. Hubungkan modul QRIS Dinamis Native (menghapus kode unik 1–999).
  └── 3. Implementasikan adapter SNAP BI untuk BCA, Mandiri, BRI, BNI Virtual Account.

[ Fase 3: Smart Routing & Ledger Immutability ]
  ├── 1. Implementasikan failover otomatis antar-provider jika healthcheck gagal.
  ├── 2. Terapkan double-entry accounting ledger agar saldo merchant selalu rekonsil.
  └── 3. Dukung BI-FAST direct batch disbursement untuk penarikan dana instan Rp 1.000.
```
