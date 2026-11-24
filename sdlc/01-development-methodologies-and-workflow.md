# Metodologi Pengembangan dan Alur Kerja Rekayasa Finansial

Dokumen ini membandingkan empat metodologi rekayasa perangkat lunak (*Agile Scrum, Kanban, Shape Up, Extreme Programming*), menetapkan alur kerja rilis untuk sistem pembayaran, serta merumuskan kriteria *Definition of Ready* (DoR) dan *Definition of Done* (DoD) dengan kepatuhan audit finansial.

---

## 1. Evaluasi Komparatif Metodologi Pengembangan

Dalam domain payment gateway, kelambatan merespons regulasi atau fitur baru sama berbahayanya dengan kelalaian bug yang menyebabkan kebocoran saldo. Metodologi harus menyeimbangkan kecepatan (*speed-to-market*) dan kehati-hatian (*safety & compliance*).

| Dimensi | Agile Scrum (2-Week Sprint) | Kanban (Continuous Flow) | Shape Up (Basecamp 6-Week Cycles) | Extreme Programming (XP) |
| :--- | :--- | :--- | :--- | :--- |
| **Irama Perencanaan** | Tetap (Sprint 1-2 Minggu) | Berkelanjutan (On-Demand / Pull) | Siklus 6 Minggu + 2 Minggu Cooldown | Harian / Mingguan Iteratif |
| **Batas Pekerjaan Berjalan (WIP)** | Dibatasi oleh *Sprint Velocity* | Dibatasi secara eksplisit (*WIP Limits*) | Dibatasi oleh ruang lingkup proyek (*Betting*) | Dibatasi oleh pasangan pemrograman (*Pairing*) |
| **Manajemen Perubahan** | Perubahan dibatasi di tengah Sprint | Sangat fleksibel (Bisa geser kartu kapan saja) | Tidak ada gangguan selama siklus 6 minggu | Perubahan diterima selama tes tetap hijau |
| **Fokus Mutu Rekayasa** | Bergantung pada kedisiplinan tim | Bergantung pada kebijakan proses | Diserahkan penuh pada tim mandiri | **Inti Metodologi** (TDD, Refactoring, Pairing) |
| **Kelemahan Finansial** | Sering tergesa-gesa di akhir Sprint | Rentan kehilangan fokus roadmap strategis | Terlalu lama untuk bug kritis integrasi bank | Butuh kedisiplinan budaya yang sangat tinggi |

### Sintesis Metodologi untuk Tamaku: *Dual-Track Hybrid (Kanban + XP Practices)*
1. **Jalur Eksekusi (Kanban)**: Mempertahankan batasan WIP (*Work-in-Progress*) yang ketat. Tiket perbaikan integrasi bank atau perubahan endpoint SNAP BI dapat segera ditarik tanpa menunggu siklus sprint dua mingguan.
2. **Disiplin Rekayasa (XP Practices)**: Mewajibkan *Test-Driven Development* (TDD) untuk modul finansial kritis, ulasan kode berpasangan (*Peer Review*), dan integrasi terus-menerus (*Continuous Integration*).

---

## 2. Alur Kerja Rilis: Siklus Dua Mingguan vs Continuous Deployment Berbasis Feature Flags

### 2.1 Mengapa Rilis Terjadwal Tradisional Berbahaya bagi Fintech

Rilis besar berkala (misal: "Deployment tiap Selasa malam pukul 00:00") mengumpulkan ratusan perubahan kode ke dalam satu rilis raksasa (*big-bang release*). Jika terjadi anomali pemotongan saldo atau ketidakcocokan tanda tangan bank, tim sulit mengisolasi *commit* mana yang menjadi biang masalah, memaksa *rollback* menyeluruh yang memicu *downtime*.

### 2.2 Standar Emas: Continuous Deployment Berbasis Feature Flags

Kode yang telah lolos uji otomatis digabungkan ke cabang utama (*trunk*) dan langsung disebarkan ke lingkungan produksi beberapa kali sehari. Namun, fungsionalitas baru dinonaktifkan secara *default* menggunakan *Feature Flags* (*Feature Toggles*).

```
[ Developer Merge PR ke Main ]
               |
               v
[ Automated Pipeline CI/CD: Test & Security Scan ]
               |
               v
[ Deploy Binary ke Produksi (Status: INACTIVE via Feature Flag) ]
               |
               v
[ Pengujian Internal: Aktifkan Flag HANYA untuk Merchant Internal ]
               |
               v
[ Gradual Rollout: 5% -> 25% -> 100% Lalu Lintas Merchant ]
               |
         (Anomali Terdeteksi?)
         /                  \
       YA                   TIDAK
       /                      \
Matikan Flag (< 1 detik)    Fitur Permanen (Hapus Flag dari Kode)
(Tanpa Perlu Redeploy)
```

- **Keuntungan**:
  1. *Mean Time to Recovery (MTTR)* turun dari hitungan jam menjadi hitungan detik (cukup mematikan saklar di dasbor flag tanpa redeploy).
  2. Memisahkan rilis teknis kode (*code deployment*) dari rilis bisnis (*feature release*).

---

## 3. Definition of Ready (DoR): Syarat Memulai Rekayasa

Sebuah tiket kebutuhan fitur tidak boleh disentuh oleh insinyur perangkat lunak sebelum memenuhi kriteria DoR berikut:

1. **Spesifikasi Antarmuka Terdefinisi**: Kontrak payload API (JSON Schema / Protobuf) sudah disetujui, termasuk pemetaan kode galat perbankan (*error code mapping*).
2. **Klarifikasi Aliran Dana & Akuntansi**: Dokumen transaksi merinci akun debit dan kredit mana saja yang terdampak, termasuk struktur biaya (*merchant discount rate* / PPN).
3. **Model Transisi Status (FSM)**: Diagram alur status pembayaran telah disepakati oleh tim produk, tim risiko, dan tim kepatuhan (*compliance*).
4. **Ketersediaan Akses Uji Upstream**: Kredensial *sandbox* bank mitra aktif dan dapat dihubungi melalui lingkungan staging internal.

---

## 4. Definition of Done (DoD): Syarat Kelulusan Produksi Finansial

Sebuah fitur dianggap selesai (*Done*) dan boleh disebarkan ke produksi hanya jika memenuhi kriteria ketat berikut:

```
+-------------------------------------------------------------------------------+
| CHECKLIST DEFINITION OF DONE (DoD) TAMAKU PAYMENT GATEWAY                     |
+-------------------------------------------------------------------------------+
| [ ] 1. Cakupan Pengujian:                                                     |
|        - Unit Test Domain Core minimal 90% (Zero Floating-Point Check).       |
|        - Integration Test menggunakan Postgres nyata (Testcontainers).       |
|        - Negative Testing: Simulasi saldo tidak cukup & bank timeout.        |
|                                                                               |
| [ ] 2. Integritas Ledger:                                                     |
|        - Pengujian pembukuan membuktikan zero-sum balance (Debit = Kredit).   |
|        - Tidak ada baris saldo yang dapat menjadi negatif.                    |
|                                                                               |
| [ ] 3. Audit Keamanan & Kepatuhan:                                            |
|        - SAST & Secret Scanner bersih (Tidak ada hardcoded API key/secret).   |
|        - Log JSON tidak membocorkan PII (Masking PAN, CVV, PIN).              |
|                                                                               |
| [ ] 4. Observabilitas & Operasional:                                          |
|        - Metrik Prometheus terpasang: Hitungan Transaksi, Latensi P99, Error. |
|        - Runbook / Playbook pemulihan insiden tersedia untuk tim On-Call.    |
|        - Saklar Feature Flag terkonfigurasi untuk mitigasi kegagalan instan.  |
+-------------------------------------------------------------------------------+
```
