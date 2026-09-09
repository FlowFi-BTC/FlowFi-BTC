;; title: registry
;; version: 1.0.0
;; summary: Protocol source of truth for FlowFi BTC -- business identity,
;;   verification, and receivable lifecycle state. Holds no sBTC.
;;
;; description:
;;   registry.clar answers "who is this business, was it verified, what
;;   receivable exists, and what state is it in?" All money movement and
;;   custody lives in escrow.clar, which is the only contract authorized
;;   to call mark-funded / mark-repaid / mark-defaulted here.
;;
;;   issue-date / due-date are burn-block heights (Bitcoin-anchored),
;;   not calendar timestamps -- Clarity has no native wall-clock time,
;;   and burn-block-height is far more stable than Stacks block height,
;;   whose cadence can change under Nakamoto. Convert calendar dates to
;;   an approximate future burn-block height off-chain before calling
;;   register-receivable (~144 Bitcoin blocks/day).
;;
;; deployment order: deploy registry.clar BEFORE escrow.clar (escrow.clar
;;   references .registry directly via contract-call?, which requires
;;   registry's interface to already exist at escrow's deploy/analysis
;;   time). After BOTH are deployed, the registry admin MUST call
;;   set-escrow-contract with escrow's fully-qualified address -- until
;;   that call happens, mark-funded/mark-repaid/mark-defaulted are
;;   unreachable by design (see "escrow-contract" below).

;; -------------------------------------------------------------------
;; Constants
;; -------------------------------------------------------------------

(define-constant CONTRACT-OWNER tx-sender)

;; Verification status
(define-constant VERIFICATION-UNVERIFIED u0)
(define-constant VERIFICATION-VERIFIED   u1)
(define-constant VERIFICATION-EXPIRED    u2)
(define-constant VERIFICATION-REVOKED    u3)

;; Verification method
(define-constant METHOD-MANUAL         u0)
(define-constant METHOD-CAC            u1)
(define-constant METHOD-PERSONA        u2)
(define-constant METHOD-OPENCORPORATES u3)
(define-constant METHOD-PARTNER        u4)
(define-constant METHOD-OTHER          u5)

;; Verification level
(define-constant LEVEL-NONE     u0)
(define-constant LEVEL-BASIC    u1)
(define-constant LEVEL-ENHANCED u2)
(define-constant LEVEL-FULL-KYB u3)

;; Receivable status
(define-constant STATUS-DRAFT     u0)
(define-constant STATUS-OPEN      u1)
(define-constant STATUS-FUNDED    u2)
(define-constant STATUS-REPAID    u3)
(define-constant STATUS-DEFAULTED u4)
(define-constant STATUS-CANCELLED u5)

;; Errors
(define-constant ERR-NOT-AUTHORIZED              (err u100))
(define-constant ERR-NOT-FOUND                    (err u101))
(define-constant ERR-ALREADY-REGISTERED           (err u102))
(define-constant ERR-INVALID-NAME                 (err u103))
(define-constant ERR-INVALID-COUNTRY              (err u104))
(define-constant ERR-NOT-BUSINESS-OWNER           (err u105))
(define-constant ERR-NOT-VERIFIED                 (err u106))
(define-constant ERR-INVALID-AMOUNT               (err u107))
(define-constant ERR-FUNDING-EXCEEDS-FACE-VALUE   (err u108))
(define-constant ERR-INVALID-DATE                 (err u109))
(define-constant ERR-INVALID-STATUS               (err u110))
(define-constant ERR-INVALID-VERIFICATION-METHOD  (err u111))
(define-constant ERR-INVALID-VERIFICATION-LEVEL   (err u112))

;; -------------------------------------------------------------------
;; State
;; -------------------------------------------------------------------

(define-data-var admin principal CONTRACT-OWNER)

;; Combined admin/verifier for the MVP -- defaults to the deployer, so
;; verification works immediately after deploy. Reassignable.
(define-data-var verifier principal CONTRACT-OWNER)

;; The ONLY contract allowed to call mark-funded / mark-repaid /
;; mark-defaulted. Deliberately starts at `none`, NOT at CONTRACT-OWNER
;; -- if this defaulted to a real, already-privileged principal, that
;; principal could call the restricted functions directly (bypassing
;; escrow entirely) during the window before set-escrow-contract is
;; called. With `none`, the (is-eq (some contract-caller) ...) check
;; below can never pass until an admin explicitly sets a real value.
(define-data-var escrow-contract (optional principal) none)

(define-data-var next-business-id uint u1)
(define-data-var next-receivable-id uint u1)

(define-map businesses
  uint
  {
    owner: principal,
    business-name: (string-ascii 100),
    country: (string-ascii 2),
    verification-status: uint,
    verification-method: uint,
    verification-level: uint,
    verified-at: (optional uint),
    verification-expiry: uint,
    verified-by: (optional principal),
    verification-reference-hash: (optional (buff 32)),
    verification-proof-hash: (optional (buff 32)),
    created-at: uint
  }
)

(define-map business-owner-index principal uint)

(define-map receivables
  uint
  {
    business-id: uint,
    debtor-name: (string-ascii 100),
    debtor-country: (string-ascii 2),
    invoice-number: (string-ascii 100),
    invoice-hash: (buff 32),
    face-value: uint,
    funding-amount: uint,
    issue-date: uint,
    due-date: uint,
    status: uint,
    escrow-id: (optional uint),
    created-at: uint
  }
)

;; -------------------------------------------------------------------
;; Business registration + verification
;; -------------------------------------------------------------------

(define-public (register-business (business-name (string-ascii 100)) (country (string-ascii 2)))
  (let ((id (var-get next-business-id)))
    (asserts! (is-none (map-get? business-owner-index tx-sender)) ERR-ALREADY-REGISTERED)
    (asserts! (> (len business-name) u0) ERR-INVALID-NAME)
    (asserts! (is-eq (len country) u2) ERR-INVALID-COUNTRY)
    (map-set businesses id {
      owner: tx-sender,
      business-name: business-name,
      country: country,
      verification-status: VERIFICATION-UNVERIFIED,
      verification-method: METHOD-MANUAL,
      verification-level: LEVEL-NONE,
      verified-at: none,
      verification-expiry: u0,
      verified-by: none,
      verification-reference-hash: none,
      verification-proof-hash: none,
      created-at: burn-block-height
    })
    (map-set business-owner-index tx-sender id)
    (var-set next-business-id (+ id u1))
    (print { event: "business-registered", id: id, owner: tx-sender })
    (ok id)
  )
)

(define-public (verify-business
    (business-id uint)
    (verification-method uint)
    (verification-level uint)
    (verification-expiry uint)
    (verified-by principal)
    (verification-reference-hash (buff 32))
    (verification-proof-hash (buff 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get verifier)) ERR-NOT-AUTHORIZED)
    (asserts! (<= verification-method u5) ERR-INVALID-VERIFICATION-METHOD)
    (asserts! (<= verification-level u3) ERR-INVALID-VERIFICATION-LEVEL)
    (asserts! (or (is-eq verification-expiry u0) (> verification-expiry burn-block-height)) ERR-INVALID-DATE)
    (let ((business (unwrap! (map-get? businesses business-id) ERR-NOT-FOUND)))
      (map-set businesses business-id
        (merge business {
          verification-status: VERIFICATION-VERIFIED,
          verification-method: verification-method,
          verification-level: verification-level,
          verified-at: (some burn-block-height),
          verification-expiry: verification-expiry,
          verified-by: (some verified-by),
          verification-reference-hash: (some verification-reference-hash),
          verification-proof-hash: (some verification-proof-hash)
        }))
      (print { event: "business-verified", id: business-id, method: verification-method, level: verification-level })
      (ok true)
    )
  )
)

(define-public (revoke-verification (business-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get verifier)) ERR-NOT-AUTHORIZED)
    (let ((business (unwrap! (map-get? businesses business-id) ERR-NOT-FOUND)))
      (map-set businesses business-id (merge business { verification-status: VERIFICATION-REVOKED }))
      (print { event: "verification-revoked", id: business-id })
      (ok true)
    )
  )
)

;; Lazily accounts for expiry: a business whose verification-expiry has
;; passed is treated as unverified here even if its stored status field
;; still literally says VERIFIED -- nobody has to call a keeper function
;; to "notice" the expiry, every caller re-derives it on read.
;; verification-expiry = u0 means "does not expire".
(define-read-only (is-business-verified (business-id uint))
  (match (map-get? businesses business-id)
    business
      (and
        (is-eq (get verification-status business) VERIFICATION-VERIFIED)
        (or (is-eq (get verification-expiry business) u0)
            (< burn-block-height (get verification-expiry business))))
    false
  )
)

;; -------------------------------------------------------------------
;; Receivables
;; -------------------------------------------------------------------

(define-public (register-receivable
    (business-id uint)
    (debtor-name (string-ascii 100))
    (debtor-country (string-ascii 2))
    (invoice-number (string-ascii 100))
    (invoice-hash (buff 32))
    (face-value uint)
    (funding-amount uint)
    (issue-date uint)
    (due-date uint))
  (let (
        (business (unwrap! (map-get? businesses business-id) ERR-NOT-FOUND))
        (id (var-get next-receivable-id))
       )
    (asserts! (is-eq tx-sender (get owner business)) ERR-NOT-BUSINESS-OWNER)
    (asserts! (is-business-verified business-id) ERR-NOT-VERIFIED)
    (asserts! (> face-value u0) ERR-INVALID-AMOUNT)
    (asserts! (> funding-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= funding-amount face-value) ERR-FUNDING-EXCEEDS-FACE-VALUE)
    (asserts! (<= issue-date burn-block-height) ERR-INVALID-DATE)
    (asserts! (> due-date burn-block-height) ERR-INVALID-DATE)
    (map-set receivables id {
      business-id: business-id,
      debtor-name: debtor-name,
      debtor-country: debtor-country,
      invoice-number: invoice-number,
      invoice-hash: invoice-hash,
      face-value: face-value,
      funding-amount: funding-amount,
      issue-date: issue-date,
      due-date: due-date,
      status: STATUS-OPEN,
      escrow-id: none,
      created-at: burn-block-height
    })
    (var-set next-receivable-id (+ id u1))
    (print { event: "receivable-registered", id: id, business-id: business-id,
             face-value: face-value, funding-amount: funding-amount, due-date: due-date })
    (ok id)
  )
)

(define-public (cancel-receivable (receivable-id uint))
  (let (
        (receivable (unwrap! (map-get? receivables receivable-id) ERR-NOT-FOUND))
        (business (unwrap! (map-get? businesses (get business-id receivable)) ERR-NOT-FOUND))
       )
    (asserts! (is-eq tx-sender (get owner business)) ERR-NOT-BUSINESS-OWNER)
    (asserts! (is-eq (get status receivable) STATUS-OPEN) ERR-INVALID-STATUS)
    (map-set receivables receivable-id (merge receivable { status: STATUS-CANCELLED }))
    (print { event: "receivable-cancelled", id: receivable-id })
    (ok true)
  )
)

;; -------------------------------------------------------------------
;; Escrow-only financial state transitions.
;; Authorization is checked FIRST, before touching any state, using
;; contract-caller (NOT tx-sender -- see file header / chat notes on
;; why tx-sender would be wrong here).
;; -------------------------------------------------------------------

(define-public (mark-funded (receivable-id uint) (funder principal) (funding-amount uint) (escrow-id uint))
  (begin
    (asserts! (is-eq (some contract-caller) (var-get escrow-contract)) ERR-NOT-AUTHORIZED)
    (let ((receivable (unwrap! (map-get? receivables receivable-id) ERR-NOT-FOUND)))
      (asserts! (is-eq (get status receivable) STATUS-OPEN) ERR-INVALID-STATUS)
      (map-set receivables receivable-id
        (merge receivable { status: STATUS-FUNDED, escrow-id: (some escrow-id) }))
      (print { event: "receivable-marked-funded", id: receivable-id, funder: funder, amount: funding-amount })
      (ok true)
    )
  )
)

(define-public (mark-repaid (receivable-id uint))
  (begin
    (asserts! (is-eq (some contract-caller) (var-get escrow-contract)) ERR-NOT-AUTHORIZED)
    (let ((receivable (unwrap! (map-get? receivables receivable-id) ERR-NOT-FOUND)))
      (asserts! (is-eq (get status receivable) STATUS-FUNDED) ERR-INVALID-STATUS)
      (map-set receivables receivable-id (merge receivable { status: STATUS-REPAID }))
      (print { event: "receivable-marked-repaid", id: receivable-id })
      (ok true)
    )
  )
)

(define-public (mark-defaulted (receivable-id uint))
  (begin
    (asserts! (is-eq (some contract-caller) (var-get escrow-contract)) ERR-NOT-AUTHORIZED)
    (let ((receivable (unwrap! (map-get? receivables receivable-id) ERR-NOT-FOUND)))
      (asserts! (is-eq (get status receivable) STATUS-FUNDED) ERR-INVALID-STATUS)
      (map-set receivables receivable-id (merge receivable { status: STATUS-DEFAULTED }))
      (print { event: "receivable-marked-defaulted", id: receivable-id })
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

(define-public (set-verifier (new-verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set verifier new-verifier)
    (ok true)
  )
)

;; Critical post-deploy step -- see file header. Pass escrow.clar's
;; fully-qualified address, e.g. 'SP....escrow (or .escrow if calling
;; from a script/console in the same project context).
(define-public (set-escrow-contract (new-escrow principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set escrow-contract (some new-escrow))
    (ok true)
  )
)

;; -------------------------------------------------------------------
;; Read-only
;; -------------------------------------------------------------------

(define-read-only (get-business (business-id uint))
  (map-get? businesses business-id)
)

(define-read-only (get-business-id-by-owner (owner principal))
  (map-get? business-owner-index owner)
)

(define-read-only (get-receivable (receivable-id uint))
  (map-get? receivables receivable-id)
)

(define-read-only (get-receivable-status (receivable-id uint))
  (match (map-get? receivables receivable-id)
    receivable (ok (get status receivable))
    ERR-NOT-FOUND
  )
)

(define-read-only (get-admin) (var-get admin))
(define-read-only (get-verifier) (var-get verifier))
(define-read-only (get-escrow-contract) (var-get escrow-contract))
(define-read-only (get-next-business-id) (var-get next-business-id))
(define-read-only (get-next-receivable-id) (var-get next-receivable-id))
