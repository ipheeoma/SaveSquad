;; SaveSquad Decentralized Savings Pool
;; A community-driven savings mechanism with rotating withdrawals

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-FUNDS (err u2))
(define-constant ERR-ALREADY-MEMBER (err u3))
(define-constant ERR-NOT-MEMBER (err u4))
(define-constant ERR-CYCLE-NOT-COMPLETE (err u5))
(define-constant ERR-INVALID-WITHDRAWAL (err u6))

;; Storage for pool parameters and state
(define-data-var pool-size uint u0)
(define-data-var contribution-amount uint u0)
(define-data-var current-cycle uint u0)
(define-data-var total-pool-balance uint u0)

;; Map to track members
(define-map members 
  principal 
  {
    is-active: bool,
    total-contributions: uint,
    last-contribution-cycle: uint
  }
)

;; Map to track cycle details
(define-map cycle-withdrawals 
  uint  ;; cycle number
  {
    selected-member: principal,
    is-withdrawn: bool
  }
)

;; Initialize the savings pool
(define-public (initialize-pool (size uint) (contribution uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set pool-size size)
    (var-set contribution-amount contribution)
    (ok true)
  )
)

;; Join the savings pool
(define-public (join-pool)
  (let 
    (
      (member-info 
        (default-to 
          {is-active: false, total-contributions: u0, last-contribution-cycle: u0}
          (map-get? members tx-sender)
        )
      )
    )
    ;; Check if already a member
    (asserts! (not (get is-active member-info)) ERR-ALREADY-MEMBER)
    
    ;; Add member to the pool
    (map-set members tx-sender 
      {
        is-active: true, 
        total-contributions: u0, 
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
      (current-cycle-num (var-get current-cycle))
      (contribution (var-get contribution-amount))
      (member-info 
        (unwrap! 
          (map-get? members tx-sender) 
          ERR-NOT-MEMBER
        )
      )
    )
    ;; Verify member is active and hasn't already contributed this cycle
    (asserts! (get is-active member-info) ERR-NOT-MEMBER)
    (asserts! 
      (not (is-eq (get last-contribution-cycle member-info) current-cycle-num)) 
      ERR-ALREADY-MEMBER
    )
    
    ;; Transfer contribution
    (try! (stx-transfer? contribution tx-sender (as-contract tx-sender)))
    
    ;; Update member and pool state
    (map-set members tx-sender 
      {
        is-active: true,
        total-contributions: (+ (get total-contributions member-info) contribution),
        last-contribution-cycle: current-cycle-num
      }
    )
    
    ;; Update total pool balance
    (var-set total-pool-balance 
      (+ (var-get total-pool-balance) contribution)
    )
    
    (ok true)
  )
)

;; Select next withdrawal recipient (simplified randomness)
(define-public (select-withdrawal-recipient)
  (let 
    (
      (current-cycle-num (var-get current-cycle))
      (pool-members (var-get pool-size))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; In a real-world scenario, use a more robust randomness mechanism
    (map-set cycle-withdrawals current-cycle-num 
      {
        selected-member: CONTRACT-OWNER,  ;; Placeholder - replace with actual selection logic
        is-withdrawn: false
      }
    )
    
    ;; Increment cycle
    (var-set current-cycle (+ current-cycle-num u1))
    
    (ok true)
  )
)

;; Withdraw pool funds
(define-public (withdraw)
  (let 
    (
      (current-cycle-num (var-get current-cycle))
      (withdrawal-info 
        (unwrap! 
          (map-get? cycle-withdrawals (- current-cycle-num u1)) 
          ERR-CYCLE-NOT-COMPLETE
        )
      )
      (pool-balance (var-get total-pool-balance))
    )
    ;; Verify withdrawal eligibility
    (asserts! 
      (is-eq (get selected-member withdrawal-info) tx-sender) 
      ERR-INVALID-WITHDRAWAL
    )
    (asserts! (not (get is-withdrawn withdrawal-info)) ERR-INVALID-WITHDRAWAL)
    
    ;; Transfer pool funds (CORRECTED LINE)
    (try! (as-contract (stx-transfer? pool-balance (as-contract tx-sender) tx-sender)))
    
    ;; Update withdrawal status
    (map-set cycle-withdrawals (- current-cycle-num u1)
      {
        selected-member: tx-sender,
        is-withdrawn: true
      }
    )
    
    ;; Reset pool balance
    (var-set total-pool-balance u0)
    
    (ok true)
  )
)

;; Read-only function to check member details
(define-read-only (get-member-info (member principal))
  (map-get? members member)
)

;; Read-only function to get current pool status
(define-read-only (get-pool-status)
  {
    current-cycle: (var-get current-cycle),
    total-pool-balance: (var-get total-pool-balance),
    pool-size: (var-get pool-size),
    contribution-amount: (var-get contribution-amount)
  }
)