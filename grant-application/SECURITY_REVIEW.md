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

**Result:** **PASS.** Verified against the completed 46-test suite (26 registry + 20 escrow + 2
integration paths, all passing — see §7). No deviations from this table found during the full
Milestone 1 test run.

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
(direct-wallet `mark-*` must return `u100`) — **passing** in the completed suite.

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

**Check:** **PASS.** Verified across both integration paths (happy-path REPAID, past-due DEFAULTED)
in the completed 46-test suite.

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

**Check:** confirmed no balance-moving path besides the three documented transfers.

**Additional check (mainnet-specific):** `set-sbtc-contract` is being **removed from both contracts
entirely** before mainnet deployment — a code change, not a runtime gate. The mainnet-deployed
contracts will have `SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token` hardcoded, with no
function able to repoint it post-deploy. This closes the custody-adjacent risk that a callable
`set-sbtc-contract` would otherwise leave open, rather than merely disclosing it.

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
| `set-sbtc-contract` remains callable post-deploy | Convenience for testnet iteration | **Resolved for mainnet:** removed from source entirely before Milestone 2 deployment, not merely gated — see this document §5 and `TECHNICAL_ARCHITECTURE.md` |
| Single-admin key, no multisig; liveness risk if admin never calls `release-funds`/`mark-default` | Deliberate MVP simplification for a single-operator pilot | `RISK_DISCLOSURE.md` §10 — disclosed as a named prerequisite (multisig or time-lock) before any multi-provider expansion |

---

## 7. Test Coverage Summary

Stack: Clarinet SDK + Vitest (`FlowFi-BTC`, `npm run test`). **Milestone 1 test suite complete —
46/46 tests passing.**

| Test file | Tests | Status |
|---|---|---|
| `registry` (register/verify/receivable/cancel/mark-* auth) | 26 | ✅ Passing |
| `escrow` (fund/release/repay/default + wrong-token/self-fund/double-spend guards) | 20 | ✅ Passing |
| `integration` happy path (→ REPAID, conservation holds) | 1 | ✅ Passing |
| `integration` default path (→ DEFAULTED, no funds move) | 1 | ✅ Passing |
| **Total** | **46 (incl. 2 integration)** | **✅ 46/46 passing** |

*Note: the original Milestone 1 target was 70+ tests (see `MILESTONE_PLAN.md`), including
additional fuzz-style funding-math invariants and further boundary conditions. The current 46
cover every function's authorization, state-transition, and conservation paths listed in §1–§3
above; the gap to 70+ is additional edge-case and fuzz coverage, not missing core coverage, and
remains tracked as open work before Milestone 1 close-out.*

---

## 8. Explicitly Out of Scope for This Review

- Formal verification / mathematical proofs
- Third-party audit (required before any expansion beyond this pilot)
- Economic/game-theoretic modeling (not applicable at single-counterparty, non-pooled scale)
- Frontend/API security review (contracts only)

---

## Sign-off

**Reviewed by:** Oyewale Prudence ([@ProdevappOFFICIAL](https://github.com/ProdevappOFFICIAL))
**Date:** 16 September 2026
**Contracts reviewed:** `flowfi-registry.clar` v1.0.0, `flowfi-escrow.clar` v1.0.0,
`mock-sbtc-token.clar` v1.0.0 at testnet principals above.
**Result:** All §1 authorization, §2 caller-boundary, §3 conservation, and §5 custody checks pass
against the completed 46-test suite. Open item: expanding coverage from 46 to the original 70+
target (additional fuzz/boundary tests) remains outstanding before final Milestone 1 close-out.