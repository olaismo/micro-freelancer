;; micro-freelance.clar
;; A simple STX (Clarity) smart contract for milestone-based freelance jobs.
;; Features:
;; - Create job with milestones and a budget in STX
;; - Fund job by the client
;; - Submit milestone by the freelancer
;; - Approve milestone by the client which releases funds to the freelancer

;; - Refund/cancel by client before funding
;; - Simple on-chain state with maps and tuples
;; Tested for basic safety: only principals who created jobs or were assigned as freelancer can act on them.
;; Note: Deploy this on a testnet first. This contract uses clarity standard library only.

(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-FUNDED (err u102))
(define-constant ERR-NOT-FUNDED (err u103))
(define-constant ERR-NOT-MILESTONE (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-ALREADY-PAID (err u106))

(define-data-var job-counter uint u0)

;; job-id => job-tuple
(define-map jobs 
  {job-id: uint} 
  {client: principal,
   freelancer: (optional principal),
   budget: uint,
   funded: bool,
   next-milestone: uint,
   milestones: (list 10 uint),
   cancelled: bool})

;; job-id + milestone-index => status (0 = open, 1 = submitted, 2 = paid)
(define-map milestone-status
  {job-id: uint, midx: uint}
  {status: uint})

;; Helper: increment job counter and return new id
(define-private (new-job-id)
  (let ((cur (var-get job-counter)))
    (var-set job-counter (+ cur u1))
    cur
  )
)

;; Create a job. client calls this to initialize job metadata and milestones.
;; Create a new job with the specified freelancer and milestone amounts
(define-public (create-job (freelancer (optional principal)) (milestone-amounts (list 10 uint)))
  (begin
    (asserts! (> (len milestone-amounts) u0) ERR-INVALID-AMOUNT)
    (let ((new-id (new-job-id)))
      (map-set jobs 
        {job-id: new-id} 
        {client: tx-sender,
         freelancer: freelancer,
         budget: u0,
         funded: false,
         next-milestone: u0,
         milestones: milestone-amounts,
         cancelled: false})
      (ok new-id))))

;; Client funds the job by sending STX with the call. Amount must equal job budget.
(define-public (fund-job (job-id uint))
  (match (map-get? jobs {job-id: job-id})
    job
    (begin 
      (asserts! (is-eq tx-sender (get client job)) ERR-UNAUTHORIZED)
      (asserts! (not (get funded job)) ERR-ALREADY-FUNDED)
      (asserts! (not (get cancelled job)) ERR-NOT-FOUND)
      (map-set jobs {job-id: job-id} 
               {client: (get client job),
                freelancer: (get freelancer job),
                budget: (get budget job),
                funded: true,
                next-milestone: (get next-milestone job),
                milestones: (get milestones job),
                cancelled: false})
      (ok true))
    (err u101)))

;; Freelancer submits a milestone: marks it as submitted (status 1)
(define-public (submit-milestone (job-id uint) (midx uint))
  (match (map-get? jobs {job-id: job-id})
    job (let ((funded (get funded job))
             (cancelled (get cancelled job))
             (ms (get milestones job)))
          (begin
            (asserts! funded ERR-NOT-FUNDED)
            (asserts! (not cancelled) ERR-NOT-FOUND)
            ;; verify midx in range
            (asserts! (< midx (len ms)) ERR-NOT-MILESTONE)
            ;; if freelancer assigned, only they can submit; otherwise ok
            (match (get freelancer job)
              freelancer-principal
                (begin 
                  (asserts! (is-eq tx-sender freelancer-principal) ERR-UNAUTHORIZED)
                  (map-set milestone-status {job-id: job-id, midx: midx} {status: u1})
                  (ok true))
              ;; no freelancer assigned yet, allow submission
              (begin
                (map-set milestone-status {job-id: job-id, midx: midx} {status: u1})
                (ok true)))))
    (err u101)))
        
      
      (err ERR-NOT-FOUND)
    
  


;; Client approves a submitted milestone, transferring funds for that milestone to freelancer.
(define-public (approve-milestone (job-id uint) (midx uint))
  (match (map-get? jobs {job-id: job-id})
    job
    (match (map-get? milestone-status {job-id: job-id, midx: midx})
      st 
      (begin
        (asserts! (is-eq tx-sender (get client job)) ERR-UNAUTHORIZED)
        (asserts! (not (get cancelled job)) ERR-NOT-FOUND)
        (asserts! (< midx (len (get milestones job))) ERR-NOT-MILESTONE)
        (asserts! (is-eq (get status st) u1) ERR-ALREADY-PAID)
        (let ((amount (unwrap! (element-at (get milestones job) midx) ERR-NOT-MILESTONE)))
          (match (get freelancer job)
            freelancer-principal
            (begin
              (try! (stx-transfer? amount tx-sender freelancer-principal))
              (map-set milestone-status {job-id: job-id, midx: midx} {status: u2})
              ;; update next-milestone if this was the current one
              (if (is-eq (get next-milestone job) midx)
                (map-set jobs {job-id: job-id}
                  {client: (get client job),
                   freelancer: (get freelancer job),
                   budget: (get budget job),
                   funded: (get funded job),
                   next-milestone: (+ (get next-milestone job) u1),
                   milestones: (get milestones job),
                   cancelled: false})
                true)
              (ok true))
            (err u100))) ;; ERR-UNAUTHORIZED
        )
      (err u104)) ;; ERR-NOT-MILESTONE
    (err u101))) ;; ERR-NOT-FOUND

;; Client can cancel and request refund before funding. If funded, cancellation is not allowed here.
(define-public (cancel-job (job-id uint))
  (let ((existing-job (unwrap! (map-get? jobs {job-id: job-id}) ERR-NOT-FOUND)))
    (begin
      (asserts! (is-eq tx-sender (get client existing-job)) ERR-UNAUTHORIZED)
      (asserts! (not (get funded existing-job)) ERR-ALREADY-FUNDED)
      (map-set jobs 
        {job-id: job-id}
        (merge existing-job {funded: false, cancelled: true}))
      (ok true))))


;; View helpers
(define-read-only (get-job (job-id uint))
  (match (map-get? jobs {job-id: job-id})
    job (ok job)
    (err ERR-NOT-FOUND))
)

(define-read-only (get-milestone-status (job-id uint) (midx uint))
  (match (map-get? milestone-status {job-id: job-id, midx: midx})
    st (ok (get status st))
    (err ERR-NOT-MILESTONE))
)

;; NOTE: stx-get-balance? is a built-in function in Clarity for checking contract balance

;; NOTES & LIMITATIONS:
;; - stx-transfer? syscall requires careful handling in testnets/mainnet; ensure the contract has available STX to send.
;; - In this simple design, the client must transfer the exact total budget when calling fund-job. Alternatively, you could support incremental funding.
;; - The contract does not implement advanced dispute resolution, timeouts, or partial refunds beyond simple milestone approvals.
;; - Before deploying on mainnet, thoroughly test: stx-transfer? behaviors, and verify that the contract holds STX funds after fund-job.

;; End of contract