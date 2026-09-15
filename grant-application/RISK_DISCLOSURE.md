# FlowFi BTC — Risk Disclosure

This document states plainly what FlowFi BTC's contracts (`flowfi-registry` v1.0.0,
`flowfi-escrow` v1.0.0, `mock-sbtc-token` v1.0.0) do and do not guarantee. It is written to be
read before funding any receivable, and reviewed before this project receives any grant funding.

Live references: frontend https://flowfi-btc.vercel.app/; testnet registry
`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-registry`; escrow
`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.flowfi-escrow`; mock sBTC
`ST1WNVWY7WCJESTHM050RAMRRE44KJTKZKJCSRFCQ.mock-sbtc-token`.

---

## 1. On-Chain vs. Off-Chain — What's Actually Enforced

| Claim | Status |
|---|---|
| A verified business registered this receivable | **Enforced on-chain** — `register-receivable` requires `is-business-verified` (VERIFIED + unexpired, unrevoked) to return true, else `u106` |
| The receivable's status (Open/Funded/Repaid/Defaulted/Cancelled) reflects reality | **Enforced on-chain**, but only as accurately as the inputs that produced it (see verification and repayment sections below). `mark-funded`/`mark-repaid`/`mark-defaulted` are callable only by the wired escrow via `contract-caller` |
| Funds are held by the smart contract, not by any team wallet | **True, and precise:** `flowfi-escrow` holds sBTC between `fund-receivable` and admin-gated `release-funds`. No private key controlled by the team custodies funds at any point. This is a non-custodial escrow, not "no custody at all" — funds do sit in the contract briefly by design |
| The business will repay | **Not enforced on-chain.** No smart contract can compel a real-world payment. See Section 3. |
| The underlying invoice is genuine | **Not independently guaranteed.** Only `invoice-hash (buff 32)` is on-chain; the document stays off-chain. See Section 2. |
| The sBTC token referenced is the real one | **True on mainnet by default** — `escrow.sbtc-contract` defaults to `SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token`. `set-sbtc-contract` exists to repoint this for testnet development and should never be invoked after mainnet launch. |

---

## 2. Verification — What It Does and Doesn't Guarantee

For this pilot, business and receivable verification is either:
- A **demo-stage Manual Pilot Review**, where a named human reviewer checks business registration information and receivable evidence before registration is allowed, optionally cross-checked against an independent public registry where one exists (see Section 8 for the pilot business's CAC registration), or
- A **third-party KYB provider** (e.g., Persona), if that integration completes within the grant timeline.

Both paths produce the same normalized on-chain record: verification status, method, level, timestamps, and a hash of the underlying evidence.

**What this does not guarantee:**
- That the reviewer or provider cannot be deceived by a sufficiently sophisticated fraud
- That the underlying receivable/invoice is free of dispute with the debtor
- That verification, once granted, remains accurate if circumstances change before expiry (hence the `revoke-verification` function, used if a verification is later found to be invalid)

**Naming convention:** this project uses "Pilot Verified" rather than "KYB Verified" unless a completed third-party KYB integration is actually in place for a given business. This distinction is maintained deliberately so the platform never implies a stronger guarantee than what was actually performed.

---

## 3. The Repayment Boundary

A smart contract can enforce what happens to funds *it holds*. It cannot compel a business to acquire funds and voluntarily repay, nor can it compel a debtor to pay the original invoice on time.

For this pilot, repayment of the on-chain position happens one way in v1.0.0:

1. **Direct on-chain sBTC repayment** — the business calls `escrow.repay-receivable(receivable-id, token)`.
   The call reverts unless the caller is the stored business (`u209`), the escrow is FUNDED (`u206`),
   and funds were already released (`u208`). It moves exactly `funding-amount` business → escrow →
   funder atomically (flat, no interest field) and calls `registry.mark-repaid`.

If the business's debtor pays in fiat and the business settles with the provider off-chain (e.g., bank
transfer), **v1.0.0 has no contract function that records that attestation** — that confirmation lives
in the pilot's off-chain process layer, not in `repay-receivable` (which always executes two SIP-010
transfers). A future version can add an admin-attested confirmation path without changing the happy path.

**Applied to pilot business selection:** The pilot business (Open Hive Innovations Ltd) was selected specifically because a technology company has materially better access to sBTC than a fiat-revenue business, directly reducing mechanical-default risk for this pilot.

If a fiat-revenue fallback business (such as Uncle Tee's Schools) were onboarded instead, the pilot's ability to reach an on-chain `REPAID` state would depend on the business independently acquiring sBTC with fiat proceeds before the due date — a step the contract cannot verify, assist with, or compel. We distinguish two different failure modes for this pilot, and will report which one occurred, not conflate them:

- **Mechanical default** — the business had the funds in a real-world sense (revenue was collected) but did not convert them to sBTC in time. This reflects a gap in the current repayment mechanism, not a credit failure.
- **Credit default** — the business's debtor(s) did not pay as expected, so the business genuinely lacked the funds to repay at all.

Prioritizing Open Hive Innovations Ltd directly mitigates mechanical-default risk for this pilot, while retaining Uncle Tee's Schools as a documented fallback.

**This is disclosed explicitly because:** it is the honest boundary of what any receivables-financing smart contract can enforce, and it mirrors how comparable real-world-asset financing protocols handle the same on-chain/off-chain settlement gap. FlowFi BTC does not build or operate any fiat-to-sBTC exchange service, and does not intend to — that would introduce a separate, unrelated regulatory category (money transmission) that this pilot deliberately avoids.

---

## 4. Default

If a funded, released receivable passes its burn-height `due-date` without repayment, the **admin**
calls `escrow.mark-default(receivable-id)` (reverts `u200` for non-admin, `u210` if not yet due,
`u208` if never released), which calls `registry.mark-defaulted`.

**What this does not do:** attempt any automated recovery, collection, or legal action. A recorded default is data — an honest, transparent outcome — not a resolved dispute. Recovery, if pursued at all for this pilot, would happen entirely off-chain and outside this grant's scope.

**Liveness risk:** If the admin does not call `release-funds` after a receivable is funded,
or does not call `mark-default` after a receivable passes its due date without repayment,
the escrowed sBTC remains locked in the contract indefinitely with no automatic release.
There is no time-lock in v1.0.0. For this single-pilot, single-operator deployment, the
admin is the same person coordinating the transaction in real time, which eliminates the
incentive misalignment that makes this dangerous at scale. A multisig admin or time-lock
mechanism is a stated prerequisite before any expansion beyond this pilot.

---

## 5. Contract Security

The contracts (`flowfi-registry` v1.0.0 and `flowfi-escrow` v1.0.0) are **not formally audited** as of this application. Risk is bounded for this pilot by:

- Small ticket size
- One business, one provider — no pooled funds, no multiple counterparties
- A full 46-test suite (26 registry + 20 escrow + 2 integration paths) covering authorization, funding, repayment, and default paths, self-reviewed against a documented security checklist

A formal third-party audit is explicitly recommended, and treated as a prerequisite, before any expansion beyond this single pilot.

---

## 6. Legal Structure of the Pilot

This pilot is structured as one bilateral financing transaction between two known, named parties. There is:

- No public solicitation of capital from multiple retail funders
- No pooled funding structure
- No advertised yield or return percentage
- No custody of funds by any private, team-controlled wallet

This structure is chosen specifically to avoid securities- and crowdfunding-adjacent exposure that would arise from a public, multi-provider funding pool. Any future move in that direction would require dedicated legal review not undertaken as part of this grant, and is not promised by this application.

---

## 7. Outcome Risk

The pilot receivable may default rather than repay. **This is disclosed as a valid, informative, and reportable outcome** — not a failure condition for this grant. The deliverable is a completed, transparent financing cycle with an honestly reported result, whichever result that turns out to be.

---

## 8. Counterparty-Sourcing Risk (Business Side Named, Capital-Provider Side Open)

**Business side:** the primary pilot business is **Open Hive Innovations Ltd** (RC-9590869), a technology company selected because it has materially better access to sBTC than a fiat-revenue business, directly reducing mechanical-default risk. **Uncle Tee's Schools** (RC-1917924) is retained as a documented, CAC-verifiable fallback — see [PILOT_READINESS.md](./PILOT_READINESS.md) for the full outreach record.

**Capital-provider side:** outreach is underway, primarily direct-message outreach to individual sBTC
holders on X. No provider has been secured as of this application. This remains the single largest open
dependency for Milestone 3.

**No self-funding fallback exists.** An earlier draft of this document described a fallback in which the
team's own funds could be used if no external provider was secured by a given point. That fallback has
been removed entirely. Milestone 3 is satisfied only by an independent third-party sBTC provider
completing the financing cycle. If no such provider is secured, Milestone 3 will be reported as
incomplete in `PILOT_RESULT.md` rather than substituted with a self-funded transaction — a self-funded
cycle would not actually test the thing this grant exists to prove, that an independent sBTC holder will
finance a real-world receivable.

---

## 9. If a Fixed Fee Is Added (Conditional, See `MILESTONE_PLAN.md`)

If Milestone 1's stretch goal (a small fixed repayment fee, see `MILESTONE_PLAN.md`) is implemented, it is disclosed here as a **fee**, not interest or yield. Section 6's legal reasoning depends on this distinction: the crowdfunding/securities risk this pilot avoids comes from *publicly soliciting* a return from *multiple* retail funders, not from a single bilateral fixed fee agreed between two named counterparties. A fixed fee does not change the structure described in Section 6 — one business, one provider, no public solicitation, no pooled funds — it only gives the provider a small, flat, pre-agreed incentive beyond goodwill. If this stretch goal is not completed in time, the pilot proceeds at 0% fee, which remains a fully valid and reportable outcome.

---

## 10. Admin Key — Single Wallet, No Multisig

The admin for both `flowfi-registry` and `flowfi-escrow` is a single Stacks wallet
controlled by the lead developer. There is no multisig. This is disclosed as a centralization
risk, not presented as a feature. A multisig admin configuration is a named prerequisite
before any deployment beyond this single pilot.