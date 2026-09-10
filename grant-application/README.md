# FlowFi BTC — Stacks Endowment Grant Application

## Getting Started Program Track

---

## Document Index

| Document | Purpose |
|---|---|
| [PROJECT_OVERVIEW.md](./PROJECT_OVERVIEW.md) | Product-level overview — the problem, the solution, how it works, what it isn't |
| [APPLICATION_NARRATIVE.md](./APPLICATION_NARRATIVE.md) | Main grant application — problem statement, solution, progress, vision |
| [MILESTONE_PLAN.md](./MILESTONE_PLAN.md) | Detailed 3-milestone execution plan with deliverables and success metrics |
| [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md) | Contract architecture, frontend stack, verification flow, data flow diagrams |
| [SECURITY_REVIEW.md](./SECURITY_REVIEW.md) | Internal security self-review — authorization, custody, token conservation, known limitations |
| [BUDGET_PROPOSAL.md](./BUDGET_PROPOSAL.md) | $10,000 budget breakdown by tranche, line item, and category |
| [ECOSYSTEM_IMPACT.md](./ECOSYSTEM_IMPACT.md) | Strategic alignment, composability, growth metrics, competitive landscape |
| [TEAM_AND_EXECUTION.md](./TEAM_AND_EXECUTION.md) | Proof of execution, technical depth, methodology, long-term commitment |
| [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md) | On-chain vs. off-chain boundaries, known limitations, honest failure modes |
| [ROADMAP.md](./ROADMAP.md) | Phased vision beyond this grant — explicitly not part of this request |

---

## Quick Facts

| Item | Detail |
|---|---|
| **Project** | FlowFi BTC — Bitcoin-Native Receivables Financing Infrastructure |
| **Track** | Getting Started Program |
| **Funding Request** | $10,000 |
| **Timeline** | ~10–12 weeks (3 milestones) |
| **Current Status** | Contract design finalized, MVP frontend built, demo verification flow built, real off-chain API layer built |
| **Key Technology** | Clarity, sBTC (SIP-010), Stacks Connect, two-contract architecture (`registry.clar` + `escrow.clar`) |

---

## What Sets This Application Apart

1. **Narrow and honest, on purpose.** This is one real financing cycle — one verified business, one real sBTC provider, one receivable, resolved on-chain — not a marketplace or investment platform. The scope was deliberately cut down from a larger vision to keep legal and execution risk low for a first grant.

2. **A real, underserved sBTC use case.** sBTC utility today is concentrated in DeFi lending, liquidity, and trading. FlowFi BTC is a concrete answer to what sBTC can do in the real economy: financing a real, verifiable trade receivable.

3. **Clean separation of concerns.** `registry.clar` owns identity, verification, and receivable state. `escrow.clar` owns sBTC custody, funding, and settlement. Neither contract does the other's job — see [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md).

4. **Every limitation is named, not hidden.** Unaudited contract status, the manual-review verification fallback, and the reality that repayment may depend on off-chain fiat confirmation are all disclosed directly in [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md) — not discovered by a reviewer reading the code.

5. **Low execution risk, real deliverable.** The grant funds hardening, mainnet deployment, and executing one real transaction — not open-ended R&D on an unproven idea.
