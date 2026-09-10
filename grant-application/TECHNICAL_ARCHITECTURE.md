# FlowFi BTC — Technical Architecture

> Source of truth: `FlowFi-BTC/contracts/flowfi-registry.clar` (v1.0.0),
> `FlowFi-BTC/contracts/flowfi-escrow.clar` (v1.0.0),
> `FlowFi-BTC/contracts/mock/mock-sbtc-token.clar` (v1.0.0).
> Clarity version 5, epoch `latest` (see `FlowFi-BTC/Clarinet.toml`).
> Every signature, enum value, error code, and permission below is transcribed from those files.
> Live frontend: https://flowfi-btc.vercel.app/

---

## 1. System Overview

FlowFi BTC is a two-contract protocol plus a frontend and a thin off-chain verification/API layer.
The rule that governs the whole split: **`flowfi-registry` owns protocol state (who, what, and what
status); `flowfi-escrow` owns money (custody and movement).** The registry holds no sBTC. No
team wallet ever custodies funds.

```
┌──────────────────────────────────────────────────────────────┐
│  Frontend (live): https://flowfi-btc.vercel.app/             │
│  ┌──────────────┐         ┌───────────────────────────────┐  │
│  │  Business     │         │  Public Receivable Page        │  │
│  │  Dashboard    │         │  (wallet-aware actions)        │  │
│  └──────┬────────┘         └───────────┬───────────────────┘  │
└─────────┼──────────────────────────────┼──────────────────────┘
          │ @stacks/connect (wallet tx signing)
          │ Hiro API (reads: balances, tx status, contract state)
          ▼                              ▼
┌──────────────────────────────────────────────────────────────┐
│  Stacks Blockchain (testnet today; mainnet planned in M2)     │
│  ┌────────────────────────┐   ┌───────────────────────────┐  │
│  │ flowfi-registry        │◄──│ flowfi-escrow             │  │
│  │ - businesses map       │   │ - fund-receivable         │  │
│  │ - business-owner-index │   │ - release-funds (admin)   │  │
│  │ - receivables map      │   │ - repay-receivable (biz)  │  │
│  │ - lifecycle state      │   │ - mark-default (admin)    │  │
│  │ - verification gates   │   │ - escrows map             │  │
│  └────────────────────────┘   └─────────────┬─────────────┘  │
│                                              │ SIP-010 transfer │
│                                              ▼                  │
│                       sBTC / mock-sBTC (SIP-010, structural)    │
└──────────────────────────────────────────────────────────────┘
          ▲
          │ verification record (hashes only)
          │
┌─────────┴────────────────────────────────────────────────────┐
│  Off-chain: Verification & API Layer                          │
│  - Manual Pilot Review today; third-party KYB if it lands     │
│  - Normalizes result into one schema regardless of source     │
│  - Stores full evidence off-chain; only buff-32 hashes on-chain│
└──────────────────────────────────────────────────────────────┘
```

Live testnet deployments (deployer `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ`):

| Contract | Fully-qualified ID (testnet) |
|---|---|
| Registry | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry` |
| Escrow | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow` |
| Mock sBTC (test-only) | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token` |

Explorer (testnet): `https://explorer.hiro.so/address/<id>?chain=testnet` for each ID above.

---

## 2. flowfi-registry — Identity, Verification & Receivable State

Answers: *who is this business, was it verified, what receivable exists, and what state is it in?*

### 2.1 Constants (exact)

Verification status: `VERIFICATION-UNVERIFIED u0`, `VERIFICATION-VERIFIED u1`,
`VERIFICATION-EXPIRED u2` (stored status stays `VERIFIED`; expiry is derived on read — see §2.5),
`VERIFICATION-REVOKED u3`.

Verification method: `METHOD-MANUAL u0`, `METHOD-CAC u1`, `METHOD-PERSONA u2`,
`METHOD-OPENCORPORATES u3`, `METHOD-PARTNER u4`, `METHOD-OTHER u5`.

Verification level: `LEVEL-NONE u0`, `LEVEL-BASIC u1`, `LEVEL-ENHANCED u2`, `LEVEL-FULL-KYB u3`.

Receivable status: `STATUS-DRAFT u0`, `STATUS-OPEN u1`, `STATUS-FUNDED u2`, `STATUS-REPAID u3`,
`STATUS-DEFAULTED u4`, `STATUS-CANCELLED u5`. Note: `register-receivable` creates records
directly in `STATUS-OPEN`; `STATUS-DRAFT` is reserved in the enum and never written by v1.0.0.

Errors (all `err uint`): `u100 NOT-AUTHORIZED`, `u101 NOT-FOUND`, `u102 ALREADY-REGISTERED`,
`u103 INVALID-NAME`, `u104 INVALID-COUNTRY`, `u105 NOT-BUSINESS-OWNER`, `u106 NOT-VERIFIED`,
`u107 INVALID-AMOUNT`, `u108 FUNDING-EXCEEDS-FACE-VALUE`, `u109 INVALID-DATE`,
`u110 INVALID-STATUS`, `u111 INVALID-VERIFICATION-METHOD`, `u112 INVALID-VERIFICATION-LEVEL`.

### 2.2 State (exact)

```clarity
(define-data-var admin principal CONTRACT-OWNER)      ;; deployer; can set-admin / set-verifier / set-escrow-contract
(define-data-var verifier principal CONTRACT-OWNER)   ;; combined admin/verifier for MVP; reassignable
(define-data-var escrow-contract (optional principal) none) ;; MUST be set post-deploy; starts at none BY DESIGN
(define-data-var next-business-id uint u1)
(define-data-var next-receivable-id uint u1)

(define-map businesses uint
  { owner: principal,
    business-name: (string-ascii 100),
    country: (string-ascii 2),
    verification-status: uint,
    verification-method: uint,
    verification-level: uint,
    verified-at: (optional uint),
    verification-expiry: uint,              ;; u0 = does not expire; else burn-block-height
    verified-by: (optional principal),
    verification-reference-hash: (optional (buff 32)),
    verification-proof-hash: (optional (buff 32)),
    created-at: uint })                      ;; burn-block-height

(define-map business-owner-index principal uint)      ;; one business per wallet (enforced)

(define-map receivables uint
  { business-id: uint,
    debtor-name: (string-ascii 100),
    debtor-country: (string-ascii 2),
    invoice-number: (string-ascii 100),
    invoice-hash: (buff 32),
    face-value: uint,                        ;; base units (sats of sBTC面值 convention decided off-chain)
    funding-amount: uint,                    ;; <= face-value; exact amount escrow will pull
    issue-date: uint,                        ;; burn-block-height, must be <= current
    due-date: uint,                          ;; burn-block-height, must be > current
    status: uint,
    escrow-id: (optional uint),
    created-at: uint })                      ;; burn-block-height
```

Key corrections to earlier drafts: map keys (`business-id`, `receivable-id`) are **not** fields
inside the tuples; `verified-at` / `verified-by` / hashes are `optional`; `escrow-id` on the
receivable is `(optional uint)` (`none` until funded).

### 2.3 Time is burn-block-height

`issue-date`, `due-date`, `verified-at`, `verification-expiry`, `created-at` are all
**burn-block heights** (Bitcoin-anchored, ~144/day), not Unix timestamps and not Stacks block
heights. Clarity has no wall clock. Convert calendar dates off-chain before calling
`register-receivable`. Checks: `issue-date <= burn-block-height < due-date`;
`verification-expiry = u0` means never expires, otherwise must be `> burn-block-height` at
`verify-business` time.

### 2.4 Public functions (exact signatures)

| Function (exact) | Caller | Guards → effect |
|---|---|---|
| `(register-business (business-name (string-ascii 100)) (country (string-ascii 2))) → (ok uint[id])` | any wallet | `business-owner-index[tx-sender]` must be `none` (u102); `len(name) > 0` (u103); `len(country) = 2` (u104). Creates record UNVERIFIED / METHOD-MANUAL / LEVEL-NONE, `created-at = burn-block-height`. Emits `business-registered`. |
| `(verify-business (business-id uint) (verification-method uint) (verification-level uint) (verification-expiry uint) (verified-by principal) (verification-reference-hash (buff 32)) (verification-proof-hash (buff 32))) → (ok true)` | `tx-sender = verifier` only (u100) | `method <= 5` (u111); `level <= 3` (u112); `expiry = 0` or `> burn-block-height` (u109); business must exist (u101). Sets VERIFIED + `verified-at = burn-block-height`. Emits `business-verified`. |
| `(revoke-verification (business-id uint)) → (ok true)` | verifier only (u100) | Business must exist (u101). Sets REVOKED. Emits `verification-revoked`. |
| `(register-receivable (business-id uint) (debtor-name (string-ascii 100)) (debtor-country (string-ascii 2)) (invoice-number (string-ascii 100)) (invoice-hash (buff 32)) (face-value uint) (funding-amount uint) (issue-date uint) (due-date uint)) → (ok uint[id])` | business owner only | Business must exist (u101); `tx-sender = business.owner` (u105); `is-business-verified` must be true (u106); `face-value > 0`, `funding-amount > 0` (u107); `funding-amount <= face-value` (u108); `issue-date <= burn-block-height` and `due-date > burn-block-height` (u109). Creates STATUS-OPEN. Emits `receivable-registered`. |
| `(cancel-receivable (receivable-id uint)) → (ok true)` | business owner only | Must exist (u101); caller = owner (u105); `status = OPEN` (u110). Sets CANCELLED. Emits `receivable-cancelled`. |
| `(mark-funded (receivable-id uint) (funder principal) (funding-amount uint) (escrow-id uint)) → (ok true)` | **escrow contract only** | `(some contract-caller) = escrow-contract` checked FIRST (u100); receivable exists (u101); `status = OPEN` (u110). Sets FUNDED + `escrow-id`. Emits `receivable-marked-funded`. |
| `(mark-repaid (receivable-id uint)) → (ok true)` | **escrow contract only** | Same caller check (u100); exists (u101); `status = FUNDED` (u110). Sets REPAID. Emits `receivable-marked-repaid`. |
| `(mark-defaulted (receivable-id uint)) → (ok true)` | **escrow contract only** | Same caller check (u100); exists (u101); `status = FUNDED` (u110). Sets DEFAULTED. Emits `receivable-marked-defaulted`. |
| `(set-admin (new-admin principal))` | current admin | — |
| `(set-verifier (new-verifier principal))` | current admin | — |
| `(set-escrow-contract (new-escrow principal))` | current admin | **Critical post-deploy step.** Until called, `escrow-contract = none` so `mark-*` can never pass. |

### 2.5 Read-only functions (exact)

`is-business-verified (business-id uint) → bool` — lazily derives expiry: true iff
`status = VERIFIED AND (expiry = u0 OR burn-block-height < expiry)`. No keeper needed.
`get-business`, `get-business-id-by-owner`, `get-receivable`, `get-receivable-status`
(returns `(ok status)` or `ERR-NOT-FOUND`), `get-admin`, `get-verifier`, `get-escrow-contract`,
`get-next-business-id`, `get-next-receivable-id`.

### 2.6 Authorization invariant

`mark-funded` / `mark-repaid` / `mark-defaulted` check **`contract-caller`, not `tx-sender`**.
`tx-sender` is the original signer; `contract-caller` is the immediate calling contract. Checking
`tx-sender` here would let any wallet forge financing state. The check runs before any state is
touched, and the `escrow-contract` var deliberately starts at `none` so no privileged principal
can slip through before wiring.

---

## 3. flowfi-escrow — sBTC Custody, Funding & Settlement

Answers: *where is the sBTC, who funded the receivable, and where should it go?*

### 3.1 SIP-010 trait (local, structural)

The contract defines `sip-010-trait` locally (`transfer`, `get-name`, `get-symbol`,
`get-decimals`, `get-balance`, `get-total-supply`, `get-token-uri`) so it has no dependency on an
external trait contract address. Real `sbtc-token` does not declare `impl-trait`, but Clarity
checks conformance structurally, so sBTC and `mock-sbtc-token` both satisfy `<sip-010-trait>`
when passed as `(token <sip-010-trait>)`. **Every** token-moving function takes the token as a
parameter and then asserts `(contract-of token) = sbtc-contract` (`ERR-WRONG-TOKEN u202`) —
a wrong-token transfer can never move real funds.

### 3.2 Constants and state (exact)

Own escrow-record status (independent namespace from registry — do not mix):
`STATUS-FUNDED u0`, `STATUS-REPAID u1`, `STATUS-DEFAULTED u2`.
Mirror constant: `REGISTRY-STATUS-OPEN u1` (only registry value needed here; keep in sync).

Errors: `u200 NOT-AUTHORIZED`, `u201 NOT-FOUND`, `u202 WRONG-TOKEN`, `u203 RECEIVABLE-NOT-OPEN`,
`u204 ALREADY-FUNDED`, `u205 SELF-FUNDING`, `u206 INVALID-STATUS`, `u207 ALREADY-RELEASED`,
`u208 NOT-RELEASED`, `u209 NOT-BUSINESS`, `u210 NOT-DUE`.

```clarity
(define-data-var admin principal CONTRACT-OWNER)
(define-data-var sbtc-contract principal
  'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token) ;; MAINNET default; repoint on testnet!
(define-data-var next-escrow-id uint u1)
(define-map escrows uint ;; KEY = receivable-id (1 receivable → at most 1 escrow in v1.0.0)
  { escrow-id: uint, receivable-id: uint, funder: principal, business: principal,
    funding-amount: uint, funded-at: uint, released-at: (optional uint),
    status: uint, repaid-at: (optional uint), settled-at: (optional uint) })
```

`escrow-id` is generated/stored for cross-reference with `registry.receivable.escrow-id`, but the
map is keyed by `receivable-id` because every entry point takes a `receivable-id`.

### 3.3 Public functions (exact — read carefully, earlier drafts were wrong here)

| Function (exact) | Caller (exact) | What it does |
|---|---|---|
| `(fund-receivable (receivable-id uint) (token <sip-010-trait>)) → (ok uint[escrow-id])` | any capital provider **except the business itself** | Reads receivable from registry (u201 if missing); asserts correct token (u202); asserts registry `status = OPEN` (u203); asserts no escrow exists yet for this receivable (u204); loads business, asserts `tx-sender ≠ business.owner` (u205 anti-self-funding); pulls **exactly** `receivable.funding-amount` (caller cannot choose amount) via `token.transfer(amount, tx-sender → escrow)`; creates escrow record FUNDED with `funded-at = burn-block-height`; calls `registry.mark-funded`; emits `receivable-funded`. |
| `(release-funds (receivable-id uint) (token <sip-010-trait>)) → (ok true)` | **`tx-sender = admin` ONLY** (u200) | Escrow must exist (u201); correct token (u202); `status = FUNDED` (u206); `released-at = none` (u207 double-release guard); `as-contract transfer(funding-amount → business)`; sets `released-at`; emits `funds-released`. The recipient is always the stored `business` — the caller can never redirect funds. Admin-gating is the MVP compliance hook (release after off-chain checks); it can be loosened to funder-or-admin or permissionless later without changing money paths. |
| `(repay-receivable (receivable-id uint) (token <sip-010-trait>)) → (ok true)` | **`tx-sender = escrow.business` ONLY** (u209) | Escrow must exist (u201); correct token (u202); `status = FUNDED` (u206); must already be released (u208); pulls `funding-amount` business → escrow, then escrow → funder **in the same transaction** (`as-contract` second leg); sets REPAID + timestamps; calls `registry.mark-repaid`; emits `receivable-repaid`. Repayment is **flat** (`= funding-amount`); v1.0.0 has no interest/fee field. |
| `(mark-default (receivable-id uint)) → (ok true)` — note: **`mark-default`, no `-ed`, no token param** | **`tx-sender = admin` ONLY** (u200) | Escrow must exist (u201); `status = FUNDED` (u206); must already be released (u208); registry `due-date` must have passed: `burn-block-height > due-date` (u210); sets DEFAULTED; calls `registry.mark-defaulted`; emits `receivable-defaulted`. Moves no funds — it flips state for off-chain recovery to key off. |
| `(set-admin (new-admin principal))` | current admin | — |
| `(set-sbtc-contract (new-contract principal))` | current admin | Repoint token (e.g. to mock on testnet). |

Corrections vs. earlier drafts: `release-funds` is **not** callable by the provider; `mark-default`
is **not** callable by the provider (it is admin-only and gated on `due-date`); `repay-receivable`
is business-only on-chain sBTC — there is **no** in-contract off-chain-confirmation path in
v1.0.0 (see §3.5).

### 3.4 Funding flow (escrow-then-release, deliberate)

```
Provider calls fund-receivable(rec-id, mock-sbtc)
  → sBTC: provider → escrow contract
  → escrow record created (FUNDED, released-at = none)
  → registry.mark-funded → registry status OPEN → FUNDED
Admin calls release-funds(rec-id, mock-sbtc)
  → sBTC: escrow → business
  → escrow.released-at set
Business calls repay-receivable(rec-id, mock-sbtc)
  → sBTC: business → escrow → funder (atomic, same tx)
  → escrow REPAID; registry.mark-repaid → registry REPAID
— or, past due-date —
Admin calls mark-default(rec-id)
  → escrow DEFAULTED; registry.mark-defaulted → registry DEFAULTED
```

Two transactions for funding (fund + release) instead of one direct pass-through, so
"money is escrowed" and "money has been released" are independently observable and testable.

### 3.5 Repayment boundary — what v1.0.0 actually does

The escrow contract only moves sBTC. If the business holds sBTC it repays on-chain via
`repay-receivable` above. If the real-world repayment happens in fiat (debtor pays invoice in
fiat, business settles with provider off-chain), **v1.0.0 has no contract function that records
that attestation** — that confirmation lives in the off-chain/API process layer for the pilot
and must be disclosed as such (see `RISK_DISCLOSURE.md` §3). Do not describe
`repay-receivable` as accepting an off-chain confirmation; it always executes two SIP-010
transfers. A future version can add an admin-attested `confirm-offchain-repayment` path without
changing the happy-path money flow.

### 3.6 Read-only

`get-escrow (receivable-id uint)`, `get-admin`, `get-sbtc-contract`, `get-next-escrow-id`.

---

## 4. mock-sbtc-token — Testnet-Only sBTC Stand-In

`contracts/mock/mock-sbtc-token.clar` v1.0.0. **Not real sBTC, no Bitcoin peg, never point a
mainnet escrow at it.** Drop-in compatible: 8 decimals like sBTC, same sender-authorization
check (`tx-sender = sender OR contract-caller = sender`), full SIP-010 surface
(`transfer`, `get-name/symbol/decimals/balance/total-supply/token-uri`), and no `impl-trait`
declaration — matching real `sbtc-token`'s own choice, so structural conformance is what matters.

- `mint (amount uint) (recipient principal)` — admin-only, unlimited. For deterministic test setup.
- `claim-daily-sbtc () → (ok amount)` — self-serve faucet: `tx-sender` claims exactly
  `claim-amount` (default `u10000000000` = 100 sBTC at 8 decimals) to **itself**, at most once per
  `claim-interval` (default `u144` ≈ 1 Bitcoin day). First claim per principal always succeeds.
  Emits `daily-claim`. No recipient/amount parameters by design (anti-drain).
- Admin: `set-admin`, `set-claim-amount`, `set-claim-interval`, `set-token-uri`.
- Reads: `get-admin`, `get-claim-amount`, `get-claim-interval`,
  `get-last-claim-height`, `blocks-until-next-claim` (`u0` = can claim now).

Live testnet instance: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`.

---

## 5. Permission Matrix (exact, code-verified)

| Caller | Registry | Escrow | Mock |
|---|---|---|---|
| Anyone | `get-*`, `is-business-verified` | `get-*` | `get-*`, `blocks-until-next-claim`, `claim-daily-sbtc` (self only) |
| Any wallet (once) | `register-business` (one per wallet via `business-owner-index`) | — | — |
| Business owner | `register-receivable` (if VERIFIED), `cancel-receivable` (if OPEN) | `repay-receivable` (if business = escrow.business, released, FUNDED) | — |
| Capital provider (≠ business) | — | `fund-receivable` (if registry OPEN, unfunded) | — |
| Verifier (`registry.verifier`) | `verify-business`, `revoke-verification` | — | — |
| Escrow contract (via `contract-caller`) | `mark-funded`, `mark-repaid`, `mark-defaulted` | — | — |
| Admin | `set-admin`, `set-verifier`, `set-escrow-contract` | `release-funds`, `mark-default`, `set-admin`, `set-sbtc-contract` | `mint`, `set-claim-*`, `set-token-uri`, `set-admin` |

---

## 6. What's On-Chain vs. Off-Chain

| On-chain | Off-chain |
|---|---|
| Business owner principal, name (`string-ascii 100`), 2-letter country | Incorporation PDFs, KYB dossiers, director PII |
| Verification status/method/level enums, `verified-at` / `expiry` burn-heights, `verified-by`, two `buff-32` hashes | Full verification report, evidence bundle |
| Receivable: debtor name/country, invoice number, `invoice-hash (buff 32)`, `face-value`, `funding-amount`, burn-height `issue/due-date`, status, `escrow-id` | Invoice PDF, debtor contact, business description, UI metadata |
| Escrow: funder/business principals, amounts, burn-height timestamps, FUNDED/REPAID/DEFAULTED | Notifications, analytics, hosting config |
| Events (`print`): `business-registered/verified`, `verification-revoked`, `receivable-registered/cancelled/marked-funded/marked-repaid/marked-defaulted`, `receivable-funded`, `funds-released`, `receivable-repaid`, `receivable-defaulted`, `daily-claim` | Indexers/subgraphs over these events (future) |

Sensitive documents never go on-chain — only `buff-32` hashes.

---

## 7. Frontend & Off-Chain API

| Layer | Technology |
|---|---|
| Frontend (live https://flowfi-btc.vercel.app/) | React + Vite + Tailwind, `@stacks/connect` for wallet signing, Hiro API (`api.testnet.hiro.so` on testnet) for reads |
| Verification/API layer | Thin service normalizing manual-review or KYB results into the registry's `(method, level, expiry, reference-hash, proof-hash)` schema; stores evidence; exposes hash references for `verify-business` |

No custom backend holds funds or private keys. All value-moving calls (`fund/repay`) are
wallet-signed against the exact deployed principals above. Frontend converts calendar due dates
to burn-block heights (~144/day) before calling `register-receivable`.

---

## 8. Test Infrastructure (honest status)

Stack: Clarinet SDK + Vitest (`vitest-environment-clarinet`), `npm run test` in `FlowFi-BTC/`.
Today `tests/` contains simnet-boot placeholders (`flowfi-registry.test.ts`,
`flowfi-escrow.test.ts` — each asserts simnet init only). Milestone 1 delivers the real suite:

```
Clarinet SDK + Vitest (simnet)
  ├── registry (register-business dup/ownership; verify ok/unauth/bad-method/bad-level/bad-expiry;
  │              register-receivable verified-vs-unverified/amount/date/owner; cancel owner/status;
  │              mark-* rejects direct-wallet callers)
  ├── escrow (fund open/already-funded/not-open/wrong-token/self-funding;
  │            release admin-only/double-release/wrong-token; repay business-only/unreleased/
  │            double-repay/wrong-amount-impossible-by-design; default admin-only/pre-due-date/post-repay)
  └── integration (happy: register→verify→receivable→fund→release→repay→REPAID;
                   default: …→fund→release→past-due→default→DEFAULTED; token-conservation invariant)
```

Target: 40–60 tests + 2 full lifecycle paths, all green on simnet before mainnet (M1 exit).

---

## 9. Deployment Architecture

### 9.1 Testnet (live today)

- Registry: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry`
- Escrow: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow`
- Mock sBTC: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`
- Frontend: https://flowfi-btc.vercel.app/ (Vercel production build)
- Reads: Hiro testnet API. Deployer: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ`.

Required wiring (in order — escrow statically calls `.flowfi-registry`, so registry must exist
first at analysis time):

```bash
# 1. Deploy registry, then escrow (clarinet deployment plans in settings/Testnet.toml)
# 2. Wire registry → escrow (as registry admin/deployer):
contract-call registry set-escrow-contract 'ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow
# 3. Point escrow at the mock token on testnet (default is MAINNET sBTC!):
contract-call escrow set-sbtc-contract 'ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token
# 4. Sanity reads:
get-escrow-contract  # expect (some escrow principal)
get-sbtc-contract    # expect (some mock principal) on testnet
```

Until step 2, every escrow→registry callback fails closed. Until step 3 on testnet, funding with
the mock token fails with `u202 WRONG-TOKEN`.

### 9.2 Mainnet (planned, Milestone 2)

- Deploy registry, then escrow, via Clarinet mainnet plan; same wiring order.
- `sbtc-contract` stays at its default `'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token`
  (real sBTC) — do **not** repoint to any mock.
- Frontend stays on Vercel; reads switch to Hiro mainnet API; monitoring = contract-event
  tracking + TVL dashboard.

---
