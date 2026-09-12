# FlowFi BTC — Milestone Plan (Revised)
## Stacks Endowment Grant | $10,000 | 3-Milestone Structure

---

## Pre-Grant Baseline (What Is Already Built)

Before any grant activity begins, FlowFi BTC already has:

| Component | Status |
|---|---|
| `flowfi-registry.clar` (385 lines) | Deployed to testnet — 11 public functions, 10 read-only functions |
| `flowfi-escrow.clar` (257 lines) | Deployed to testnet — 6 public functions, 4 read-only functions |
| `mock-sbtc-token.clar` (161 lines) | Deployed to testnet — SIP-010 test stand-in for sBTC (admin mint + daily faucet) |
| Test suite | 46 passing tests across 2 suites (26 registry + 20 escrow, Clarinet SDK v3.9.0 + Vitest 3.2.7) |
| Frontend (21 pages) | Live on Vercel — all 7 contract interactions wired via prepare → sign → confirm → poll |
| Express.js API | 11 routers (auth, onboarding, businesses, investors, receivables, marketplace, verification, fundings, transactions, escrows, dashboards) for queries and transaction building |
| Wallet integration | Leather + Xverse via @stacks/connect |

This baseline means the grant period is not about building from scratch — it is about hardening, deploying, and proving that one real business and one real sBTC holder will complete one real financing cycle through it.

Scope lock (unchanged): one verified business, one sBTC provider, one receivable, one full cycle (repayment OR番茄 default both count as resolution). Not a marketplace, not a multi-tenant platform, not a consumer investment product.

---

## Milestone 1: Complete Production Hardening for Mainnet

**Disbursement: $2,000 (20%)**

### Acceptance Criteria (from grant agreement)
1. Expanded test coverage for funding/settlement math and authorization gates
2. Public review notes
3. Release candidate ready for mainnet deployment

---

### What Needs to Change From Current State

The existing 46 tests cover the happy paths and key rejections well (duplicate registration, verifier-only gates, exact-amount funding, release-first repay, past-due default, both end-to-end lifecycles). What is missing for production confidence:

- No property-based / fuzz tests that probe the funding math (`funding-amount ≤ face-value`, exact-amount pull, flat repayment conservation) with adversarial inputs
- No formal invariant documentation
- No independent review by anyone outside the project
- No formal deployment checklist or RC tag in the repository

All four of these gaps are addressed in this milestone.

---

### Deliverable 1.1 — Expanded Test Coverage and Fuzzing

**Target: 70+ tests, funding/settlement invariants verified with randomized inputs**

The existing suites (`flowfi-registry.test.ts`, `flowfi-escrow.test.ts`) cover discrete scenarios. This deliverable adds a property-based layer that runs the funding math against hundreds of generated inputs.

**Fuzz targets (critical invariants that must hold for ALL valid inputs):**

| Invariant | Test Description |
|---|---|
| Bound: `funding-amount <= face-value` | For any face-value (1 to u128-max) and any funding-amount, registration rejects whenever funding exceeds face |
| Exact pull: `transferred == registry funding-amount` | For any registered funding-amount, the funder is debited exactly that — a caller-supplied amount cannot move the number |
| Repay conservation: `business_pays == funder_receives == funding-amount` | Flat repayment moves exactly funding-amount business → escrow → funder atomically; nothing created or destroyed |
| Gate order: no repay before release, no double release | For any interleaving of fund/release/repay calls, repay before release always fails (u208) and a second release always fails (u207) |
| Default window: `mark-default` only past due-date, never after REPAID | For any due-date and chain height, default succeeds only when funded + released + past-due, and never on a repaid receivable |

**Implementation approach:**

Because Clarinet's simnet is deterministic, fuzz testing is implemented by generating random parameter sets in Vitest and running each set through the simnet. A simple helper generates 300–500 random funding configurations and asserts invariants after each operation. This does not require an external fuzzing library — just parameterized loops with `Math.random()` seeded inputs logged for reproducibility.

**Success metric:** 70+ tests passing with a published coverage summary showing all 5 invariants are exercised.

---

### Deliverable 1.2 — Community Security Review and Public Review Notes

**Target: Published review document with findings, responses, and mitigations**

This is the primary evidence item for "public review notes" in the acceptance criteria. The approach:

1. **Self-audit against the Stacks security checklist** — every public function in both contracts reviewed for:
   - `tx-sender` authorization on all mutating calls (`register-business` owner, `verify-business` verifier-only, `fund-receivable` non-business, `release-funds`/`mark-default` admin-only, `repay-receivable` business-only)
   - `tx-sender` vs `contract-caller` correctness on the escrow-only `mark-funded` / `mark-repaid` / `mark-defaulted` entry points
   - Token conservation on every exit path (fund → release → repay/default)
   - Status-transition guards (OPEN → FUNDED → REPAID / DEFAULTED, no skips or repeats)

2. **Community peer review submission** — Post to Stacks developer Discord (`#clarity-smart-contracts` and `#dev-showcase`) with a direct link to the contract source and a request for review. Offer a small STX bounty ($100–$200 worth) for substantive findings. Document every response received.

3. **Publish the review document** — Update `SECURITY_REVIEW.md` in the repository so it lists:
   - Each function reviewed
   - Potential concern identified (or "none identified")
   - Resolution or mitigation
   - Community comments received and responses

This document becomes the "public review notes" artifact submitted for M1 verification.

**Success metric:** `SECURITY_REVIEW.md` published in the repository with all functions covered.

---

### Deliverable 1.3 — Release Candidate for Mainnet Deployment

**Target: Tagged RC in GitHub, deployment checklist complete, contracts ready to deploy to mainnet**

A release candidate means the contracts are finalized and every step of the mainnet deployment is documented and pre-validated.

**Release candidate checklist:**

- [ ] Mainnet sBTC principal locked to real sBTC `SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token` — never a mock; `set-sbtc-contract` locked or heavily gated post-deploy
- [ ] `Clarinet.toml` deployment plan with mainnet addresses — `deployments/default.mainnet-plan.yaml` committed
- [ ] Post-deployment validation script written (calls `get-escrow-contract` / `get-sbtc-contract` and every read-only function to confirm deployment success)
- [ ] Admin/verifier key management documented — `set-admin` / `set-verifier` two-step discipline documented in SECURITY_REVIEW.md
- [ ] GitHub tag `v1.0.0-rc1` created on the commit that includes the above

**Success metric:** GitHub release tag `v1.0.0-rc1` exists with release notes describing the RC scope.

---

### Milestone 1 — Evidence Submission

| Evidence Item | Format |
|---|---|
| Test run output | Screenshot or CI log showing 70+ tests passing |
| Coverage summary | Markdown table of invariants tested with pass/fail |
| `SECURITY_REVIEW.md` | Published in repository — public URL |
| RC release tag | GitHub release link (`v1.0.0-rc1`) |

---

### Milestone 1 — Cost Allocation (from $2,000 disbursement)

| Item | Estimated Cost | Notes |
|---|---|---|
| Community review bounty | $200 | STX bounty for substantive findings from community reviewers |
| CI/CD pipeline (GitHub Actions) | $0 | GitHub Actions free tier covers this |
| Clarinet tooling | $0 | Open-source |
| Hosting (Vercel + API) | $40 | 1 month of staging hosting pre-mainnet |
| Developer time (test writing + review) | ~$1,600 | Core time allocation — 2–3 weeks of focused work |
| Contingency | $160 | Buffer for unexpected tooling or testnet STX needs |
| **Total** | **$2,000** | |

---

## Milestone 2: Launch FlowFi BTC on Mainnet

**Disbursement: $3,000 (30%)**

### Acceptance Criteria (from grant agreement)
1. Verified contracts on mainnet
2. Production frontend live
3. At least 1 end-to-end mainnet financing flow completed (register → fund → release → repay) to prove the wiring before pilot counterparties touch it

---

### What Needs to Change From Current State

The frontend currently points to testnet (mock sBTC). The contracts are testnet-deployed. To satisfy M2:
- Contracts must be deployed to mainnet and verifiable on Stacks Explorer, with the real sBTC principal
- Frontend + API must switch environment to mainnet and hide the mock faucet
- No public page shows the full funding trail today — without one, the proving flow is invisible to anyone who was not a counterparty
- 1 real-asset flow must run on mainnet end-to-end — self-funded with a small amount initially, to establish the baseline before the named pilot counterparties in M3

---

### Deliverable 2.1 — Mainnet Contract Deployment and Verification

**Target: Both contracts deployed to Stacks mainnet, verified on explorer**

Steps:
1. Fund the mainnet deployer wallet with enough STX for deployment gas (~1,000–2,000 STX for safety)
2. Deploy registry first, then escrow; wire via `set-escrow-contract` from the RC plan
3. Confirm `set-sbtc-contract` reads the real sBTC principal and is locked/gated
4. Verify both contracts on Stacks Explorer and confirm each public function is callable via the post-deployment validation script
5. Record both contract addresses and publish them in the repository `README.md`

**Success metric:** Both contract addresses visible on Stacks Explorer mainnet with source verification.

---

### Deliverable 2.2 — Production Frontend Live

**Target: Frontend + API on production, pointed at mainnet contracts**

The frontend is already deployed on Vercel. The changes needed:
- Update environment variables: swap testnet contract addresses + mock sBTC for mainnet addresses + real sBTC
- Update Stacks network config: switch from `StacksTestnet` to `StacksMainnet` in `@stacks/connect`
- Remove or gate the mock-sBTC faucet UI behind a testnet toggle
- Confirm the wallet-aware receivable page (business actions / provider actions / read-only) and dashboards work against mainnet reads
- Keep the production domain (`flowfi-btc.vercel.app` or successor) pointing at the mainnet build

**Success metric:** Live URL with wallet connection, registration, funding, and repayment flows working against mainnet contracts.

---

### Deliverable 2.3 — 1 End-to-End Mainnet Proving Flow

**Target: 1 full cycle completed on mainnet (register → verify → fund → release → repay), with transaction hashes**

This is both a technical verification step and the foundation of the pilot story. The proving flow establishes that the protocol works end-to-end on mainnet with real sBTC.

**Approach:**
- Run the cycle with a small, self-funded amount between controlled wallets (business + provider + admin roles held explicitly)
- Document every transaction hash: register-business, verify-business, register-receivable, fund-receivable, release-funds, repay-receivable

**This proving flow also serves as first social content** — each step is a shareable mainnet transaction on Stacks Explorer.

**Success metric:** 1 complete create-to-repay chain on mainnet, with explorer links submitted as evidence — and visible on the public transparency page (Deliverable 2.4).

---

### Deliverable 2.4 — Public Transparency Page (how the provider funded the business, in detail)

**Target: A public, no-wallet route that shows the full funding trail of any cycle, step by step**

Anyone — reviewer, future business, future provider — can open the page without connecting a wallet and see exactly how money moved, backed by on-chain records rather than claims.

**What the page shows, in order:**
1. **The business** — name, registration reference, and verification status (verified by whom, when, at what level)
2. **The receivable** — invoice reference, face value, funding amount, due date, debtor, and the invoice SHA-256 evidence hash
3. **The funding** — provider wallet address, exact sBTC amount pulled (read from the registry, so under/over-funding is impossible), and the funding transaction hash
4. **The escrow trail** — FUNDED → RELEASED (admin release, tx hash, timestamp) → REPAID or DEFAULTED (tx hash or honestly labeled off-chain record), each state with its timestamp
5. **Every transaction hash** as a Stacks Explorer link, so any step can be independently verified

**Implementation notes:**
- Read-only: built on existing read endpoints (receivable detail, on-chain state, activity timeline, escrow, transaction proof). No new contract surface, no new custody, no wallet required.
- Statuses that are still off-chain records (e.g. the MVP default flag) are labeled as such and never linked as chain proofs.
- The M2 proving flow (Deliverable 2.3) ships displayed on this page; the M3 pilot cycle reuses the same page, so reviewers compare like with like.

**Success metric:** Transparency page reachable without a wallet, showing the M2 proving flow end-to-end with working explorer links on every step.

---

### Milestone 2 — Evidence Submission

| Evidence Item | Format |
|---|---|
| Contract addresses | Stacks Explorer links for both contracts |
| Production frontend | Live URL pointed at mainnet |
| 1 proving flow | Transaction hashes: register → verify → register-receivable → fund → release → repay on mainnet |
| Transparency page | Live URL + screenshot showing the proving flow's full funding trail with explorer links |

---

### Milestone 2 — Cost Allocation (from $3,000 disbursement)

| Item | Estimated Cost | Notes |
|---|---|---|
| Mainnet deployment gas | $100 | ~1,000 STX buffer at market rate for deployment transactions |
| sBTC for proving flow | $150 | Small self-funded cycle to prove end-to-end wiring |
| Domain registration (1 year) | $15 | Production domain |
| Vercel (3 months) | $60 | Production SLA and custom domain |
| API + Postgres hosting (3 months) | $90 | Node API + managed Postgres |
| Marketing content creation | $300 | Demo video, launch graphics, thread writing (Loom + Canva) |
| Community campaign (bounties) | $200 | Incentive for reviewers and early followers |
| Developer time (deployment + frontend switch) | ~$1,900 | Core time allocation |
| Contingency | $185 | Buffer |
| **Total** | **$3,000** | |

---

## Milestone 3: Prove Real Usage

**Disbursement: $5,000 (50%)**

### Acceptance Criteria (from grant agreement)
One completed real financing cycle — registration through resolution — with real sBTC, involving one named business and one named capital provider. A resolved default counts equally with a resolved repayment: the metric is a completed transparent cycle, not a guaranteed successful outcome.

---

### Deliverable 3.1 — Real Business Onboarded (from existing leads)

**Target: 1 named real business with a real receivable registered on mainnet**

**What counts:**
- A named business (or redacted descriptor where consent is limited) verified through the Milestone 1 path that registers one real receivable on mainnet
- Independently verifiable on-chain via `register-receivable`

**Pipeline strategy (start building in M1, accelerate in M2):**

Two Nigerian SME leads already contacted (see `PILOT_READINESS.md`) — one is selected on readiness (verification-ready documentation, invoice availability, timeline fit); the second is a fallback if the first is not ready, not an expansion of scope.

**Success metric:** 1 real `register-receivable` call on mainnet tied to the named business.

---

### Deliverable 3.2 — Real Provider, Full Cycle, Honest Report

**Target: 1 named sBTC holder funds the receivable; the cycle resolves on-chain; `PILOT_RESULT.md` published**

- The provider funds via a real on-chain `fund-receivable` transaction; admin follows with `release-funds`
- Resolution is on-chain `repay-receivable` (business → escrow → funder, flat funding-amount) or, past the burn-height due-date, admin `mark-default`. Any off-chain fiat leg is process-confirmed only — v1.0.0 has no off-chain-confirm function
- `PILOT_RESULT.md` publishes the actual outcome: what worked, what didn't, and what Phase 2 needs based on real evidence

---

### Milestone 3 — Evidence Submission

| Evidence Item | Format |
|---|---|
| Named counterparties | Business + provider references (per consent) with readiness trail |
| Cycle evidence | Explorer links: register → verify → register-receivable → fund → release → repay/default on mainnet |
| Transparency page | Updated live URL showing the pilot cycle's full funding trail (same page as M2) |
| Outcome report | `PILOT_RESULT.md` published in the repository |

---

### Milestone 3 — Cost Allocation (from $5,000 disbursement)

| Item | Estimated Cost | Notes |
|---|---|---|
| Marketing and community campaigns | $600 | Paid promotion on X, campaign bounties, community contests |
| Counterparty onboarding support | $400 | 1-on-1 calls, setup walkthroughs, verification handling |
| Ecosystem outreach (presentations, AMAs) | $100 | Content creation for community calls |
| Infrastructure (Vercel + API + DB, 3 more months) | $150 | Ongoing hosting |
| Chainhook event indexer | $200 | For production funding/settlement event tracking |
| Pilot support reserve | $400 | Fee subsidy / logistics for pilot counterparties — never framed as yield |
| Developer time (support + iteration + reporting) | ~$2,800 | Core time allocation |
| Contingency | $350 | Buffer |
| **Total** | **$5,000** | |

---

## Section 4 — Total Cost Summary Across All Three Milestones

| Category | M1 | M2 | M3 | Total |
|---|---|---|---|---|
| Developer / builder time | $1,600 | $1,900 | $2,800 | **$6,300** |
| Infrastructure & hosting | $40 | $150 | $150 | **$340** |
| Deployment & gas costs | — | $100 | — | **$100** |
| Marketing & campaigns | — | $300 | $600 | **$900** |
| Community bounties & incentives | $200 | $200 | — | **$400** |
| Pilot support reserve | — | — | $400 | **$400** |
| Documentation & content | — | — | — | **$0** (time only) |
| Contingency | $160 | $185 | $350 | **$695** |
| Domain & tooling | — | $15 | — | **$15** |
| Indexer & analytics | — | — | $200 | **$200** |
| Proving-flow sBTC (self-funded) | — | $150 | — | **$150** |
| Onboarding support | — | — | $500 | **$500** |
| **Milestone total** | **$2,000** | **$3,000** | **$5,000** | **$10,000** |

> Developer time is the dominant cost across all milestones, which reflects the reality of a solo builder. Infrastructure costs are intentionally lean — the stack is Vercel + Node API + managed Postgres, under $60/month combined.

---

## Section 5 — Marketing Strategy: Getting Real Traction

M2 requires a verifiable mainnet proving flow and M3 requires named real counterparties — marketing and ecosystem positioning matter as much as the technical work. The strategy below is organized by platform and phase. Everything ladders to one goal: one business, one provider, one completed cycle.

---

### Phase 0 — Pre-Launch (During M1)

Build awareness before the mainnet launch so there is an audience — and a counterparty pipeline — ready when it goes live. Do not wait until contracts are deployed to start talking.

**Goals for Phase 0:**
- Establish a presence on every relevant platform
- Keep the 2 business leads + 1 provider lead warm with visible rigor (tests, review notes)
- Create content that educates sBTC holders on real-world, short-duration, asset-backed uses beyond DeFi

---

### Platform 1 — X (Twitter)

X is the primary channel for Stacks ecosystem activity. Most builders, sBTC holders, and grant watchers follow Stacks conversations on X.

**During M1 (pre-launch content):**

1. **Origin story thread** — "sBTC has few real-economy uses. I built Bitcoin-native receivables financing so one real invoice can be funded with real sBTC. Here is how it works." Walk through the problem, show a testnet demo GIF, link the repo.

2. **Educational content** — "What does fund → release → repay actually look like on-chain?" Explain the escrow-then-release model with a simple visual. This is for sBTC holders, not developers.

3. **Build-in-public updates** — Every time the fuzz suite lands or the security review publishes, tweet about it. "Just published our public security review for FlowFi BTC — here is what we found and how we fixed it." These demonstrate rigor and build trust.

4. **Target and tag the right accounts:**
   - `@Stacks` (official Stacks account)
   - `@HiroSystems` (tooling)
   - `@StacksOrg`
   - sBTC holders and Stacks grant recipients — potential pilot witnesses and Phase-2 counterparties

**During M2 (launch content):**

5. **Launch thread** — "FlowFi BTC is live on mainnet. Here are the contract addresses, here is the frontend, and here is the first proving flow on-chain." Include the Stacks Explorer links.

6. **Live demo posts** — Record a 60-second Loom video of the proving flow (fund → release → repay) on mainnet. Post it as a video tweet. Short demos convert skeptics better than any text.

7. **Proof-of-cycle posts** — Every step of the proving flow gets its transaction hash posted. This creates a visible trail of on-chain activity.

**During M3 (pilot content):**

8. **Counterparty spotlight** — With consent, announce the business. "Proud to welcome [Business] as the first real business financing a receivable with sBTC." Tag them where appropriate.

9. **Outcome post** — Repaid or defaulted, publish the result honestly with the `PILOT_RESULT.md` link. An honest default post builds more long-term trust than a hyped repayment post.

10. **Weekly ecosystem content** — One thread per week on sBTC utility, SME finance, or Bitcoin DeFi. Authority compounds even on weeks with no product news.

---

### Platform 2 — Discord

Discord is where you find reviewers first and witnesses second — it is the working environment of every active Stacks project.

**Key Stacks Discord channels:**
- `#dev-showcase` — Post the security review and the mainnet launch
- `#clarity-smart-contracts` — Engage in technical conversations; mention FlowFi when relevant
- `#building-on-stacks` — Find teams whose contributors or treasuries touch sBTC
- `#grants` — Post milestone updates; other grantees may be pilot witnesses

**Tactics:**
1. **Post the security review for community input** (M1 deliverable) — both a technical requirement and a credibility event.
2. **Announce the mainnet launch** in `#dev-showcase` with the same launch-thread content as X.
3. **Direct outreach** — Identify 5–10 sBTC-active community members and send a personalized message. No mass DMs: "I see you hold/use sBTC — would you watch a 5-minute demo of a real-invoice funding flow?"
4. **Create a FlowFi Discord** — Once there is any audience (even 20–30 people), own the community instead of depending on Stacks' Discord.

---

### Platform 3 — Telegram

Telegram is stronger than Discord in West Africa — directly relevant, since both pilot business leads are Nigerian SMEs.

**Setup:**
1. Create a **FlowFi Telegram channel** for announcements (one-way broadcast)
2. Create a **FlowFi Telegram group** for community discussion
3. Cross-post all major announcements from X to Telegram

**Target groups to join and engage in:**
- Stacks community Telegram groups
- Africa Bitcoin / Stacks communities — FlowFi's value proposition (30–90-day invoices unlocked with sBTC) lands hardest where traditional receivables finance is slow or unavailable
- SME / trade-finance operator groups

**Tactics:**
- Share the launch announcement in relevant groups (do not spam — be helpful)
- Post demo videos natively since Telegram video plays well
- Use Telegram polls for feedback: "What invoice size should the next pilot target?"

---

### Platform 4 — LinkedIn

LinkedIn is slower to convert than X or Discord but reaches SME operators and finance professionals with budget authority who are not on crypto-native platforms.

**Content strategy:**
1. **Article: "Why sBTC belongs in SME working capital"** — 500-word educational piece. Link to FlowFi at the end, not a sales pitch.
2. **Product announcement post** — At mainnet launch: "FlowFi BTC is now live on Stacks mainnet. One invoice, one funder, fully on-chain."
3. **Milestone updates** — Post when each milestone is met. Execution credibility compounds for anyone doing diligence.
4. **Connect with Stacks ecosystem leaders** — Foundation, Hiro, major projects. Follow, engage, be visible.

LinkedIn is not where the first provider comes from, but it is where the second and third waves of businesses discover the pilot result.

---

### Platform 5 — Skool

Skool communities suit the education-heavy part of this project (SMEs learning on-chain finance):

- Web3/blockchain builder communities where future businesses gather
- African tech/startup communities on Skool
- Crypto education communities covering Bitcoin L2s

**Tactics:**
1. Post with an educational framing: "How does escrow-then-release receivables funding work? Here is what I built."
2. Offer a live walkthrough for community members — Skool supports live events
3. Distribute the same educational material posted on X and LinkedIn

---

### Ecosystem-Specific Positioning

Beyond social media, Stacks-native distribution channels are often more valuable:

1. **Stacks Forum (forum.stacks.org)** — Post the security review and the mainnet launch. Indexed and discoverable by anyone researching Stacks projects.

2. **Stacks Weekly Newsletter** — Submit a project update for inclusion. Reaches developers and investors in one send.

3. **Hiro / community calls** — Request a 5-minute demo slot. Live demos convert.

4. **Stacks Ecosystem Directory** — Submit FlowFi once mainnet is live.

5. **Sigle.io** — Publish the pilot retrospective there as well as in-repo. On-chain blogging signals ecosystem commitment and is discovered by Stacks users organically.

---

### Marketing Cadence (Week-by-Week Overlay)

| Week | Milestone Phase | Marketing Action |
|---|---|---|
| Week 1 | M1 begins | Origin story thread on X. Set up / refresh FlowFi accounts. Join Stacks Discord channels. |
| Week 2 | M1 — testing | "Building in public" tweet about funding-math fuzzing. First Discord post. |
| Week 3 | M1 — review | Publish security review. Post on X, Discord, and the Stacks Forum. Request community review. |
| Week 4 | M2 begins | RC announcement: "FlowFi v1.0.0-rc1 is ready. Mainnet deployment coming." |
| Week 5 | M2 — deployment | Mainnet deployment tweet + Discord announcement. First proving-flow transactions. Post the tx hashes. |
| Week 6 | M2 — frontend | Production frontend live post. Demo video on X and Telegram. |
| Week 7 | M2 — proving flow | "Full cycle complete on mainnet" proof post. Counterparty check-ins for M3. |
| Week 8 | M3 begins | LinkedIn article published. Final onboarding calls with business + provider. Campaign launched. |
| Week 9 | M3 — pilot | Pilot transactions posted as they confirm. Metrics update post. |
| Week 10–12 | M3 — resolution | Outcome post (repaid or defaulted) + `PILOT_RESULT.md`. Submit M3 evidence to Stacks Endowment. |

---

## Section 6 — Recommended Tools

These tools are selected for alignment with the Stacks ecosystem, low cost, and direct utility for building and marketing FlowFi BTC.

### Development and Testing

| Tool | Purpose | Cost | Why This One |
|---|---|---|---|
| Clarinet | Smart contract testing and simnet | Free | Official Stacks tooling; Clarity 3 / current epoch already configured |
| Vitest 3.2.7 + clarinet SDK | Test runner | Free | Already in use; fast, TypeScript-native |
| GitHub Actions | CI/CD for automated test runs | Free (public repo) | Runs tests on every push; generates coverage artifacts for M1 evidence |
| Hiro Platform (explorer.hiro.so) | Contract verification and monitoring | Free | Official Stacks explorer; where contract addresses are submitted as evidence |
| Stacks.js (`@stacks/connect`, `@stacks/transactions`, `@stacks/network`) | Wallet integration and transaction building | Free | Official SDKs; already in use |

### Infrastructure and Hosting

| Tool | Purpose | Cost | Why This One |
|---|---|---|---|
| Vercel | Frontend hosting | Free–$20/month | Already in use |
| Railway / Render + managed Postgres | API + database hosting | ~$30/month | Already the API's shape (Express + Prisma); simple Node deployment |
| Chainhook (by Hiro) | On-chain event indexing for funding/settlement | Free (self-hosted) or Hiro API | Stacks-native event indexing; query cycle history without running a full node |

### Analytics and Monitoring

| Tool | Purpose | Cost | Why This One |
|---|---|---|---|
| PostHog | Frontend usage analytics (privacy-first) | Free up to 1M events | Open-source; funnel from landing → register → fund → repay |
| Vercel Analytics | Core web vitals and page-level traffic | Free on Vercel | Built in; zero setup |
| Hiro API | On-chain data (funded amounts, cycle counts) | Free | Official Stacks API; already used for balances |

### Marketing and Content

| Tool | Purpose | Cost | Why This One |
|---|---|---|---|
| Loom | Demo video recording | Free (up to 5 min) | Fastest screen-capture demos; no editing needed |
| Canva | Social graphics and diagrams | Free | X headers, announcement cards, escrow-flow diagrams |
| Typefully | X thread drafting and scheduling | Free (basic) | Draft offline, schedule for consistent cadence |
| Buffer | Multi-platform scheduling (X, LinkedIn) | Free (3 channels) | Cross-post from one place |

### Community and Counterparty Outreach

| Tool | Purpose | Cost | Why This One |
|---|---|---|---|
| Discord (FlowFi server) | Community hub | Free | Essential once past ~20 engaged users |
| Telegram (channel + group) | Announcements + discussion | Free | High engagement in crypto and West-African SME communities |
| Zealy (formerly Crew3) | Community quests and leaderboard | Free (basic) | Structured campaign: "verify a test invoice, earn XP" |

### Counterparty Discovery

| Tool | Purpose | Cost | Why This One |
|---|---|---|---|
| Existing pilot leads | M3 counterparties | Free | 2 SME leads + 1 provider lead already contacted (see PILOT_READINESS.md) |
| Stacks Forum search | Witness and Phase-2 pipeline | Free | Find sBTC holders discussing real-world utility |
| GitHub (stacks-network ecosystem) | Builder pipeline | Free | Active Stacks developers as Phase-2 witnesses |

---

## Section 7 — Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Mainnet deployment gas costs exceed estimate | Low | Low | $100 gas buffer; contracts are small |
| Community security review receives no responses | Medium | Medium | $200 STX bounty; post in multiple channels; if silent, document the self-audit as the review and note no community issues were raised |
| Proving-flow sBTC exceeds available funds | Low | Low | Small self-funded amount; well within the $150 allocation |
| Named pilot business drops out before M3 | Medium | High | 2 leads maintained so 1 can convert; selection on readiness, not promises |
| Provider withdraws before funding | Medium | High | Keep provider warm with M1/M2 rigor posts; proving flow de-risks the mechanics independently |
| sBTC volatility complicates the pilot narrative | Low | Medium | Flat funding-amount mechanics (no price leg in-contract); report USD equivalents at each step |
| STX price drop changes real-dollar costs | Low | Low | Grant is USD-denominated; affects timing, not amounts |

---

## Summary Table

| Milestone | Core Deliverable | Grant % | Amount | Primary Evidence |
|---|---|---|---|---|
| M1: Hardening | 70+ tests, public security review, RC tag | 20% | $2,000 | Test log, `SECURITY_REVIEW.md`, GitHub release |
| M2: Launch | Mainnet contracts, production frontend + public transparency page, 1 proving flow | 30% | $3,000 | Explorer links, live URL, cycle tx hashes |
| M3: Pilot | 1 real business + 1 real provider, 1 resolved cycle | 50% | $5,000 | On-chain cycle, counterparties, `PILOT_RESULT.md` |
| **Total** | | **100%** | **$10,000** | |
