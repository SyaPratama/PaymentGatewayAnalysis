[← Master Report](../../payment-gateway-research.md) | [← Category G: Commercial Free-Tier Gateways](../G-commercial-free-tier-gateways.md)

---

# Adyen — Deep-Dive Report

> The global enterprise benchmark in direct acquiring, interchange++ pricing, and unified commerce.

---

## 1. Overview

Adyen is the undisputed enterprise powerhouse in global payment processing, handling hundreds of billions for Uber, Spotify, Microsoft, and McDonald's. Operating with direct acquiring bank licenses rather than acting as a reseller, Adyen bypasses intermediaries to deliver Interchange++ pricing, unified cross-channel commerce, and peak transaction resilience.

---

## 2. Key Features

- **Direct End-to-End Acquiring** — Acts as gateway, risk management, and acquiring bank on a single technical platform.
- **Interchange++ Pricing** — Complete transparency into actual card network fees without hidden markups.
- **250+ Local Payment Methods** — Native local payment schemes worldwide (iDEAL, Pix, Boleto, WeChat Pay, Bancontact).
- **RevenueAccelerate Engine** — Machine learning to retry failed transactions with dynamic messaging formats.
- **Unified Commerce** — True synchronization of physical in-store terminals and digital checkouts.

---

## 3. Fee Structure

- **Per Transaction**: €0.11 fixed fee + interchange fee (~0.2%–1.5%) + card scheme fee (~0.1%–0.3%)
- **Monthly Minimum**: Typically requires minimum invoicing commitments ($50K+ GMV)
- **Setup Fee**: $0

---

## 4. Pros & Cons

### Pros
1. Significantly cheaper than flat-rate gateways (Stripe/PayPal) at transaction volumes above $100K/month
2. Highest card authorization success rates in the industry
3. Global enterprise compliance and financial stability

### Cons
1. Strict minimum processing volume requirements (typically >$50,000–$100,000/month)
2. Lengthy enterprise underwriting and contract negotiations
3. Complex setup and integration compared to drop-in developer gateways

---

## 5. Links & Reference

- **Official Website**: https://adyen.com
- **Developer Documentation**: https://docs.adyen.com
