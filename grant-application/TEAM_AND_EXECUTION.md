# FlowFi BTC — Team & Execution Capability

---

## Execution Evidence

FlowFi BTC is not a whitepaper-stage idea. The following exists today, before any grant funding:

| Component | Detail |
|---|---|
| Contract architecture | Two-contract design (`registry.clar` + `escrow.clar`) fully specified, including data models, state machines, and permission model — see `TECHNICAL_ARCHITECTURE.md` |
| Demo verification flow | Built and functioning — produces a normalized, hashable verification record regardless of underlying verification source |
| Off-chain API layer | Built — connects verification data to the frontend and prepares contract-call parameters |
| Frontend | Business dashboard and receivable-detail views built and functional against the current design |

## Technical Depth Demonstrated

Designing FlowFi BTC required working through non-trivial Clarity-specific problems:

1. **`tx-sender` vs. `contract-caller` authorization** — financial state transitions (`mark-funded`, `mark-repaid`, `mark-defaulted`) are restricted to be callable only by the authorized escrow contract, preventing any wallet from forging financing state directly on the registry.

2. **Custody precision** — choosing escrow-then-release (rather than atomic pass-through funding) specifically to make funding state easier to reason about and audit, and disclosing exactly what is and isn't custodied, for how long, in `RISK_DISCLOSURE.md`.

3. **The repayment boundary** — recognizing explicitly that a smart contract cannot compel real-world fiat repayment, and designing `repay-receivable` to support both direct on-chain sBTC repayment and confirmed off-chain fiat settlement, rather than assuming away the harder, more realistic case.

4. **Verification abstraction** — designing verification result storage (status/method/level enums, reference and proof hashes) so that a demo-stage manual review and a future third-party KYB provider produce identical on-chain records, without requiring a contract redesign later.

5. **Scope discipline** — the project went through several more ambitious architectures (a full multi-contract marketplace protocol, a public investor pool, automated KYB) before deliberately cutting back to the two-contract, single-pilot design submitted here, specifically to manage legal and execution risk appropriately for a first grant.

---

## Development Methodology

### Testing Approach (Milestone 1)

- Unit tests for every public function, covering both success and failure cases
- Integration tests for the two complete lifecycles: full repayment and default
- Explicit authorization tests confirming that only the intended caller (business owner, authorized verifier, authorized escrow contract) can invoke each restricted function

### Code Quality Practices

- Clear separation of protocol state (`registry.clar`) from money movement (`escrow.clar`) — neither contract duplicates the other's responsibility
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
