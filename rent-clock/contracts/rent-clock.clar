;; Rent Clock - Rental Payment Automation Contract
;; A time-locked contract for automated rental payments on Stacks blockchain

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_RENTAL_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_PAYMENT_NOT_DUE (err u103))
(define-constant ERR_RENTAL_INACTIVE (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))

;; Data Variables
(define-data-var contract-nonce uint u0)

;; Data Maps
(define-map rentals
  { rental-id: uint }
  {
    tenant: principal,
    landlord: principal,
    monthly-rent: uint,
    deposit: uint,
    start-block: uint,
    end-block: uint,
    payment-interval: uint,
    last-payment-block: uint,
    is-active: bool,
    total-paid: uint
  }
)

(define-map rental-balances
  { rental-id: uint }
  { balance: uint }
)

;; Private Functions
(define-private (get-next-rental-id)
  (begin
    (var-set contract-nonce (+ (var-get contract-nonce) u1))
    (var-get contract-nonce)
  )
)

;; Public Functions

;; Create a new rental agreement
(define-public (create-rental 
  (landlord principal)
  (monthly-rent uint)
  (deposit uint)
  (duration-blocks uint)
  (payment-interval uint))
  (let
    (
      (rental-id (get-next-rental-id))
      (start-block block-height)
      (end-block (+ block-height duration-blocks))
    )
    (asserts! (> monthly-rent u0) ERR_INVALID_AMOUNT)
    (asserts! (> duration-blocks u0) ERR_INVALID_AMOUNT)
    (asserts! (> payment-interval u0) ERR_INVALID_AMOUNT)
    
    ;; Store rental agreement
    (map-set rentals
      { rental-id: rental-id }
      {
        tenant: tx-sender,
        landlord: landlord,
        monthly-rent: monthly-rent,
        deposit: deposit,
        start-block: start-block,
        end-block: end-block,
        payment-interval: payment-interval,
        last-payment-block: u0,
        is-active: true,
        total-paid: u0
      }
    )
    
    ;; Initialize balance
    (map-set rental-balances
      { rental-id: rental-id }
      { balance: u0 }
    )
    
    (ok rental-id)
  )
)

;; Deposit funds for rental payments
(define-public (deposit-funds (rental-id uint) (amount uint))
  (let
    (
      (rental (unwrap! (map-get? rentals { rental-id: rental-id }) ERR_RENTAL_NOT_FOUND))
      (current-balance (default-to u0 (get balance (map-get? rental-balances { rental-id: rental-id }))))
    )
    (asserts! (get is-active rental) ERR_RENTAL_INACTIVE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX from sender to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update balance
    (map-set rental-balances
      { rental-id: rental-id }
      { balance: (+ current-balance amount) }
    )
    
    (ok true)
  )
)

;; Check if payment is due
(define-read-only (is-payment-due (rental-id uint))
  (match (map-get? rentals { rental-id: rental-id })
    rental
    (let
      (
        (last-payment (get last-payment-block rental))
        (payment-interval (get payment-interval rental))
        (next-payment-due (+ last-payment payment-interval))
      )
      (and 
        (get is-active rental)
        (>= block-height next-payment-due)
        (<= block-height (get end-block rental))
      )
    )
    false
  )
)

;; Execute rental payment (can be called by anyone when due)
(define-public (execute-payment (rental-id uint))
  (let
    (
      (rental (unwrap! (map-get? rentals { rental-id: rental-id }) ERR_RENTAL_NOT_FOUND))
      (current-balance (default-to u0 (get balance (map-get? rental-balances { rental-id: rental-id }))))
      (monthly-rent (get monthly-rent rental))
      (landlord (get landlord rental))
    )
    (asserts! (get is-active rental) ERR_RENTAL_INACTIVE)
    (asserts! (is-payment-due rental-id) ERR_PAYMENT_NOT_DUE)
    (asserts! (>= current-balance monthly-rent) ERR_INSUFFICIENT_FUNDS)
    
    ;; Transfer payment to landlord
    (try! (as-contract (stx-transfer? monthly-rent tx-sender landlord)))
    
    ;; Update rental record
    (map-set rentals
      { rental-id: rental-id }
      (merge rental {
        last-payment-block: block-height,
        total-paid: (+ (get total-paid rental) monthly-rent)
      })
    )
    
    ;; Update balance
    (map-set rental-balances
      { rental-id: rental-id }
      { balance: (- current-balance monthly-rent) }
    )
    
    (ok true)
  )
)

;; Withdraw remaining funds (only tenant can call)
(define-public (withdraw-funds (rental-id uint) (amount uint))
  (let
    (
      (rental (unwrap! (map-get? rentals { rental-id: rental-id }) ERR_RENTAL_NOT_FOUND))
      (current-balance (default-to u0 (get balance (map-get? rental-balances { rental-id: rental-id }))))
    )
    (asserts! (is-eq tx-sender (get tenant rental)) ERR_NOT_AUTHORIZED)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_FUNDS)
    
    ;; Transfer funds back to tenant
    (try! (as-contract (stx-transfer? amount tx-sender (get tenant rental))))
    
    ;; Update balance
    (map-set rental-balances
      { rental-id: rental-id }
      { balance: (- current-balance amount) }
    )
    
    (ok true)
  )
)

;; End rental agreement (only tenant or landlord can call)
(define-public (end-rental (rental-id uint))
  (let
    (
      (rental (unwrap! (map-get? rentals { rental-id: rental-id }) ERR_RENTAL_NOT_FOUND))
      (is-authorized (or 
        (is-eq tx-sender (get tenant rental))
        (is-eq tx-sender (get landlord rental))
      ))
    )
    (asserts! is-authorized ERR_NOT_AUTHORIZED)
    (asserts! (get is-active rental) ERR_RENTAL_INACTIVE)
    
    ;; Deactivate rental
    (map-set rentals
      { rental-id: rental-id }
      (merge rental { is-active: false })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get rental details
(define-read-only (get-rental (rental-id uint))
  (map-get? rentals { rental-id: rental-id })
)

;; Get rental balance
(define-read-only (get-rental-balance (rental-id uint))
  (default-to u0 (get balance (map-get? rental-balances { rental-id: rental-id })))
)

;; Get next payment due block
(define-read-only (get-next-payment-block (rental-id uint))
  (match (map-get? rentals { rental-id: rental-id })
    rental (+ (get last-payment-block rental) (get payment-interval rental))
    u0
  )
)

;; Check if rental is expired
(define-read-only (is-rental-expired (rental-id uint))
  (match (map-get? rentals { rental-id: rental-id })
    rental (> block-height (get end-block rental))
    true
  )
)

;; Get contract stats
(define-read-only (get-contract-stats)
  {
    total-rentals: (var-get contract-nonce),
    current-block: block-height
  }
)