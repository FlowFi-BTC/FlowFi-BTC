# FlowFi BTC — Milestone Plan

## Getting Started Program Track | $10,000 Request | 20 / 30 / 50 Split

---

## Scope Lock

**Primary user for this grant: one real business (capital seeker) and one real sBTC provider (capital giver), completing one full financing cycle through `registry.clar` and `escrow.clar`.**

This is not a marketplace, not a multi-tenant platform, and not a consumer investment product. Every milestone below is evaluated against one question:

> *"Does this help one verified business receive real sBTC financing against one real receivable, transparently, non-custodially, and safely?"*

Explicitly deferred (see [ROADMAP.md](./ROADMAP.md), not built in this grant):
- Multi-provider pooling or marketplace UI at scale
- Consumer-facing investment product
- Automated collections or recovery
- A fiat/sBTC exchange or P2P conversion service (repayment uses off-chain confirmation instead — see [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md))

---

## Milestone 1 — Contract Hardening, Testing & Verification

**Timeline:** Weeks 1–4
**Tranche:** $2,000 (20%)

### Deliverables

| Item | Detail |
|---|---|
| `registry.clar` finalized | Business registration, verification (status/method/level enums), receivable registration and lifecycle state, authorization restricting financial state changes to the authorized escrow contract only |
| `escrow.clar` finalized | Funding, escrow-then-release, repayment confirmation, default marking — restricted to real sBTC (SIP-010) movement, no custody by any private/team wallet |
| Test suite | Target 40–60 tests across both contracts on Clarinet simnet: business registration, verification (verified/unverified/expired/revoked/unauthorized-verifier), receivable registration (verified vs. unverified business), funding (open/already-funded/wrong-amount), release, repayment (correct/underpayment/double-repayment), default (before/after due date, already-repaid, already-defaulted) |
| Two full integration tests | (1) full happy path: register → verify → register receivable → fund → release → repay → REPAID. (2) default path: register → verify → register receivable → fund → release → due date passes → default → DEFAULTED |
| Verification path finalized | Either a completed third-party KYB integration, or the documented Manual Pilot Review fallback — both produce a normalized, on-chain-hashed verification record so the contract layer doesn't change either way |
| Security self-review | Checklist covering authorization on every mutating function, `tx-sender` vs. `contract-caller` correctness, no reentrancy vectors, correct status-transition guards |
| Testnet deployment | Both contracts live and interacting correctly on Stacks testnet |

### Success Metrics

- [ ] 40+ tests passing on Clarinet simnet, 0 known failing edge cases
- [ ] Both integration tests (happy path and default path) passing end-to-end
- [ ] Verification path produces a real, reviewable record for at least one test business
- [ ] `SECURITY_REVIEW.md` published

### Acceptance Criteria for Tranche Release

Working testnet deployment of both contracts + passing test suite (including both integration tests) + finalized verification path + published security review notes.

---

## Milestone 2 — Mainnet Launch & Transparency Layer

**Timeline:** Weeks 5–8
**Tranche:** $3,000 (30%)

### Deliverables

| Item | Detail |
|---|---|
| Mainnet deployment | `registry.clar` and `escrow.clar` deployed to Stacks mainnet, correctly configured (authorized escrow address, sBTC contract reference) |
| Public receivable page | Wallet-aware: business sees management actions, provider sees funding actions, anyone else sees read-only status and verification information |
| Business dashboard | Overview, Receivables, Active Funding, Settings |
| Full documentation | `README.md`, `RISK_DISCLOSURE.md`, `ROADMAP.md`, `TECHNICAL_ARCHITECTURE.md` — all published, open-source |
| Explicit custody statement | `RISK_DISCLOSURE.md` states precisely what escrow holds, for how long, and under what conditions it releases — not a blanket "no custody" claim, since escrow briefly holds funds by design |

### Success Metrics

- [ ] Both contracts live and independently verifiable on Stacks mainnet
- [ ] Public receivable page reachable and functional without dashboard access
- [ ] Full documentation set published in the open-source repository
- [ ] Custody and repayment boundaries stated precisely, matching what the code actually does

### Acceptance Criteria for Tranche Release

Live mainnet contracts + functioning public page and dashboard + complete, accurate documentation set, all open-source.

---

## Milestone 3 — Real Pilot Execution & Outcome Report

**Timeline:** Weeks 9–12
**Tranche:** $5,000 (50%, Final)

### Deliverables

| Item | Detail |
|---|---|
| Named real business | One real business, verified through the Milestone 1 verification path, registers one real receivable on mainnet |
| Named real capital provider | One real sBTC holder funds the receivable with a real, on-chain sBTC transaction |
| Full cycle to resolution | Registered → Funded → Repaid or Defaulted, completed on-chain. Repayment may occur via direct sBTC or via confirmed off-chain fiat settlement reflected on-chain, per the boundary disclosed in `RISK_DISCLOSURE.md` |
| Outcome report | `PILOT_RESULT.md` — the actual outcome, whichever it is, what worked, what didn't, and what Phase 2 needs based on real evidence |

### Success Metrics

- [ ] One real receivable registered, verified, and funded with real sBTC (not testnet, not a mock transaction)
- [ ] Full lifecycle completed and visible on-chain
- [ ] `PILOT_RESULT.md` published with an honest account of the outcome

### Final Adoption Metric (required)

**Metric:** one completed real financing cycle — registration through resolution — with real sBTC, involving one named business and one named capital provider.

**Measured by:** on-chain transaction history for both contracts (verifiable via Stacks Explorer) plus the published `PILOT_RESULT.md`. A resolved default counts as a completed cycle equally with a resolved repayment — the metric is a completed, transparent transaction, not a guaranteed successful outcome.

### Acceptance Criteria for Tranche Release

Completed real financing cycle with a named business and named provider, resolved on-chain, honestly reported.
