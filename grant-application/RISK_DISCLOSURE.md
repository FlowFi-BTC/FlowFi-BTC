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

For this pilot, repayment of the on-chain position happens one way in v1.0.0:

1. **Direct on-chain sBTC repayment** — the business calls `escrow.repay-receivable(receivable-id, token)`.
   The call reverts unless the caller is the stored business (`u209`), the escrow is FUNDED (`u206`),
   and funds were already released (`u208`). It moves exactly `funding-amount` business → escrow →
   funder atomically (flat, no interest field) and calls `registry.mark-repaid`.

If the business's debtor pays in fiat and the business settles with the provider off-chain (e.g., bank
transfer), **v1.0.0 has no contract function that records that attestation** — that confirmation lives
in the pilot's off-chain process layer, not in `repay-receivable` (which always executes two SIP-010
transfers). A future version can add an admin-attested confirmation path without changing the happy path.

**This is disclosed explicitly because:** it is the honest boundary of what any receivables-financing smart contract can enforce, and it mirrors how comparable real-world-asset financing protocols handle the same on-chain/off-chain settlement gap. FlowFi BTC does not build or operate any fiat-to-sBTC exchange service, and does not intend to — that would introduce a separate, unrelated regulatory category (money transmission) that this pilot deliberately avoids.

---

## 4. Default

If a funded, released receivable passes its burn-height `due-date` without repayment, the **admin**
calls `escrow.mark-default(receivable-id)` (reverts `u200` for non-admin, `u210` if not yet due,
`u208` if never released), which calls `registry.mark-defaulted`.

**What this does not do:** attempt any automated recovery, collection, or legal action. A recorded default is data — an honest, transparent outcome — not a resolved dispute. Recovery, if pursued at all for this pilot, would happen entirely off-chain and outside this grant's scope.

---

## 5. Contract Security

The contracts (`flowfi-registry` v1.0.0 and `flowfi-escrow` v1.0.0) are **not formally audited** as of this application. Risk is bounded for this pilot by:

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