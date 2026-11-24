# Kategori F — Banking & Ledger Infrastructure

[← Kembali ke Laporan Utama](../payment-gateway-research.md)

Solusi infrastruktur perbankan dan buku besar (banking & ledger) menyediakan fondasi tingkat rendah untuk memindahkan dan mencatat mutasi uang secara matematis. Berbeda dari gateway checkout komersial yang sekadar mengembalikan token otorisasi, sistem-sistem ini mengimplementasikan jalur kliring perbankan, format pesan transaksi kartu ISO 8583, dan mesin pembukuan berpasangan (double-entry) berkecepatan tinggi.

---

## 34. Moov — [Lihat Laporan Deep-Dive Mandiri →](individual/moov.md)
Platform protokol finansial open-source berbasis Go yang mengimplementasikan standar spesifikasi perbankan AS (NACHA ACH, Fedwire, FedNow, ISO 20022) dan penyaringan daftar sanksi OFAC otomatis.

---

## 35. Apache Fineract — [Lihat Laporan Deep-Dive Mandiri →](individual/apache-fineract.md)
Platform core banking open-source enterprise di bawah Apache Foundation yang mengelola operasional pinjaman, tabungan, perhitungan bunga, dan buku besar akuntansi pada lebih dari 100 institusi keuangan global.

---

## 36. TigerBeetle — [Lihat Laporan Deep-Dive Mandiri →](individual/tigerbeetle.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~10.000 |
| **Lisensi** | Apache-2.0 |
| **Bahasa / Stack** | Zig, Native Binary, Zero Dependencies |
| **Situs Web** | [https://tigerbeetle.com](https://tigerbeetle.com) |
| **Repositori GitHub** | [https://github.com/tigerbeetle/tigerbeetle](https://github.com/tigerbeetle/tigerbeetle) |

### Gambaran Umum
TigerBeetle adalah database akuntansi finansial terdistribusi berkecepatan tinggi yang dirancang untuk memproses lebih dari **1.000.000 transfer double-entry per detik**. Ditulis dalam bahasa Zig dengan alokasi memori statis dan protokol konsensus Viewstamped Replication (VSR), TigerBeetle menjamin secara mutlak bahwa debit selalu sama dengan kredit dan kebal terhadap korupsi data disk.

---

## 37. Formance Ledger — [Lihat Laporan Deep-Dive Mandiri →](individual/formance-ledger.md)
Buku besar double-entry terprogram (programmable ledger) berbasis Go dan PostgreSQL yang menggunakan bahasa khusus Numscript untuk memodelkan pembagian komisi marketplace, escrow, dan alur multi-dompet secara deklaratif.

---

## 38. Blnk — [Lihat Laporan Deep-Dive Mandiri →](individual/blnk.md)
Core banking ledger open-source berbasis Go untuk fintech pasar berkembang, menyederhanakan manajemen dompet multi-mata uang dan rekonsiliasi transaksi otomatis terhadap rekening koran bank.

---

## 39. jPOS — [Lihat Laporan Deep-Dive Mandiri →](individual/jpos.md)
Platform switching transaksi kartu berbasis standar ISO 8583 yang telah beroperasi lebih dari 25 tahun di jaringan ATM, terminal POS kasir, dan kartu perbankan global.

---

## 40. Mojaloop — [Lihat Laporan Deep-Dive Mandiri →](individual/mojaloop.md)
Switch pembayaran realtime nasional open-source yang diprakarsai oleh Bill & Melinda Gates Foundation, menggunakan Interledger Protocol (ILP) untuk menghubungkan dompet digital dan bank secara interoperable di tingkat negara.

---

## 41. Hatchet Ledger — [Lihat Laporan Deep-Dive Mandiri →](individual/hatchet-ledger.md)
Pustaka double-entry ledger ringan berbasis TypeScript dan PostgreSQL dengan penguncian baris konkurensi database dan audit trail kekal.

---

## Tabel Perbandingan Kategori F

| Sistem | Fokus Spesialisasi | Bahasa | Mesin Penyimpanan | Throughput Transaksi | Aplikasi Terbaik |
|---|---|:---:|:---:|:---:|---|
| **Moov** | Perbankan AS (ACH/Wire) | Go | Cloud-Native | Tinggi | File NACHA & cek OFAC |
| **Apache Fineract** | Core Banking Lengkap | Java | MySQL / Postgres | Enterprise | Neobank & pinjaman |
| **TigerBeetle** | Database Akuntansi Kecepatan Tinggi | Zig | Kustom (io_uring) | **1.000.000+ tx/detik** | Saldo dompet volume masif |
| **Formance Ledger** | Alur Uang Terprogram (Numscript) | Go | PostgreSQL | Menengah–Tinggi | Bagi hasil marketplace & escrow |
| **Blnk** | Dompet Fintech & Rekonsiliasi | Go | Postgres / Redis | Menengah–Tinggi | Dompet multi-valuta |
| **jPOS** | Switching Kartu & ISO 8583 | Java | Memori / Tuple Q2| 10.000+ pesan/detik | Jaringan ATM & EDC |
| **Mojaloop** | Switch Pembayaran Nasional | Node / TS | Kafka / K8s | Skala Nasional | Kliring instan antar-bank |
| **Hatchet Ledger** | Double-Entry Tersemat | TypeScript | PostgreSQL | Moderat | Saldo akun SaaS sederhana |
