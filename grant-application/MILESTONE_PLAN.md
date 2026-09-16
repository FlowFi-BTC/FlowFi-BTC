# FlowFi BTC — Milestone Plan

## Getting Started Program Track | $10,000 Request | 20 / 30 / 50 Split

---

## Scope Lock

**Primary user for this grant: one real business (capital seeker) and one real sBTC provider (capital giver), completing one full financing cycle through `flowfi-registry` and `flowfi-escrow`.**

Live references for every milestone: frontend https://flowfi-btc.vercel.app/; testnet registry
`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry`; escrow
`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow`; mock sBTC
`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`.

This is not a marketplace, not a multi-tenant platform, and not a consumer investment product. Every milestone below is evaluated against one question:

> *"Does this help one verified business receive real sBTC financing against one real receivable, transparently, non-custodially, and safely?"*

Explicitly deferred (see [ROADMAP.md](./ROADMAP.md), not built in this grant):
- Multi-provider pooling or marketplace UI at scale
- Consumer-facing investment product
- Automated collections or recovery
- A fiat/sBTC exchange or P2P conversion service (repayment uses off-chain confirmation instead — see [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md))

**Revised timeline (see below):** Milestone dates were compressed after reviewer feedback that the original ~25-week plan carried excess buffer relative to this track's 8–12 week guidance. The dates below are the current commitment, not the original submission.

---

## Milestone 1 — Contract Hardening, Testing & Verification

**Timeline:** Weeks 1–4 (Target: **October 25, 2026**, ~4 weeks from approval)
**Tranche:** $2,000 (20%)

### Deliverables

| Item | Detail |
|---|---|
| `flowfi-registry` finalized | Business registration (one per wallet), verifier-gated verification (status/method/level enums + lazy expiry + `buff-32` hashes), receivable registration and lifecycle state; `mark-funded`/`mark-repaid`/`mark-defaulted` restricted to the wired escrow via `contract-caller` |
| `flowfi-escrow` finalized | `fund-receivable` (provider ≠ business, exact registry amount), admin-only `release-funds`, business-only `repay-receivable` (flat, atomic), admin-only `mark-default` (past burn-height due-date); SIP-010 structural trait + wrong-token guard; no custody outside documented paths. **Stretch goal, if runway allows:** replace the flat `funding-amount` repayment with a single `repayment-amount` field equal to `funding-amount` plus a small fixed fee (not compounding interest, no rate schedule, no oracle) — see note below |
| `mock-sbtc-token` (testnet) | Admin `mint` + self-serve `claim-daily-sbtc` (100 sBTC / 144 burn-blocks, 8 decimals); live at `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`. Testnet-only — never referenced by the mainnet build (see Milestone 2) |
| Test suite | 46 tests passing today (26 registry + 20 escrow, including 2 full integration paths). This milestone's hardening work expands coverage to **70+ tests** — additional edge cases on amount/date boundaries, repeated-call sequencing, and admin-reassignment interactions |
| Two full integration tests | (1) full happy path: register → verify → register receivable → fund → release → repay → REPAID. (2) default path: register → verify → register receivable → fund → release → due date passes → admin default → DEFAULTED. Both already implemented and passing; retained and re-verified as part of this milestone's expanded suite |
| Verification path finalized | Either a completed third-party KYB integration, or the documented Manual Pilot Review fallback — both produce a normalized, on-chain-hashed verification record so the contract layer doesn't change either way |
| Security self-review | Completed against [SECURITY_REVIEW.md](./SECURITY_REVIEW.md) — authorization on every mutating function, `tx-sender` vs. `contract-caller` correctness, token conservation, correct status-transition guards |
| Testnet deployment | **Already live** (registry + escrow + mock at principals above, wired via `set-escrow-contract` / `set-sbtc-contract`); M1 re-verifies wiring and publishes explorer links + `get-escrow-contract` / `get-sbtc-contract` reads |

### Milestone 1 Adoption / Success Metric

**N/A — this is a testnet-only milestone; no user-adoption claim is made.** Success for Milestone 1 is measured entirely by: 70+ passing tests on Clarinet simnet, both integration tests (happy path and default path) passing end-to-end, a published and signed-off [SECURITY_REVIEW.md](./SECURITY_REVIEW.md), and a clean frontend QA log with no known broken flows. There is no user or transaction-volume metric at this stage — that begins at Milestone 3.

### Success Metrics

- [x] 46 tests passing on Clarinet simnet today (26 registry + 20 escrow, including 2 integration paths), 0 known failing edge cases
- [ ] Suite expanded to 70+ tests as part of this milestone's hardening work
- [ ] Both integration tests (happy path and default path) passing end-to-end
- [ ] Verification path produces a real, reviewable record for at least one test business
- [ ] [SECURITY_REVIEW.md](./SECURITY_REVIEW.md) completed and published, with sign-off section filled in

### Acceptance Criteria for Tranche Release

Working testnet deployment of both contracts + passing 70+-test suite (including both integration tests) + finalized verification path + published security review notes.

**Note on the fixed-fee stretch goal:** a flat 0%-fee repayment is still a valid, honestly-reported pilot and satisfies this milestone on its own — the fee is not required for tranche release. If added, call it a **fee**, never "interest" or "yield," in all documentation. `RISK_DISCLOSURE.md` §6 already establishes that the securities/crowdfunding risk in this space comes from *public solicitation* of returns from *multiple* retail funders — a single bilateral fixed fee between two named counterparties does not trigger that risk, but the "fee not yield" language should be kept consistent everywhere to avoid undermining that argument.

---

## Milestone 2 — Mainnet Launch & Transparency Layer

**Timeline:** Weeks 5–8 (Target: **November 22, 2026**, ~8 weeks from approval)
**Tranche:** $3,000 (30%)

### Deliverables

| Item | Detail |
|---|---|
| Mainnet deployment | `flowfi-registry` and `flowfi-escrow` deployed to Stacks mainnet (registry first), wired via `set-escrow-contract`. **`set-sbtc-contract` is removed from the contract source entirely before this deployment** — not locked, not gated, not left-but-unused: the function does not exist in the mainnet build. The sBTC contract address is hardcoded to `SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token` with no post-deploy override path of any kind |
| Public receivable page | Wallet-aware on https://flowfi-btc.vercel.app/: business sees management actions, provider sees funding actions, anyone else sees read-only status and verification information. **All demo/placeholder content (seed businesses, funding-progress bars, yield language) is removed before this milestone is considered complete** — the public site reflects only real state: empty, clearly-labeled testnet data, or a real registered receivable |
| Business dashboard | Overview, Receivables, Active Funding, Settings |
| Full documentation | `README.md`, `RISK_DISCLOSURE.md`, `ROADMAP.md`, `TECHNICAL_ARCHITECTURE.md` — all published, open-source, and re-verified against the mainnet contracts (not the testnet build) |
| Explicit custody statement | `RISK_DISCLOSURE.md` states precisely what escrow holds, for how long, and under what conditions it releases — not a blanket "no custody" claim, since escrow briefly holds funds by design |

### Success Metrics

- [ ] Both contracts live and independently verifiable on Stacks mainnet, with `set-sbtc-contract` absent from the deployed source (verifiable by anyone reading the mainnet contract)
- [ ] Public receivable page reachable and functional without dashboard access, with no placeholder/demo content presented as real
- [ ] Full documentation set published in the open-source repository
- [ ] Custody and repayment boundaries stated precisely, matching what the code actually does

### Acceptance Criteria for Tranche Release

Live mainnet contracts (with `set-sbtc-contract` removed) + functioning public page with no placeholder data + complete, accurate documentation set, all open-source.

---

## Milestone 3 — Real Pilot Execution & Outcome Report

**Timeline:** Weeks 9–12 (Target: **December 20, 2026**, ~12 weeks from approval)
**Tranche:** $5,000 (50%, Final)

The longest relative allowance remains on this milestone specifically because it depends on external counterparties (a real business and a real capital provider) outside our direct control — not because the underlying work takes 4 weeks on its own.

### Deliverables

| Item | Detail |
|---|---|
| Named real business | One real business — selected from the two candidate businesses already contacted, see [PILOT_READINESS.md](./PILOT_READINESS.md) — verified through the Milestone 1 verification path, registers one real receivable on mainnet. Having two candidate leads is risk mitigation (a fallback if one isn't ready in time), not an expansion of scope — only one receivable is registered for this grant |
| Named real capital provider | One real, **independent, unaffiliated** sBTC holder funds the receivable with a real, on-chain sBTC transaction via `fund-receivable` (admin then calls `release-funds`). Capital-provider outreach is underway but not yet resolved as of this application — see [PILOT_READINESS.md](./PILOT_READINESS.md) and `RISK_DISCLOSURE.md` §8 for current outreach numbers. **There is no self-funding or related-party fallback.** If no independent provider is secured by this milestone's deadline, the milestone is reported incomplete in `PILOT_RESULT.md`, naming the absence of an independent provider as the specific unmet condition |
| Full cycle to resolution | Registered (OPEN) → Funded (FUNDED) → Repaid (REPAID) or Defaulted (DEFAULTED, admin `mark-default` past burn-height due-date), completed on-chain. On-chain sBTC repayment via `repay-receivable`; any off-chain fiat leg is process-confirmed (v1.0.0 has no off-chain-confirm function), per `RISK_DISCLOSURE.md` |
| Outcome report | `PILOT_RESULT.md` — the actual outcome, whichever it is, what worked, what didn't, and what Phase 2 needs based on real evidence. If a financing cycle completes, this report discloses: the provider's public Stacks wallet address, the approximate date and channel of initial contact, a statement that the provider was not affiliated with the project team, and evidence that the provider chose to participate independently. This disclosure is what distinguishes a genuine third-party cycle from a self-funded or related-party one |

### Success Metrics

- [ ] One real receivable registered, verified, and funded with real sBTC (not testnet, not a mock transaction) **by an independent, unaffiliated provider**
- [ ] Full lifecycle completed and visible on-chain
- [ ] `PILOT_RESULT.md` published with an honest account of the outcome, including the independence-disclosure items above if a cycle completed, or a plain statement of incompletion if it did not

### Final Adoption Metric (required)

**Metric:** one completed real financing cycle — registration through resolution — with real sBTC, involving one named business and one named, independent, unaffiliated capital provider.

**Measured by:** on-chain transaction history for both contracts (verifiable via Stacks Explorer) plus the published `PILOT_RESULT.md`, including the independence-disclosure items listed above. A resolved default counts as a completed cycle equally with a resolved repayment — the metric is a completed, transparent transaction with a genuine independent counterparty, not a guaranteed successful outcome and not a self-funded substitute.

### Acceptance Criteria for Tranche Release

Completed real financing cycle with a named business and a named, independent, unaffiliated provider, resolved on-chain, honestly reported — or, absent that, an honest incomplete-milestone report naming the unmet condition.
