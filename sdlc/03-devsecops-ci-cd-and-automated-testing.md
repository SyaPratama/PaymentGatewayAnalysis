# DevSecOps, Otomasi Pipeline CI/CD, dan Piramida Pengujian Finansial

Dokumen ini mendefinisikan piramida pengujian perangkat lunak sistem pembayaran (*Testing Pyramid*), perancangan alur integrasi berkelanjutan (*CI/CD Pipeline*) dengan audit keamanan otomatis (*SAST, SCA, Secret Scanning*), pengerasan citra kontainer (*Container Hardening*), serta strategi penyebaran *Blue-Green* dan *Canary*.

---

## 1. Piramida Pengujian Sistem Finansial (Testing Pyramid)

Dalam domain fintech, pengujian harus menjamin kebenaran logika domain tanpa membuat siklus pengujian di CI berjalan lambat.

```
                   / \
                  /   \
                 / E2E \       <-- 5% Kontrak & Uji Upstream Bank (WireMock/Pact)
                /-------\
               / Integr. \     <-- 25% Basis Data Nyata (Testcontainers Postgres/Redis)
              /-----------\
             /  Unit Tests \   <-- 70% Logika Domain Finansial Murni & Invarian FSM
            /---------------\
```

### 1.1 Tiga Lapisan Pengujian

1. **Unit Test (70% - Cepat, In-Memory, Eksekusi < 10 Detik)**:
   - *Target*: Perhitungan nilai moneter (`Money`), kalkulasi potongan biaya merchant (*MDR*), transisi status FSM, dan validasi tanda tangan kriptografi HMAC/RSA.
   - *Karakteristik*: Dilarang melakukan I/O disk atau panggilan jaringan. Menggunakan *mock* atau *stub* untuk dependensi luar.
2. **Integration Test (25% - Menengah, Berbasis Kontainer, Eksekusi 1-3 Menit)**:
   - *Target*: Integritas transaksi basis data PostgreSQL (memverifikasi *trigger zero-sum balance* dan *row-level locking*), pembacaan/penulisan atomic lock di Redis.
   - *Alat Bantu*: Menggunakan pustaka `testcontainers-go` untuk memutar kontainer PostgreSQL dan Redis sementara yang bersih pada setiap pengujian.
3. **End-to-End Contract Testing (5% - Komprehensif)**:
   - *Target*: Verifikasi kecocokan spesifikasi API terhadap simulator gateway bank mitra (SNAP BI BCA/Mandiri).
   - *Alat Bantu*: Menggunakan `WireMock` atau `Pact` untuk memastikan format header, payload tanda tangan kriptografi, dan kode galat bank terverifikasi tanpa membebani lingkungan sandbox perbankan langsung.

---

## 2. Pipeline CI/CD Otomatis dengan Keamanan Berlapis (GitHub Actions)

Setiap *pull request* wajib melalui gerbang pemindaian keamanan (*Security Gates*) sebelum disetujui.

```
[ Developer Push Code ]
           |
           v
+---------------------------------------------------------------+
| TAHAP 1: CODE QUALITY & LINTING                               |
| - Format Check & Static Analysis (golangci-lint / eslint)     |
+---------------------------------------------------------------+
           |
           v
+---------------------------------------------------------------+
| TAHAP 2: DEVSECOPS SECURITY SCANNING                          |
| - Secret Scanning (Gitleaks): Deteksi API key & private key   |
| - SAST (gosec / semgrep): Analisis kerentanan injeksi kode    |
| - SCA (govulncheck / trivy): Audit kerentanan CVE pustaka luar|
+---------------------------------------------------------------+
           |
           v
+---------------------------------------------------------------+
| TAHAP 3: AUTOMATED TESTING SUITE                              |
| - Unit Tests (Cakupan Domain > 90%)                           |
| - Integration Tests (PostgreSQL via Testcontainers)           |
+---------------------------------------------------------------+
           |
           v
+---------------------------------------------------------------+
| TAHAP 4: CONTAINER BUILD & HARDENING                          |
| - Multi-Stage Dockerfile -> Distroless Non-Root Image         |
| - Image Vulnerability Scan (Trivy Container Scan)             |
+---------------------------------------------------------------+
           |
           v
[ Deploy ke Produksi via Canary / Blue-Green ]
```

### 2.1 Konfigurasi Pipeline GitHub Actions Rujukan

```yaml
name: Financial Gateway CI Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  security-and-lint:
    name: Security Scan & Lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect Hardcoded Secrets
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'
          cache: true

      - name: Static Security Analysis (SAST)
        run: |
          go install github.com/securego/gosec/v2/cmd/gosec@latest
          gosec -quiet -exclude-dir=test ./...

      - name: Software Composition Analysis (SCA)
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./...

      - name: Golang Linter
        uses: golangci/golangci-lint-action@v4
        with:
          version: v1.56

  test-suite:
    name: Test Execution
    needs: security-and-lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Run Unit & Integration Tests
        run: |
          go test -v -race -coverprofile=coverage.out ./...
        env:
          TESTCONTAINERS_RYUK_DISABLED: "false"

      - name: Verify Minimum Coverage (90%)
        run: |
          COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print substr($3, 1, length($3)-1)}')
          echo "Current Total Coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 90.0" | bc -l) )); then
            echo "FAILED: Test coverage ($COVERAGE%) di bawah ambang batas minimal 90%"
            exit 1
          fi
```

---

## 3. Pengerasan Citra Kontainer (Container Image Hardening)

Citra kontainer yang menjalankan gateway finansial dilarang keras memuat paket shell (`/bin/sh`, `/bin/bash`), pustaka kompilator, atau utilitas jaringan (*curl*, *wget*) yang dapat dieksploitasi penyerang saat terjadi *Remote Code Execution* (RCE).

### 3.1 Multi-Stage Build dengan Google Distroless

```dockerfile
# -------------------------------------------------------------
# Tahap 1: Builder (Kompilasi Biner Go)
# -------------------------------------------------------------
FROM golang:1.22-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git ca-certificates tzdata

COPY go.mod go.sum ./
RUN go mod download

COPY . .
# Kompilasi statis tanpa dependensi pustaka C (CGO_ENABLED=0)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -extldflags '-static'" \
    -o /app/bin/tamaku-gateway ./cmd/api/main.go

# -------------------------------------------------------------
# Tahap 2: Runtime Image (Google Distroless Non-Root)
# -------------------------------------------------------------
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /
# Salin biner dari tahap builder
COPY --from=builder /app/bin/tamaku-gateway /tamaku-gateway
# Salin sertifikat CA dan zona waktu
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Jalankan sebagai non-root user (UID 65532)
USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/tamaku-gateway"]
```

---

## 4. Strategi Penyebaran Tanpa Downtime: Blue-Green vs Canary Release

### 4.1 Blue-Green Deployment
Menyiapkan dua lingkungan produksi identik: Lingkungan Biru (*Active*) dan Lingkungan Hijau (*Idle*).

```
                      [ Load Balancer / Ingress Router ]
                                       |
                  +--------------------+--------------------+
                  | (100% Traffic)                          | (0% Traffic)
                  v                                         v
        +-------------------+                     +-------------------+
        | LINGKUNGAN BIRU   |                     | LINGKUNGAN HIJAU  |
        | (Versi v1.4.0)    |                     | (Versi v1.5.0)    |
        +-------------------+                     +-------------------+
```
- **Kelebihan**: Pengalihan seketika (*instant switch*) dan *rollback* mudah jika terjadi galat (cukup alihkan kembali rute router).
- **Kekurangan Finansial**: Membutuhkan kapasitas server dua kali lipat, dan berisiko memutus koneksi WebSocket/HTTP panjang yang sedang berjalan.

### 4.2 Canary Release Berbasis Metrik Prometheus

Mengarahkan sebagian kecil lalu lintas transaksi nyata ke versi baru secara bertahap sambil memantau tingkat galat (*error rate*) dan latensi.

```
[ Lalu Lintas Masuk (100%) ]
        |
        +---> 95% ke Versi Stabil (v1.4.0)
        |
        +---> 5% ke Versi Baru (Canary v1.5.0)
                 |
                 v
        [ Prometheus Metric Monitor ]
        - HTTP 5xx Error Rate > 0.1%?
        - Latensi P99 > 800 ms?
        - Anomali Transaksi Gagal Bank Upstream?
                 |
        +--------+--------+
        |                 |
     (YA: Galat)     (TIDAK: Stabil)
        |                 |
        v                 v
   ROLLBACK OTOMATIS  Tingkatkan ke 20% -> 50% -> 100%
   (Durasi < 15 Detik)
```
Pola Canary direkomendasikan untuk perubahan pada modul integrasi perbankan, di mana anomali perilaku bank baru dapat dideteksi pada skala kecil sebelum berdampak luas pada seluruh merchant.
