# FlowFi BTC — Pilot Readiness

## Objective

FlowFi's MVP is designed to complete a single end-to-end receivable financing cycle using sBTC.

The pilot scope is intentionally limited to:

- One receivable
- One business participant
- One capital provider
- One funding transaction
- One repayment event

This document exists to show reviewers that Milestone 3 outreach is already underway, not deferred until after funding arrives.

---

## Business Outreach

### Primary: Open Hive Innovations Ltd

- **Registration:** RC-9590869, independently verifiable at [https://icrp.cac.gov.ng/public-search](https://icrp.cac.gov.ng/public-search) (Nigeria's Corporate Affairs Commission public register)
- **How outreach happened:** initial contact via WhatsApp, followed by an in-person discussion
- **Why this business:** Open Hive is a technology-focused business, and was prioritized as the primary candidate specifically because it has a higher likelihood of being able to interact with digital-asset infrastructure (holding or acquiring sBTC to repay) than a traditional SME with no prior crypto exposure — see `RISK_DISCLOSURE.md` §3 for why this matters given the current repayment mechanism
- **Status:** preliminary interest expressed. No receivable has been onboarded, no on-chain registration has occurred, and no formal participation commitment has been executed.

### Fallback: Uncle Tee's Schools

- **Registration:** RC-1917924, independently verifiable at [https://icrp.cac.gov.ng/public-search](https://icrp.cac.gov.ng/public-search)
- **How outreach happened:** initial contact via WhatsApp, followed by an in-person meeting
- **Why this business:** a registered, independently verifiable business with which direct communication has already been established, kept as a documented fallback in case Open Hive isn't ready in time — not to expand the pilot's scope beyond one receivable
- **Status:** preliminary interest expressed. No receivable has been onboarded, no on-chain registration has occurred, and no formal participation commitment has been executed.

*(Additional business leads, if pursued, will be added below in this same format.)*

## Capital Provider Outreach

Outreach to potential sBTC capital providers is ongoing and remains the largest dependency for Milestone 3.

Outreach has focused on members of the Stacks and sBTC community via direct messages on X (Twitter).

**Update — September 20, 2026:** After approaching **30+ Stacks community members** via X DMs, **one individual has expressed preliminary interest** in participating as the pilot capital provider:

- **Stacks address (provided with consent):** `SP2PZYA27E8MRBQHQXE0JQH5CHM9JJNM00YEMC4QJ` — verifiable on [Stacks Explorer](https://explorer.hiro.so/address/SP2PZYA27E8MRBQHQXE0JQH5CHM9JJNM00YEMC4QJ?chain=testnet)
- **X handle:** [@Demihumanb](https://x.com/Demihumanb) — initial contact was via X, followed by direct conversation
- **Status:** preliminary interest expressed. No on-chain funding has occurred, no formal participation commitment has been executed, and no terms have been finalized.

Before this update, 5 individuals had been approached, 3 had responded, and 0 had committed — that history is retained here for transparency. The 30+ figure above is the current cumulative total as of September 20, 2026. That this single positive response came after 30+ approaches underscores how difficult provider sourcing has been, and why the application treats an independent provider as the gating condition for Milestone 3 rather than an assumed outcome.

There is no fallback that substitutes team or associated-party funds if an independent provider is not secured — see `RISK_DISCLOSURE.md` §8 for why. If a provider proceeds to fund the pilot, the repository will include evidence of outreach and participation, and the final `PILOT_RESULT.md` will document the provider's role, public wallet address, and confirmation of independence from the project team.

---

## Pilot Status

Current status, as of September 20, 2026:

- MVP development in progress (contracts implemented and deployed to testnet — see [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md))
- API and frontend integration built (see [APPLICATION_NARRATIVE.md](./APPLICATION_NARRATIVE.md) and [TECHNICAL_ARCHITECTURE.md](./TECHNICAL_ARCHITECTURE.md))
- Business-side outreach: two named, CAC-verifiable leads (Open Hive Innovations Ltd — primary, Uncle Tee's Schools — fallback), both at preliminary-interest stage
- Capital-provider outreach (as of September 20, 2026): 30+ approached via X, 1 preliminary interest — [@Demihumanb](https://x.com/Demihumanb) (`SP2PZYA27E8MRBQHQXE0JQH5CHM9JJNM00YEMC4QJ`)
- Final counterparty selection and formal onboarding scheduled for Milestone 3

---


**Pre-registration gate:** Before any receivable is registered, the pilot business
must independently complete a small sBTC acquisition via the official sBTC Bridge
(sbtc.stacks.co) — Bitcoin deposit txid and resulting sBTC mint logged with Stacks
Explorer links. If the business cannot complete this step, they are not onboarded
and we proceed to the fallback candidate.


---

## Important Note

This document is provided solely to demonstrate that pilot outreach is genuinely underway, not to assert that any agreement is in place.

Nothing described here constitutes a legally binding agreement, investment solicitation, lending offer, securities offering, or crowdfunding activity. Participation by any party remains voluntary and would be confirmed formally at Milestone 3.
