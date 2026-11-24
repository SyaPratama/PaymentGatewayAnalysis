# Kepatuhan Regulasi Finansial, Keamanan Data, dan Jejak Audit Kekal

Dokumen ini membedah kepatuhan standar industri finansial (*PCI-DSS v4.0* dan regulasi Bank Indonesia), arsitektur pencatatan jejak audit kekal (*Immutable Audit Trail*), penyamaran data pribadi (*PII Masking*), serta protokol penanganan insiden dan *Blameless Post-Mortem*.

---

## 1. Kepatuhan Regulasi Finansial: PCI-DSS v4.0 dan Standar Bank Indonesia

Sistem pembayaran yang memproses atau meneruskan data kartu pembayaran wajib mematuhi standar *Payment Card Industry Data Security Standard* (PCI-DSS) versi 4.0.

```
                      +---------------------------------------+
                      | INTERNET PUBLIK (Zona Tidak Tepercaya)|
                      +---------------------------------------+
                                          |
                                          v (TLS 1.3 Strict)
+-----------------------------------------------------------------------------------+
| CARDHOLDER DATA ENVIRONMENT (CDE) - ZONA TERISOLASI KETAT                         |
|                                                                                   |
|  [ Ingress Gateway & WAF ]                                                        |
|             |                                                                     |
|             v (Enkripsi Transit)                                                  |
|  [ Tokenization Vault Service ] <---> [ HSM / KMS (Enkripsi Kunci AES-256-GCM) ]  |
|             |                                                                     |
|             | 1. Simpan PAN/CVV Asli ke Vault Khusus                              |
|             | 2. Hasilkan Token Acak Aman (e.g. "tok_card_99812")                 |
|             v                                                                     |
|  [ Core Payment System ]                                                          |
|  (HANYA melihat Token Acak & 4 Digit Terakhir; ZERO RAW CARD DATA)                |
+-----------------------------------------------------------------------------------+
```

### 1.1 Prinsip Desain Kepatuhan PCI-DSS v4.0

1. **Pengecilan Cakupan Audit (*Scope Reduction via Tokenization*)**:
   - Inti pemrosesan pembayaran Tamaku tidak boleh menyentuh atau menyimpan nomor kartu mentah (*Primary Account Number / PAN*) atau nilai verifikasi kartu (*CVV / CVC*).
   - Seluruh input kartu di frontend menggunakan *Hosted Fields* atau *Iframe SDK* terisolasi yang langsung mengirimkan data kartu ke *Tokenization Vault*. Inti backend hanya menerima token yang tidak memiliki nilai matematis bagi penyerang.
2. **Kriptografi Kuat dalam Transit dan Penyimpanan**:
   - **Data in Transit**: Komunikasi HTTPS wajib menggunakan **TLS 1.3** (*cipher suites* modern seperti `TLS_AES_256_GCM_SHA384`). Protokol TLS 1.0, 1.1, dan 1.2 dengan cipher lemah wajib dinonaktifkan di level ingress proxy.
   - **Data at Rest**: Nomor rekening bank dan identitas pedagang wajib dienkripsi di basis data menggunakan kunci AES-256-GCM yang dirotasi secara otomatis melalui *Hardware Security Module* (HSM) atau *Cloud Key Management Service* (KMS).

---

## 2. Struktur Jejak Audit Kekal (Immutable Audit Trail) dan PII Masking

Setiap interaksi pengguna, modifikasi saldo merchant, dan panggilan API perbankan wajib dicatat ke dalam log terstruktur (*Structured JSON Logging*) yang tidak dapat dimanipulasi (*tamper-proof*).

### 2.1 Penyamaran Informasi Identitas Pribadi (PII Masking)

Pencatatan data mentah seperti nomor kartu penuh, CVV, PIN virtual account, atau kata sandi ke dalam log aplikasi adalah pelanggaran berat kepatuhan.

| Jenis Informasi | Format Mentah | Format Wajib dalam Log (*Masked*) |
| :--- | :--- | :--- |
| **Nomor Kartu (PAN)** | `4111 2222 3333 4444` | `4111-XXXX-XXXX-4444` (Hanya 6 depan & 4 belakang) |
| **Card Verification Value (CVV)** | `123` | `[STRIPPED]` (Dilarang disimpan atau dicatat sama sekali) |
| **Nomor Rekening Bank** | `1234567890` | `******7890` (Hanya 4 digit terakhir) |
| **Email Pengguna** | `budi.santoso@gmail.com`| `b***o@gmail.com` |
| **Nomor Telepon** | `+6281234567890` | `+62812****7890` |

### 2.2 Skema Log Terstruktur Berstandar OpenTelemetry / W3C TraceContext

```json
{
  "timestamp": "2025-05-14T08:30:15.123Z",
  "level": "INFO",
  "service": "tamaku-payment-router",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "actor": {
    "type": "MERCHANT_API",
    "id": "mch_prod_991823",
    "ip_address": "103.28.12.5"
  },
  "action": "PAYMENT_CAPTURE_REQUESTED",
  "payload": {
    "session_id": "sess_01HQ9K...",
    "amount": 500000,
    "currency": "IDR",
    "channel": "BCA_VIRTUAL_ACCOUNT",
    "va_number": "******4567"
  },
  "audit": {
    "is_financial_mutation": true,
    "source_file": "usecase/payment_usecase.go:142"
  }
}
```

- **Penyimpanan Log Jangka Panjang**:
  Log dikirimkan secara *real-time* ke sistem *Log Aggregator* (seperti OpenSearch / Grafana Loki) dan diarsipkan ke *Object Storage* (S3 / GCS) dengan kebijakan **WORM (Write Once, Read Many)** dan proteksi *Object Lock* selama minimal 5 tahun sesuai regulasi perbankan Indonesia.

---

## 3. Protokol Penanganan Insiden dan Post-Mortem Tanpa Menyalahkan (Blameless)

Ketika terjadi kegagalan pemrosesan transaksi di produksi, kecepatan koordinasi dan keterbukaan investigasi menentukan kelangsungan operasional sistem.

### 3.1 Prosedur Tanggap Darurat Insiden (Incident Response Flow)

```
[ Pemicu Alarm: Prometheus / Sentry / Merchant Report ]
                         |
                         v
+---------------------------------------------------------------+
| Fase 1: TRIAGE & SEVERITY CLASSIFICATION (Durasi: < 5 Menit)  |
| - SEV-1: Sistem mati total, kebocoran saldo, atau data leak   |
| - SEV-2: Kanal bank tertentu mati (misal BCA VA down)         |
| - SEV-3: Dashboard pelaporan lambat, fitur non-kritis minor   |
+---------------------------------------------------------------+
                         |
                         v
+---------------------------------------------------------------+
| Fase 2: MITIGATION & CONTAINMENT (Prioritas: Pulihkan Layanan)|
| - Matikan fitur via Feature Flag (< 1 menit)                  |
| - Alihkan rute transaksi bank ke kanal cadangan               |
| - DILARANG melakukan debugging panjang di server produksi aktif|
+---------------------------------------------------------------+
                         |
                         v
+---------------------------------------------------------------+
| Fase 3: RESOLUTION VERIFICATION                               |
| - Pastikan transaksi uji coba sukses 100%                     |
| - Turunkan status insiden dan informasikan ke merchant        |
+---------------------------------------------------------------+
                         |
                         v
+---------------------------------------------------------------+
| Fase 4: BLAMELESS POST-MORTEM & ROOT CAUSE ANALYSIS (RCA)     |
+---------------------------------------------------------------+
```

### 3.2 Budaya Blameless Post-Mortem

Investigasi pasca-insiden **dilarang mencari individu yang bersalah** ("Siapa yang salah memencet tombol atau salah membuat PR"). Fokus diarahkan penuh pada **kegagalan sistem**:
- *Pertanyaan yang Benar*: "Mengapa pipeline CI tidak mendeteksi bug tersebut?", "Mengapa saklar feature flag tidak memutus aliran error secara otomatis?", "Bagaimana cara merancang guardrail agar insinyur lain tidak bisa membuat kesalahan yang sama di masa depan?".

### 3.3 Struktur Laporan Post-Mortem Wajib

1. **Ringkasan Eksekutif**: Ringkasan singkat insiden, durasi *downtime*, dampak finansial, dan jumlah transaksi terdampak.
2. **Garis Waktu (*Incident Timeline*)**: Urutan peristiwa berbasis waktu UTC dari pemicu masalah, alarm pertama berbunyi, hingga mitigasi diterapkan.
3. **Analisis Akar Masalah (*Five Whys Method*)**:
   - Mengapa transaksi gagal? Karena koneksi database habis.
   - Mengapa koneksi habis? Karena ada kueri pelaporan berat yang menahan koneksi.
   - Mengapa kueri pelaporan berada di database utama? Karena belum ada replika baca terpisah.
4. **Tindakan Korektif (*Action Items*)**:
   - **Tindakan Pencegahan**: Menambahkan isolasi replika baca.
   - **Uji Regresi Wajib**: Membuat *Integration Test* otomatis yang mensimulasikan kueri berat paralel untuk membuktikan bahwa *connection pool* utama tetap aman.
