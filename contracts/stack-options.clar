;; Options Trading Platform
;; Version: 1.0.0

(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1001))
(define-constant ERR-INVALID-EXPIRY (err u1002))
(define-constant ERR-INVALID-STRIKE-PRICE (err u1003))
(define-constant ERR-OPTION-NOT-FOUND (err u1004))
(define-constant ERR-OPTION-EXPIRED (err u1005))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u1006))
(define-constant ERR-ALREADY-EXERCISED (err u1007))
(define-constant ERR-INVALID-PREMIUM (err u1008))


;; Data Types
(define-map options
    uint
    {
        writer: principal,
        holder: (optional principal),
        collateral-amount: uint,
        strike-price: uint,
        premium: uint,
        expiry: uint,
        is-exercised: bool,
        option-type: (string-ascii 4),  ;; "CALL" or "PUT"
        state: (string-ascii 8)         ;; "ACTIVE", "EXPIRED", "EXERCISED"
    }
)

(define-map user-positions
    principal
    {
        written-options: (list 10 uint),
        held-options: (list 10 uint),
        total-collateral-locked: uint
    }
)

;; Counter for option IDs
(define-data-var next-option-id uint u1)

;; Governance
(define-data-var contract-owner principal tx-sender)
(define-data-var protocol-fee-rate uint u100) ;; 1% = 100 basis points

;; Price Oracle Integration
(define-map price-feeds
    (string-ascii 10)
    {
        price: uint,
        timestamp: uint,
        source: principal
    }
)


;; Black-Scholes Implementation
(define-private (calculate-black-scholes-price 
    (spot-price uint)
    (strike-price uint)
    (time-to-expiry uint)
    (volatility uint)
    (risk-free-rate uint)
    (option-type (string-ascii 4)))
    ;; Simplified Black-Scholes calculation
    ;; Returns premium in base units
    (let (
        (time-sqrt (sqrti (* time-to-expiry u100000)))
        (vol-adjustment (* volatility time-sqrt))
        (price-ratio (/ (* spot-price u100000000) strike-price))
    )
        (if (is-eq option-type "CALL")
            ;; Call option pricing
            (/ (* price-ratio vol-adjustment) u100000)
            ;; Put option pricing
            (/ (* strike-price vol-adjustment) (* spot-price u100000))
        )
    )
)

;; Core Functions

;; Write a new option
(define-public (write-option
    (collateral-amount uint)
    (strike-price uint)
    (premium uint)
    (expiry uint)
    (option-type (string-ascii 4)))
    (let (
        (option-id (var-get next-option-id))
        (current-time block-height)
    )
        (asserts! (> expiry current-time) ERR-INVALID-EXPIRY)
        (asserts! (> strike-price u0) ERR-INVALID-STRIKE-PRICE)
        (asserts! (> premium u0) ERR-INVALID-PREMIUM)
        (asserts! (check-collateral-requirement collateral-amount strike-price option-type) ERR-INSUFFICIENT-COLLATERAL)
        
        ;; Lock collateral
        (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        
        ;; Create option
        (map-set options option-id {
            writer: tx-sender,
            holder: none,
            collateral-amount: collateral-amount,
            strike-price: strike-price,
            premium: premium,
            expiry: expiry,
            is-exercised: false,
            option-type: option-type,
            state: "ACTIVE"
        })
        
        ;; Update user position
        (let ((current-position (default-to 
            { written-options: (list ), held-options: (list ), total-collateral-locked: u0 }
            (map-get? user-positions tx-sender))))
            (map-set user-positions tx-sender
                (merge current-position {
                    written-options: (unwrap-panic (as-max-len? 
                        (append (get written-options current-position) option-id) u10)),
                    total-collateral-locked: (+ (get total-collateral-locked current-position) collateral-amount)
                })
            )
        )
        
        ;; Increment option ID
        (var-set next-option-id (+ option-id u1))
        (ok option-id)
    )
)


;; Buy an option
(define-public (buy-option (option-id uint))
    (let (
        (option (unwrap! (map-get? options option-id) ERR-OPTION-NOT-FOUND))
        (premium (get premium option))
    )
        (asserts! (is-none (get holder option)) ERR-ALREADY-EXERCISED)
        (asserts! (< block-height (get expiry option)) ERR-OPTION-EXPIRED)
        
        ;; Transfer premium
        (try! (stx-transfer? premium tx-sender (get writer option)))
        
        ;; Update option
        (map-set options option-id (merge option { 
            holder: (some tx-sender)
        }))
        
        ;; Update buyer position
        (let ((current-position (default-to 
            { written-options: (list ), held-options: (list ), total-collateral-locked: u0 }
            (map-get? user-positions tx-sender))))
            (map-set user-positions tx-sender
                (merge current-position {
                    held-options: (unwrap-panic (as-max-len? 
                        (append (get held-options current-position) option-id) u10))
                })
            )
        )
        
        (ok true)
    )
)


;; Exercise option
(define-public (exercise-option (option-id uint))
    (let (
        (option (unwrap! (map-get? options option-id) ERR-OPTION-NOT-FOUND))
        (current-price (get-current-price))
    )
        (asserts! (is-eq (some tx-sender) (get holder option)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-exercised option)) ERR-ALREADY-EXERCISED)
        (asserts! (< block-height (get expiry option)) ERR-OPTION-EXPIRED)
        
        (if (is-eq (get option-type option) "CALL")
            (exercise-call option current-price)
            (exercise-put option current-price)
        )
    )
)

;; Private helper functions

(define-private (check-collateral-requirement (amount uint) (strike uint) (option-type (string-ascii 4)))
    (if (is-eq option-type "CALL")
        (>= amount strike)
        (>= amount (/ (* strike u100000000) (get-current-price)))
    )
)

(define-private (exercise-call (option {
        writer: principal,
        holder: (optional principal),
        collateral-amount: uint,
        strike-price: uint,
        premium: uint,
        expiry: uint,
        is-exercised: bool,
        option-type: (string-ascii 4),
        state: (string-ascii 8)
    }) (current-price uint))
    (let (
        (profit (- current-price (get strike-price option)))
        (payout (min profit (get collateral-amount option)))
    )
        ;; Transfer payout
        (try! (as-contract (stx-transfer? payout tx-sender (unwrap! (get holder option) ERR-NOT-AUTHORIZED))))
        
        ;; Return remaining collateral to writer
        (try! (as-contract (stx-transfer? 
            (- (get collateral-amount option) payout)
            tx-sender
            (get writer option)
        )))
        
        ;; Update option state
        (map-set options (get-option-id option) (merge option {
            is-exercised: true,
            state: "EXERCISED"
        }))
        
        (ok true)
    )
)

(define-private (exercise-put (option {
        writer: principal,
        holder: (optional principal),
        collateral-amount: uint,
        strike-price: uint,
        premium: uint,
        expiry: uint,
        is-exercised: bool,
        option-type: (string-ascii 4),
        state: (string-ascii 8)
    }) (current-price uint))
    (let (
        (profit (- (get strike-price option) current-price))
        (payout (min profit (get collateral-amount option)))
    )
        ;; Transfer payout
        (try! (as-contract (stx-transfer? payout tx-sender (unwrap! (get holder option) ERR-NOT-AUTHORIZED))))
        
        ;; Return remaining collateral to writer
        (try! (as-contract (stx-transfer? 
            (- (get collateral-amount option) payout)
            tx-sender
            (get writer option)
        )))
        
        ;; Update option state
        (map-set options (get-option-id option) (merge option {
            is-exercised: true,
            state: "EXERCISED"
        }))
        
        (ok true)
    )
)

;; Utility functions

(define-private (get-current-price)
    (get price (unwrap! (map-get? price-feeds "BTC-USD") u0))
)