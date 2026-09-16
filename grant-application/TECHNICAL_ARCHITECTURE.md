# FlowFi BTC — Technical Architecture

---

## Live Deployment

| Component | Address / URL |
|---|---|
| **Network** | Stacks Testnet |
| `flowfi-registry.clar` | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry` — [view on Explorer](https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry?chain=testnet) |
| `flowfi-escrow.clar` | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow` — [view on Explorer](https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow?chain=testnet) |
| `mock-sbtc-token.clar` | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token` — [view on Explorer](https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token?chain=testnet) |
| **Frontend** | [https://flowfi-btc.vercel.app/](https://flowfi-btc.vercel.app/) |

*Verify these links resolve to the correct deployed source before citing them in any external submission — always confirm on the Explorer's testnet view, not mainnet. Note these are contract `/address/` links, not transaction IDs.*

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
│  │  - lifecycle state  │    │  - mark-default (ADMIN)       │   │
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
  verified-at:            (optional uint),      ;; none until first verify-business call
  verification-expiry:    uint,                 ;; 0 = never expires
  verified-by:            (optional principal), ;; none until first verify-business call
  verification-reference-hash: (optional (buff 32)),
  verification-proof-hash:     (optional (buff 32)),
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
  status:          uint,             ;; 0=DRAFT 1=OPEN 2=FUNDED 3=REPAID 4=DEFAULTED 5=CANCELLED
  escrow-id:       (optional uint),  ;; none until fund-receivable succeeds
  created-at:      uint
}
```

**Public functions:**

| Function | Caller | Effect |
|---|---|---|
| `register-business` | any wallet (one business per wallet, `u102` otherwise) | Creates business record, status UNVERIFIED |
| `verify-business` | authorized verifier only (`u100` otherwise) | Sets verification status/method/level/expiry/hashes; validates method ≤ 5 (`u111`), level ≤ 3 (`u112`), expiry is `0` or in the future (`u109`) |
| `revoke-verification` | authorized verifier only (`u100` otherwise) | Sets status to REVOKED |
| `is-business-verified` | anyone (read-only) | Returns current verification status; lazily treats an expired `verification-expiry` as unverified even if the stored status still says VERIFIED |
| `register-receivable` | business owner (`u105` otherwise), only if business is VERIFIED (`u106` otherwise) | Creates receivable, status OPEN; validates `funding-amount ≤ face-value` (`u108`) and issue/due dates (`u109`) |
| `cancel-receivable` | business owner, only if status OPEN | Sets status CANCELLED |
| `mark-funded` / `mark-repaid` / `mark-defaulted` | **`flowfi-escrow` contract only**, via `contract-caller` | Updates receivable status |
| `get-business` / `get-receivable` / `get-receivable-status` | anyone (read-only) | Returns records |

**Key rule:** `mark-funded`, `mark-repaid`, and `mark-defaulted` check `(is-eq (some contract-caller) escrow-contract)`. No wallet — including the business or provider, or the admin calling directly — can call these. `escrow-contract` defaults to `none` at deploy time specifically so this check cannot pass until an admin has explicitly wired it (see Deployment section below).

### flowfi-escrow — sBTC Custody, Funding & Settlement

Answers: *where is the sBTC, who funded the receivable, and where should it go?*

**Escrow record (one receivable → one funding position → one funder, for this pilot; keyed by `receivable-id`):**
```clarity
{
  escrow-id:        uint,
  receivable-id:    uint,
  funder:           principal,
  business:         principal,
  funding-amount:   uint,
  funded-at:        uint,
  released-at:      (optional uint),  ;; none until release-funds succeeds; gates repay-receivable and mark-default
  status:           uint,             ;; 0=FUNDED 1=REPAID 2=DEFAULTED (independent number space from the registry's receivable-status enum above — an escrow record only ever exists once funded, so there is no OPEN value here)
  repaid-at:        (optional uint),
  settled-at:        (optional uint)  ;; set on either REPAID or DEFAULTED
}
```

**Public functions:**

| Function | Caller | Effect |
|---|---|---|
| `fund-receivable` | capital provider, not the business (`u205` otherwise) | Checks receivable is OPEN in registry (`u203`) and not already funded (`u204`), checks the token matches the configured sBTC contract (`u202`), transfers exactly the registry's `funding-amount` from provider into escrow, creates escrow record, calls `registry.mark-funded` |
| `release-funds` | **admin wallet only** (`u200` otherwise) | Checks escrow is FUNDED and not already released (`u207`), transfers sBTC from escrow to the stored business address |
| `repay-receivable` | business only (`u209` otherwise), only after release (`u208` otherwise) | Transfers a flat repayment equal to `funding-amount`, business → escrow → provider, atomically; calls `registry.mark-repaid` |
| `mark-default` | **admin wallet only** (`u200` otherwise), only if `burn-block-height > due-date` (`u210` otherwise) and only after release (`u208` otherwise) | No funds move. Calls `registry.mark-defaulted`. **Fully implemented and on-chain as of v1.0.0** — this is not a roadmap item; see `RISK_DISCLOSURE.md` §4 and `SECURITY_REVIEW.md` §1 for the same function described with its exact revert codes |
| `get-escrow` | anyone (read-only) | Returns escrow record |

**Funding flow (escrow-then-release, chosen deliberately for clearer state reasoning):**
```
Capital Provider → fund-receivable() → sBTC moves to escrow → escrow record created
                                                              → registry.mark-funded()
Admin wallet     → release-funds()   → sBTC moves from escrow to business
```

### Important Design Note: Admin-Signs-Release-and-Default

**`release-funds` and `mark-default` both require a signature from a specific admin wallet — not the provider, not the business, not any arbitrary caller.** The admin for both contracts is a single Stacks wallet controlled by the lead developer, Oyewale Prudence ([@ProdevappOFFICIAL](https://github.com/ProdevappOFFICIAL)) — `CONTRACT-OWNER` set to `tx-sender` at deploy time, with **no multisig**. This is a deliberate MVP simplification, and it introduces two real risks worth stating plainly, not just one:

1. **Custody-adjacent trust:** the admin wallet controls *when* escrowed funds move to the business, even though it never has the power to redirect them elsewhere or withdraw them for itself — the contract logic only allows a transfer from escrow to the business, to the address recorded at funding time.
2. **Liveness risk:** if the admin never calls `release-funds`, funds sit in escrow indefinitely — there is no time-lock or automatic release in v1.0.0. The same applies to `mark-default` if the admin never calls it after the due date: the receivable simply remains recorded as FUNDED indefinitely. See `RISK_DISCLOSURE.md` §10 for the full disclosure and the single-operator mitigation that applies only at this pilot's scale.

A future version could make release automatic, or governed by a time-lock or multi-signature rule, to remove this admin dependency; that is documented as a named prerequisite before any multi-provider expansion, not solved by the current MVP.

### Important Design Note: Flat Repayment (No Separate Interest/Fee Amount Yet)

**`repay-receivable` currently requires repayment of exactly `funding-amount` — the same amount that was funded, no more, no less.** There is no separate repayment/interest amount field wired into the contract yet, even though a future version could add one (a distinct `repayment-amount` field, so a fee could be added without redesigning the contract). For this pilot, repayment is flat by design, to keep the first real transaction as simple as possible to reason about and test. Adding a distinct repayment amount is explicitly deferred to a future version — see `ROADMAP.md`.

### Repayment Boundary — Read This Before Assuming Off-Chain Settlement Is Recorded

A smart contract cannot compel a real-world fiat payment. **In v1.0.0, there is exactly one way to reach REPAID on-chain:**

1. **Direct sBTC repayment** — the business calls `repay-receivable`, and `funding-amount` moves business → escrow → provider inside the same atomic function call (flat amount, per above).

**There is no second, off-chain-confirmation path in v1.0.0.** An earlier draft of this document described an "authorized party confirms this happened, registry records state without moving sBTC" path — **that function does not exist in the current contracts** and describing it here was inaccurate; it has been removed from this document to match reality. If the business's debtor pays in fiat and the business settles with the provider off-chain, that confirmation lives entirely in the pilot's off-chain process layer — it is not recorded as an on-chain state transition by any contract function. See `RISK_DISCLOSURE.md` §3 for the full disclosure, including the estimated probability that this gap causes a mechanical default for the pilot specifically. A future version could add an admin-attested off-chain-confirmation function without changing the happy path — that is a roadmap item, not a current capability.

### Permission Model

| Role | Can call |
|---|---|
| Public / anyone | `get-business`, `get-receivable`, `is-business-verified`, `get-receivable-status`, `get-escrow` |
| Business wallet | `register-business`, `register-receivable`, `cancel-receivable`, `repay-receivable` (only after release) |
| Authorized verifier | `verify-business`, `revoke-verification` |
| Capital provider (investor wallet) | `fund-receivable` |
| **Admin wallet** | `release-funds`, `mark-default`, deployment configuration (`set-escrow-contract`, `set-verifier`, `set-admin`, testnet-only `set-sbtc-contract`) |
| `flowfi-escrow` contract (via registry, `contract-caller`-gated) | `mark-funded`, `mark-repaid`, `mark-defaulted` |

---

## What's On-Chain vs. Off-Chain

| On-chain | Off-chain |
|---|---|
| Business ID, wallet, name, country | PDF invoices, KYB documents |
| Verification status/method/level, timestamps, proof hash | Identity information, director information, full verification reports |
| Receivable ID, invoice reference, invoice hash, face value, funding amount, due date, status | Business address, descriptions, uploaded evidence |
| Funder, funding amount, escrow status, timestamps | UI settings, notifications, analytics; any off-chain fiat settlement confirmation (v1.0.0 has no function that records this on-chain — see Repayment Boundary above) |

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
Clarinet SDK + Vitest (simnet), FlowFi-BTC/flowfi-contracts, `npm run test`
    │
    ├── tests/registry.test.ts  (26 tests)
    │   ├── register-business (duplicate prevention, name/country validation)
    │   ├── verify-business / revoke-verification (authorized-verifier-only, method/level range, expiry)
    │   ├── is-business-verified (unverified, lazy expiry)
    │   ├── register-receivable (owner + verified gates, funding-amount ≤ face-value, issue/due dates)
    │   ├── cancel-receivable
    │   ├── escrow authorization gate (mark-funded/mark-repaid/mark-defaulted unreachable by any
    │   │   direct wallet call, including the admin, both before and after set-escrow-contract)
    │   └── admin configuration (set-verifier, set-admin reassignment)
    │
    └── tests/escrow.test.ts  (20 tests, including 2 full end-to-end integration paths)
        ├── fund-receivable (exact registry amount, not-open/already-funded/self-fund/wrong-token rejections)
        ├── release-funds (admin-only, no double-release, payout recorded)
        ├── repay-receivable (release-first gate, business-only)
        ├── mark-default (before/after due date, admin-only, already-repaid excluded)
        ├── admin configuration
        └── end-to-end: (1) full happy path — register → verify → register receivable → fund →
            release (admin) → repay (flat) → REPAID; (2) default path — register → verify →
            register receivable → fund → release → due date passes → mark-default (admin) → DEFAULTED
```

---

## Deployment

### Testnet (Live)
- **Deployer / Contract address:** `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ`
- `flowfi-registry`: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry`
- `flowfi-escrow`: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow`
- `mock-sbtc-token`: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`
- **Frontend:** [https://flowfi-btc.vercel.app/](https://flowfi-btc.vercel.app/)
- Reads via Hiro API (testnet)

**Required post-deploy wiring (in order):**
1. Deploy `flowfi-registry` first — `flowfi-escrow` references it statically via `contract-call?`, which requires `flowfi-registry`'s interface to already exist.
2. Deploy `flowfi-escrow`.
3. Call `flowfi-registry.set-escrow-contract` with `flowfi-escrow`'s fully-qualified address. Until this call happens, `mark-funded`/`mark-repaid`/`mark-defaulted` are unreachable by design — see the "Key rule" note above.
4. (Testnet only) Call `flowfi-escrow.set-sbtc-contract` with the mock sBTC principal, since `flowfi-escrow`'s default points at the real mainnet sBTC address.

### Mainnet (Planned — Milestone 2)
- Not yet deployed. Mainnet deployment, and any change to the admin-release or flat-repayment simplifications, will be documented here when it happens. The same wiring order applies (registry, then escrow, then `set-escrow-contract`) — step 4 above does not apply on mainnet.
- **`sbtc-contract` — being removed, not just gated:** `set-sbtc-contract` is being **removed from `flowfi-escrow` entirely** before mainnet deployment — a code change, not a configuration toggle. The mainnet contract will have the sBTC address hardcoded to `SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token` (verified against current Stacks/Hiro documentation), with no function able to change it post-deploy. The updated contract, without this function, is what will be submitted for Milestone 2 verification.