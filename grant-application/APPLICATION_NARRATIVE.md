# FlowFi BTC — Grant Application Narrative

## Stacks Endowment: Getting Started Program Track

---

## Project Name

**FlowFi BTC** — Bitcoin-Native Receivables Financing Infrastructure

## One-Line Description

FlowFi BTC lets a verified business register a real trade receivable and receive financing directly from an sBTC holder through a non-custodial Clarity smart contract — proving, with one real transaction, that Bitcoin liquidity can finance real-world cash flows.

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

FlowFi BTC is a two-contract Clarity protocol: `registry.clar` (identity, verification, and receivable state) and `escrow.clar` (sBTC custody, funding, and settlement). See [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md) for full detail.

### How It Works

1. **Register** — A business registers on-chain and completes a verification step (demo-stage manual review, or a third-party KYB provider if integration completes in time — see [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md)).
2. **Submit** — The verified business registers one real receivable: amount, due date, and a hash of the underlying invoice evidence.
3. **Fund** — A capital provider reviews the receivable and its verification status, then funds it directly with sBTC through their own wallet. FlowFi BTC never holds a user's private key.
4. **Escrow & Release** — sBTC is held in the escrow contract and released to the business once funding is confirmed.
5. **Repay & Settle** — The business repays, either directly in sBTC or via confirmed off-chain fiat settlement (see [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md) for why this boundary exists and how it's handled honestly). The registry records the final state: repaid or defaulted.

### What Makes This Stacks-Native

- **sBTC specifically, not a stablecoin substitute** — a Bitcoin holder finances a real-world receivable without ever leaving the Bitcoin asset or off-ramping to fiat.
- **Bitcoin-anchored settlement** — financing state transitions are recorded on Stacks, giving both parties a Bitcoin-verifiable record of an off-chain economic event.
- **Clarity's safety model** — decidable execution and no reentrancy risk make the fund-movement logic easier to reason about at small, bounded scale without a full external audit.

---

## 3. Current Progress

FlowFi BTC is not an idea-stage application. The following exists today:

| Component | Status |
|---|---|
| Contract architecture (`registry.clar` + `escrow.clar`) | Design finalized, implementation in progress |
| Demo verification flow | Built — produces a normalized, on-chain-hashable verification record |
| Off-chain API layer | Built — connects verification data to the frontend and contract calls |
| Frontend (business dashboard + public receivable page) | Built |
| Test suite | In progress — target 40–60 tests across both contracts before mainnet |

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

- **Repository:** [REPO LINK]
- **Risk Disclosure:** [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md)
- **Technical Architecture:** [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md)
