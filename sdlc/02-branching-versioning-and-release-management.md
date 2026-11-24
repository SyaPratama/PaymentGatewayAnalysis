# Tata Kelola Percabangan Git, Penomoran Versi, dan Migrasi Skema Basis Data

Dokumen ini membandingkan strategi percabangan Git (*Trunk-Based Development vs GitFlow vs GitHub Flow*), menetapkan standar penomoran versi API publik berbasis SemVer 2.0.0, serta merumuskan teknik migrasi skema basis data tanpa *downtime* melalui *Expand and Contract Pattern*.

---

## 1. Analisis Strategi Percabangan Git

Dalam lingkungan rekayasa finansial yang bergerak cepat, strategi pengelolaan cabang (*branching model*) berdampak langsung pada stabilitas kode di produksi.

```
A. GitFlow (Kompleks & Lambat)
[main] --------------------------------------------* (Release v1.0)
          \                                      /
[develop]  \---*--------*--------*--------------* (Pre-release)
                \      /          \            /
[feature]        *----*            *----------* (Merge Hell Risk)

B. Trunk-Based Development (Ramping & Cepat)
[main/trunk] ---*------*-------*-------*-------*-------*---> (Selalu deployable)
                 \    /         \     /
[short-lived]     *--*           *---* (Usia branch < 24 jam)
```

| Parameter Evaluasi | GitFlow | GitHub Flow | Trunk-Based Development (TBD) |
| :--- | :--- | :--- | :--- |
| **Cabang Utama** | Terbelah: `main` dan `develop` | Tunggal: `main` | Tunggal: `main` / `trunk` |
| **Masa Hidup Feature Branch** | Lama (Bisa berminggu-minggu) | Pendek (Beberapa hari) | **Sangat Singkat** (Kurang dari 24 jam) |
| **Risiko Konflik Penggabungan** | Sangat Tinggi (*Merge Hell*) | Sedang | Sangat Rendah |
| **Frekuensi Rilis ke Produksi** | Jarang (Tiap siklus sprint) | Sering (Setelah PR merge) | **Terus-Menerus** (Beberapa kali per hari) |
| **Ketergantungan Feature Flag** | Rendah | Sedang | **Wajib** (Kunci isolasi fungsional) |
| **Kesesuaian Payment Gateway** | Buruk (Memperlambat hotfix) | Cukup | **Sangat Baik (Standar Industri)** |

### 1.1 Mengapa Trunk-Based Development Adalah Standar Emas Fintech Modern
1. **Meniadakan *Merge Hell***: Branch berumur panjang di GitFlow sering kali membuat integrasi kode menjadi momok menakutkan saat ratusan baris konflik harus diselesaikan secara manual. Dalam domain pembayaran, resolusi konflik manual adalah sumber utama masuknya bug logika pemotongan saldo.
2. **Uji Cepat (*Fast Feedback Loop*)**: Perubahan kecil digabungkan ke `main` setiap beberapa jam, memicu eksekusi pengujian regresi menyeluruh secara otomatis di pipeline CI.
3. **Penyebaran Bertahap dengan Feature Flag**: Fungsionalitas integrasi bank baru yang belum selesai dapat digabungkan ke cabang utama tanpa risiko aktif di produksi sebelum saatnya diuji.

---

## 2. Penomoran Versi Semantik (SemVer 2.0.0) dan Kebijakan Deprecasi API

Antarmuka API yang dipublikasikan ke ribuan merchant pihak ketiga membutuhkan garansi stabilitas kontrak yang tidak boleh rusak secara tiba-tiba (*backward compatibility*).

### 2.1 Format SemVer: `MAJOR.MINOR.PATCH`

- **MAJOR (Perubahan yang Merusak Kontrak / Breaking Changes)**:
  - Contoh: Mengubah nama kolom JSON `amount` menjadi `gross_amount`, menghapus endpoint, mewajibkan parameter baru yang sebelumnya opsional.
  - *Aturan*: Mengubah nomor versi pada URL API (`/v1/payments` menjadi `/v2/payments`).
- **MINOR (Penambahan Fitur Baru yang Kompatibel)**:
  - Contoh: Menambahkan metode pembayaran baru pada respons JSON tanpa mengubah kolom lama, menambahkan filter pencarian opsional.
  - *Aturan*: Versi URL tetap sama (`/v1/payments`).
- **PATCH (Perbaikan Bug Tanpa Mengubah Kontrak)**:
  - Contoh: Mengoptimalkan kueri basis data untuk mempercepat latensi transaksi, memperbaiki validasi format nomor rekening internal.

### 2.2 Kebijakan Deprecasi (Deprecation & Sunset Policy)

Menghapus endpoint lama secara tiba-tiba akan merusak integrasi checkout milik merchant. Tamaku menerapkan prosedur bertahap minimal 180 hari:

```
[ Pengumuman Deprecasi ] 
       |
       v (Hari ke-0)
Tambahkan Header HTTP Standar pada Endpoint Versi Lama:
- Deprecation: @1735689600 (Cap waktu Unix waktu pensiun)
- Sunset: Wed, 31 Dec 2025 23:59:59 GMT
- Link: <https://docs.tamaku.id/migration-v2>; rel="deprecation"
       |
       v (Hari ke-1 s.d. 150)
Kirim Email & Notifikasi Otomatis ke Merchant yang Masih Memanggil Endpoint Lama
       |
       v (Hari ke-151 s.d. 179: Brownout Test)
Matikan Endpoint Lama Secara Acak Selama 1 Jam untuk Mengingatkan Merchant
       |
       v (Hari ke-180: Sunset Penuh)
Hapus Kode Endpoint Lama Secara Permanen. Kembalikan HTTP 410 Gone.
```

---

## 3. Migrasi Skema Basis Data Tanpa Downtime: Expand and Contract Pattern

Mengubah skema basis data (misalnya mengubah nama kolom, mengganti tipe data, atau memecah tabel) pada sistem yang aktif memproses ribuan transaksi per detik dilarang keras menggunakan *locking migration* konvensional seperti `ALTER TABLE ... RENAME COLUMN`.

### 3.1 Pola Tiga Fase: Expand, Migrate, Contract

Kasus Nyata: Mengubah kolom `user_phone` menjadi `encrypted_phone` pada tabel `merchants`.

```
Fase 1: EXPAND (Ekspansi Skema Baru)
- Tambahkan kolom baru tanpa menghapus kolom lama:
  ALTER TABLE merchants ADD COLUMN encrypted_phone VARCHAR(255) NULL;
- Aplikasi diperbarui untuk melakukan Dual-Write:
  Menulis ke 'user_phone' DAN 'encrypted_phone' secara bersamaan.
  Membaca masih dari 'user_phone'.

              |
              v
Fase 2: MIGRATE (Migrasi Data Historis di Latar Belakang)
- Jalankan skrip migrasi data lama secara bertahap (chunking per 1.000 baris):
  UPDATE merchants 
  SET encrypted_phone = encrypt(user_phone) 
  WHERE encrypted_phone IS NULL;
- Setelah 100% data terisi, perbarui kode aplikasi:
  Aplikasi sekarang membaca HANYA dari 'encrypted_phone'.

              |
              v
Fase 3: CONTRACT (Pembersihan Kolom Lama)
- Hapus ketergantungan kode terhadap 'user_phone'.
- Pasang migrasi untuk menghapus kolom lama secara aman:
  ALTER TABLE merchants DROP COLUMN user_phone;
```

### 3.2 Aturan Baku Migrasi Basis Data Finansial
1. **Dilarang Menambahkan Kolom `NOT NULL` Tanpa Default Value**: Penambahan kolom `NOT NULL` tanpa default akan mengunci tabel raksasa untuk memeriksa setiap baris (*table lock*).
2. **Indeks Wajib Dibuat Secara Asinkron**: Pembuatan indeks pada PostgreSQL produksi wajib menggunakan klausa `CREATE INDEX CONCURRENTLY` agar pembacaan dan penulisan transaksi tidak terhenti.
3. **Pemisahan Deployment Kode dan Migrasi**: Skrip migrasi skema basis data harus selalu kompatibel dengan versi kode aplikasi saat ini maupun versi yang akan disebarkan (*backward-compatible schema*).
