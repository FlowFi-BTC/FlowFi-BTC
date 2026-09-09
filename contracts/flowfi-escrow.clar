;; title: escrow
;; version: 1.0.0
;; summary: sBTC custody, funding, release, repayment and default
;;   handling for FlowFi BTC. Owns the money; registry.clar owns the
;;   protocol state.
;;
;; description:
;;   One receivable maps to at most one escrow record (one funder --
;;   the MVP has no multi-investor support). Funding is two-step by
;;   design: fund-receivable() pulls sBTC from the investor into this
;;   contract's own custody, and a separate release-funds() call pays
;;   it out to the business. Splitting these keeps "money is escrowed"
;;   and "money has been released" independently observable and
;;   independently testable, at the cost of one extra transaction
;;   versus paying the business directly on funding.
;;
;; deployment order: deploy AFTER registry.clar (this contract calls
;;   .registry directly via contract-call?, a static reference that
;;   requires registry's interface to exist already at compile time).
;;   After deploying THIS contract, an admin must call
;;   registry.set-escrow-contract with this contract's fully-qualified
;;   address, or every call this contract makes into registry
;;   (mark-funded / mark-repaid / mark-defaulted) will be rejected.

;; -------------------------------------------------------------------
;; SIP-010 trait, defined locally so this contract has no dependency
;; on an external, network-specific trait-contract address. sBTC's own
;; contract does not declare `impl-trait sip-010-trait`, but Clarity
;; checks trait conformance structurally against the callee's public
;; functions, so sBTC still satisfies this trait when passed in as
;; <sip-010-trait>.
;; -------------------------------------------------------------------
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; -------------------------------------------------------------------
;; Constants
;; -------------------------------------------------------------------

(define-constant CONTRACT-OWNER tx-sender)

;; Mirrors registry.clar's STATUS-OPEN (u1). Only this one value from
;; registry's receivable-status enum is needed here; keep in sync if
;; registry.clar's enum ever changes.
(define-constant REGISTRY-STATUS-OPEN u1)

;; This contract's OWN escrow-record status -- an independent number
;; space from registry.clar's receivable status. Do not confuse the
;; two: this is what "status" means inside THIS file's `escrows` map.
(define-constant STATUS-FUNDED    u0)
(define-constant STATUS-REPAID    u1)
(define-constant STATUS-DEFAULTED u2)

;; Errors
(define-constant ERR-NOT-AUTHORIZED      (err u200))
(define-constant ERR-NOT-FOUND           (err u201))
(define-constant ERR-WRONG-TOKEN         (err u202))
(define-constant ERR-RECEIVABLE-NOT-OPEN (err u203))
(define-constant ERR-ALREADY-FUNDED      (err u204))
(define-constant ERR-SELF-FUNDING        (err u205))
(define-constant ERR-INVALID-STATUS      (err u206))
(define-constant ERR-ALREADY-RELEASED    (err u207))
(define-constant ERR-NOT-RELEASED        (err u208))
(define-constant ERR-NOT-BUSINESS        (err u209))
(define-constant ERR-NOT-DUE             (err u210))

;; -------------------------------------------------------------------
;; State
;; -------------------------------------------------------------------

(define-data-var admin principal CONTRACT-OWNER)

;; mainnet / simnet : SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
;; testnet          : ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
(define-data-var sbtc-contract principal 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)

(define-data-var next-escrow-id uint u1)

;; Keyed by receivable-id directly (not by a separate escrow-id) since
;; every public function below is called with a receivable-id, and
;; the MVP is one-receivable-to-one-escrow. escrow-id is still
;; generated and stored as a field, for display/cross-reference with
;; registry's receivable.escrow-id.
(define-map escrows
  uint
  {
    escrow-id: uint,
    receivable-id: uint,
    funder: principal,
    business: principal,
    funding-amount: uint,
    funded-at: uint,
    released-at: (optional uint),
    status: uint,
    repaid-at: (optional uint),
    settled-at: (optional uint)
  }
)

;; -------------------------------------------------------------------
;; 13. fund-receivable
;; Investor -> this contract, for the exact funding-amount already
;; registered on the receivable (not caller-supplied, so nobody can
;; under- or over-fund a receivable relative to what the business
;; agreed to).
;; -------------------------------------------------------------------
(define-public (fund-receivable (receivable-id uint) (token <sip-010-trait>))
  (let ((receivable (unwrap! (contract-call? .registry get-receivable receivable-id) ERR-NOT-FOUND)))
    (asserts! (is-eq (contract-of token) (var-get sbtc-contract)) ERR-WRONG-TOKEN)
    (asserts! (is-eq (get status receivable) REGISTRY-STATUS-OPEN) ERR-RECEIVABLE-NOT-OPEN)
    (asserts! (is-none (map-get? escrows receivable-id)) ERR-ALREADY-FUNDED)
    (let (
          (business (unwrap! (contract-call? .registry get-business (get business-id receivable)) ERR-NOT-FOUND))
          (amount (get funding-amount receivable))
          (escrow-id (var-get next-escrow-id))
         )
      (asserts! (not (is-eq tx-sender (get owner business))) ERR-SELF-FUNDING)
      (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
      (map-set escrows receivable-id {
        escrow-id: escrow-id,
        receivable-id: receivable-id,
        funder: tx-sender,
        business: (get owner business),
        funding-amount: amount,
        funded-at: burn-block-height,
        released-at: none,
        status: STATUS-FUNDED,
        repaid-at: none,
        settled-at: none
      })
      (var-set next-escrow-id (+ escrow-id u1))
      (try! (contract-call? .registry mark-funded receivable-id tx-sender amount escrow-id))
      (print { event: "receivable-funded", receivable-id: receivable-id, escrow-id: escrow-id,
               funder: tx-sender, amount: amount })
      (ok escrow-id)
    )
  )
)

;; -------------------------------------------------------------------
;; 15. release-funds
;; Escrow -> business. Restricted to admin for the MVP: this is the
;; point where a real deployment would gate on an off-chain compliance
;; check before capital actually moves. Loosen to "funder or admin",
;; or make permissionless, if that gate isn't needed for your flow --
;; the recipient is always the escrow record's stored business
;; address regardless of caller, so a permissionless version would not
;; let anyone redirect funds, only trigger the release earlier.
;; -------------------------------------------------------------------
(define-public (release-funds (receivable-id uint) (token <sip-010-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (let ((escrow (unwrap! (map-get? escrows receivable-id) ERR-NOT-FOUND)))
      (asserts! (is-eq (contract-of token) (var-get sbtc-contract)) ERR-WRONG-TOKEN)
      (asserts! (is-eq (get status escrow) STATUS-FUNDED) ERR-INVALID-STATUS)
      (asserts! (is-none (get released-at escrow)) ERR-ALREADY-RELEASED)
      (try! (as-contract (contract-call? token transfer (get funding-amount escrow) tx-sender (get business escrow) none)))
      (map-set escrows receivable-id (merge escrow { released-at: (some burn-block-height) }))
      (print { event: "funds-released", receivable-id: receivable-id, business: (get business escrow) })
      (ok true)
    )
  )
)

;; -------------------------------------------------------------------
;; 16. repay-receivable
;; Business -> escrow -> funder, in one transaction. MVP repayment is
;; flat (== funding-amount; no separate interest/fee field yet -- add
;; a `repayment-amount` field to registry's receivable tuple and use
;; it here instead of escrow.funding-amount when you're ready to
;; support a spread).
;; -------------------------------------------------------------------
(define-public (repay-receivable (receivable-id uint) (token <sip-010-trait>))
  (let ((escrow (unwrap! (map-get? escrows receivable-id) ERR-NOT-FOUND)))
    (asserts! (is-eq (contract-of token) (var-get sbtc-contract)) ERR-WRONG-TOKEN)
    (asserts! (is-eq (get status escrow) STATUS-FUNDED) ERR-INVALID-STATUS)
    (asserts! (is-some (get released-at escrow)) ERR-NOT-RELEASED)
    (asserts! (is-eq tx-sender (get business escrow)) ERR-NOT-BUSINESS)
    (let ((amount (get funding-amount escrow))
          (funder (get funder escrow)))
      (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
      (try! (as-contract (contract-call? token transfer amount tx-sender funder none)))
      (map-set escrows receivable-id
        (merge escrow { status: STATUS-REPAID, repaid-at: (some burn-block-height), settled-at: (some burn-block-height) }))
      (try! (contract-call? .registry mark-repaid receivable-id))
      (print { event: "receivable-repaid", receivable-id: receivable-id, funder: funder, amount: amount })
      (ok true)
    )
  )
)

;; -------------------------------------------------------------------
;; 18. mark-default
;; No funds move here -- this only flips state for off-chain
;; collections/recovery to key off of. Restricted to admin (see
;; release-funds comment on the same trade-off); requires the
;; receivable's due date (held in registry, not here) to have passed.
;; -------------------------------------------------------------------
(define-public (mark-default (receivable-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (let (
          (escrow (unwrap! (map-get? escrows receivable-id) ERR-NOT-FOUND))
          (receivable (unwrap! (contract-call? .registry get-receivable receivable-id) ERR-NOT-FOUND))
         )
      (asserts! (is-eq (get status escrow) STATUS-FUNDED) ERR-INVALID-STATUS)
      (asserts! (is-some (get released-at escrow)) ERR-NOT-RELEASED)
      (asserts! (> burn-block-height (get due-date receivable)) ERR-NOT-DUE)
      (map-set escrows receivable-id
        (merge escrow { status: STATUS-DEFAULTED, settled-at: (some burn-block-height) }))
      (try! (contract-call? .registry mark-defaulted receivable-id))
      (print { event: "receivable-defaulted", receivable-id: receivable-id })
      (ok true)
    )
  )
)

;; -------------------------------------------------------------------
;; Admin configuration
;; -------------------------------------------------------------------

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-sbtc-contract (new-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set sbtc-contract new-contract)
    (ok true)
  )
)

;; -------------------------------------------------------------------
;; Read-only
;; -------------------------------------------------------------------

(define-read-only (get-escrow (receivable-id uint))
  (map-get? escrows receivable-id)
)

(define-read-only (get-admin) (var-get admin))
(define-read-only (get-sbtc-contract) (var-get sbtc-contract))
(define-read-only (get-next-escrow-id) (var-get next-escrow-id))
