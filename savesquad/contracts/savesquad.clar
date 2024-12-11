;; SaveSquad Decentralized Savings Pool
;; A community-driven savings mechanism with rotating withdrawals

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERROR-UNAUTHORIZED (err u1))
(define-constant ERROR-INSUFFICIENT-FUNDS (err u2))
(define-constant ERROR-ALREADY-PARTICIPANT (err u3))
(define-constant ERROR-NOT-PARTICIPANT (err u4))
(define-constant ERROR-CYCLE-INCOMPLETE (err u5))
(define-constant ERROR-INVALID-WITHDRAWAL (err u6))
(define-constant ERROR-INVALID-PARTICIPANT-COUNT (err u7))
(define-constant ERROR-INVALID-CONTRIBUTION-AMOUNT (err u8))

;; Storage for pool parameters and state
(define-data-var participant-limit uint u0)
(define-data-var required-contribution uint u0)
(define-data-var current-cycle-number uint u0)
(define-data-var total-pool-funds uint u0)

;; Map to track participants
(define-map pool-participants 
  principal 
  {
    is-active: bool,
    total-contributed: uint,
    last-contribution-cycle: uint
  }
)

;; Map to track cycle details
(define-map cycle-payout-info 
  uint  ;; cycle number
  {
    payout-recipient: principal,
    has-received-payout: bool
  }
)

;; Initialize the savings pool
(define-public (initialize-pool (max-participants uint) (contribution-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-UNAUTHORIZED)
    ;; Check that max-participants is greater than 0
    (asserts! (> max-participants u0) ERROR-INVALID-PARTICIPANT-COUNT)
    ;; Check that contribution-amount is greater than 0
    (asserts! (> contribution-amount u0) ERROR-INVALID-CONTRIBUTION-AMOUNT)
    (var-set participant-limit max-participants)
    (var-set required-contribution contribution-amount)
    (ok true)
  )
)

;; Join the savings pool
(define-public (join-pool)
  (let 
    (
      (participant-data 
        (default-to 
          {is-active: false, total-contributed: u0, last-contribution-cycle: u0}
          (map-get? pool-participants tx-sender)
        )
      )
    )
    ;; Check if already a participant
    (asserts! (not (get is-active participant-data)) ERROR-ALREADY-PARTICIPANT)
    
    ;; Add participant to the pool
    (map-set pool-participants tx-sender 
      {
        is-active: true, 
        total-contributed: u0, 
        last-contribution-cycle: u0
      }
    )
    (ok true)
  )
)

;; Contribute to the pool
(define-public (contribute)
  (let 
    (
      (current-cycle (var-get current-cycle-number))
      (contribution-amount (var-get required-contribution))
      (participant-data 
        (unwrap! 
          (map-get? pool-participants tx-sender) 
          ERROR-NOT-PARTICIPANT
        )
      )
    )
    ;; Verify participant is active and hasn't already contributed this cycle
    (asserts! (get is-active participant-data) ERROR-NOT-PARTICIPANT)
    (asserts! 
      (not (is-eq (get last-contribution-cycle participant-data) current-cycle)) 
      ERROR-ALREADY-PARTICIPANT
    )
    
    ;; Transfer contribution
    (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
    
    ;; Update participant and pool state
    (map-set pool-participants tx-sender 
      {
        is-active: true,
        total-contributed: (+ (get total-contributed participant-data) contribution-amount),
        last-contribution-cycle: current-cycle
      }
    )
    
    ;; Update total pool funds
    (var-set total-pool-funds 
      (+ (var-get total-pool-funds) contribution-amount)
    )
    
    (ok true)
  )
)

;; Select next payout recipient (simplified randomness)
(define-public (select-payout-recipient)
  (let 
    (
      (current-cycle (var-get current-cycle-number))
      (total-participants (var-get participant-limit))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-UNAUTHORIZED)
    
    ;; In a real-world scenario, use a more robust randomness mechanism
    (map-set cycle-payout-info current-cycle 
      {
        payout-recipient: CONTRACT-OWNER,  ;; Placeholder - replace with actual selection logic
        has-received-payout: false
      }
    )
    
    ;; Increment cycle
    (var-set current-cycle-number (+ current-cycle u1))
    
    (ok true)
  )
)

;; Withdraw pool funds
(define-public (withdraw-payout)
  (let 
    (
      (current-cycle (var-get current-cycle-number))
      (payout-data 
        (unwrap! 
          (map-get? cycle-payout-info (- current-cycle u1)) 
          ERROR-CYCLE-INCOMPLETE
        )
      )
      (payout-amount (var-get total-pool-funds))
    )
    ;; Verify withdrawal eligibility
    (asserts! 
      (is-eq (get payout-recipient payout-data) tx-sender) 
      ERROR-INVALID-WITHDRAWAL
    )
    (asserts! (not (get has-received-payout payout-data)) ERROR-INVALID-WITHDRAWAL)
    
    ;; Transfer pool funds
    (try! (as-contract (stx-transfer? payout-amount (as-contract tx-sender) tx-sender)))
    
    ;; Update payout status
    (map-set cycle-payout-info (- current-cycle u1)
      {
        payout-recipient: tx-sender,
        has-received-payout: true
      }
    )
    
    ;; Reset pool funds
    (var-set total-pool-funds u0)
    
    (ok true)
  )
)

;; Read-only function to check participant details
(define-read-only (get-participant-info (participant principal))
  (map-get? pool-participants participant)
)

;; Read-only function to get current pool status
(define-read-only (get-pool-status)
  {
    current-cycle: (var-get current-cycle-number),
    total-pool-funds: (var-get total-pool-funds),
    participant-limit: (var-get participant-limit),
    required-contribution: (var-get required-contribution)
  }
)