# FlowFi BTC — Stacks Endowment Grant Application

## Getting Started Program Track

---

## Document Index

| Document | Purpose |
|---|---|
| [PROJECT_OVERVIEW.md](../README.md) | Product-level overview — the problem, the solution, how it works, what it isn't (repo-root README) |
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
| **Current Status** | Contracts implemented (`flowfi-registry.clar` v1.0.0 + `flowfi-escrow.clar` v1.0.0 + `mock-sbtc-token.clar` v1.0.0), deployed to Stacks **testnet** (see Live Deployments below); frontend live; test suite scaffolding in place (Milestone 1 target: 40–60 tests) |
| **Key Technology** | Clarity 5, sBTC (SIP-010, structural trait), Stacks Connect, two-contract architecture (`flowfi-registry` owns state, `flowfi-escrow` owns money) |
| **Frontend (live)** | https://flowfi-btc.vercel.app/ |

---

## Live Deployments (Stacks Testnet)

Deployer: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ`

| Contract | Fully-qualified ID (testnet) | Source file |
|---|---|---|
| Registry (identity, verification, receivable state — holds no sBTC) | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry` | `FlowFi-BTC/contracts/flowfi-registry.clar` |
| Escrow (sBTC custody, funding, release, repayment, default) | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow` | `FlowFi-BTC/contracts/flowfi-escrow.clar` |
| Mock sBTC (testnet-only SIP-010 stand-in, 8 decimals, faucet + mint) | `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token` | `FlowFi-BTC/contracts/mock/mock-sbtc-token.clar` |

Verify on Stacks Explorer (testnet), e.g.:

- `https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry?chain=testnet`
- `https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow?chain=testnet`
- `https://explorer.hiro.so/address/ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token?chain=testnet`

> Post-deploy wiring (required, in order): deploy `flowfi-registry` first (escrow references `.flowfi-registry` statically), then deploy `flowfi-escrow`, then call `registry.set-escrow-contract` with the escrow principal, then call `escrow.set-sbtc-contract` with the mock-sBTC principal on testnet. Until `set-escrow-contract` is called, `mark-funded` / `mark-repaid` / `mark-defaulted` are unreachable by design (`escrow-contract` defaults to `none`). The escrow's `sbtc-contract` defaults to the **mainnet** sBTC principal and must be repointed on testnet.

---

## What Sets This Application Apart

1. **Narrow and honest, on purpose.** This is one real financing cycle — one verified business, one real sBTC provider, one receivable, resolved on-chain — not a marketplace or investment platform. The scope was deliberately cut down from a larger vision to keep legal and execution risk low for a first grant.

2. **A real, underserved sBTC use case.** sBTC utility today is concentrated in DeFi lending, liquidity, and trading. FlowFi BTC is a concrete answer to what sBTC can do in the real economy: financing a real, verifiable trade receivable.

3. **Clean separation of concerns.** `flowfi-registry` owns identity, verification, and receivable state. `flowfi-escrow` owns sBTC custody, funding, and settlement. Neither contract does the other's job — see [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md). All dates are Bitcoin-anchored **burn-block heights**, not wall-clock timestamps.

4. **Every limitation is named, not hidden.** Unaudited contract status, the manual-review verification fallback, and the reality that repayment may depend on off-chain fiat confirmation are all disclosed directly in [RISK_DISCLOSURE.md](./RISK_DISCLOSURE.md) — not discovered by a reviewer reading the code.

5. **Low execution risk, real deliverable.** The grant funds hardening, mainnet deployment, and executing one real transaction — not open-ended R&D on an unproven idea.
