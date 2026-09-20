# FlowFi BTC — Grant Application Narrative

## Stacks Endowment: Getting Started Program Track

> **Update — September 20, 2026:** Capital-provider outreach, the project's largest open dependency, has its first provider-side signal — after 30+ X outreach attempts, [@Demihumanb](https://x.com/Demihumanb) (`SP2PZYA27E8MRBQHQXE0JQH5CHM9JJNM00YEMC4QJ`) has expressed preliminary interest (pre-commitment, pre-funding). See [PILOT_READINESS.md](./PILOT_READINESS.md) for full detail and [RISK_DISCLOSURE.md §8](./RISK_DISCLOSURE.md) for the unchanged risk framing.

---

## Project Name

**FlowFi BTC** — Bitcoin-Native Receivables Financing Infrastructure

## One-Line Description

FlowFi BTC lets a verified business register a real trade receivable and receive financing directly from an sBTC holder through a non-custodial Clarity smart contract — proving, with one real transaction, that Bitcoin liquidity can finance real-world cash flows.

*For the fuller product description independent of this grant application, see the repo-root [PROJECT_OVERVIEW](../README.md).*

---

## 1. Problem Statement

### The Gap in the Stacks Ecosystem

sBTC holders currently have very few ways to put Bitcoin capital to work outside of DeFi lending, liquidity provision, and trading — activity that mostly recirculates capital within DeFi rather than financing the real economy.

At the same time, small and growing businesses routinely have capital locked in unpaid invoices for 30–90 days. They have earned the money; they cannot use it yet. Traditional receivables financing solves this but is typically slow, intermediary-heavy, and geographically restricted.

**No project on Stacks currently connects these two gaps directly.**

### Who This Affects

- **Businesses** holding real receivables who need working capital before the invoice is due.
- **sBTC holders** looking for real-world, short-duration, asset-backed uses of their Bitcoin capital, beyond existing DeFi options.
- **The broader Stacks ecosystem** — a working, transparent receivables-financing primitive is composable infrastructure other builders can eventually build on.

---

## 2. Solution: FlowFi BTC

FlowFi BTC is a two-contract Clarity protocol: `flowfi-registry` (identity, verification, and receivable state — holds no sBTC) and `flowfi-escrow` (sBTC custody, funding, and settlement). See [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md) for the code-verified spec.

Live on Stacks testnet today — deployer `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ`:

- Registry: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry`
- Escrow: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow`
- Mock sBTC (test-only faucet/mint token): `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`
- Frontend: https://flowfi-btc.vercel.app/

### How It Works

1. **Register** — A business registers on-chain via `registry.register-business` (one business per wallet) and completes verification via `verify-business` (verifier-only; demo-stage Manual Pilot Review, or third-party KYB if integration completes — see [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md)). Expiry is lazy: `is-business-verified` re-derives it every read.
2. **Submit** — The verified business registers one real receivable via `register-receivable`: debtor, invoice number + `invoice-hash (buff 32)`, `face-value`, `funding-amount (≤ face-value)`, and burn-height `issue/due-date`. Status opens as `OPEN`.
3. **Fund** — A capital provider (any wallet except the business itself) reviews the receivable and calls `escrow.fund-receivable` with the SIP-010 token. Exactly `funding-amount` moves provider → escrow; the amount is read from the registry so under/over-funding is impossible. Registry flips `OPEN → FUNDED` via escrow-only `mark-funded`.
4. **Escrow & Release** — sBTC sits in `flowfi-escrow` until the **admin** calls `release-funds` (MVP compliance gate; recipient is always the stored business, never redirectable), moving escrow → business.
5. **Repay & Settle** — The business repays on-chain via `repay-receivable` (business-only; moves `funding-amount` business → escrow → funder atomically; registry `FUNDED → REPAID`), or past-due the admin records `mark-default` (no funds move; registry `FUNDED → DEFAULTED`). Off-chain fiat settlement, if used, is a process-layer confirmation in v1.0.0 — the contract has no off-chain-confirm function (see [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md)). FlowFi BTC never holds a user's private key.

### What Makes This Stacks-Native

- **sBTC specifically, not a stablecoin substitute** — a Bitcoin holder finances a real-world receivable without ever leaving the Bitcoin asset or off-ramping to fiat.
- **Bitcoin-anchored settlement** — financing state transitions are recorded on Stacks, giving both parties a Bitcoin-verifiable record of an off-chain economic event.
- **Clarity's safety model** — decidable execution and no reentrancy risk make the fund-movement logic easier to reason about at small, bounded scale without a full external audit.

---

## 3. Current Progress (Proof of Concept)

I have a working MVP deployed to Stacks testnet with a built frontend. This is not an idea — it is a built product. The frontend is functional but still under active polish: minor inconsistencies are possible, and Milestone 1 explicitly includes frontend testing and UI fixes (see MILESTONE_PLAN.md Deliverable 1.4).

### Smart Contracts (Deployed to Testnet)

| Contract | Lines | Status |
|---|---|---|
| `flowfi-registry.clar` | 385 | Complete — 11 public functions (register-business, verify-business, revoke-verification, register-receivable, cancel-receivable, mark-funded, mark-repaid, mark-defaulted, set-admin, set-verifier, set-escrow-contract), 10 read-only functions |
| `flowfi-escrow.clar` | 257 | Complete — 6 public functions (fund-receivable, release-funds, repay-receivable, mark-default, set-admin, set-sbtc-contract), 4 read-only functions |
| `mock-sbtc-token.clar` | 161 | Complete — test-only SIP-010 stand-in for sBTC (8 decimals, admin mint + self-serve daily faucet) |

Testnet deployer: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ`

- Registry: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry`
- Escrow: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow`
- Mock sBTC (test-only faucet/mint token): `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`
- Wiring: `set-escrow-contract` + `set-sbtc-contract` → mock (escrow-only `mark-funded` / `mark-repaid` / `mark-defaulted` gate enforced)

### Test Suite

46 tests passing (26 flowfi-registry + 20 flowfi-escrow)
Covers: register-business (incl. duplicate rejection), verify-business (verifier-only, method/level range, expiry), revoke-verification, is-business-verified (incl. lazy expiry), register-receivable (owner + verified gates, funding-amount ≤ face-value, due/issue dates), cancel-receivable, escrow auth gate (direct `mark-funded` rejected even by deployer), fund-receivable (exact registry amount pulled, non-OPEN / double-fund / self-fund / wrong-token rejections), release-funds (admin-only, no double-release, payout recorded), repay-receivable (release-first gate, business-only), mark-default (past-due-only, admin-only, repaid-excluded), admin reassignment, plus 2 end-to-end lifecycles (register → verify → fund → release → repay; and → default path)
Built with Clarinet SDK v3.9.0 + Vitest 3.2.7 (`vitest-environment-clarinet`)

### Frontend Application

21 pages across landing, public marketplace explorer, receivable detail (wallet-aware), business dashboard (overview / receivables / submit / funding / settings), investor dashboard (overview / fundings / funding-detail), onboarding, business verification, transparency log, and admin surface — live at https://flowfi-btc.vercel.app/
Full wallet integration (Leather & Xverse via `@stacks/connect`)
All 7 contract interactions wired through backend `prepare → sign → confirm → poll`: register-business, verify-business (verifier session), register-receivable, fund-receivable, release-funds (admin), repay-receivable, mark-default (admin; MVP off-chain flag pending on-chain wiring)
Honest caveat: the frontend is built and live but still being polished — minor inconsistencies (stale routes, wrong status displays, dead links) are possible. Frontend testing and UI fixes are a committed Milestone 1 deliverable, so what reviewers click in M2/M3 is verified, not assumed.
Off-chain API layer (11 routers: auth, onboarding, businesses, investors, receivables, marketplace, verification, fundings, transactions, escrows, dashboards) connects verification data, invoice SHA-256 evidence, and `operationId` + `Idempotency-Key` flows to the frontend and contract calls

---

## 4. Milestone Plan (Summary)

See [MILESTONE_PLAN.md](./MILESTONE_PLAN.md) for full detail.

| Milestone | Deliverables | Funding |
|---|---|---|
| **M1: Hardening & Verification** | Full test suite, finalized verification path, testnet deployment | 20% |
| **M2: Mainnet Launch** | Mainnet deployment, public frontend, complete documentation | 30% |
| **M3: Real Pilot & Outcome Report** | One real financing cycle, resolved on-chain, honestly reported | 50% |

---



## 5. Ecosystem Impact

See [ECOSYSTEM_IMPACT.md](./ECOSYSTEM_IMPACT.md) for detailed analysis. In summary, FlowFi BTC:

- Demonstrates a concrete, real-money sBTC use case outside DeFi lending, liquidity, and trading.
- Produces open-source Clarity patterns (verified-identity gating, escrow-then-release funding, on-chain-hashed off-chain evidence) other builders can reference.
- Stays deliberately narrow — one pilot, one business, one provider — so the deliverable is provable rather than promised.

---

## 6. Team & Execution Capability

See [TEAM_AND_EXECUTION.md](./TEAM_AND_EXECUTION.md).

---

## 7. Long-Term Vision

See [ROADMAP.md](./ROADMAP.md). In short: if the single pilot resolves and proves the mechanism, the natural next step is additional receivables with additional counterparties, and eventually a pluggable verification layer supporting multiple attestation sources. Any move toward multi-provider or public funding is explicitly deferred pending proper legal review — it is not part of this grant.

---

## 8. Links & Resources

- **Frontend (live):** https://flowfi-btc.vercel.app/
- **Testnet registry:** `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry` ([explorer](https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry?chain=testnet))  ([deployment-link](https://explorer.hiro.so/txid/0xf96f8a99dec13b87fef17cc6b7f77642a93a3dc05babe6ee263c65bd39ef2aa5?chain=testnet)) 
- **Testnet escrow:** `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow` ([explorer](https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow?chain=testnet))  ([deployment-link](https://explorer.hiro.so/txid/0x291c96775ffbc9e5e4ca5ecd390cf451a3f0a07c565a4e4f2876afe07113c58b?chain=testnet)) 
- **Testnet mock sBTC:** `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token` ([explorer](https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token?chain=testnet))
- **Repository:** [https://github.com/FlowFi-BTC/FlowFi-BTC](https://github.com/FlowFi-BTC/FlowFi-BTC)
- **Risk Disclosure:** [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md)
- **Technical Architecture:** [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md)
- **Security Self-Review:** [SECURITY_REVIEW.md](./SECURITY_REVIEW.md)
