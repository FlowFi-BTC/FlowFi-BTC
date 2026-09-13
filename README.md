# FlowFi BTC — Project Overview

## Bitcoin-Native Receivables Financing Infrastructure

**FlowFi BTC** is a two-contract Clarity protocol on Stacks that lets a verified business register a real trade receivable and receive financing directly from an sBTC holder — non-custodially, transparently, and without a pooled fund or a marketplace.

This document is the product-level overview for the repository. For the grant-specific pitch, see [APPLICATION_NARRATIVE.md](./grant-application/APPLICATION_NARRATIVE.md). For contract internals, see [TECHNICAL_ARCHITECTURE.md](./grant-application/TECHNICAL_ARCHITECTURE.md).

---

## The Problem

Small and growing businesses frequently have money locked inside unpaid invoices. A business may complete a $2,000 service today, but its customer may not pay for 30, 60, or 90 days. The business has earned the money but cannot use it yet.

At the same time, Bitcoin holders who bridge into sBTC have very few ways to deploy that capital into the real economy — sBTC utility today is concentrated in DeFi lending, liquidity provision, and trading.

FlowFi BTC connects these two gaps with one narrow, honest financing primitive.

---

## The Solution

```
Verified Business
      ↓
Registered Receivable
      ↓
Capital Provider Reviews
      ↓
sBTC Funding (escrow)
      ↓
Release to Business
      ↓
Repayment or Default
      ↓
Settlement (on-chain)
```

A business completes verification once. Once verified, it can register a receivable. A capital provider reviews the receivable's information and verification status, then funds it directly through their own wallet — FlowFi BTC never takes custody of a user's private key.

---

## How It Works

### 1. Business Registration & Verification

A business connects its Stacks wallet, registers, and completes verification — for this pilot, a demo-stage Manual Pilot Review, or a completed third-party KYB integration if that path finishes in time (see [RISK_DISCLOSURE.md](./grant-application/RISK_DISCLOSURE.md)). The result is recorded on-chain as a status, method, and level, alongside a hash of the underlying evidence.

### 2. Receivable Registration

A verified business registers one receivable: debtor, invoice reference, face value, funding amount, and due date. Only the invoice hash goes on-chain — the document itself stays off-chain.

### 3. Capital Provider Review & Funding

A capital provider connects their wallet, reviews the receivable's details and verification status, and chooses to fund it. Funding moves sBTC from the provider's wallet into the escrow contract.

### 4. Escrow & Release

Once funding is confirmed, the escrow contract releases the funds to the business. This two-step design (escrow, then release) makes the funding state easier to reason about and audit than an atomic pass-through.

### 5. Repayment or Default

Repayment happens either directly on-chain in sBTC, or through confirmed off-chain fiat settlement reflected on-chain — see the Repayment Boundary section in [RISK_DISCLOSURE.md](./grant-application/RISK_DISCLOSURE.md) for why this distinction exists and how it's handled honestly. If the due date passes without repayment, the receivable is marked defaulted — a recorded, transparent outcome, not a resolved dispute.

---

## Smart Contract Architecture (Summary)

Two contracts, strictly separated by responsibility:

| Contract | Owns |
|---|---|
| `flowfi-registry.clar` | Business identity, verification, receivable metadata and lifecycle status |
| `flowfi-escrow.clar` | sBTC custody, funding, release, repayment, default |

Full detail, including data models and function signatures, in [TECHNICAL_ARCHITECTURE.md](./grant-application/TECHNICAL_ARCHITECTURE.md).

---

## What This MVP Is Not

- Not a marketplace or multi-provider investment pool
- Not a consumer investment product
- Not an automated KYB/AML system
- Not a fiat-to-sBTC exchange service
- Not a platform claiming to independently verify every receivable beyond what its stated verification method actually performed

---

## Current Status

| Component | Status |
|---|---|
| Contract architecture | Finalized — see `TECHNICAL_ARCHITECTURE.md` |
| Demo verification flow | Built |
| Off-chain API layer | Built |
| Frontend (dashboard + public receivable page) | Built |
| Test suite | Done — 46/46 passing (26 registry + 20 escrow + 2 integration paths) |
| Security self-review | See [SECURITY_REVIEW.md](./grant-application/SECURITY_REVIEW.md) |

---

## Links

- **Repository:** https://github.com/FlowFi-BTC/FlowFi-BTC
- **Grant Application:** [APPLICATION_NARRATIVE.md](./grant-application/APPLICATION_NARRATIVE.md)
- **Risk Disclosure:** [RISK_DISCLOSURE.md](./grant-application/RISK_DISCLOSURE.md)
- **Roadmap:** [ROADMAP.md](./grant-application/ROADMAP.md)
