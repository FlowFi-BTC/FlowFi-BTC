# FlowFi BTC — Budget Proposal

## Getting Started Program Track | $10,000 Request

---

## Budget Philosophy

This budget funds hardening a designed protocol, deploying it to mainnet, and executing one real transaction — not open-ended research on an unproven idea. Every dollar maps to a milestone deliverable in [MILESTONE_PLAN.md](./MILESTONE_PLAN.md).

---

## Budget Breakdown

### Tranche 1: $2,000 (20%) — Released After Milestone 1

| Line Item | Amount | Description |
|---|---|---|
| Contract development & hardening (`flowfi-registry` + `flowfi-escrow` ) | $900 | Finalizing implemented v1.0.0 contracts per the code-verified `TECHNICAL_ARCHITECTURE.md` (burn-height dates, `contract-caller` gates, SIP-010 guards) |
| Test suite expansion & hardening | $600 | 46 tests completed (26 registry + 20 escrow + 2 integration paths); funds edge-case hardening, simnet execution, and continuous integration maintenance |
| Verification path integration | $500 | Either third-party KYB integration costs, or design/build of the documented manual review fallback |
| **Tranche 1 Total** | **$2,000** | |

### Tranche 2: $3,000 (30%) — Released After Milestone 2

| Line Item | Amount | Description |
|---|---|---|
| Mainnet deployment | $300 | Registry-first Clarinet mainnet deployment + `set-escrow-contract` wiring (testnet already live: `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry` / `.flowfi-escrow`); real sBTC default kept on mainnet |
| Frontend development | $1,600 | Public receivable page + business dashboard on https://flowfi-btc.vercel.app/ (wallet signing, Hiro reads, burn-height date conversion) |
| Documentation | $700 | README, risk disclosure, roadmap, technical architecture |
| Initial hosting | $400 | Frontend hosting, domain, SSL for the pilot period |
| **Tranche 2 Total** | **$3,000** | |

### Tranche 3: $5,000 (50%, Final) — Released After Milestone 3

| Line Item | Amount | Description |
|---|---|---|
| Pilot coordination | $2,000 | Onboarding the real business and real capital provider, coordinating verification and the financing cycle |
| Contingency for pilot execution issues | $1,000 | Buffer for counterparty delays, repayment-path complications, or verification process delays |
| Outcome reporting and retrospective | $1,000 | Writing and publishing `PILOT_RESULT.md`, an honest account of what happened |
| Ecosystem outreach | $1,000 | Sharing results with the Stacks/sBTC community, documentation polish for future builders |
| **Tranche 3 Total** | **$5,000** | |

---

## Total Budget Summary

| Category | Amount | % of Total |
|---|---|---|
| Contract development & testing | $2,000 | 20% |
| Verification integration | $500 | 5% |
| Mainnet deployment & frontend | $1,900 | 19% |
| Documentation & hosting | $1,100 | 11% |
| Pilot coordination & contingency | $3,000 | 30% |
| Outcome reporting & outreach | $1,500 | 15% |
| **Total** | **$10,000** | **100%** |

---

## Funding Efficiency

| Metric | Value |
|---|---|
| Pre-grant work already done | Contract architecture finalized, demo verification flow built, off-chain API layer built, MVP frontend built |
| Cost per milestone | ~$3,333 average across three milestones |
| Deliverable per milestone | Working, testable artifact — not a progress report |

---

## Post-Grant Sustainability

FlowFi BTC's core contracts run autonomously on-chain with no ongoing server costs beyond frontend hosting (~$50–100/month). If the single pilot proves the mechanism, further growth — additional receivables, additional counterparties, a pluggable verification layer — is a future funding conversation, not a cost absorbed by this grant. No revenue model is assumed or built into this pilot; monetization decisions, if any, would follow real usage evidence, not precede it.

---

## How Funds Will NOT Be Used

- No funds for non-Stacks ecosystem activities
- No market manipulation or metric inflation
- No public solicitation of capital from multiple retail funders
- No token purchases for speculation
- No personal expenses unrelated to project development
- No custody of user funds by any team-controlled wallet
