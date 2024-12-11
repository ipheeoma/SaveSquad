;; SaveSquad Decentralized Savings Pool
;; A community-driven savings mechanism with rotating withdrawals

(define-constant CONTRACT-OWNER tx-sender)

;; Error Codes
(define-constant ERROR-UNAUTHORIZED (err u1))
(define-constant ERROR-ALREADY-PARTICIPANT (err u2))
(define-constant ERROR-NOT-PARTICIPANT (err u3))
(define-constant ERROR-INSUFFICIENT-FUNDS (err u4))
(define-constant ERROR-INVALID-WITHDRAWAL (err u5))

;; Pool Configuration
(define-data-var participant-limit uint u10)
(define-data-var contribution-amount uint u100)
(define-data-var current-cycle uint u0)
(define-data-var total-pool-funds uint u0)

;; Participant Tracking
(define-map participants 
  principal 
  {
    is-active: bool,
    total-contributed: uint,
    last-contribution-cycle: uint
  }
)

;; Cycle Payout Information
(define-map cycle-payouts 
  uint  ;; cycle number
  {
    recipient: principal,
    has-withdrawn: bool
  }
)

;; Initialize the Savings Pool
(define-public (initialize-pool 
  (max-participants uint) 
  (monthly-contribution uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-UNAUTHORIZED)
    (var-set participant-limit max-participants)
    (var-set contribution-amount monthly-contribution)
    (ok true)
  )
)

;; Join the Savings Pool
(define-public (join-pool)
  (let 
    (
      (participant-data 
        (default-to 
          {is-active: false, total-contributed: u0, last-contribution-cycle: u0}
          (map-get? participants tx-sender)
        )
      )
      (current-participants 
        (len (filter is-active-participant (map-keys participants)))
      )
    )
    ;; Validate participation
    (asserts! 
      (< current-participants (var-get participant-limit)) 
      ERROR-ALREADY-PARTICIPANT
    )
    (asserts! (not (get is-active participant-data)) ERROR-ALREADY-PARTICIPANT)
    
    ;; Add participant
    (map-set participants tx-sender 
      {
        is-active: true, 
        total-contributed: u0, 
        last-contribution-cycle: u0
      }
    )
    (ok true)
  )
)

;; Contribute to the Pool
(define-public (contribute)
  (let 
    (
      (current-cycle-number (var-get current-cycle))
      (monthly-contribution (var-get contribution-amount))
      (participant-data 
        (unwrap! 
          (map-get? participants tx-sender) 
          ERROR-NOT-PARTICIPANT
        )
      )
    )
    ;; Validate contribution
    (asserts! (get is-active participant-data) ERROR-NOT-PARTICIPANT)
    (asserts! 
      (not (is-eq (get last-contribution-cycle participant-data) current-cycle-number)) 
      ERROR-ALREADY-PARTICIPANT
    )
    
    ;; Transfer contribution
    (try! (stx-transfer? monthly-contribution tx-sender (as-contract tx-sender)))
    
    ;; Update participant state
    (map-set participants tx-sender 
      {
        is-active: true,
        total-contributed: (+ (get total-contributed participant-data) monthly-contribution),
        last-contribution-cycle: current-cycle-number
      }
    )
    
    ;; Update pool funds
    (var-set total-pool-funds 
      (+ (var-get total-pool-funds) monthly-contribution)
    )
    
    (ok true)
  )
)

;; Select Next Payout Recipient
(define-public (select-payout-recipient)
  (let 
    (
      (current-cycle-number (var-get current-cycle))
      (active-participants 
        (filter 
          is-active-participant 
          (map-keys participants)
        )
      )
    )
    ;; Only contract owner can select recipient
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-UNAUTHORIZED)
    
    ;; Require at least one active participant
    (asserts! (> (len active-participants) u0) ERROR-INSUFFICIENT-FUNDS)
    
    ;; Pseudorandom recipient selection
    (let 
      (
        (recipient 
          (default-to 
            CONTRACT-OWNER 
            (element-at 
              active-participants 
              (mod current-cycle-number (len active-participants))
            )
          )
        )
      )
      ;; Record payout information
      (map-set cycle-payouts current-cycle-number 
        {
          recipient: recipient,
          has-withdrawn: false
        }
      )
      
      ;; Increment cycle
      (var-set current-cycle (+ current-cycle-number u1))
      
      (ok true)
    )
  )
)

;; Withdraw Pool Funds
(define-public (withdraw-payout)
  (let 
    (
      (current-cycle-number (var-get current-cycle))
      (payout-cycle (- current-cycle-number u1))
      (payout-info 
        (unwrap! 
          (map-get? cycle-payouts payout-cycle) 
          ERROR-INVALID-WITHDRAWAL
        )
      )
      (pool-funds (var-get total-pool-funds))
    )
    ;; Validate withdrawal
    (asserts! 
      (is-eq (get recipient payout-info) tx-sender) 
      ERROR-UNAUTHORIZED
    )
    (asserts! (not (get has-withdrawn payout-info)) ERROR-INVALID-WITHDRAWAL)
    
    ;; Transfer funds
    (try! (as-contract (stx-transfer? pool-funds (as-contract tx-sender) tx-sender)))
    
    ;; Update payout status
    (map-set cycle-payouts payout-cycle 
      {
        recipient: tx-sender,
        has-withdrawn: true
      }
    )
    
    ;; Reset pool funds
    (var-set total-pool-funds u0)
    
    (ok true)
  )
)

;; Helper function to check if participant is active
(define-private (is-active-participant (participant principal))
  (default-to false 
    (map-get? 
      (lambda (data) (get is-active data)) 
      (map-get? participants participant)
    )
  )
)

;; Read-only Functions
(define-read-only (get-participant-info (participant principal))
  (map-get? participants participant)
)

(define-read-only (get-pool-status)
  {
    current-cycle: (var-get current-cycle),
    total-pool-funds: (var-get total-pool-funds),
    participant-limit: (var-get participant-limit),
    contribution-amount: (var-get contribution-amount)
  }
)