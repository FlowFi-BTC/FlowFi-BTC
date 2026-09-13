# FlowFi BTC — Team & Execution Capability

---

## About the Team

**Oyewale Prudence** — builder of FlowFi BTC, with prior shipped work in the Stacks ecosystem:
- **[LabSTX](https://labstx.online)** — a live Clarity development-tooling IDE, cited in official Stacks documentation. This is the most directly relevant credential to FlowFi BTC's contract work: it demonstrates hands-on depth with Clarity tooling specifically, not just general blockchain development.
- **[StacksMart](https://stacks-mart-murex.vercel.app/)** ([source](https://github.com/ProdevappOFFICIAL/StacksMart)) — a live Next.js storefront with `@stacks/connect` wallet authentication, an admin dashboard, and STX checkout. This demonstrates full-stack shipping discipline and real wallet-integration experience — the same `@stacks/connect` pattern FlowFi BTC's frontend relies on.
**Honest caveat:** StacksMart takes direct STX payments and does not include custom Clarity contracts — it proves frontend and wallet-integration ability, not additional Clarity-contract depth beyond what FlowFi BTC's own `flowfi-registry`/`flowfi-escrow` contracts already demonstrate. LabSTX is the stronger Clarity-specific credential of the two.
 
Both are real, live, public-repository Stacks-ecosystem products, shipped before this grant application — the same kind of evidence this document's "Execution Evidence" section below relies on for FlowFi BTC itself.
 
---
 
## Execution Evidence
 
FlowFi BTC is not a whitepaper-stage idea. The following exists today, before any grant funding:
 
| Component | Detail |
|---|---|
| Contract architecture + implementation | Two-contract design (`flowfi-registry` v1.0.0 + `flowfi-escrow` v1.0.0, Clarity 5) fully specified **and implemented**, including exact data models, burn-height state machines, and permission model — see `TECHNICAL_ARCHITECTURE.md`; deployed to testnet (`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry`, `ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow`) with test-only `mock-sbtc-token` (`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`) |
| Demo verification flow | Built and functioning — produces a normalized, hashable verification record regardless of underlying verification source |
| Off-chain API layer | Built — connects verification data to the frontend and prepares contract-call parameters |
| Frontend (live) | https://flowfi-btc.vercel.app/ — business dashboard and receivable-detail views functional against the deployed contracts |
 
## Technical Depth Demonstrated
 
Designing FlowFi BTC required working through non-trivial Clarity-specific problems:
 
1. **`tx-sender` vs. `contract-caller` authorization** — financial state transitions (`mark-funded`, `mark-repaid`, `mark-defaulted`) are restricted to the wired escrow via `(some contract-caller)`, with `escrow-contract` defaulting to `none` so the gate fails closed before wiring — preventing any wallet from forging financing state directly on the registry.
2. **Custody precision** — choosing escrow-then-release (`fund-receivable` → admin `release-funds`) rather than atomic pass-through specifically to make funding state easier to reason about and audit; `release-funds`/`mark-default` are admin-gated timing gates whose recipient is always the stored business, and disclosing exactly what is and isn't custodied, for how long, in `RISK_DISCLOSURE.md`.
3. **The repayment boundary** — recognizing explicitly that a smart contract cannot compel real-world fiat repayment: v1.0.0 `repay-receivable` is business-only on-chain sBTC (atomic business → escrow → funder, flat amount), with any fiat leg living in the pilot's off-chain process layer rather than a pretended contract guarantee.
4. **Burn-height time + verification abstraction** — all dates as Bitcoin-anchored burn-heights with lazy expiry derivation (`expiry = u0` = never), and verification results stored as (status/method/level enums + `buff-32` reference/proof hashes) so manual review and future KYB produce identical on-chain records without redesign.
5. **Real mainnet-contract awareness** — `flowfi-escrow`'s sBTC reference defaults to the actual mainnet sBTC token (`SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token`), with a testnet-only override path to the mock token, rather than hard-coding a testnet address that would need replacing at mainnet launch.
6. **Scope discipline** — the project went through several more ambitious architectures (a full multi-contract marketplace protocol, a public investor pool, automated KYB) before deliberately cutting back to the two-contract, single-pilot design submitted here, specifically to manage legal and execution risk appropriately for a first grant.
7. **Active pilot-sourcing, not deferred to post-funding** — several businesses have already been contacted, with two expressing preliminary interest, ahead of any grant funding being received (see [PILOT_READINESS.md](./PILOT_READINESS.md)). Capital-provider outreach is underway in parallel, though no provider is secured yet. This is the business-development work this grant is meant to fund already underway, not work waiting on the grant to start.
---
 
## Development Methodology
 
### Testing Approach (Milestone 1)
 
- Unit tests for every public function, covering both success and failure cases
- Integration tests for the two complete lifecycles: full repayment and default
- Explicit authorization tests confirming that only the intended caller (business owner, authorized verifier, authorized escrow contract) can invoke each restricted function
### Code Quality Practices
 
- Clear separation of protocol state (`flowfi-registry`) from money movement (`flowfi-escrow`) — neither contract duplicates the other's responsibility
- Enums (verification status/method/level, receivable status) instead of raw strings, for extensibility without redesign
- Sensitive data (documents, identity information) kept off-chain; only hashes recorded on-chain
---
 
## Commitment to the Stacks Ecosystem
 
### Long-Term Intent
 
FlowFi BTC's long-term vision (see `ROADMAP.md`) includes a pluggable verification layer supporting multiple attestation sources, additional receivables with additional counterparties, and eventually exploring composability with other Stacks protocols — none of which are promised or funded by this grant, all of which are explicitly deferred pending evidence from the single pilot.
 
### Open-Source Commitment
 
Contract source, tests, and documentation are published open-source, so that:
 
- The community can audit and verify contract logic directly
- Other builders can reference the verified-identity-gating and escrow-then-release patterns
- No claim in this application is unverifiable — the code and the disclosed limitations are both public
### Honesty as a Design Principle
 
Throughout this application and its documentation, known limitations are named directly rather than minimized: the contracts are unaudited pending formal review, the verification path may rely on manual review rather than automated KYB depending on integration timing, and repayment may depend on off-chain confirmation rather than purely on-chain settlement. This is a deliberate posture, not an oversight — reviewers should be able to trust every claim in this application against the code and documentation that accompanies it.
 