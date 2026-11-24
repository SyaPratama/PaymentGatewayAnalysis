# Audit Tech Stack & Reverse-Engineering Solosmartpay

> **Target**: `https://solosmartpay.com/`  
> **Entity**: Solo Smart Digital (Surakarta, Jawa Tengah)  
> **Status**: Terdaftar PSE Komdigi; Penyelenggara Jasa Pembayaran (PJP) Kategori 3 / Technical Facilitator (White-label Aggregator)

---

## 1. Executive Summary

Solosmartpay memposisikan diri sebagai payment gateway multi-channel di Indonesia untuk QRIS, Virtual Account (VA), E-Wallet, dan Retail. Hasil reverse-engineering kode klien, HTTP headers, API endpoints, bundle JavaScript, SDK publik, dan MCP server membuktikan bahwa **Solosmartpay bukanlah prinsipal atau acquirer langsung**, melainkan **layer wrapper / sub-aggregator** di atas agregator resmi (**Duitku**) yang dikombinasikan dengan sistem mutasi kode unik (1–999) untuk memotong biaya QRIS mikro.

---

## 2. Tech Stack Decomposition

### A. Frontend Layer
| Komponen | Teknologi | Bukti Observasi |
|---|---|---|
| **Framework** | **Laravel Livewire v3** | Script tag `/livewire-87de35d6/livewire.min.js?id=a964a3c8`, atribut `wire:navigate`, `data-navigate-once="true"`, morph DOM comments `<!--[if BLOCK]>`. |
| **Bundler & Tooling** | **Vite** | Asset loading pattern `/build/assets/app-*.js`, `/build/assets/public-*.css`, dynamic imports `__vite__mapDeps`. |
| **Styling** | **Tailwind CSS** | Utility classes (`slate`, `blue`, `emerald`), custom CSS variables `--primary`, `--ring`, dark mode theme storage di `localStorage.ak_theme` dan cookie `ak_dark`. |
| **Realtime / Websockets** | **Laravel Echo + Pusher/Reverb Client** | Bundle `/build/assets/realtime-*.js` mendefinisikan connector class `Illuminate\Notifications\Events\BroadcastNotificationCreated`, event `whisper`, dan string protocol Pusher/Reverb. |
| **Visualisasi / Charts** | **Chart.js / ApexCharts** | Bundle `/build/assets/charts-*.js` dan canvas container `.ssp-chart-box canvas`. |
| **Embedded Checkout Widget** | **Vanilla JS Modal / Popup** | Script standalone `https://solosmartpay.com/embed.js` (SRI hash `sha384-thD4G...`), package `@solosmartpay/node/browser` dengan method `openCheckout()`. |
| **Analytics & SEO** | **Google Tag Manager** | Container ID `G-0WXHWG72NH`, JSON-LD schema `@type: Service` & `Organization`. |

### B. Backend & API Layer
| Komponen | Konfigurasi | Bukti Observasi |
|---|---|---|
| **Core Framework** | **Laravel (PHP 8.2+ / 8.3)** | Set-Cookie headers: `XSRF-TOKEN` dan `solosmartpay-session` terenkripsi format Laravel (JSON base64 berisi `iv`, `value`, `mac`, `tag`). CSRF token di meta tags. |
| **API Architecture** | **RESTful JSON (`/v1`)** | Base URL `https://solosmartpay.com/v1`, autentikasi `X-API-Token` (`ssp_` / `ssp_test_`), header `Idempotency-Key` (8–100 char), rate limiting `X-RateLimit-Limit: 120 req/min`. |
| **Execution Pattern** | **Asynchronous Provisioning (`202 Accepted`)** | Pembuatan tagihan `POST /v1/qris` dan `POST /v1/payments` tidak langsung menghasilkan tagihan instan; mengembalikan `202 Accepted` dengan header `Location` dan `Retry-After: 2`, status `queued` -> polling ke `GET /v1/*/{id}` sampai `ready`. |
| **Webhook Delivery** | **HMAC-SHA256 Signed + Exponential Backoff** | Header `X-SoloSmartPay-Signature: sha256={hmac}`, `X-SoloSmartPay-Timestamp`, anti-replay window 300s, 8x retry schedule (10s, 1m, 5m, 30m, 2h, 12h, 24h). |
| **AI / Developer MCP** | **Model Context Protocol (HTTP Stream)** | Endpoint publik `https://solosmartpay.com/mcp` (JSON-RPC 2.0 tools: `get_integration_guide`, `search_docs`, `get_section`, `list_payment_methods`) dan index crawler `/llms.txt`. |

### C. Edge, Network & Infrastructure
| Komponen | Detail |
|---|---|
| **Reverse Proxy & WAF** | **Cloudflare** (`CF-RAY: a4f9f6c90b9337e5-CDG`, server header `cloudflare`, H3/QUIC support). |
| **Security Headers** | `strict-transport-security: max-age=31536000`, `x-frame-options: SAMEORIGIN`, `x-content-type-options: nosniff`, `cross-origin-opener-policy: same-origin`. |
| **DNS / Hosting** | Cloudflare Anycast IPs (`104.21.9.224`, `172.67.161.93`). |

---

## 3. Reverse-Engineering Upstream Providers & Channel Origin

### Bukti Identifikasi Upstream: Duitku (PT Duitku Cyber Global)
Melalui endpoint MCP `list_payment_methods` dan SDK WooCommerce (`class-ssp-gateway.php`), Solosmartpay mengekspos kode metode internal dua karakter berikut:

```
M2 : Mandiri Virtual Account
I1 : BNI Virtual Account
BR : BRI Virtual Account
BT : Permata Virtual Account
B1 : CIMB Niaga Virtual Account
A1 : ATM Bersama Virtual Account
OV : OVO
SA : ShopeePay
LA : LinkAja
VA : Maybank Virtual Account
FT : Gerai Retail (Alfamart / Pegadaian / Pos - Finnet)
AG : Bank Artha Graha VA
S1 : Bank Sahabat Sampoerna VA
NC : Bank Neo Commerce (BNC) VA
DM : Danamon Virtual Account
BV : BSI Virtual Account
```

**Analisis Forensik**:
Daftar kode 2 karakter di atas identik 100% dengan **spesifikasi kamus channel Duitku API** (`docs.duitku.com/api/en`). Tidak ada payment gateway lain di Indonesia yang menggunakan mapping kode persis `M2` (Mandiri), `I1` (BNI), `BT` (Permata), `B1` (CIMB), `FT` (Finnet Retail), `S1` (Sampoerna), dan `AG` (Artha Graha).

### Mekanisme QRIS: Mutasi Nominal & Kode Unik (1–999)
Berbeda dengan Virtual Account yang di-forward ke Duitku, QRIS Solosmartpay beroperasi dengan pola **Kode Unik Otomatis** ("Auto-Check Mutasi"):
1. Saat merchant membuat tagihan Rp 100.000, sistem membubuhkan kode unik acak/sekuensial (contoh: +Rp 7).
2. Pelanggan diminta mentransfer tepat Rp 100.007.
3. Backend memeriksa data mutasi rekening penampung (bank account / merchant static QRIS) secara periodik / via webhook mutasi.
4. Nominal Rp 100.007 yang masuk dicocokkan dengan order aktif.
5. Biaya: tagihan ≤ Rp 500.000 hanya dikenakan biaya flat Rp 300, sedangkan > Rp 500.000 dikenakan 0,5% (0,3% pemrosesan + 0,2% Solosmartpay).

---

## 4. Kelemahan Teknis & Beban Biaya Arsitektur Saat Ini

1. **Margin Bertingkat (Double-Hop Pricing)**:
   - Karena menjadi sub-aggregator di atas Duitku, Solosmartpay harus menaikkan tarif agar menghasilkan margin:
     - Biaya VA modal Duitku: ~Rp 1.800 – Rp 3.000
     - Biaya VA Solosmartpay ke merchant: **Rp 3.300 – Rp 4.300**
     - Biaya E-Wallet: ShopeePay mencapai **4,25%**, OVO mencapai **3,28%**.
2. **Resource Inefficiency akibat Queue Polling (202 Accepted)**:
   - Pola pembuatan tagihan async memaksa setiap klien API melakukan polling `GET /v1/*/{id}` tiap 1–2 detik hingga `ready`.
   - Polling berulang membebani PHP-FPM worker, database read connection, dan jaringan.
3. **Batas Konkurensi & Risiko Mutasi Kode Unik**:
   - Kode unik 1–999 membatasi transaksi nominal sama menjadi maksimal 999 transaksi aktif bersamaan dalam jendela kedaluwarsa 15 menit.
   - Risiko human error: pelanggan salah transfer nominal (tidak memasukkan kode unik) menyebabkan tagihan gantung dan eskalasi CS manual.
4. **Ketergantungan Tunggal (Single Point of Failure)**:
   - Jika koneksi upstream Duitku mengalami gangguan atau maintenance, seluruh channel VA, E-Wallet, dan Retail di Solosmartpay ikut mati tanpa automatic fallback ke provider sekunder.

---

## 5. Analisis Regulasi MDR Bank Indonesia & Akuisisi Kategori UMI (Usaha Mikro)

### A. Bedah Skema MDR Resmi Bank Indonesia (PBI No. 25/7/PBI/2023)
MDR (*Merchant Discount Rate*) adalah potongan resmi interchange fee yang dipotong oleh pihak bank/acquirer dari nilai transaksi bruto sebelum dana diteruskan ke merchant:
- **Usaha Mikro (UMI) Transaksi ≤ Rp 100.000**: **MDR 0% (Gratis / Nol Rupiah)**. Bank tidak memotong sepeser pun.
- **Usaha Mikro (UMI) Transaksi > Rp 100.000**: **MDR 0,3%**. Potongan bank hanya Rp 300 per kelipatan Rp 100.000.
- **Usaha Kecil (UKE), Usaha Menengah (UME), Usaha Besar (UBE)**: **MDR 0,7%**.

**Korelasi dengan Model Bisnis Solosmartpay**:
Solosmartpay memanfaatkan subsidi MDR 0% ini untuk transaksi kecil (≤ Rp 500.000). Saat membebankan fee flat Rp 300 ke merchant untuk transaksi di bawah Rp 100.000, biaya modal mereka ke perbankan adalah Rp 0, sehingga menghasilkan **margin kotor 100%**.

### B. Kriteria Legalitas Kategori UMI
Berdasarkan UU No. 20/2008 dan PP No. 7/2021, kriteria Usaha Mikro di Indonesia:
1. **Modal Usaha**: Maksimal Rp 1 Miliar (di luar tanah dan bangunan tempat usaha).
2. **Hasil Penjualan / Omzet Tahunan**: Maksimal Rp 2 Miliar per tahun.

### C. Panduan Langkah Mendapatkan Status QRIS UMI
1. **Penerbitan NIB Perseorangan Gratis via OSS (`oss.go.id`)**:
   - Login menggunakan NIK KTP pemilik usaha.
   - Pilih skala usaha: **"Mikro"**.
   - Pilih KBLI perdagangan eceran / ritel umum (contoh: KBLI 47912 untuk perdagangan ritel via internet).
   - Dokumen NIB langsung terbit instan tanpa biaya (Rp 0).
2. **Pendaftaran Merchant ke Acquirer**:
   - Daftarkan akun merchant perorangan di Acquirer QRIS (misal: BCA Merchant, Livin' Usaha Mandiri, DANA Bisnis, ShopeePay Merchant, atau mitra PayFac Bank Nobu/Netzme).
   - Upload NIK KTP, NIB OSS Skala Mikro, dan foto bukti usaha/toko online.
   - Pilih opsi omzet: **"< Rp 300 Juta / tahun"**.
   - Acquirer mendaftarkan NMID merchant ke ASPI dengan tag status MDR **UMI (0% / 0,3%)**.
3. **Aturan Krusial Lolos Verifikasi UMI**:
   - **Hindari Pendaftaran Entitas PT**: Perseroan Terbatas (PT) otomatis diklasifikasikan ke UKE/UME (MDR 0,7%). Gunakan nama perorangan atau CV mikro.
   - **Kesesuaian Identitas Rekening**: Nama di KTP, NIB OSS, dan rekening penampung wajib identik.

### D. Toleransi Threshold Anti-Blokir Rekening Mutasi Mikro
Meskipun transaksi nominal kecil (Rp 10.000 – Rp 100.000) berada di bawah batas pelaporan PPATK (Rp 500 juta) dan batas pantau AML manual (Rp 10 juta), rekening tetap terancam diblokir otomatis oleh AI fraud detection bank jika menerima frekuensi tinggi:
- **Pemicu Blokir**: Pola transaksi beruntun (*burst transactions*) dengan ekor kode unik acak menyerupai pola rekening deposit judi online.
- **Ambang Batas Aman per Rekening**:
  - **Frekuensi Maksimal**: 30 – 50 transaksi / hari per rekening.
  - **Omzet Maksimal**: Rp 2.000.000 – Rp 3.000.000 / hari per rekening.
  - **Rotasi Cluster**: Wajib menggunakan pool 5–10 rekening QRIS yang dirotasi secara *round-robin* jika volume transaksi platform melebihi 100 transaksi per hari.
