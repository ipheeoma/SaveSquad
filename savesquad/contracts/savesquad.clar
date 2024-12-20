;; SaveSquad Decentralized Savings Pool
;; Version with proper trait handling

;; Define a simplified local FT trait
(define-trait ft-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
  )
)

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-FUNDS (err u2))
(define-constant ERR-ALREADY-MEMBER (err u3))
(define-constant ERR-NOT-MEMBER (err u4))
(define-constant ERR-CYCLE-NOT-COMPLETE (err u5))
(define-constant ERR-INVALID-WITHDRAWAL (err u6))
(define-constant ERR-INVALID-POOL-SIZE (err u7))
(define-constant ERR-INVALID-CONTRIBUTION (err u8))
(define-constant ERR-INVALID-CURRENCY (err u9))
(define-constant ERR-ORACLE-ERROR (err u10))
(define-constant ERR-REFERRAL-NOT-FOUND (err u11))
(define-constant ERR-CONVERSION-FAILED (err u12))
(define-constant ERR-TOKEN-CONTRACT-NOT-FOUND (err u13))

;; Storage for pool parameters and state
(define-data-var pool-size uint u0)
(define-data-var contribution-amount uint u0)
(define-data-var current-cycle uint u0)
(define-data-var total-pool-balance uint u0)
(define-data-var oracle-address principal 'SP000000000000000000002Q6VF78)

;; Supported currencies map - modified to store contract identifier
(define-map supported-currencies
  {currency: (string-ascii 10)}
  {
    is-active: bool,
    decimals: uint,
    min-amount: uint,
    price-multiplier: uint,
    token-contract: (optional (string-ascii 40))  ;; Store contract identifier instead of principal
  }
)

;; Member structure with referral tracking
(define-map members 
  principal 
  {
    is-active: bool,
    total-contributions: uint,
    last-contribution-cycle: uint,
    referrer: (optional principal),
    referral-count: uint,
    bonus-balance: uint
  }
)

;; Map to track cycle details
(define-map cycle-withdrawals 
  uint  
  {
    selected-member: principal,
    is-withdrawn: bool,
    withdrawal-currency: (string-ascii 10)
  }
)

;; Referral rewards configuration
(define-data-var referral-bonus-percentage uint u5) ;; 5% bonus
(define-data-var max-referral-bonus uint u100000000) ;; in microSTX

;; Initialize the savings pool
(define-public (initialize-pool (size uint) (contribution uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> size u1) ERR-INVALID-POOL-SIZE)
    (asserts! (> contribution u0) ERR-INVALID-CONTRIBUTION)
    (var-set pool-size size)
    (var-set contribution-amount contribution)
    (ok true)
  )
)

;; Add supported currency
(define-public (add-supported-currency 
    (currency (string-ascii 10)) 
    (decimals uint) 
    (min-amount uint)
    (price-multiplier uint)
    (token-contract (optional (string-ascii 40)))
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set supported-currencies {currency: currency}
      {
        is-active: true,
        decimals: decimals,
        min-amount: min-amount,
        price-multiplier: price-multiplier,
        token-contract: token-contract
      }
    )
    (ok true)
  )
)

;; Set oracle address
(define-public (set-oracle-address (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set oracle-address new-oracle)
    (ok true)
  )
)

;; Join the pool with optional referrer
(define-public (join-pool (referrer (optional principal)))
  (let 
    (
      (member-info 
        (default-to 
          {
            is-active: false,
            total-contributions: u0,
            last-contribution-cycle: u0,
            referrer: none,
            referral-count: u0,
            bonus-balance: u0
          }
          (map-get? members tx-sender)
        )
      )
    )
    (asserts! (not (get is-active member-info)) ERR-ALREADY-MEMBER)
    (match referrer ref-principal
      (begin
        (asserts! (is-some (map-get? members ref-principal)) ERR-REFERRAL-NOT-FOUND)
        (try! (update-referrer-stats ref-principal))
      )
      true
    )
    (map-set members tx-sender 
      (merge member-info
        {
          is-active: true,
          referrer: referrer
        }
      )
    )
    (ok true)
  )
)

;; Update referrer statistics
(define-private (update-referrer-stats (referrer principal))
  (let
    (
      (referrer-info (unwrap! (map-get? members referrer) ERR-REFERRAL-NOT-FOUND))
      (new-referral-count (+ (get referral-count referrer-info) u1))
      (bonus-amount (calculate-referral-bonus))
    )
    (map-set members referrer
      (merge referrer-info
        {
          referral-count: new-referral-count,
          bonus-balance: (+ (get bonus-balance referrer-info) bonus-amount)
        }
      )
    )
    (ok true)
  )
)

;; Calculate referral bonus
(define-private (calculate-referral-bonus)
  (let
    (
      (base-contribution (var-get contribution-amount))
      (bonus-percentage (var-get referral-bonus-percentage))
      (calculated-bonus (/ (* base-contribution bonus-percentage) u100))
    )
    (if (> calculated-bonus (var-get max-referral-bonus))
        (var-get max-referral-bonus)
        calculated-bonus)
  )
)

;; Get converted amount
(define-private (get-converted-amount (currency (string-ascii 10)) (amount uint))
  (match (map-get? supported-currencies {currency: currency})
    currency-info (ok (* amount (get price-multiplier currency-info)))
    ERR-INVALID-CURRENCY
  )
)

;; Contribute in any supported currency
(define-public (contribute-in-currency (currency (string-ascii 10)) (token <ft-trait>))
  (let 
    (
      (current-cycle-num (var-get current-cycle))
      (contribution (var-get contribution-amount))
      (member-info (unwrap! (map-get? members tx-sender) ERR-NOT-MEMBER))
      (currency-info (unwrap! (map-get? supported-currencies {currency: currency}) ERR-INVALID-CURRENCY))
    )
    (asserts! (get is-active member-info) ERR-NOT-MEMBER)
    (asserts! (not (is-eq (get last-contribution-cycle member-info) current-cycle-num)) ERR-ALREADY-MEMBER)
    (match (get-converted-amount currency contribution)
      converted-amount
        (let
          (
            (final-contribution (- converted-amount (get bonus-balance member-info)))
          )
          (if (is-eq currency "STX")
              (match (stx-transfer? final-contribution tx-sender (as-contract tx-sender))
                success
                  (begin
                    (map-set members tx-sender 
                      (merge member-info
                        {
                          total-contributions: (+ (get total-contributions member-info) converted-amount),
                          last-contribution-cycle: current-cycle-num,
                          bonus-balance: u0
                        }
                      )
                    )
                    (var-set total-pool-balance (+ (var-get total-pool-balance) converted-amount))
                    (ok true)
                  )
                error (err error)
              )
              (match (contract-call? token transfer final-contribution tx-sender (as-contract tx-sender) none)
                success
                  (begin
                    (map-set members tx-sender 
                      (merge member-info
                        {
                          total-contributions: (+ (get total-contributions member-info) converted-amount),
                          last-contribution-cycle: current-cycle-num,
                          bonus-balance: u0
                        }
                      )
                    )
                    (var-set total-pool-balance (+ (var-get total-pool-balance) converted-amount))
                    (ok true)
                  )
                error (err error)
              )
          )
        )
      error (err error)
    )
  )
)

;; Withdraw pool funds in preferred currency
(define-public (withdraw (token <ft-trait>))
  (let 
    (
      (current-cycle-num (var-get current-cycle))
      (withdrawal-info (unwrap! (map-get? cycle-withdrawals (- current-cycle-num u1)) ERR-CYCLE-NOT-COMPLETE))
      (pool-balance (var-get total-pool-balance))
    )
    (asserts! (is-eq (get selected-member withdrawal-info) tx-sender) ERR-INVALID-WITHDRAWAL)
    (asserts! (not (get is-withdrawn withdrawal-info)) ERR-INVALID-WITHDRAWAL)
    
    (if (is-eq (get withdrawal-currency withdrawal-info) "STX")
        (match (stx-transfer? pool-balance (as-contract tx-sender) tx-sender)
          success
            (begin
              (map-set cycle-withdrawals (- current-cycle-num u1) (merge withdrawal-info {is-withdrawn: true}))
              (var-set total-pool-balance u0)
              (ok true)
            )
          error (err error)
        )
        (match (contract-call? token transfer pool-balance (as-contract tx-sender) tx-sender none)
          success
            (begin
              (map-set cycle-withdrawals (- current-cycle-num u1) (merge withdrawal-info {is-withdrawn: true}))
              (var-set total-pool-balance u0)
              (ok true)
            )
          error (err error)
        )
    )
  )
)

;; Read-only functions
(define-read-only (get-member-info (member principal))
  (map-get? members member)
)

(define-read-only (get-pool-status)
  {
    current-cycle: (var-get current-cycle),
    total-pool-balance: (var-get total-pool-balance),
    pool-size: (var-get pool-size),
    contribution-amount: (var-get contribution-amount)
  }
)

(define-read-only (get-currency-info (currency (string-ascii 10)))
  (map-get? supported-currencies {currency: currency})
)

(define-read-only (get-referral-program-info)
  {
    bonus-percentage: (var-get referral-bonus-percentage),
    max-bonus: (var-get max-referral-bonus)
  }
)

;; Convert amount between currencies
(define-public (convert-amount (currency-from (string-ascii 10)) (currency-to (string-ascii 10)) (amount uint))
  (let ((result (get-converted-amount currency-from amount)))
    (match result
      converted-amount 
        (match (get-converted-amount currency-to converted-amount)
          final-amount (ok final-amount)
          error (err error)
        )
      error (err error)
    )
  )
)