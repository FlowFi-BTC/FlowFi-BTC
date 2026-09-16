# FlowFi BTC — Technical Architecture

---

## Live Deployment

| Component | Address / URL |
|---|---|
| **Network** | Stacks Testnet |
| `registry.clar` | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry` — [view on Explorer](https://explorer.hiro.so/txid/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry?chain=testnet) |
| `escrow.clar` | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow` — [view on Explorer](https://explorer.hiro.so/txid/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow?chain=testnet) |
| **Frontend** | [https://flowfi-btc.vercel.app/](https://flowfi-btc.vercel.app/) |

*Verify these links resolve to the correct deployed source before citing them in any external submission — always confirm on the Explorer's testnet view, not mainnet.*

---

## System Overview

FlowFi BTC is a two-layer protocol: two Clarity contracts, and a frontend + thin off-chain API layer for verification data and read convenience.

```
┌─────────────────────────────────────────────────────────┐
│                       Frontend                            │
│         https://flowfi-btc.vercel.app/                    │
│  ┌──────────────┐         ┌──────────────────────────┐  │
│  │  Business     │         │  Public Receivable Page   │  │
│  │  Dashboard    │         │  (wallet-aware actions)   │  │
│  └──────┬────────┘         └───────────┬───────────────┘  │
└─────────┼───────────────────────────────┼─────────────────┘
          │ @stacks/connect (wallet tx signing)              
          │ Hiro API (reads)                                 
          ▼                               ▼
┌───────────────────────────────────────────────────────────┐
│                Stacks Blockchain (Testnet)                 │
│  ┌────────────────────┐    ┌──────────────────────────┐   │
│  │  flowfi-registry    │◄──►│      flowfi-escrow         │   │
│  │                     │    │                            │   │
│  │  - businesses       │    │  - fund-receivable          │   │
│  │  - verification     │    │  - release-funds  (ADMIN)   │   │
│  │  - receivables      │    │  - repay-receivable          │   │
│  │  - lifecycle state  │    │  - mark-default (roadmap)     │   │
│  └─────────────────────┘    └───────────┬──────────────┘   │
│                                          │                    │
│                                          ▼                    │
│                                    sBTC (SIP-010)              │
└───────────────────────────────────────────────────────────┘
          ▲
          │ verification record (hashed)
          │
┌─────────┴─────────────────────────────────────────────────┐
│              Off-chain: Verification & API Layer             │
│  - Demo/manual pilot review, or third-party KYB provider     │
│  - Normalizes result into one schema regardless of source    │
│  - Stores full evidence off-chain; hashes reference on-chain │
└───────────────────────────────────────────────────────────────┘
```

---

## Smart Contract Architecture

FlowFi BTC uses exactly two contracts. This split follows a deliberate rule: **`flowfi-registry` owns protocol state (who, what, and what status); `flowfi-escrow` owns money (custody and movement).** Neither contract duplicates the other's responsibility.

### flowfi-registry — Identity, Verification & Receivable State

Answers: *who is this business, was it verified, what receivable exists, and what state is it in?*

**Business record:**
```clarity
{
  business-id:            uint,
  owner:                  principal,
  business-name:          (string-ascii 100),
  country:                (string-ascii 2),
  verification-status:    uint,  ;; 0=UNVERIFIED 1=VERIFIED 2=EXPIRED 3=REVOKED
  verification-method:    uint,  ;; 0=MANUAL 1=CAC 2=PERSONA 3=OPENCORPORATES 4=PARTNER 5=OTHER
  verification-level:     uint,  ;; 0=NONE 1=BASIC 2=ENHANCED 3=FULL_KYB
  verified-at:            uint,
  verification-expiry:    uint,
  verified-by:            principal,
  verification-reference-hash: (buff 32),
  verification-proof-hash:     (buff 32),
  created-at:             uint
}
```

**Receivable record:**
```clarity
{
  receivable-id:   uint,
  business-id:     uint,
  debtor-name:     (string-ascii 100),
  debtor-country:  (string-ascii 2),
  invoice-number:  (string-ascii 100),
  invoice-hash:    (buff 32),
  face-value:      uint,
  funding-amount:  uint,
  issue-date:      uint,
  due-date:        uint,
  status:          uint,  ;; 0=DRAFT 1=OPEN 2=FUNDED 3=REPAID 4=DEFAULTED 5=CANCELLED
  escrow-id:       uint,
  created-at:      uint
}
```

**Public functions:**

| Function | Caller | Effect |
|---|---|---|
| `register-business` | any wallet (one business per wallet) | Creates business record, status UNVERIFIED |
| `verify-business` | authorized verifier only (`u100` otherwise) | Sets verification status/method/level/expiry/hashes |
| `revoke-verification` | authorized verifier only | Sets status to REVOKED |
| `is-business-verified` | anyone (read-only) | Returns current verification status |
| `register-receivable` | business owner, only if business is VERIFIED (`u105`/`u106` otherwise) | Creates receivable, status OPEN |
| `cancel-receivable` | business owner, only if status OPEN | Sets status CANCELLED |
| `mark-funded` / `mark-repaid` / `mark-defaulted` | **`flowfi-escrow` contract only**, via `contract-caller` | Updates receivable status |
| `get-business` / `get-receivable` / `get-receivable-status` | anyone (read-only) | Returns records |

**Key rule:** `mark-funded`, `mark-repaid`, and `mark-defaulted` check `contract-caller == flowfi-escrow`. No wallet — including the business or provider — can call these directly.

### flowfi-escrow — sBTC Custody, Funding & Settlement

Answers: *where is the sBTC, who funded the receivable, and where should it go?*

**Escrow record (one receivable → one funding position → one funder, for this pilot):**
```clarity
{
  escrow-id:        uint,
  receivable-id:    uint,
  funder:           principal,
  business:         principal,
  funding-amount:   uint,
  funded-at:        uint,
  status:           uint,  ;; 0=OPEN 1=FUNDED 2=REPAID 3=DEFAULTED
  repaid-at:         uint,
  settled-at:        uint
}
```

**Public functions:**

| Function | Caller | Effect |
|---|---|---|
| `fund-receivable` | capital provider (investor wallet, not the business — `u205` otherwise) | Checks receivable is OPEN in registry, transfers sBTC from provider into escrow, creates escrow record, calls `registry.mark-funded` |
| `release-funds` | **admin wallet only** (`u200` otherwise) | Checks escrow is FUNDED and not already released, transfers sBTC from escrow to business |
| `repay-receivable` | business, only after release (`u208`/`u209` otherwise) | Transfers a flat repayment equal to `funding-amount` from business to provider, calls `registry.mark-repaid` |
| `mark-default` | admin wallet, only if `block-height > due-date` | Calls `registry.mark-defaulted` — **on the roadmap; current MVP handles default as an off-chain admin action, not yet wired to this on-chain function** |
| `get-escrow` | anyone (read-only) | Returns escrow record |

**Funding flow (escrow-then-release, chosen deliberately for clearer state reasoning):**
```
Capital Provider → fund-receivable() → sBTC moves to escrow → escrow record created
                                                              → registry.mark-funded()
Admin wallet     → release-funds()   → sBTC moves from escrow to business
```

### Important Design Note: Admin-Signs-Release

**`release-funds` requires a signature from a specific admin wallet — not the provider, not the business, not any arbitrary caller.** The admin for both contracts is a single Stacks wallet controlled by the lead developer, Oyewale Prudence ([@ProdevappOFFICIAL](https://github.com/ProdevappOFFICIAL)) — `CONTRACT-OWNER` set to `tx-sender` at deploy time, with **no multisig**. This is a deliberate MVP simplification, and it introduces two real risks worth stating plainly, not just one:

1. **Custody-adjacent trust:** the admin wallet controls *when* escrowed funds move to the business, even though it never has the power to redirect them elsewhere or withdraw them for itself — the contract logic only allows a transfer from escrow to the business, to the address recorded at funding time.
2. **Liveness risk:** if the admin never calls `release-funds`, funds sit in escrow indefinitely — there is no time-lock or automatic release in v1.0.0. The same applies to `mark-default` if the admin never calls it after the due date. See `RISK_DISCLOSURE.md` §10 for the full disclosure and the single-operator mitigation that applies only at this pilot's scale.

A future version could make release automatic, or governed by a time-lock or multi-signature rule, to remove this admin dependency; that is documented as a named prerequisite before any multi-provider expansion, not solved by the current MVP.

### Important Design Note: Flat Repayment (No Separate Interest/Fee Amount Yet)

**`repay-receivable` currently requires repayment of exactly `funding-amount` — the same amount that was funded, no more, no less.** There is no separate repayment/interest amount field wired into the contract yet, even though the original registry design anticipated one (`funding amount` vs. a future `repayment amount`, so interest or fees could be added without a contract redesign). For this pilot, repayment is flat by design, to keep the first real transaction as simple as possible to reason about and test. Adding a distinct repayment amount is explicitly deferred to a future version — see `ROADMAP.md`.

### Repayment Boundary — Read This Before Assuming On-Chain-Only Settlement

A smart contract cannot compel a real-world fiat payment. For this pilot, repayment happens one of two ways:

1. **Direct sBTC repayment** — if the business holds or acquires sBTC, it repays directly through `repay-receivable`, and sBTC moves from the business to the provider inside the same function (flat amount, per above).
2. **Off-chain fiat repayment, on-chain confirmation** — if the business's debtor pays in fiat and the business repays the provider outside the chain, an authorized party confirms this happened, and the registry records the state without moving sBTC. This is disclosed explicitly and is consistent with how other real-world-asset financing protocols handle the same boundary.

Both paths are documented in `RISK_DISCLOSURE.md`. Neither pretends the contract enforces real-world payment.

### Permission Model

| Role | Can call |
|---|---|
| Public / anyone | `get-business`, `get-receivable`, `is-business-verified`, `get-receivable-status`, `get-escrow` |
| Business wallet | `register-business`, `register-receivable`, `cancel-receivable`, `repay-receivable` (only after release) |
| Authorized verifier | `verify-business`, `revoke-verification` |
| Capital provider (investor wallet) | `fund-receivable` |
| **Admin wallet** | `release-funds`, `mark-default` (roadmap), deployment configuration (escrow contract address, verifier address, sBTC contract address) |
| `flowfi-escrow` contract (via registry) | `mark-funded`, `mark-repaid`, `mark-defaulted` |

---

## What's On-Chain vs. Off-Chain

| On-chain | Off-chain |
|---|---|
| Business ID, wallet, name, country | PDF invoices, KYB documents |
| Verification status/method/level, timestamps, proof hash | Identity information, director information, full verification reports |
| Receivable ID, invoice reference, invoice hash, face value, funding amount, due date, status | Business address, descriptions, uploaded evidence |
| Funder, funding amount, escrow status, timestamps | UI settings, notifications, analytics |

Sensitive documents never go on-chain — only their hashes. The full evidence lives in the off-chain verification/API layer.

---

## Frontend & Off-Chain API

| Layer | Technology |
|---|---|
| Frontend | Live at [flowfi-btc.vercel.app](https://flowfi-btc.vercel.app/), `@stacks/connect` for wallet signing, Hiro API for reads |
| Verification/API layer | Thin service normalizing verification results (manual review or third-party KYB) into one schema, storing evidence, exposing the on-chain hash reference. Full endpoint reference: `FRONTEND_API_DOCS.md` |

No custom backend holds funds or private keys. All value-moving transactions are wallet-signed by the user directly against the contracts, except for `release-funds` and `mark-default`, which require the admin wallet's signature (see design notes above).

---

## Test Infrastructure

```
Clarinet SDK + Vitest (simnet)
    │
    ├── registry_test.ts
    │   ├── register-business (duplicate prevention, ownership)
    │   ├── verify-business (verified/unverified/expired/revoked/unauthorized)
    │   ├── register-receivable (verified vs. unverified business, invalid amount/date)
    │   └── financial state restriction (only flowfi-escrow can call mark-*)
    │
    ├── escrow_test.ts
    │   ├── fund-receivable (open/already-funded/wrong-amount, investor-only)
    │   ├── release-funds (admin-only, correct release, cannot release twice)
    │   ├── repay-receivable (flat amount, only after release, double-repayment, already-defaulted)
    │   └── mark-default (before/after due date, already-repaid, already-defaulted)
    │
    └── integration_test.ts
        ├── full happy path: register → verify → register receivable → fund → release (admin) → repay (flat) → REPAID
        └── default path: register → verify → register receivable → fund → release → due date passes → default → DEFAULTED
```

---

## Deployment

### Testnet (Live)
- **Deployer / Contract address:** `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ`
- `flowfi-registry`: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry`
- `flowfi-escrow`: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow`
- **Frontend:** [https://flowfi-btc.vercel.app/](https://flowfi-btc.vercel.app/)
- Reads via Hiro API (testnet)

### Mainnet (Planned — Milestone 2)
- Not yet deployed. Mainnet deployment, and any change to the admin-release or flat-repayment simplifications, will be documented here when it happens.
- **`sbtc-contract` — being removed, not just gated:** `set-sbtc-contract` is being **removed from both contracts entirely** before mainnet deployment — a code change, not a configuration toggle. The mainnet contracts will have the sBTC address hardcoded to `SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token` (verified against current Stacks/Hiro documentation), with no function able to change it post-deploy. The updated contracts, without this function, are what will be submitted for Milestone 2 verification.
