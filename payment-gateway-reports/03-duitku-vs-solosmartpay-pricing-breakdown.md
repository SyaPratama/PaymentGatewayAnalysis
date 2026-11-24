# Analisis Komparasi Harga: Duitku vs Solosmartpay

> **Analisis Paradoks Harga**: Mengapa Solosmartpay tampak lebih murah di halaman harga publik padahal menggunakan Duitku sebagai aggregator upstream di belakang layar?

---

## 1. Tabel Perbandingan Tarif Resmi

Perbandingan data langsung antara `https://www.duitku.com/harga/` dan `https://solosmartpay.com/pricing`:

| Metode Pembayaran | Biaya Resmi Duitku (`duitku.com/harga`) | Biaya Solosmartpay (`solosmartpay.com/pricing`) | Selisih (Markup Solosmartpay) |
|---|---|---|---|
| **Mandiri VA (`M2`)** | **Rp 4.000** | **Rp 4.300** | **+Rp 300 lebih mahal** |
| **BNI VA (`I1`)** | **Rp 3.000** | **Rp 3.300** | **+Rp 300 lebih mahal** |
| **BRI VA (`BR`)** | **Rp 3.000** | **Rp 3.300** | **+Rp 300 lebih mahal** |
| **Permata VA (`BT`)** | **Rp 3.000** | **Rp 3.300** | **+Rp 300 lebih mahal** |
| **CIMB Niaga VA (`B1`)** | **Rp 3.000** | **Rp 3.300** | **+Rp 300 lebih mahal** |
| **Sahabat Sampoerna VA (`S1`)** | **Rp 1.500** | **Rp 1.800** | **+Rp 300 lebih mahal** |
| **Artha Graha VA (`AG`)** | **Rp 1.500** | **Rp 1.800** | **+Rp 300 lebih mahal** |
| **Gerai Retail (Alfamart/POS/Pegadaian)** | **Rp 2.500** | **Rp 2.800** | **+Rp 300 lebih mahal** |
| **OVO (E-Wallet)** | **1,67%** (reguler) / 3,03% (digital) | **3,28%** | **Hingga +1,61% lebih mahal** |
| **ShopeePay (E-Wallet)** | **2,00%** (reguler) / 4,00% (digital) | **4,25%** | **Hingga +2,25% lebih mahal** |
| **QRIS Dinamis** | **0,70%** (resmi BI MDR) | **Rp 300 flat** (≤ 500rb) / **0,50%** (> 500rb) | **Tampak lebih murah di Solosmartpay** |

---

## 2. Mengapa QRIS Solosmartpay Bisa Menawarkan Rp 300 Flat?

Jika Solosmartpay membeli seluruh layanannya dari Duitku, menjual QRIS seharga Rp 300 akan menyebabkan kerugian besar di setiap transaksi di atas Rp 45.000 (0,7% dari Rp 50.000 saja sudah Rp 350).

Solosmartpay dapat menawarkan Rp 300 flat karena **QRIS Solosmartpay tidak melewati rel Duitku**. Solosmartpay menjalankan arsitektur **Dual-Rail**:

```
                         [ Solosmartpay Gateway ]
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         │                                                     │
         ▼                                                     ▼
 [ Rail 1: Duitku API ]                               [ Rail 2: QRIS Bypass ]
  - Bank Virtual Account                               - QRIS Statis Merchant Sendiri
  - E-Wallet                                           - Modifikasi String EMVCo Dinamis
  - Gerai Retail                                       - Alokasi Kode Unik 1–999
  ───────────────────────                              - Bot Cek Mutasi Rekening Bank
  Biaya: Tarif Duitku + Rp 300                          ─────────────────────────────
  Margin: Rp 300 / transaksi                           Biaya: Rp 0 (MDR Mikro BI 0%)
                                                       Margin: Rp 300 Murni (100% Margin)
```

### Mekanisme Penghematan Biaya QRIS Solosmartpay:
1. **Pemanfaatan QRIS Statis Merchant Usaha Mikro (UMI)**:
   - Berdasarkan Peraturan Bank Indonesia, transaksi QRIS untuk kategori Usaha Mikro (UMI) hingga nominal Rp 100.000 dikenakan MDR **0%**.
   - Solosmartpay menggunakan QRIS statis rekening penampung internal. Biaya interchange/switching ke perbankan adalah **Rp 0**.
2. **Kompensasi Kode Unik Ditanggung Pelanggan**:
   - Sistem membubuhkan kode unik acak/berurutan Rp 1 – Rp 999 ke total tagihan pembeli.
   - Hak kode unik tersebut menjadi hak penampung/merchant.
   - Biaya Rp 300 yang ditagihkan ke merchant adalah keuntungan operasional murni Solosmartpay, bukan biaya interchange yang disetor ke acquirer.

---

## 3. Faktor Psikologis & Trik Tampilan "Terlihat Murah"

Terdapat beberapa faktor yang menyebabkan Solosmartpay dipersepsikan lebih murah oleh calon pengguna:

1. **Efek Anchoring "Mulai Rp 1.800"**:
   - Solosmartpay menonjolkan Virtual Account Bank Sahabat Sampoerna dan Bank Artha Graha yang berbiaya Rp 1.800. Padahal harga modal dari Duitku untuk kedua bank tersebut adalah Rp 1.500.
2. **Penghilangan Kanal Bank Termahal (BCA VA)**:
   - Di Duitku, BCA VA mematok biaya Rp 5.000 dan mewajibkan legalitas PT.
   - Solosmartpay memilih tidak mengaktifkan BCA VA dalam daftar kanal mereka, sehingga angka tarif tertinggi yang terlihat di halaman harga mereka hanya Mandiri (Rp 4.300).
3. **Fitur Pengalihan Biaya (`fee_payer = customer`)**:
   - Dashboard Solosmartpay memungkinkan pembebanan seluruh biaya admin ke pembeli. Saldo yang masuk ke merchant terlihat 100% utuh tanpa potongan, menciptakan impresi layanan gratis bagi merchant yang tidak memperhitungkan konversi pembeli.

---

## 4. Kesimpulan Evaluasi

- Untuk **Virtual Account, E-Wallet, dan Retail**: Menggunakan Duitku secara langsung **jauh lebih murah** daripada Solosmartpay (menghemat Rp 300 per VA dan menghemat hingga 2,25% pada E-Wallet).
- Untuk **QRIS**: Solosmartpay lebih murah semata-mata karena mereka tidak menggunakan rel switching resmi aggregator, melainkan menjalankan sistem mutasi rekening kode unik mandiri.
