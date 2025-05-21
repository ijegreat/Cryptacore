;; Cryptacore: Privacy-focused Data Management on Stacks Blockchain

;; Constants
(define-constant error-unauthorized (err u100))
(define-constant error-record-not-found (err u101))
(define-constant error-permission-invalid (err u102))
(define-constant error-duplicate-record (err u103))
(define-constant error-access-expired (err u104))
(define-constant error-height-invalid (err u105))
(define-constant error-input-invalid (err u106))
(define-constant error-record-id-invalid (err u107))
(define-constant error-content-invalid (err u108))
(define-constant error-content-type-invalid (err u109))

;; Permission type constants
(define-constant access-level-read "read")
(define-constant access-level-write "write")
(define-constant access-level-admin "admin")
(define-constant access-level-none "none")

;; Action type constants
(define-constant operation-read "read")
(define-constant operation-create "create")
(define-constant operation-update "update")
(define-constant operation-delete "delete")
(define-constant operation-grant "grant")
(define-constant operation-revoke "revoke")
(define-constant operation-delete-req "delete-req")

;; Data entry storage
(define-map storage-records
  { record-owner: principal, record-id: (string-ascii 36) }
  { 
    content: (string-ascii 1024),
    content-type: (string-ascii 64),
    is-encrypted: bool,
    timestamp-created: uint,
    timestamp-modified: uint
  }
)

;; Permissions storage
(define-map access-rights
  { record-owner: principal, record-id: (string-ascii 36), user: principal }
  {
    access-type: (string-ascii 10),
    access-expiry: uint,
    can-revoke: bool
  }
)

;; Access log storage
(define-map activity-logs
  { record-owner: principal, record-id: (string-ascii 36), timestamp: uint }
  {
    actor: principal,
    operation: (string-ascii 10)
  }
)

;; Privacy settings storage
(define-map user-preferences
  { account: principal }
  {
    default-access: (string-ascii 10),
    logging-enabled: bool,
    auto-encrypt: bool
  }
)

;; --------------------
;; Private Functions
;; --------------------

(define-private (is-valid-access-type (access-type (string-ascii 10)))
  (or 
    (is-eq access-type access-level-read)
    (is-eq access-type access-level-write)
    (is-eq access-type access-level-admin)
    (is-eq access-type access-level-none)
  )
)

(define-private (is-valid-record-id (record-id (string-ascii 36)))
  (> (len record-id) u0)
)

(define-private (check-permission (record-owner principal) (record-id (string-ascii 36)) (requester principal) (required-access (string-ascii 10)))
  (let (
    (rights-entry (map-get? access-rights { record-owner: record-owner, record-id: record-id, user: requester }))
    (is-record-owner (is-eq record-owner requester))
  )
    (if is-record-owner
      true
      (if (is-none rights-entry)
        false
        (let (
          (access-level (get access-type (unwrap-panic rights-entry)))
          (access-expiry (get access-expiry (unwrap-panic rights-entry)))
        )
          (and
            (or (is-eq access-level access-level-admin) (is-eq access-level required-access))
            (or (is-eq access-expiry u0) (> access-expiry stacks-block-height))
          )
        )
      )
    )
  )
)

(define-private (record-activity (record-owner principal) (record-id (string-ascii 36)) (requester principal) (operation-type (string-ascii 10)))
  (let (
    (user-prefs (default-to 
                { default-access: access-level-none, logging-enabled: true, auto-encrypt: false } 
                (map-get? user-preferences { account: record-owner })))
    (should-record (get logging-enabled user-prefs))
  )
    (if should-record
      (map-set activity-logs 
        { record-owner: record-owner, record-id: record-id, timestamp: stacks-block-height }
        { actor: requester, operation: operation-type })
      true
    )
  )
)

;; --------------------
;; Public Functions
;; --------------------

(define-public (setup-preferences (default-access (string-ascii 10)) (enable-logs bool) (default-encrypt bool))
  (let (
    (account-holder tx-sender)
  )
    (asserts! (is-valid-access-type default-access) error-permission-invalid)

    (map-set user-preferences
      { account: account-holder }
      { 
        default-access: default-access,
        logging-enabled: enable-logs,
        auto-encrypt: default-encrypt
      }
    )
    (ok true)
  )
)

(define-public (save-record (record-id (string-ascii 36)) (content (string-ascii 1024)) (content-type (string-ascii 64)) (is-encrypted bool))
  (let (
    (account-holder tx-sender)
  )
    (asserts! (is-valid-record-id record-id) error-record-id-invalid)
    (asserts! (> (len content) u0) error-content-invalid)
    (asserts! (> (len content-type) u0) error-content-type-invalid)

    (let (
      (existing-record (map-get? storage-records { record-owner: account-holder, record-id: record-id }))
      (user-prefs (default-to 
                  { default-access: access-level-none, logging-enabled: true, auto-encrypt: false } 
                  (map-get? user-preferences { account: account-holder })))
      (final-encryption (if is-encrypted is-encrypted (get auto-encrypt user-prefs)))
    )
      (if (is-some existing-record)
        (begin
          (map-set storage-records
            { record-owner: account-holder, record-id: record-id }
            { 
              content: content,
              content-type: content-type,
              is-encrypted: final-encryption,
              timestamp-created: (get timestamp-created (unwrap-panic existing-record)),
              timestamp-modified: stacks-block-height
            }
          )
          (record-activity account-holder record-id account-holder operation-update)
          (ok true)
        )
        (begin
          (map-set storage-records
            { record-owner: account-holder, record-id: record-id }
            { 
              content: content,
              content-type: content-type,
              is-encrypted: final-encryption,
              timestamp-created: stacks-block-height,
              timestamp-modified: stacks-block-height
            }
          )
          (record-activity account-holder record-id account-holder operation-create)
          (ok true)
        )
      )
    )
  )
)

(define-public (retrieve-record (record-owner principal) (record-id (string-ascii 36)))
  (let (
    (requester tx-sender)
  )
    (asserts! (is-valid-record-id record-id) error-record-id-invalid)

    (let (
      (stored-record (map-get? storage-records { record-owner: record-owner, record-id: record-id }))
    )
      (asserts! (is-some stored-record) error-record-not-found)
      (asserts! (check-permission record-owner record-id requester access-level-read) error-unauthorized)
      (record-activity record-owner record-id requester operation-read)
      (ok (unwrap-panic stored-record))
    )
  )
)

(define-public (remove-record (record-id (string-ascii 36)))
  (let (
    (account-holder tx-sender)
  )
    (asserts! (is-valid-record-id record-id) error-record-id-invalid)
    (let (
      (stored-record (map-get? storage-records { record-owner: account-holder, record-id: record-id }))
    )
      (asserts! (is-some stored-record) error-record-not-found)
      (map-delete storage-records { record-owner: account-holder, record-id: record-id })
      (record-activity account-holder record-id account-holder operation-delete)
      (ok true)
    )
  )
)

(define-public (grant-permission (record-id (string-ascii 36)) (recipient principal) (access-type (string-ascii 10)) (expiry uint) (can-revoke bool))
  (let (
    (account-holder tx-sender)
  )
    (asserts! (is-valid-record-id record-id) error-record-id-invalid)
    (asserts! (is-valid-access-type access-type) error-permission-invalid)
    (asserts! (or (is-eq expiry u0) (> expiry stacks-block-height)) error-height-invalid)

    (let (
      (stored-record (map-get? storage-records { record-owner: account-holder, record-id: record-id }))
    )
      (asserts! (is-some stored-record) error-record-not-found)

      (map-set access-rights
        { record-owner: account-holder, record-id: record-id, user: recipient }
        {
          access-type: access-type,
          access-expiry: expiry,
          can-revoke: can-revoke
        }
      )
      (record-activity account-holder record-id account-holder operation-grant)
      (ok true)
    )
  )
)

(define-public (revoke-permission (record-id (string-ascii 36)) (recipient principal))
  (let (
    (account-holder tx-sender)
  )
    (asserts! (is-valid-record-id record-id) error-record-id-invalid)

    (let (
      (rights-entry (map-get? access-rights { record-owner: account-holder, record-id: record-id, user: recipient }))
    )
      (asserts! (is-some rights-entry) error-record-not-found)
      (asserts! (get can-revoke (unwrap-panic rights-entry)) error-unauthorized)

      (map-delete access-rights { record-owner: account-holder, record-id: record-id, user: recipient })
      (record-activity account-holder record-id account-holder operation-revoke)
      (ok true)
    )
  )
)

(define-public (check-access (record-owner principal) (record-id (string-ascii 36)) (user principal))
  (let (
    (requester tx-sender)
  )
    (asserts! (is-valid-record-id record-id) error-record-id-invalid)

    (let (
      (rights-entry (map-get? access-rights { record-owner: record-owner, record-id: record-id, user: user }))
    )
      (asserts! (or (is-eq requester record-owner) (is-eq requester user)) error-unauthorized)

      (ok (if (is-some rights-entry)
           (let (
             (access-info (unwrap-panic rights-entry))
             (is-expired (and (> (get access-expiry access-info) u0) (>= stacks-block-height (get access-expiry access-info))))
           )
             (if is-expired
               { has-access: false, access-details: access-info }
               { has-access: true, access-details: access-info }
             )
           )
           { has-access: false, access-details:
             {
               access-type: access-level-none,
               access-expiry: u0,
               can-revoke: false
             }
           }
         ))
    )
  )
)

(define-public (get-activity-history (record-id (string-ascii 36)) (start-height uint) (end-height uint))
  (let (
    (account-holder tx-sender)
  )
    (asserts! (is-valid-record-id record-id) error-record-id-invalid)
    (asserts! (>= end-height start-height) error-height-invalid)

    (let (
      (stored-record (map-get? storage-records { record-owner: account-holder, record-id: record-id }))
    )
      (asserts! (is-some stored-record) error-unauthorized)

      (ok { record-owner: account-holder, record-id: record-id, start-height: start-height, end-height: end-height })
    )
  )
)

(define-public (get-preferences)
  (let (
    (account-holder tx-sender)
    (user-prefs (map-get? user-preferences { account: account-holder }))
  )
    (if (is-some user-prefs)
      (ok (unwrap-panic user-prefs))
      (ok { default-access: access-level-none, logging-enabled: true, auto-encrypt: false })
    )
  )
)

(define-public (request-record-deletion (record-id (string-ascii 36)))
  (let (
    (account-holder tx-sender)
  )
    (asserts! (is-valid-record-id record-id) error-record-id-invalid)

    (let (
      (stored-record (map-get? storage-records { record-owner: account-holder, record-id: record-id }))
    )
      (asserts! (is-some stored-record) error-record-not-found)
      (record-activity account-holder record-id account-holder operation-delete-req)
      (ok true)
    )
  )
)

(define-public (update-preferences (default-access (string-ascii 10)) (enable-logs bool) (default-encrypt bool))
  (let (
    (account-holder tx-sender)
  )
    (asserts! (is-valid-access-type default-access) error-permission-invalid)

    (let (
      (user-prefs (map-get? user-preferences { account: account-holder }))
    )
      (asserts! (is-some user-prefs) error-record-not-found)

      (map-set user-preferences
        { account: account-holder }
        { 
          default-access: default-access,
          logging-enabled: enable-logs,
          auto-encrypt: default-encrypt
        }
      )
      (ok true)
    )
  )
)