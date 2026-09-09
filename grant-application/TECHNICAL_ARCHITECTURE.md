# FlowFi BTC — Technical Architecture

---

## System Overview

FlowFi BTC is a two-layer protocol: two Clarity contracts, and a frontend + thin off-chain API layer for verification data and read convenience.

```
┌─────────────────────────────────────────────────────────┐
│                       Frontend                            │
│  ┌──────────────┐         ┌──────────────────────────┐  │
│  │  Business     │         │  Public Receivable Page   │  │
│  │  Dashboard    │         │  (wallet-aware actions)   │  │
│  └──────┬────────┘         └───────────┬───────────────┘  │
└─────────┼───────────────────────────────┼─────────────────┘
          │ @stacks/connect (wallet tx signing)              
          │ Hiro API (reads)                                 
          ▼                               ▼
┌───────────────────────────────────────────────────────────┐
│                    Stacks Blockchain                       │
│  ┌────────────────────┐    ┌──────────────────────────┐   │
│  │   registry.clar     │◄──►│      escrow.clar          │   │
│  │                     │    │                            │   │
│  │  - businesses       │    │  - fund-receivable          │   │
│  │  - verification     │    │  - release-funds            │   │
│  │  - receivables      │    │  - repay-receivable          │   │
│  │  - lifecycle state  │    │  - mark-default               │   │
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

FlowFi BTC uses exactly two contracts. This split follows a deliberate rule: **`registry.clar` owns protocol state (who, what, and what status); `escrow.clar` owns money (custody and movement).** Neither contract duplicates the other's responsibility.

### registry.clar — Identity, Verification & Receivable State

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
| `verify-business` | authorized verifier only | Sets verification status/method/level/expiry/hashes |
| `revoke-verification` | authorized verifier only | Sets status to REVOKED |
| `is-business-verified` | anyone (read-only) | Returns current verification status |
| `register-receivable` | business owner, only if business is VERIFIED | Creates receivable, status OPEN |
| `cancel-receivable` | business owner, only if status OPEN | Sets status CANCELLED |
| `mark-funded` / `mark-repaid` / `mark-defaulted` | **authorized escrow contract only** | Updates receivable status |
| `get-business` / `get-receivable` / `get-receivable-status` | anyone (read-only) | Returns records |

**Key rule:** `mark-funded`, `mark-repaid`, and `mark-defaulted` check `contract-caller == authorized-escrow-contract`, configured at deployment. No wallet — including the business or provider — can call these directly. This prevents a random wallet from forging financing state.

### escrow.clar — sBTC Custody, Funding & Settlement

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
| `fund-receivable` | capital provider | Checks receivable is OPEN in registry, transfers sBTC from provider into escrow, creates escrow record, calls `registry.mark-funded` |
| `release-funds` | provider (or automatically post-funding, implementation choice) | Checks escrow is FUNDED and not already released, transfers sBTC from escrow to business |
| `repay-receivable` | business, or an authorized confirming party for off-chain-settled repayment (see Repayment Boundary below) | Confirms repayment, transfers sBTC to provider if repayment is on-chain, calls `registry.mark-repaid` |
| `mark-default` | provider, only if `block-height > due-date` and not already repaid | Calls `registry.mark-defaulted` |
| `get-escrow` | anyone (read-only) | Returns escrow record |

**Funding flow (Option B — escrow-then-release, chosen deliberately for clearer state reasoning):**
```
Capital Provider → fund-receivable() → sBTC moves to escrow → escrow record created
                                                              → registry.mark-funded()
                 → release-funds() → sBTC moves from escrow to business
```

### Repayment Boundary — Read This Before Assuming On-Chain-Only Settlement

A smart contract cannot compel a real-world fiat payment. For this pilot, repayment happens one of two ways:

1. **Direct sBTC repayment** — if the business holds or acquires sBTC, it repays directly through `repay-receivable`, and sBTC moves from the business to the provider inside the same function.
2. **Off-chain fiat repayment, on-chain confirmation** — if the business's debtor pays in fiat and the business repays the provider outside the chain (bank transfer, etc.), an authorized party confirms this happened, and `repay-receivable` records the state without moving sBTC. This is disclosed explicitly and is consistent with how other real-world-asset financing protocols handle the same boundary.

Both paths are documented in [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md). Neither path pretends the contract enforces real-world payment — it can only record what a trusted party attests happened.

### Permission Model

| Role | Can call |
|---|---|
| Public / anyone | `get-business`, `get-receivable`, `is-business-verified`, `get-receivable-status`, `get-escrow` |
| Business wallet | `register-business`, `register-receivable`, `cancel-receivable` |
| Authorized verifier | `verify-business`, `revoke-verification` |
| Capital provider | `fund-receivable`, `mark-default` (after due date) |
| Authorized escrow contract (via registry) | `mark-funded`, `mark-repaid`, `mark-defaulted` |
| Admin (deployment config only) | Sets escrow contract address, verifier address, sBTC contract address |

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
| Frontend | React/Next.js, `@stacks/connect` for wallet signing, Hiro API for reads |
| Verification/API layer | Thin service normalizing verification results (manual review or third-party KYB) into one schema, storing evidence, exposing the on-chain hash reference |

No custom backend holds funds or private keys. All value-moving transactions are wallet-signed by the user directly against the contracts.

---

## Test Infrastructure

```
Clarinet SDK + Vitest (simnet)
    │
    ├── registry_test.ts
    │   ├── register-business (duplicate prevention, ownership)
    │   ├── verify-business (verified/unverified/expired/revoked/unauthorized)
    │   ├── register-receivable (verified vs. unverified business, invalid amount/date)
    │   └── financial state restriction (only authorized escrow can call mark-*)
    │
    ├── escrow_test.ts
    │   ├── fund-receivable (open/already-funded/wrong-amount)
    │   ├── release-funds (correct release, cannot release twice)
    │   ├── repay-receivable (correct, underpayment, double-repayment, already-defaulted)
    │   └── mark-default (before/after due date, already-repaid, already-defaulted)
    │
    └── integration_test.ts
        ├── full happy path: register → verify → register receivable → fund → release → repay → REPAID
        └── default path: register → verify → register receivable → fund → release → due date passes → default → DEFAULTED
```

---

## Deployment

### Testnet (Milestone 1)
- Contracts deployed via Clarinet to Stacks testnet
- Deployer: [TESTNET DEPLOYER ADDRESS]

### Mainnet (Milestone 2)
- Contracts deployed via Clarinet with mainnet plan
- Frontend hosted on [HOSTING PROVIDER]
- Reads via Hiro API
