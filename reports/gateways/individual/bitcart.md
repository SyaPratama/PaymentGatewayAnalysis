[← Master Report](../../payment-gateway-research.md) | [← Category B: Self-Hosted Crypto Gateways](../B-crypto-gateways.md)

---

# Bitcart — Deep-Dive Report

> Open-source, non-custodial multi-cryptocurrency platform powered by FastAPI and Vue.js.

---

## 1. Overview

Bitcart is an open-source, self-hosted cryptocurrency platform developed in Python (FastAPI) with a Vue.js merchant dashboard. Designed as a flexible, multi-currency alternative to BTCPay Server, Bitcart provides native support for Bitcoin, Lightning Network, Monero, Litecoin, Ethereum, and major stablecoins (USDT, USDC) without relying on third-party custodial services.

Bitcart's modular microservices architecture allows merchants to enable only the coin daemons they actually intend to accept, significantly conserving server memory and disk space compared to running monolithic multi-node systems.

---

## 2. Key Features

- **Multi-Cryptocurrency Support** — Native integrations for BTC, LN, LTC, XMR, ETH, BCH, and ERC-20/TRC-20 tokens.
- **Native Monero (XMR) Privacy** — Integrated view-only wallet support for untraceable customer payments.
- **Async Python Architecture** — Built with FastAPI, Starlette, and Celery for high-throughput asynchronous event handling.
- **Docker Compose Deployment** — Modular deployment configuration allowing one-command setup.
- **REST & WebSocket API** — Real-time invoice status streaming via WebSockets directly to checkout frontends.

---

## 3. Pros & Cons

### Pros
1. Native multi-coin and privacy coin (Monero) support out of the box
2. Clean, modern Python codebase that is easy to extend
3. Modern Vue.js merchant dashboard with real-time WebSocket updates
4. 100% free and open-source under permissive MIT license

### Cons
1. Smaller user base and plugin ecosystem compared to BTCPay Server
2. Running multiple coin nodes simultaneously requires substantial storage (NVMe SSD)
3. Fewer turnkey e-commerce extensions available

---

## 4. Links & Reference

- **Official Website**: https://bitcart.ai
- **GitHub Repository**: https://github.com/bitcart/bitcart
- **Documentation**: https://docs.bitcart.ai
