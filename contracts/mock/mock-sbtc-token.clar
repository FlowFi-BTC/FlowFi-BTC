;; title: mock-sbtc-token
;; version: 1.0.0
;; summary: A local SIP-010 stand-in for sBTC, for devnet/testnet
;;   development without depending on Clarinet's sBTC requirement or a
;;   real Bitcoin peg-in. Drop-in compatible: same decimals (8) and
;;   the same transfer sender-authorization check as the real
;;   sbtc-token.clar, so anything tested against this mock behaves
;;   the same when later pointed at the real contract via
;;   escrow.set-sbtc-contract.
;;
;; description:
;;   Two ways to get test tokens:
;;     1. mint(amount, recipient)  -- admin-only, unlimited, any
;;        recipient. Use this to set up specific test scenarios.
;;     2. claim-daily-sbtc()       -- self-serve. Any wallet can call
;;        this FOR ITSELF (tx-sender receives it) to get a fixed
;;        amount (default 100 sBTC), at most once per claim-interval
;;        burn-blocks (default 144, ~1 Bitcoin day). There is no
;;        recipient/amount parameter -- you can only ever claim the
;;        fixed amount, to yourself.
;;
;;   This is NOT the real sBTC contract, carries no Bitcoin peg, and
;;   should never be pointed at from a mainnet deployment. It exists
;;   purely so wallets in local tests/demos can self-serve test
;;   tokens instead of relying on an admin to mint for them one at a
;;   time. Does not declare `impl-trait sip-010-trait`, matching the
;;   real sbtc-token.clar's own choice -- callers checking trait
;;   conformance (e.g. escrow.clar's <sip-010-trait> parameter) do so
;;   structurally, so this isn't required for compatibility.

(define-fungible-token mock-sbtc)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant TOKEN-DECIMALS u8)

;; 100 sBTC at 8 decimals: 100 * 10^8
(define-constant DEFAULT-CLAIM-AMOUNT u10000000000)
;; ~1 Bitcoin day, at ~10 minutes/block
(define-constant DEFAULT-CLAIM-INTERVAL u144)

(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-NOT-OWNER      (err u301))
(define-constant ERR-CLAIM-TOO-SOON (err u302))

(define-data-var admin principal CONTRACT-OWNER)
(define-data-var token-name (string-ascii 32) "sBTC")
(define-data-var token-symbol (string-ascii 32) "sBTC")
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-data-var claim-amount uint DEFAULT-CLAIM-AMOUNT)
(define-data-var claim-interval uint DEFAULT-CLAIM-INTERVAL)

(define-map last-claim-height principal uint)

;; -------------------------------------------------------------------
;; SIP-010
;; -------------------------------------------------------------------

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR-NOT-OWNER)
    (try! (ft-transfer? mock-sbtc amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-read-only (get-name) (ok (var-get token-name)))
(define-read-only (get-symbol) (ok (var-get token-symbol)))
(define-read-only (get-decimals) (ok TOKEN-DECIMALS))
(define-read-only (get-balance (who principal)) (ok (ft-get-balance mock-sbtc who)))
(define-read-only (get-total-supply) (ok (ft-get-supply mock-sbtc)))
(define-read-only (get-token-uri) (ok (var-get token-uri)))

;; -------------------------------------------------------------------
;; Minting
;; -------------------------------------------------------------------

;; Unrestricted amount, admin-only, any recipient.
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (ft-mint? mock-sbtc amount recipient)
  )
)

;; Self-serve faucet: tx-sender claims claim-amount for themselves, at
;; most once per claim-interval burn-blocks. First-ever call for a
;; given principal always succeeds (no prior claim on record).
(define-public (claim-daily-sbtc)
  (let ((last (map-get? last-claim-height tx-sender)))
    (asserts!
      (match last
        last-height (>= (- burn-block-height last-height) (var-get claim-interval))
        true)
      ERR-CLAIM-TOO-SOON)
    (map-set last-claim-height tx-sender burn-block-height)
    (try! (ft-mint? mock-sbtc (var-get claim-amount) tx-sender))
    (print { event: "daily-claim", claimant: tx-sender, amount: (var-get claim-amount) })
    (ok (var-get claim-amount))
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

(define-public (set-claim-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set claim-amount new-amount)
    (ok true)
  )
)

(define-public (set-claim-interval (new-interval uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set claim-interval new-interval)
    (ok true)
  )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)
  )
)

;; -------------------------------------------------------------------
;; Read-only helpers
;; -------------------------------------------------------------------

(define-read-only (get-admin) (var-get admin))
(define-read-only (get-claim-amount) (var-get claim-amount))
(define-read-only (get-claim-interval) (var-get claim-interval))
(define-read-only (get-last-claim-height (who principal)) (map-get? last-claim-height who))

;; How many more burn-blocks `who` must wait before their next claim
;; succeeds. Returns u0 if they can claim right now (including if
;; they have never claimed before).
(define-read-only (blocks-until-next-claim (who principal))
  (match (map-get? last-claim-height who)
    last-height
      (let ((elapsed (- burn-block-height last-height)))
        (if (>= elapsed (var-get claim-interval))
          u0
          (- (var-get claim-interval) elapsed)))
    u0
  )
)
