# Kategori B — Self-Hosted Crypto Gateways

[← Kembali ke Laporan Utama](../payment-gateway-research.md)

Gateway pembayaran kripto self-hosted memungkinkan bisnis memproses pembayaran aset digital secara peer-to-peer tanpa perantara kustodian. Dengan memegang private key sendiri dan menjalankan node/verifikator lokal, merchant menghapus potongan persentase pihak ketiga, kebal terhadap penahanan saldo sepihak, dan menjaga kedaulatan finansial mutlak.

**Kapan digunakan:** Transaksi lintas negara tanpa gesekan konversi valuta asing, industri berisiko tinggi yang rentan terhadap pemblokiran sepihak jaringan kartu kredit, atau pelanggan yang mengutamakan privasi pembayaran.

---

## 5. BTCPay Server — [Lihat Laporan Deep-Dive Mandiri →](individual/btcpay-server.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~6.500 |
| **Lisensi** | MIT |
| **Bahasa / Stack** | C# / .NET Core, ASP.NET Core, PostgreSQL, Docker |
| **Situs Web** | [https://btcpayserver.org](https://btcpayserver.org) |
| **Repositori GitHub** | [https://github.com/btcpayserver/btcpayserver](https://github.com/btcpayserver/btcpayserver) |

### Gambaran Umum
BTCPay Server adalah pemroses pembayaran mata uang kripto open-source standar industri global. Diciptakan sebagai alternatif anti-sensor terhadap pemroses komersial seperti BitPay, BTCPay Server memungkinkan penerimaan Bitcoin on-chain dan Lightning Network langsung ke dompet pribadi tanpa biaya potongan transaksi sepeser pun.

### Fitur Utama
- **Penyelesaian Langsung Peer-to-Peer** — Dana ditransfer langsung ke dompet merchant via alamat xPub tanpa perantara.
- **Dukungan Lightning Network** — Pembayaran instan bernilai mikro dengan biaya jaringan sub-sen via c-lightning atau LND.
- **Manajemen Multi-Store** — Menjalankan ratusan toko terisolasi dalam satu instalasi server yang sama.
- **Greenfield REST API** — API modern untuk integrasi checkout aplikasi web dan dispatch webhook terenkripsi.
- **Konversi Otomatis ke Fiat** — Plugin otomatis untuk menjual Bitcoin yang diterima ke exchange (Kraken, Binance) guna menghindari volatilitas harga.

### Kelebihan & Kekurangan
- ✅ 0% potongan biaya transaksi (hanya membayar sewa server VPS).
- ✅ Kebal terhadap pembekuan akun atau intervensi pihak ketiga.
- ❌ Membutuhkan pemeliharaan server node Bitcoin (kapasitas disk NVMe besar untuk node penuh, atau mode pruned ~20GB).
- ❌ Hanya mendukung aset kripto; tidak memproses kartu kredit fiat.

---

## 6. Bitcart — [Lihat Laporan Deep-Dive Mandiri →](individual/bitcart.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~500 |
| **Lisensi** | MIT |
| **Bahasa / Stack** | Python (FastAPI), Vue.js, Docker |
| **Situs Web** | [https://bitcart.ai](https://bitcart.ai) |
| **Repositori GitHub** | [https://github.com/bitcart/bitcart](https://github.com/bitcart/bitcart) |

### Gambaran Umum
Bitcart adalah platform pembayaran kripto non-kustodian yang dibangun dengan Python (FastAPI) dan dasbor admin Vue.js. Bitcart mendukung transaksi multi-koin (BTC, LN, LTC, XMR, ETH, USDT) secara modular, sehingga pengembang hanya perlu menyalakan daemon koin yang dibutuhkan untuk menghemat RAM server.

### Kelebihan & Kekurangan
- ✅ Dukungan bawaan untuk stablecoin (USDT/USDC) dan koin privasi (Monero).
- ✅ Kode Python asinkron yang bersih dan mudah dikembangkan.
- ❌ Komunitas dan plugin CMS lebih sedikit dibanding BTCPay Server.

---

## 7. SHKeeper — [Lihat Laporan Deep-Dive Mandiri →](individual/shkeeper.md)

| Informasi | Keterangan |
|---|---|
| **Bintang GitHub** | ~150 |
| **Lisensi** | MIT |
| **Bahasa / Stack** | Python, Docker, PostgreSQL |
| **Situs Web** | [https://shkeeper.io](https://shkeeper.io) |
| **Repositori GitHub** | [https://github.com/vsys-host/shkeeper](https://github.com/vsys-host/shkeeper) |

### Gambaran Umum
SHKeeper adalah pemroses pembayaran kripto self-hosted yang menitikberatkan pada privasi transaksi dan kemudahan penerimaan stablecoin USDT pada jaringan TRON (TRC-20) serta Monero tanpa telemetri atau prosedur KYC.

---

## 8. CryptoPayServer — [Lihat Laporan Deep-Dive Mandiri →](individual/cryptopayserver.md)

Daemon pembayaran kripto ultra-ringan berbasis Go (<50MB RAM). Dirancang untuk lingkungan edge dan perangkat keras terbatas yang hanya memerlukan pembuatan alamat terima dan verifikasi konfirmasi blok sederhana.

---

## 9. Globee OSS — [Lihat Laporan Deep-Dive Mandiri →](individual/globee.md)

Implementasi referensi pemroses invoice kripto berbasis PHP dan Laravel. Menyediakan model Eloquent dan migrasi basis data untuk penguncian kurs fiat-kripto dan penanganan webhook IPN.

---

## Tabel Perbandingan Kategori B

| Fitur | BTCPay Server | Bitcart | SHKeeper | CryptoPayServer | Globee OSS |
|---|:---:|:---:|:---:|:---:|:---:|
| **Bahasa Utama** | C# (.NET) | Python | Python | Go | PHP / Laravel |
| **Lightning Network** | ✅ Native | ✅ Native | ❌ | ❌ | ❌ |
| **Monero (XMR)** | Via Plugin | ✅ Native | ✅ Native | ❌ | ❌ |
| **Stablecoin (USDT-TRC20)**| Via Liquid/ETH | ✅ Native | ✅ Native | ❌ | ❌ |
| **UI Dasbor Toko** | ✅ Sangat Lengkap| ✅ Dasbor Vue | ❌ API-first | ❌ API-first | ⚠️ Sederhana |
| **Model Non-Kustodian** | ✅ Ya | ✅ Ya | ✅ Ya | ✅ Ya | ✅ Ya |
| **Kebutuhan RAM Minimal**| 2GB – 4GB | 1GB – 2GB | 1GB | <100MB | 512MB |
