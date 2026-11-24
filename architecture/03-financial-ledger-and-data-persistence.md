# Arsitektur Financial Ledger, Pembukuan Double-Entry, dan Persistensi Data

Dokumen ini menguraikan perancangan sistem pembukuan berpasangan (*double-entry bookkeeping*), penegakan invarian matematika nol-selisih (*zero-sum balance*), evaluasi basis data relasional terpartisi versus mesin *ledger* terdedikasi, serta teknik isolasi konkurensi untuk mencegah *deadlock* dan inkonsistensi saldo.

---

## 1. Arsitektur Double-Entry Bookkeeping: Fondasi Kebenaran Finansial

Dalam sistem keuangan berstandar industri, perubahan saldo tidak boleh dilakukan melalui perintah mutasi langsung (`UPDATE balance = balance + X`). Pendekatan mutasi langsung memusnahkan riwayat audit (*audit trail*), rentan terhadap *race condition*, dan mustahil direkonstruksi saat terjadi selisih kas.

Seluruh aliran dana wajib dicatat sebagai transaksi berpasangan yang terdiri dari minimal dua entri pembukuan (*postings*) yang saling menyeimbangkan: **Total Debit harus selalu sama dengan Total Kredit** ($\sum \text{Debit} = \sum \text{Kredit}$).

```
                             [ TRANSAKSI PEMBAYARAN: Rp 100.000 ]
                                              |
                                              v
                              +-------------------------------+
                              |      Journal Entry (Header)   |
                              |  ID: jrn_01HQ...              |
                              |  Type: PAYMENT_CAPTURE        |
                              +-------------------------------+
                                     /                 \
                                    /                   \
        +--------------------------+                     +---------------------------+
        | Posting 1 (DEBIT)        |                     | Posting 2 (KREDIT)        |
        | Account: BCA Cash Inflow |                     | Account: Merchant Balance |
        | Amount: Rp 100.000       |                     | Amount: Rp 100.000        |
        +--------------------------+                     +---------------------------+
                                    \                   /
                                     \                 /
                              +-------------------------------+
                              |    Verifikasi Zero-Sum:       |
                              |    Debit - Kredit = 0         |
                              +-------------------------------+
```

### 1.1 Persamaan Akuntansi Dasar

Pada akuntansi standar:
$$\text{Aset} + \text{Beban} = \text{Liabilitas} + \text{Ekuitas} + \text{Pendapatan}$$

- **Debit**: Menambah Aset/Beban, mengurangi Liabilitas/Ekuitas/Pendapatan.
- **Kredit**: Menambah Liabilitas/Ekuitas/Pendapatan, mengurangi Aset/Beban.

Bagi Payment Gateway:
- **Akun Kas Bank (Kas Masuk)**: Aset Tamaku (Debit bertambah saat uang masuk dari pelanggan).
- **Akun Saldo Merchant**: Liabilitas Tamaku (Kredit bertambah karena kewajiban membayar merchant di kemudian hari).
- **Akun Biaya Layanan (*MDR / Fee*)**: Pendapatan Tamaku (Kredit bertambah dari pemotongan komisi).

### 1.2 Skema Tabel PostgreSQL: `accounts`, `journals`, dan `postings`

Penerapan skema basis data relasional dengan aturan integritas ketat (*foreign key constraints* dan *check constraints*):

```sql
-- 1. Klasifikasi Tipe Akun
CREATE TYPE account_type AS ENUM (
    'ASSET',
    'LIABILITY',
    'EQUITY',
    'REVENUE',
    'EXPENSE'
);

-- 2. Master Akun Pembukuan
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(64) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    type account_type NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'IDR',
    merchant_id UUID NULL, -- NULL jika akun internal sistem
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Jurnal Transaksi (Header Dokumen)
CREATE TABLE journals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_id VARCHAR(128) UNIQUE NOT NULL, -- ID transaksi eksternal
    event_type VARCHAR(64) NOT NULL,           -- e.g., 'PAYMENT_SETTLED', 'FEE_DEDUCTION'
    description TEXT NOT NULL,
    posted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Detail Postings (Baris Mutasi Debit & Kredit)
CREATE TABLE postings (
    id BIGSERIAL PRIMARY KEY,
    journal_id UUID NOT NULL REFERENCES journals(id) ON DELETE RESTRICT,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    amount BIGINT NOT NULL, -- Satuan terkecil (sen/rupiah utuh), DILARANG FLOAT
    direction VARCHAR(6) NOT NULL CHECK (direction IN ('DEBIT', 'CREDIT')),
    sequence INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_journal_sequence UNIQUE (journal_id, sequence)
);

CREATE INDEX idx_postings_account_created ON postings (account_id, created_at DESC);
```

### 1.3 Penegakan Invarian Matematika Zero-Sum di Tingkat Basis Data

Untuk memastikan bahwa transaksi cacat tidak pernah berhasil tersimpan, validasi dapat dipaksakan menggunakan *trigger* basis data sebelum transaksi di-*commit*:

```sql
CREATE OR REPLACE FUNCTION verify_journal_zero_sum() 
RETURNS TRIGGER AS $$
DECLARE
    v_debit_sum BIGINT;
    v_credit_sum BIGINT;
BEGIN
    SELECT 
        COALESCE(SUM(CASE WHEN direction = 'DEBIT' THEN amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount ELSE 0 END), 0)
    INTO v_debit_sum, v_credit_sum
    FROM postings
    WHERE journal_id = NEW.journal_id;

    IF v_debit_sum <> v_credit_sum THEN
        RAISE EXCEPTION 'INVARIANT_VIOLATION: Journal % tidak seimbang. Total Debit (%) != Total Kredit (%)', 
            NEW.journal_id, v_debit_sum, v_credit_sum;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger dijalankan pada akhir transaksi (DEFERRABLE INITIALLY DEFERRED)
CREATE CONSTRAINT TRIGGER trg_verify_journal_balance
AFTER INSERT OR UPDATE ON postings
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION verify_journal_zero_sum();
```

---

## 2. Komparasi Mesin Ledger: PostgreSQL Terpartisi vs TigerBeetle vs Formance

| Fitur / Parameter | PostgreSQL Terpartisi | TigerBeetle | Formance Ledger (Numscript) |
| :--- | :--- | :--- | :--- |
| **Arsitektur Utama** | RDBMS Serbaguna, Skema Relasional | Khusus Financial Accounting (Zig), Distributed State Machine | Ledger Engine berbasis Open Source (Go) dengan DSL Numscript |
| **Throughput Mutasi** | 2.000 - 8.000 postings/detik | 500.000 - 1.000.000+ postings/detik | 5.000 - 15.000 postings/detik |
| **Penyimpanan Nilai Uang** | `BIGINT` atau `NUMERIC(20,4)` | `uint128` bawaan | `BigInt` / Arbitrary Precision |
| **Konsistensi & Replikasi** | Streaming Replication / Raft (Patroni) | Viewstamped Replication (VSR) dengan proteksi disk corruption | Bergantung pada basis data dasar (PostgreSQL backend) |
| **Ekosistem & Kemudahan** | Sangat Matang, ribuan tool audit & pelaporan | Khusus (*niche*), API via TCP socket kustom | Matang untuk fintech, ekosistem UI & SDK lengkap |
| **Model Biaya Infrastruktur** | Terintegrasi dengan DB operasional yang ada | Butuh node khusus berkinerja tinggi | Dapat di-host mandiri di atas cloud VPS |

### Rekomendasi Pemilihan:
- **0 s.d. 10.000 Transaksi Harian**: Gunakan **PostgreSQL Terpartisi**. Menghindari kompleksitas operasional memelihara dua kluster basis data terpisah.
- **Skala Jutaan Transaksi Harian (Enterprise High-Frequency)**: Gunakan **TigerBeetle** sebagai mesin penyimpan saldo inti (*balance engine*), dengan PostgreSQL sebagai tempat penyimpanan metadata relasional merchant.

---

## 3. Isolasi Transaksi, Row-Level Locking, dan Mitigasi Deadlock

Tantangan terbesar sistem pembayaran berskala tinggi adalah perebutan kunci (*lock contention*) pada baris saldo akun utama.

### 3.1 Skenario Terjadinya Deadlock pada Mutasi Paralel

Bayangkan dua transaksi transfer terjadi secara simultan antara Akun A dan Akun B:
- **Transaksi 1 (Kirim dana dari A ke B)**: Mengunci Akun A lebih dulu, lalu mencoba mengunci Akun B.
- **Transaksi 2 (Kirim dana dari B ke A)**: Mengunci Akun B lebih dulu, lalu mencoba mengunci Akun A.

```
Waktu    Transaksi 1                    Transaksi 2
-------------------------------------------------------------------------
T1       SELECT FOR UPDATE Akun A (Berhasil)  
T2                                      SELECT FOR UPDATE Akun B (Berhasil)
T3       SELECT FOR UPDATE Akun B (TERBLOCK)
T4                                      SELECT FOR UPDATE Akun A (DEADLOCK!)
```

Basis data PostgreSQL akan membatalkan salah satu transaksi dengan pesan kesalahan: `ERROR: deadlock detected`.

### 3.2 Solusi Baku: Deterministic Row Ordering (Pengurutan ID Kunci)

Untuk meniadakan risiko *deadlock* selamanya, seluruh transaksi yang membutuhkan penguncian baris akun ganda **wajib mengurutkan penguncian berdasarkan urutan deterministik** (misalnya alfabetis ID akun):

```go
// Pola Aplikasi: Pengurutan Kunci Akun Sebelum Mengunci
func LockAccountsDeterministically(ctx context.Context, tx *sql.Tx, accountID1, accountID2 string) error {
    firstID := accountID1
    secondID := accountID2
    
    // Urutkan leksikografis
    if firstID > secondID {
        firstID, secondID = secondID, firstID
    }

    // Kunci baris pertama
    _, err := tx.ExecContext(ctx, "SELECT id FROM accounts WHERE id = $1 FOR UPDATE", firstID)
    if err != nil {
        return err
    }

    // Kunci baris kedua
    _, err = tx.ExecContext(ctx, "SELECT id FROM accounts WHERE id = $2 FOR UPDATE", secondID)
    return err
}
```

Dengan mengunci akun secara berurutan, siklus penguncian tertutup (*circular wait condition*) tidak akan pernah dapat terbentuk.

---

## 4. Partisi Tabel Berbasis Rentang Waktu (*Range Partitioning*)

Tabel `postings` dan `journals` akan membengkak hingga puluhan juta baris dalam hitungan bulan. Kueri audit akan melambat drastis jika indeks berada di atas satu tabel raksasa (*bloated B-Tree index*).

### 4.1 Deklarasi Partisi Bulanan PostgreSQL

```sql
-- Membuat Master Table dengan Partisi Berdasarkan Waktu
CREATE TABLE journals_partitioned (
    id UUID NOT NULL,
    reference_id VARCHAR(128) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    description TEXT NOT NULL,
    posted_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (id, posted_at)
) PARTITION BY RANGE (posted_at);

-- Partisi Bulan Berjalan (Contoh: April 2025)
CREATE TABLE journals_y2025m04 PARTITION OF journals_partitioned
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');

-- Partisi Bulan Berikutnya (Contoh: Mei 2025)
CREATE TABLE journals_y2025m05 PARTITION OF journals_partitioned
    FOR VALUES FROM ('2025-05-01 00:00:00+00') TO ('2025-06-01 00:00:00+00');
```

- **Keuntungan**:
  1. *Partition Pruning*: Kueri dengan filter tanggal tertentu hanya memindai berkas tabel partisi yang relevan, memangkas penggunaan I/O disk hingga 90%.
  2. *Cold Data Archival*: Partisi data lama (misalnya data lebih dari 2 tahun) dapat dipindahkan ke penyimpanan *object storage* (S3) atau *compressed storage engine* tanpa mengganggu operasional sistem aktif.

---

## 5. Menghitung Saldo Real-Time: Snapshot vs Full Ledger Replay

Melakukan perhitungan saldo dengan menjumlahkan seluruh mutasi dari awal waktu (`SUM(amount) FROM postings`) akan melumpuhkan performa ketika jumlah transaksi akun mencapai jutaan baris.

### 5.1 Arsitektur Periodic Snapshot + Forward Roll

```
[ Snapshot Terakhir ] ---------------------> Saldo Tersimpan: Rp 50.000.000
(Tgl 30 April, 23:59:59)                     (Tercatat di tabel account_snapshots)
                                              |
                                              v (Ditambah mutasi berjalan)
[ Mutasi Baru (Postings) ] ----------------> + Rp 200.000 (Posting #101)
(1 Mei 00:00 s.d. Sekarang)                  - Rp 50.000  (Posting #102)
                                              = Saldo Real-Time: Rp 50.150.000
```

1. **Tabel Snapshot Periodik**: Tabel terpisah menyimpan saldo akhir terkomputasi setiap pergantian hari.
2. **Kueri Saldo Cepat**:
   ```sql
   SELECT 
       s.balance + COALESCE(SUM(
           CASE WHEN p.direction = 'CREDIT' THEN p.amount ELSE -p.amount END
       ), 0) AS current_balance
   FROM account_snapshots s
   LEFT JOIN postings p ON p.account_id = s.account_id 
       AND p.created_at > s.snapshot_date
   WHERE s.account_id = :account_id
     AND s.snapshot_date = (
         SELECT MAX(snapshot_date) FROM account_snapshots WHERE account_id = :account_id
     )
   GROUP BY s.balance;
   ```
   Kueri hanya perlu menjumlahkan mutasi beberapa jam atau hari terakhir, menjaga latensi kueri saldo merchant tetap berada di bawah 2 milidetik.
