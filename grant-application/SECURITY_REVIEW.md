# FlowFi BTC — Security Self-Review

**Status: Internal self-review against `flowfi-registry.clar` v1.0.0, `flowfi-escrow.clar` v1.0.0,
and `mock-sbtc-token.clar` v1.0.0. Not a substitute for a formal third-party audit.**

This document records what was checked, how, and what remains open. Read alongside
[RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md) (user-facing risk) and
[TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md) (code-verified spec).
Live testnet contracts: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry`,
`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow`,
`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`.

---

## Scope

Registry + escrow + mock as implemented at Milestone 1. Frontend, API layer, and economic
modeling are out of scope here (§8).

---

## 1. Authorization Checks (code-verified)

| Function | Required caller (code) | Check |
|---|---|---|
| `registry.register-business` | any wallet, once per wallet | `business-owner-index[tx-sender]` must be `none` else `u102`; name/country validated (`u103/u104`) |
| `registry.verify-business` / `revoke-verification` | `tx-sender = verifier` | Reverts `u100` otherwise; method `<= 5` (`u111`), level `<= 3` (`u112`), expiry `0` or future (`u109`) |
| `registry.register-receivable` | business owner AND `is-business-verified` | Reverts `u105` for non-owner, `u106` for unverified/expired/revoked; amount/date guards `u107/u108/u109` |
| `registry.cancel-receivable` | business owner, `status = OPEN` | Reverts `u105` / `u110` |
| `registry.mark-funded` / `mark-repaid` / `mark-defaulted` | **`(some contract-caller) = escrow-contract`** | Reverts `u100` for any direct wallet call, including business/provider; status must be OPEN (funded) or FUNDED (repaid/defaulted) else `u110` |
| `escrow.fund-receivable` | provider ≠ business, registry OPEN | Reverts `u203` not-open, `u204` already-funded, `u205` self-funding, `u202` wrong token |
| `escrow.release-funds` | **`tx-sender = admin` only** | Reverts `u200` otherwise; `u207` blocks double-release; recipient fixed to stored business |
| `escrow.repay-receivable` | **`tx-sender = escrow.business` only** | Reverts `u209` otherwise; `u208` requires prior release; `u206` requires FUNDED; flat amount = funding-amount |
| `escrow.mark-default` | **`tx-sender = admin` only** | Reverts `u200` otherwise; requires FUNDED (`u206`), released (`u208`), `burn-block-height > due-date` (`u210`) |
| `mock.mint` / `set-*` | `tx-sender = admin` | Reverts `u300`; `claim-daily-sbtc` is self-only with `u302` rate limit |

**Result:** PASS against implementation — verified against the 46-test suite (26 registry + 20 escrow, including 2 full integration paths, all green on Clarinet simnet).

---

## 2. The `tx-sender` vs. `contract-caller` Boundary

Registry `mark-*` checks **`contract-caller`**, never `tx-sender`. `tx-sender` is the original
signer; `contract-caller` is the immediate calling contract (the escrow). Reversing this would let
any wallet forge financing state by routing through an unrelated contract. Additionally,
`escrow-contract` defaults to `none`, so the `(is-eq (some contract-caller) …)` check can never
pass before the admin's explicit `set-escrow-contract` — there is no window where a privileged
default principal could bypass escrow. Mock `transfer` accepts `tx-sender = sender OR
contract-caller = sender`, matching real `sbtc-token` semantics so escrow's `as-contract`
second legs (release, repay payout) work identically against mock and real sBTC.

**Check:** confirmed in source for all three `mark-*` functions; covered by negative tests
(direct-wallet `mark-*` must return `u100`).

---

## 3. Token Conservation

Per-escrow invariant (amounts in base units, 8 decimals):

```
funding-amount == released-to-business (after release-funds)
                + paid-to-provider (after repay-receivable, same amount, same tx legs)
                + escrow balance (before release / before repay)
```

Mechanisms: funding amount is read from the registry (caller cannot supply it, so under/over-funding
is impossible by construction); repayment moves the identical `funding-amount` twice atomically
(business → escrow → funder) so no dust can strand; `release-funds` and `repay-receivable` each
enforce single-execution (`released-at` / status transitions); `mark-default` moves no funds.
No mint/burn exists in registry or escrow.

**Check:** verified across both integration paths (happy-path REPAID, past-due DEFAULTED) in M1.

---

## 4. Reentrancy

Clarity has no mid-execution callbacks (unlike EVM reentrancy), so the classic reentrancy surface
does not exist by language design. No reentrancy guard is implemented or needed; noted so reviewers
do not mistake its absence for an omission. Cross-contract calls (`escrow → registry.mark-*`,
`escrow → token.transfer`) are sequential and fully committed or rolled back per-transaction.

---

## 5. Custody Precision

`flowfi-escrow` holds sBTC between `fund-receivable` and `release-funds` (escrow-then-release,
deliberate). No admin/team function can move escrowed funds outside `release-funds` /
`repay-receivable` paths: `set-admin` / `set-sbtc-contract` change configuration only, never
balances; `mark-default` changes state only. The release recipient is always the stored
`escrow.business`, so even the admin cannot redirect funds — only trigger timing. Mock `mint` is
admin-only but the mock is testnet-only and must never be referenced by a mainnet escrow.

**Update (Milestone 2 commitment):** `set-sbtc-contract` itself is removed from the contract source
entirely before mainnet deployment, rather than left in place and simply never called. This closes
the configuration surface completely rather than relying on operational discipline not to invoke it.

**Check:** confirmed no balance-moving path besides the three documented transfers.

---

## 6. Known Limitations (Not Bugs — Disclosed by Design)

| Limitation | Why it exists | User disclosure |
|---|---|---|
| Verification cannot catch sophisticated fraud | Manual review / KYB have real-world limits | `RISK_DISCLOSURE.md` §2 |
| Contract cannot compel fiat repayment; v1.0.0 `repay-receivable` is on-chain sBTC only | No contract enforces off-chain payment; no off-chain-confirm function exists in v1.0.0 | `RISK_DISCLOSURE.md` §3 |
| Default triggers no recovery | Out of scope; default is data, not dispute resolution | `RISK_DISCLOSURE.md` §4 |
| No formal third-party audit | Bounded by single-counterparty pilot + full test suite; audit required before expansion | `RISK_DISCLOSURE.md` §5 |
| Flat repayment (no interest/fee field) | MVP has no `repayment-amount`; economics handled off-chain for pilot | `TECHNICAL_ARCHITECTURE.md` §3.3 |
| Admin-gated release/default (not permissionless) | MVP compliance hook; loosening changes timing only, never recipient | `TECHNICAL_ARCHITECTURE.md` §3.3 |
| `set-sbtc-contract` exists in the testnet build reviewed here | Needed to repoint escrow at `mock-sbtc-token` during development | Scheduled for full removal from source before mainnet deployment — see `MILESTONE_PLAN.md` Milestone 2, not merely a runtime restriction |

---

## 7. Test Coverage Summary

Stack: Clarinet SDK + Vitest (`FlowFi-BTC`, `npm run test`). Full 46-test suite passing on Clarinet simnet:

| Test file | Count | Status |
|---|---|---|
| `registry` (register/verify/receivable/cancel/mark-* auth) | 26 | ☑ Done (26 passing) |
| `escrow` (fund/release/repay/default + wrong-token/self-fund/double-spend guards, **including 2 full end-to-end integration paths**: happy-path → REPAID, and past-due → DEFAULTED) | 20 | ☑ Done (20 passing) |
| **Total** | **46** | ☑ All passing |

Milestone 1 hardening work expands this to 70+ tests (additional boundary cases on amounts/dates,
repeated-call sequencing, and admin-reassignment interactions) — see `MILESTONE_PLAN.md`.

---

## 8. Explicitly Out of Scope for This Review

- Formal verification / mathematical proofs
- Third-party audit (required before any expansion beyond this pilot)
- Economic/game-theoretic modeling (not applicable at single-counterparty, non-pooled scale)
- Frontend/API security review (contracts only)

---

## Sign-off

**Reviewed by:** @ProdevappOFFICIAL
**Date:** September 1, 2026
**Contracts reviewed:** `flowfi-registry.clar` v1.0.0, `flowfi-escrow.clar` v1.0.0,
`mock-sbtc-token.clar` v1.0.0 at testnet principals above.
**Result:** All §1 authorization, §2 caller-boundary, §3 conservation, and §5 custody checks pass against the 46-test suite (26 registry + 20 escrow, including 2 full integration paths, all green on Clarinet simnet). Open items: `set-sbtc-contract` removal, scheduled for Milestone 2, not yet executed as of this review.
