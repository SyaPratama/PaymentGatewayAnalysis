# Kategori G — Commercial Free-Tier Gateways

[← Kembali ke Laporan Utama](../payment-gateway-research.md)

Gateway pembayaran komersial tidak berlisensi open-source, namun beroperasi murni dengan model bayar sesuai pemakaian (pay-as-you-go): **Rp 0 / $0 biaya langganan bulanan, Rp 0 biaya setup awal, dan nol biaya pemeliharaan infrastruktur server**. Merchant hanya dipotong biaya variabel saat transaksi berhasil diselesaikan. Kategori ini menjadi tolok ukur finansial pembanding terhadap gateway self-hosted.

**Status di Proyek Ini:** Aplikasi e-commerce Laravel ini telah mengintegrasikan dua gateway komersial utama Indonesia: **TripPay** (`config/tripay.php`, `TripayPaymentService.php`) dan **DOKU** (`config/doku.php`, `DokuPaymentService.php`).

---

## 42. Stripe — [Lihat Laporan Deep-Dive Mandiri →](individual/stripe.md)
Standar emas global pemrosesan kartu kredit dan API pembayaran pengembang. Memiliki Payment Intents API, Stripe Elements terenkripsi, radar pendeteksi kecurangan (fraud), dan dukungan 135+ mata uang dunia. *(Catatan: Belum membuka entitas acquiring lokal berizin di Indonesia).*

---

## 43. PayPal — [Lihat Laporan Deep-Dive Mandiri →](individual/paypal.md)
Merek pembayaran konsumen internasional dengan 400M+ akun pengguna aktif. Meningkatkan konversi transaksi e-commerce ritel ekspor ke pembeli Amerika Serikat dan Eropa melalui tombol cerdas PayPal dan perlindungan sengketa pembeli/penjual.

---

## 44. Square — [Lihat Laporan Deep-Dive Mandiri →](individual/square.md)
Pemimpin pasar omnichannel yang menyatukan perangkat kasir fisik (EDC/POS terminal) dengan toko checkout web online dalam satu dasbor merchant tunggal.

---

## 45. Razorpay — [Lihat Laporan Deep-Dive Mandiri →](individual/razorpay.md)
Gateway pembayaran nomor satu di India ("Stripe-nya India") dengan integrasi native jalur transfer instan UPI (Google Pay, PhonePe, Paytm), netbanking, dan kepatuhan regulasi tokenisasi RBI.

---

## 46. Midtrans — [Lihat Laporan Deep-Dive Mandiri →](individual/midtrans.md)

| Informasi | Keterangan |
|---|---|
| **Kantor Pusat** | Jakarta, Indonesia (Bagian dari GoTo / Gojek Tokopedia) |
| **Model Biaya** | 2.9% + Rp 2.000 (Kartu) / Rp 4.000 (VA) / 0.7% (QRIS) |
| **Wilayah** | Indonesia (Pemimpin Pasar Domestik) |
| **Rating Pengembang**| Sangat Tinggi (⭐⭐⭐⭐⭐) |
| **Situs Web** | [https://midtrans.com](https://midtrans.com) |

### Gambaran Umum
Midtrans adalah standar emas developer experience dan kelengkapan kanal pembayaran di Indonesia. Memiliki checkout modal Snap drop-in, API headless Core API, deep linking langsung aplikasi GoPay dan ShopeePay, serta Virtual Account bank-bank terbesar di Indonesia (BCA, Mandiri, BNI, BRI, Permata).

---

## 47. Xendit — [Lihat Laporan Deep-Dive Mandiri →](individual/xendit.md)

| Informasi | Keterangan |
|---|---|
| **Kantor Pusat** | Jakarta, Indonesia & Manila, Filipina |
| **Model Biaya** | 2.9% + Rp 2.000 (Kartu) / Rp 4.500 (VA) / 0.7% (QRIS) |
| **Wilayah** | Indonesia, Filipina, Vietnam, Thailand |
| **Rating Pengembang**| Sangat Tinggi (⭐⭐⭐⭐⭐) |
| **Situs Web** | [https://xendit.co](https://xendit.co) |

### Gambaran Umum
Fintech unicorn Asia Tenggara yang menyediakan API pembayaran terpadu ala Stripe untuk kawasan ASEAN. Pilihan paling ideal bila toko e-commerce berencana melakukan ekspansi internasional ke pasar Filipina (GCash, Maya) dan Vietnam dengan satu kontrak API.

---

## 48. Adyen — [Lihat Laporan Deep-Dive Mandiri →](individual/adyen.md)
Pemimpin global pembayaran enterprise (mentenagai Spotify, Uber, McDonald's) dengan lisensi bank acquiring langsung di berbagai benua dan skema tarif transparan Interchange++ (€0.11 + biaya scheme kartu).

---

## 49. Mollie — [Lihat Laporan Deep-Dive Mandiri →](individual/mollie.md)
Gateway pembayaran favorit pengembang di Eropa dengan biaya transparan tanpa kontrak terikat, mendukung penuh metode pembayaran lokal Eropa (iDEAL, Bancontact, SOFORT, Klarna).

---

## 50. Paystack — [Lihat Laporan Deep-Dive Mandiri →](individual/paystack.md)
Infrastruktur pembayaran nomor satu di Afrika (anak perusahaan Stripe), mendukung kartu lokal, transfer bank USSD, dan mobile money di Nigeria, Ghana, Kenya, dan Afrika Selatan.

---

## 51. Flutterwave — [Lihat Laporan Deep-Dive Mandiri →](individual/flutterwave.md)
Unicorn pembayaran pan-Afrika dengan cakupan jaringan lebih dari 34 negara di benua Afrika dan agregasi dompet mobile money internasional.

---

## 52. TripPay (TriPay) ⭐ — [Lihat Laporan Deep-Dive Mandiri →](individual/tripay.md)

| Informasi | Keterangan |
|---|---|
| **Kantor Pusat** | Surakarta (Solo), Jawa Tengah, Indonesia |
| **Model Biaya** | Flat Rp 750 – Rp 4.250 per transaksi VA; 0.7% QRIS |
| **Wilayah** | Indonesia (Agregator Domestik) |
| **Status di Proyek Ini** | **Aktif Terpasang (`config/tripay.php`, `TripayPaymentService.php`)** |

### Gambaran Umum & Peran Proyek
TripPay adalah agregator pembayaran domestik dengan spesialisasi transaksi tertutup (closed payment) yang sangat ramah bagi UMKM dan produk digital. Keunggulan terbesarnya adalah **biaya flat per transaksi Virtual Account yang jauh lebih murah** dibanding gateway tier-1, menghemat margin keuntungan pada pesanan domestik.

---

## 53. DOKU ⭐ — [Lihat Laporan Deep-Dive Mandiri →](individual/doku.md)

| Informasi | Keterangan |
|---|---|
| **Kantor Pusat** | Jakarta, Indonesia |
| **Model Biaya** | ~2.5%–3.0% (Kartu) / Rp 3.500–Rp 5.000 (VA) |
| **Wilayah** | Indonesia (PJP Kategori 1 Berlisensi Bank Indonesia) |
| **Status di Proyek Ini** | **Aktif Terpasang (`config/doku.php`, `DokuPaymentService.php`)** |

### Gambaran Umum & Peran Proyek
Penyedia jasa pembayaran tertua di Indonesia (sejak 2007) dengan lisensi resmi direct card acquiring. DOKU menjadi pilar utama di aplikasi ini untuk pemrosesan kartu kredit berkat dukungan 3D Secure 2.0 yang memberikan pengalihan tanggung jawab penipuan (liability shift) langsung ke bank penerbit kartu.

---

## Tabel Perbandingan Kategori G

| Gateway | Fokus Utama | Biaya Kartu Kredit | Biaya Virtual Account / Bank Transfer | Rating Dev | Biaya Akun Bulanan | Status di Proyek Ini |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Stripe** | Global (AS/Eropa) | 2.9% + $0.30 | ACH AS 0.8% | ⭐⭐⭐⭐⭐ | $0 | ❌ |
| **PayPal** | Pembeli Global | 2.99% + $0.49 | N/A | ⭐⭐⭐ | $0 | ❌ |
| **Square** | Omnichannel POS | 2.6%–2.9% + fix | N/A | ⭐⭐⭐⭐ | $0 | ❌ |
| **Razorpay** | Domestik India | 2.0% + GST | UPI Gratis / Netbanking 2% | ⭐⭐⭐⭐⭐ | $0 | ❌ |
| **Midtrans** | Domestik Indonesia | 2.9% + Rp 2k | Rp 4.000 / VA | ⭐⭐⭐⭐⭐ | $0 | ❌ |
| **Xendit** | Asia Tenggara | 2.9% + Rp 2k | Rp 4.500 / VA | ⭐⭐⭐⭐⭐ | $0 | ❌ |
| **Adyen** | Enterprise Global | Interchange++ | Tarif Kliring Lokal | ⭐⭐⭐⭐ | Min. Komitmen | ❌ |
| **Mollie** | Eropa (EEA/UK) | 1.8% + €0.25 | €0.29 (iDEAL) | ⭐⭐⭐⭐⭐ | €0 | ❌ |
| **Paystack** | Afrika | 1.5% + ₦100 | Tarif Transfer Lokal | ⭐⭐⭐⭐⭐ | $0 | ❌ |
| **Flutterwave**| Pan-Afrika | 1.4% – 3.8% | Rel Lokal Afrika | ⭐⭐⭐⭐ | $0 | ❌ |
| **TripPay** | Domestik Indonesia | ~2.5% | **Rp 750 – Rp 4.250 (Termurah)**| ⭐⭐⭐⭐ | **Rp 0** | ✅ **Aktif Digunakan** |
| **DOKU** | Domestik Indonesia | **2.5%–3.0% (Direct)**| Rp 3.500 – Rp 5.000 | ⭐⭐⭐⭐ | **Rp 0** | ✅ **Aktif Digunakan** |
