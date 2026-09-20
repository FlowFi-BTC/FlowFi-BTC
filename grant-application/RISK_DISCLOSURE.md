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
| The receivable's status (Open/Funded/Repaid/Defaulted/Cancelled) reflects reality | **Enforced on-chain**, but only as accurately as the inputs that produced it. `mark-funded`/`mark-repaid`/`mark-defaulted` are callable only by the wired escrow via `contract-caller` |
| Funds are held by the smart contract, not by any team wallet | **True and precise, corrected wording:** funds sit in a non-custodial escrow contract between `fund-receivable` and admin-gated `release-funds`. "Non-custodial" means no private key controlled by the team can redirect or withdraw the funds — the contract can only send sBTC to the stored business address or return it to the stored funder address. It does not mean the funds are never held anywhere; they are held in the contract by design. See Section 10 for the admin role in full. |
| The business will repay | **Not enforced on-chain.** No smart contract can compel a real-world payment. See Section 3. |
| The underlying invoice is genuine | **Not independently guaranteed.** Only `invoice-hash (buff 32)` is on-chain; the document stays off-chain. See Section 2. |
| The sBTC token referenced is the real one | **Will be permanently true on mainnet** — see Section 10: `set-sbtc-contract` is being removed from both contracts entirely before mainnet deployment, and the sBTC address will be hardcoded to `SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token`, not configurable post-deploy. |

---

## 2. Verification — What It Does and Doesn't Guarantee

For this pilot, business and receivable verification is either:
- A **demo-stage Manual Pilot Review**, where a named human reviewer checks business registration information and receivable evidence before registration is allowed, cross-checked against Nigeria's Corporate Affairs Commission public registry for both current pilot candidates, or
- A **third-party KYB provider** (e.g., Persona), if that integration completes within the grant timeline.

Both paths produce the same normalized on-chain record: verification status, method, level, timestamps, and a hash of the underlying evidence.

**What this does not guarantee:**
- That the reviewer or provider cannot be deceived by a sufficiently sophisticated fraud
- That the underlying receivable/invoice is free of dispute with the debtor
- That verification, once granted, remains accurate if circumstances change before expiry (hence the `revoke-verification` function, used if a verification is later found to be invalid)

**Naming convention:** this project uses "Pilot Verified" rather than "KYB Verified" unless a completed third-party KYB integration is actually in place for a given business.

---

## 3. The Repayment Boundary

A smart contract can enforce what happens to funds *it holds*. It cannot compel a business to acquire funds and voluntarily repay, nor can it compel a debtor to pay the original invoice on time.

For this pilot, repayment of the on-chain position happens one way in v1.0.0:

1. **Direct on-chain sBTC repayment** — the business calls `escrow.repay-receivable(receivable-id, token)`.
   The call reverts unless the caller is the stored business (`u209`), the escrow is FUNDED (`u206`),
   and funds were already released (`u208`). It moves exactly `funding-amount` business → escrow →
   funder atomically (flat, no interest field) and calls `registry.mark-repaid`.

**v1.0.0 has no contract function that records an off-chain fiat settlement.** `repay-receivable`
always executes two SIP-010 sBTC transfers — meaning the business must independently acquire sBTC
before it can repay, even though its own debtors typically settle in fiat on 30–90 day terms. This is
the current mechanism's most significant real-world limitation.

**Applied to the pilot specifically:** the primary pilot candidate, Open Hive Innovations Ltd, was
selected partly because it is a technology-focused business and therefore has a more realistic chance
of holding or acquiring sBTC than a business with no digital-asset experience. However, no formal
evidence currently exists that Open Hive already holds sBTC or routinely acquires digital assets.
**We estimate the probability of a mechanical default arising from conversion friction at
approximately 20–30% for this pilot.**

We distinguish two different failure modes, and will report which one occurred rather than
conflating them:

- **Mechanical default** — the business had fiat proceeds from its receivable but did not complete
  acquisition and transfer of sBTC before the due date. This reflects a gap in the current repayment
  mechanism, not a credit failure.
- **Credit default** — the business's debtor did not pay as expected, so the business genuinely
  lacked the funds to repay at all.

If a mechanical default occurs, `PILOT_RESULT.md` will classify it explicitly as such. Separately,
the business and capital provider may voluntarily agree, off-chain, to continue settlement efforts
beyond the initial due date if fiat proceeds have been received but conversion is still in progress —
this would not alter the on-chain contract mechanics and would be disclosed in full if it occurs.

**This is disclosed explicitly because:** it is the honest boundary of what any receivables-financing smart contract can enforce. FlowFi BTC does not build or operate any fiat-to-sBTC exchange service, and does not intend to — that would introduce a separate, unrelated regulatory category (money transmission) that this pilot deliberately avoids. The pilot's outcome, whichever way it resolves, will directly inform whether a future version should add a mechanism for recording verified off-chain settlement transparently.

---

## 4. Default

If a funded, released receivable passes its burn-height `due-date` without repayment, the **admin**
calls `escrow.mark-default(receivable-id)` (reverts `u200` for non-admin, `u210` if not yet due,
`u208` if never released), which calls `registry.mark-defaulted`.

**What this does not do:** attempt any automated recovery, collection, or legal action. A recorded default is data — an honest, transparent outcome — not a resolved dispute.

---

## 5. Contract Security

The contracts (`flowfi-registry` v1.0.0 and `flowfi-escrow` v1.0.0) are **not formally audited** as of this application. Risk is bounded for this pilot by:

- Small ticket size
- One business, one provider — no pooled funds, no multiple counterparties
- A full 46-test suite (26 registry + 20 escrow + 2 integration paths), self-reviewed against a documented security checklist (`SECURITY_REVIEW.md`)

A formal third-party audit is explicitly recommended, and treated as a prerequisite, before any expansion beyond this single pilot.

---

## 6. Legal Structure of the Pilot

This pilot is structured as one bilateral financing transaction between two known, named parties. There is:

- No public solicitation of capital from multiple retail funders
- No pooled funding structure
- No advertised yield or return percentage
- No custody of funds by any private, team-controlled wallet in the sense of a key that can redirect them (see Section 10 for the precise custody position)

This structure is chosen specifically to avoid securities- and crowdfunding-adjacent exposure that would arise from a public, multi-provider funding pool.

---

## 7. Outcome Risk

The pilot receivable may default rather than repay. **This is disclosed as a valid, informative, and reportable outcome** — not a failure condition for this grant.

---

## 8. Counterparty-Sourcing Risk

**Business side:** two named, CAC-verifiable candidates are identified — Open Hive Innovations Ltd
(RC-9590869, primary) and Uncle Tee's Schools (RC-1917924, fallback). Both are at preliminary-interest
stage; neither has been formally onboarded. See `PILOT_READINESS.md` for full detail.

**Capital-provider side:** 30+ individuals approached via X direct messages (cumulative as of September 20, 2026). Before this update: 5 approached, 3 responded, 0 committed. **Update — September 20, 2026:** one individual has now expressed preliminary interest — [@Demihumanb](https://x.com/Demihumanb) (`SP2PZYA27E8MRBQHQXE0JQH5CHM9JJNM00YEMC4QJ`). No on-chain funding has occurred and no formal commitment has been executed. This remains the single largest open dependency for Milestone 3, and the 30:1 response ratio underscores its difficulty.

**No self-funding fallback exists.** Milestone 3's only success criterion is completion of an
end-to-end financing cycle involving a real business and an **independent third-party sBTC capital
provider with no affiliation with the project team, no shared wallet ownership, and no financial
relationship with the project that would make the transaction effectively self-funded.** If no such
provider is secured by the Milestone 3 deadline, the milestone will be reported as incomplete in
`PILOT_RESULT.md`, which will explicitly identify the absence of an independent provider as the unmet
condition. Team-controlled wallets, founder funds, associated parties, or related entities will not be
used to simulate or replace an external provider.

If a third-party financing cycle is completed, `PILOT_RESULT.md` will disclose: the provider's public
Stacks wallet address; the approximate date and channel of initial contact; a statement confirming the
provider was not affiliated with the project team; and evidence the provider independently chose to
participate. This disclosure is the distinguishing criterion between a genuine third-party cycle and
any self-funded or related-party transaction.

---

## 9. If a Fixed Fee Is Added (Conditional, See `MILESTONE_PLAN.md`)

If Milestone 1's stretch goal (a small fixed repayment fee) is implemented, it is disclosed here as a
**fee**, not interest or yield. Section 6's legal reasoning depends on this distinction: the risk this
pilot avoids comes from *publicly soliciting* a return from *multiple* retail funders, not from a
single bilateral fixed fee agreed between two named counterparties. If this stretch goal is not
completed in time, the pilot proceeds at 0% fee, which remains a fully valid, reportable outcome.

---

## 10. Admin Role, Key Security, and Liveness Risk

**Who holds the admin key:** the admin for both `flowfi-registry` and `flowfi-escrow` is a single
Stacks wallet controlled by the lead developer, Oyewale Prudence ([@ProdevappOFFICIAL](https://github.com/ProdevappOFFICIAL)).
`CONTRACT-OWNER` is set to `tx-sender` at deploy time. **There is no multisig.** This is a
centralization risk that is disclosed here directly, not obscured.

**If the admin never calls `release-funds`:** the sBTC funded by the capital provider sits in the
escrow contract indefinitely. The business cannot receive the advance; the funder cannot recover
their funds. **There is no time-lock or automatic release mechanism in v1.0.0.** This is a genuine
liveness risk.

**If the admin never calls `mark-default`:** the receivable remains in FUNDED state on-chain after
the due date, indefinitely. Same liveness risk applies.

**Mitigation for this single-operator, single-transaction pilot:** the admin is the same person
coordinating the pilot in real time, with direct contact with both parties, so the incentive-alignment
problem that makes admin-gating dangerous at scale does not exist at this scale. **This reasoning does
not extend to any multi-provider deployment** — a multisig admin or a time-lock mechanism is a named
prerequisite before any expansion beyond this single pilot, and is carried forward as a requirement in
`MILESTONE_PLAN.md`'s post-pilot roadmap discussion.

**`set-sbtc-contract`:** this function is being **removed from both contracts entirely** before
mainnet deployment — not locked, not gated, removed from the source. It will not exist in the version
deployed at Milestone 2. The sBTC contract address will be hardcoded to
`SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token` and will not be changeable post-deploy. This is
a code change, and the updated contracts (without this function) are what will be submitted for
Milestone 2 verification.

**On "no custody of user assets, no intermediary holding capital":** this phrasing, used earlier in
the application, was imprecise and has been corrected throughout. The accurate statement is the one
given in Section 1 above: funds sit in a non-custodial escrow contract by design; no private key can
redirect or withdraw them; the admin's power is limited to *timing* (when `release-funds` or
`mark-default` is called), never *destination*.
