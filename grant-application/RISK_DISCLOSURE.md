# FlowFi BTC — Risk Disclosure

This document states plainly what FlowFi BTC's contracts do and do not guarantee. It is written to be read before funding any receivable, and reviewed before this project receives any grant funding.

---

## 1. On-Chain vs. Off-Chain — What's Actually Enforced

| Claim | Status |
|---|---|
| A verified business registered this receivable | **Enforced on-chain** — `register-receivable` requires `is-business-verified` to return true |
| The receivable's status (Open/Funded/Repaid/Defaulted) reflects reality | **Enforced on-chain**, but only as accurately as the inputs that produced it (see verification and repayment sections below) |
| Funds are held by the smart contract, not by any team wallet | **True, and precise:** `escrow.clar` holds sBTC between `fund-receivable` and `release-funds`. No private key controlled by the team custodies funds at any point. This is a non-custodial escrow, not "no custody at all" — funds do sit in the contract briefly by design |
| The business will repay | **Not enforced on-chain.** No smart contract can compel a real-world payment. See Section 3. |
| The underlying invoice is genuine | **Not independently guaranteed.** See Section 2. |

---

## 2. Verification — What It Does and Doesn't Guarantee

For this pilot, business and receivable verification is either:
- A **demo-stage Manual Pilot Review**, where a named human reviewer checks business registration information and receivable evidence before registration is allowed, or
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

For this pilot, repayment happens one of two ways:

1. **Direct on-chain sBTC repayment** — if the business holds or acquires sBTC (e.g., by converting fiat proceeds through an existing exchange or bridge), it repays directly through `repay-receivable`, and sBTC moves from the business to the provider within that transaction.
2. **Off-chain fiat repayment, confirmed on-chain** — if the business's debtor pays in fiat and the business settles with the provider off-chain (e.g., bank transfer), an authorized party confirms this occurred, and the registry records the repaid state without an accompanying sBTC transfer.

**This is disclosed explicitly because:** it is the honest boundary of what any receivables-financing smart contract can enforce, and it mirrors how comparable real-world-asset financing protocols handle the same on-chain/off-chain settlement gap. FlowFi BTC does not build or operate any fiat-to-sBTC exchange service, and does not intend to — that would introduce a separate, unrelated regulatory category (money transmission) that this pilot deliberately avoids.

---

## 4. Default

If a funded receivable passes its due date without repayment, `mark-default` records the receivable as `DEFAULTED` on-chain.

**What this does not do:** attempt any automated recovery, collection, or legal action. A recorded default is data — an honest, transparent outcome — not a resolved dispute. Recovery, if pursued at all for this pilot, would happen entirely off-chain and outside this grant's scope.

---

## 5. Contract Security

The contracts (`registry.clar` and `escrow.clar`) are **not formally audited** as of this application. Risk is bounded for this pilot by:

- Small ticket size
- One business, one provider — no pooled funds, no multiple counterparties
- A test suite (target 40–60 tests plus two full integration tests) covering authorization, funding, repayment, and default paths, self-reviewed against a documented security checklist

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
