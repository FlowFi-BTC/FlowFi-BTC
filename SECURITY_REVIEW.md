# FlowFi BTC — Security Self-Review

**Status: Internal self-review. Not a substitute for a formal third-party audit.**

This document records what was checked, how, and what remains open. It is written to be read alongside [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md), which covers risk from a user's perspective; this document covers it from an implementation perspective.

---

## Scope

This review covers `registry.clar` and `escrow.clar` as specified in [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md), at the state reached by the end of Milestone 1.

---

## 1. Authorization Checks

| Function | Required caller | Checked? |
|---|---|---|
| `register-business` | any wallet, but only once per wallet | [ ] Duplicate-registration prevented |
| `verify-business` / `revoke-verification` | authorized verifier only | [ ] Reverts if caller ≠ configured verifier |
| `register-receivable` | business owner, and business must be VERIFIED | [ ] Reverts for unverified business; reverts if caller ≠ business owner |
| `cancel-receivable` | business owner, only if status is OPEN | [ ] Reverts for non-owner; reverts if status ≠ OPEN |
| `mark-funded` / `mark-repaid` / `mark-defaulted` | **authorized escrow contract only**, via `contract-caller` | [ ] Reverts if called by any wallet directly, including the business or provider |
| `fund-receivable` | capital provider, receivable must be OPEN | [ ] Reverts if already funded or not OPEN |
| `release-funds` | cannot be called twice for the same escrow | [ ] Reverts on second call |
| `repay-receivable` | business, or authorized confirming party for off-chain settlement | [ ] Reverts if escrow is not in FUNDED status |
| `mark-default` | only if `block-height > due-date` and not already repaid | [ ] Reverts if called before due date or after repayment |

**Result:** [PASS / OPEN ITEMS — fill in once tests are run against the actual implementation]

---

## 2. The `tx-sender` vs. `contract-caller` Boundary

The registry's `mark-funded`, `mark-repaid`, and `mark-defaulted` functions must check `contract-caller` (which reflects the immediate calling contract) rather than `tx-sender` (which reflects the original transaction signer) when restricting access to the authorized escrow contract. This is the same boundary that other Stacks protocols have had to solve explicitly — getting it backwards would let any wallet forge financing state by calling through an unrelated contract.

**Check:** [ ] Confirmed the registry checks `contract-caller`, not `tx-sender`, for these three functions.

---

## 3. Token Conservation

For every escrow record, the invariant that should hold at all times:

```
funding-amount == amount released to business (if released)
                + amount released to provider on repayment (if repaid)
                + amount remaining in escrow (if neither has occurred yet)
```

No sBTC should ever be creatable, destroyable, or strandable within the contract's logic.

**Check:** [ ] Verified this invariant holds across the two integration test paths (full repayment, default).

---

## 4. Reentrancy

Clarity does not support arbitrary callbacks mid-execution the way EVM chains do, which removes the classic reentrancy attack surface by design. This is a property of the language, not something this project implemented — noted here so reviewers understand why no explicit reentrancy guard exists in the code.

---

## 5. Custody Precision

`escrow.clar` holds sBTC between `fund-receivable` and `release-funds`. This is a deliberate design choice (Option B: escrow-then-release), not an oversight. No private key controlled by the team custodies funds at any point — the escrow is a smart contract, not a wallet.

**Check:** [ ] Confirmed no admin/team function exists that could move escrowed funds outside the documented `release-funds` / `repay-receivable` / `mark-default` paths.

---

## 6. Known Limitations (Not Bugs — Disclosed by Design)

| Limitation | Why it exists | Where it's disclosed to users |
|---|---|---|
| Verification cannot detect a sufficiently sophisticated fraud | Manual review / third-party KYB both have real-world limits | `RISK_DISCLOSURE.md` §2 |
| The contract cannot compel real-world repayment | No smart contract can enforce a fiat payment | `RISK_DISCLOSURE.md` §3 |
| Default triggers no automated recovery | Out of scope for this pilot; real-world collection is not a smart-contract problem | `RISK_DISCLOSURE.md` §4 |
| No formal third-party audit performed | Bounded by small ticket size and single-counterparty scope for this pilot | `RISK_DISCLOSURE.md` §5 |

---

## 7. Test Coverage Summary

*(Fill in once Milestone 1 testing is complete.)*

| Test file | Tests | Status |
|---|---|---|
| `registry_test.ts` | [N] | [ ] |
| `escrow_test.ts` | [N] | [ ] |
| `integration_test.ts` (happy path) | 1 | [ ] |
| `integration_test.ts` (default path) | 1 | [ ] |

---

## 8. Explicitly Out of Scope for This Review

- Formal verification / mathematical proof of contract correctness
- Third-party audit (recommended before any expansion beyond this single pilot — see `RISK_DISCLOSURE.md` §5)
- Economic/game-theoretic attack modeling (not applicable at single-counterparty, non-pooled scale)
- Front-end security review (out of scope for this document; contracts only)

---

## Sign-off

**Reviewed by:** [YOUR NAME]
**Date:** [DATE]
**Result:** [Summarize: e.g. "All authorization and custody checks pass against the current implementation. Open items: none / [list]."]
