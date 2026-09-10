# FlowFi BTC — Grant Application Narrative

## Stacks Endowment: Getting Started Program Track

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

## 3. Current Progress

FlowFi BTC is not an idea-stage application. The following exists today:

| Component | Status |
|---|---|
| Contracts (`flowfi-registry` v1.0.0 + `flowfi-escrow` v1.0.0 + `mock-sbtc-token` v1.0.0) | Implemented and **deployed to Stacks testnet** (principals above); wiring: `set-escrow-contract` + `set-sbtc-contract` → mock |
| Demo verification flow | Built — produces a normalized, on-chain-hashable verification record |
| Off-chain API layer | Built — connects verification data to the frontend and contract calls |
| Frontend (live) | https://flowfi-btc.vercel.app/ — business dashboard + public receivable page |
| Test suite | Scaffolding in place (`vitest-environment-clarinet` placeholders); M1 target: 40–60 tests + 2 lifecycle integrations |

---

## 4. Milestone Plan (Summary)

See [MILESTONE_PLAN.md](./MILESTONE_PLAN.md) for full detail.

| Milestone | Deliverables | Funding |
|---|---|---|
| **M1: Hardening & Verification** | Full test suite, finalized verification path, testnet deployment | 20% |
| **M2: Mainnet Launch** | Mainnet deployment, public frontend, complete documentation | 30% |
| **M3: Real Pilot & Outcome Report** | One real financing cycle, resolved on-chain, honestly reported | 50% |

---

## 5. Budget Breakdown (Summary)

See [BUDGET_PROPOSAL.md](./BUDGET_PROPOSAL.md) for full detail.

**Requested Amount: $10,000**

| Category | Amount | % |
|---|---|---|
| Contract hardening, testing, verification | $4,000 | 40% |
| Mainnet launch, frontend, documentation | $3,500 | 35% |
| Real pilot execution and reporting | $2,500 | 25% |

---

## 6. Ecosystem Impact

See [ECOSYSTEM_IMPACT.md](./ECOSYSTEM_IMPACT.md) for detailed analysis. In summary, FlowFi BTC:

- Demonstrates a concrete, real-money sBTC use case outside DeFi lending, liquidity, and trading.
- Produces open-source Clarity patterns (verified-identity gating, escrow-then-release funding, on-chain-hashed off-chain evidence) other builders can reference.
- Stays deliberately narrow — one pilot, one business, one provider — so the deliverable is provable rather than promised.

---

## 7. Team & Execution Capability

See [TEAM_AND_EXECUTION.md](./TEAM_AND_EXECUTION.md).

---

## 8. Long-Term Vision

See [ROADMAP.md](./ROADMAP.md). In short: if the single pilot resolves and proves the mechanism, the natural next step is additional receivables with additional counterparties, and eventually a pluggable verification layer supporting multiple attestation sources. Any move toward multi-provider or public funding is explicitly deferred pending proper legal review — it is not part of this grant.

---

## 9. Links & Resources

- **Frontend (live):** https://flowfi-btc.vercel.app/
- **Testnet registry:** `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry` ([explorer](https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry?chain=testnet))
- **Testnet escrow:** `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow` ([explorer](https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow?chain=testnet))
- **Testnet mock sBTC:** `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token` ([explorer](https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token?chain=testnet))
- **Repository:** [https://github.com/FlowFi-BTC/FlowFi-BTC](https://github.com/FlowFi-BTC/FlowFi-BTC)
- **Risk Disclosure:** [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md)
- **Technical Architecture:** [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md)
- **Security Self-Review:** [SECURITY_REVIEW.md](./SECURITY_REVIEW.md)
