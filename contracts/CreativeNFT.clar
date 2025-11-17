;; CreativeNFT - Digital creator portfolio and artwork verification system
;; Creators earn tokens through artwork validation and community appreciation

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_ALREADY_APPRECIATED (err u105))
(define-constant ERR_SELF_APPRECIATION (err u106))
(define-constant ERR_EMPTY_STRING (err u107))
(define-constant ERR_INVALID_SCORE (err u108))
(define-constant ERR_INVALID_ARTWORK_ID (err u109))
(define-constant ERR_EMPTY_METADATA (err u110))

;; Constants
(define-constant MAX_APPRECIATION_SCORE u5)
(define-constant CURATOR_REWARD u12)
(define-constant FEATURED_REWARD u30)
(define-constant VIRAL_BONUS u75)

;; Data maps
(define-map creators
  { creator-id: principal }
  { display-name: (string-ascii 50), genre: (string-ascii 20), followers: uint, tokens: uint, featured: bool }
)

(define-map artworks
  { artwork-id: uint }
  { 
    creator: principal, 
    title: (string-ascii 50), 
    metadata-hash: (buff 32),
    created-at: uint, 
    curated: bool,
    curation-count: uint,
    appreciation-count: uint,
    quality-score: uint,
    scorer-count: uint
  }
)

(define-map artwork-curations
  { artwork-id: uint, curator: principal }
  { curated: bool }
)

(define-map appreciation-tokens
  { artwork-id: uint, appreciator: principal }
  { appreciation-level: uint, appreciated-at: uint }
)

(define-map quality-scores
  { artwork-id: uint, scorer: principal }
  { score: uint }
)

;; Variables
(define-data-var next-artwork-id uint u1)
(define-data-var action-log uint u0)

;; Helper functions
(define-private (is-valid-artwork-id (artwork-id uint))
  (< artwork-id (var-get next-artwork-id))
)

;; Creator functions
(define-public (register-creator (display-name (string-ascii 50)) (genre (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len display-name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq genre "visual") (is-eq genre "music") (is-eq genre "video")) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? creators {creator-id: caller})) ERR_ALREADY_EXISTS)
    (ok (map-set creators 
      {creator-id: caller} 
      {display-name: display-name, genre: genre, followers: u0, tokens: u200, featured: false}))
  )
)

(define-public (update-creator (display-name (string-ascii 50)) (genre (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len display-name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq genre "visual") (is-eq genre "music") (is-eq genre "video")) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? creators {creator-id: caller})) ERR_NOT_FOUND)
    (ok (map-set creators 
      {creator-id: caller} 
      (merge (unwrap! (map-get? creators {creator-id: caller}) ERR_NOT_FOUND)
             {display-name: display-name, genre: genre})))
  )
)

;; Artwork functions
(define-public (publish-artwork (title (string-ascii 50)) (metadata-hash (buff 32)))
  (let ((caller tx-sender)
        (artwork-id (var-get next-artwork-id)))
    (asserts! (> (len title) u0) ERR_EMPTY_STRING)
    (asserts! (> (len metadata-hash) u0) ERR_EMPTY_METADATA)
    (asserts! (is-some (map-get? creators {creator-id: caller})) ERR_NOT_FOUND)
    (var-set action-log (+ (var-get action-log) u1))
    
    (map-set artworks 
      {artwork-id: artwork-id} 
      { 
        creator: caller, 
        title: title, 
        metadata-hash: metadata-hash,
        created-at: (var-get action-log), 
        curated: false,
        curation-count: u0,
        appreciation-count: u0,
        quality-score: u0,
        scorer-count: u0
      })
    (var-set next-artwork-id (+ artwork-id u1))
    (ok artwork-id)
  )
)

(define-public (curate-artwork (artwork-id uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-artwork-id artwork-id) ERR_INVALID_ARTWORK_ID)
    (asserts! (is-some (map-get? creators {creator-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? artworks {artwork-id: artwork-id})) ERR_NOT_FOUND)
    
    (let ((artwork (unwrap! (map-get? artworks {artwork-id: artwork-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get creator artwork))) ERR_SELF_APPRECIATION)
      (asserts! (is-none (map-get? artwork-curations {artwork-id: artwork-id, curator: caller})) ERR_ALREADY_VERIFIED)
      
      (map-set artwork-curations 
        {artwork-id: artwork-id, curator: caller} 
        {curated: true})
      
      (let ((new-curation-count (+ (get curation-count artwork) u1))
            (artwork-creator (unwrap! (map-get? creators {creator-id: (get creator artwork)}) ERR_NOT_FOUND))
            (curator-creator (unwrap! (map-get? creators {creator-id: caller}) ERR_NOT_FOUND)))
        
        (map-set artworks 
          {artwork-id: artwork-id} 
          (merge artwork {
            curation-count: new-curation-count,
            curated: (>= new-curation-count u2)
          }))
        
        (map-set creators 
          {creator-id: caller} 
          (merge curator-creator {
            tokens: (+ (get tokens curator-creator) u7),
            followers: (+ (get followers curator-creator) u1)
          }))
        
        (if (and (>= new-curation-count u2) (not (get curated artwork)))
          (map-set creators 
            {creator-id: (get creator artwork)} 
            (merge artwork-creator {
              tokens: (+ (get tokens artwork-creator) FEATURED_REWARD),
              followers: (+ (get followers artwork-creator) u5),
              featured: true
            }))
          true)
        
        (ok new-curation-count)
      )
    )
  )
)

(define-public (appreciate-artwork (artwork-id uint) (appreciation-level uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-artwork-id artwork-id) ERR_INVALID_ARTWORK_ID)
    (asserts! (> appreciation-level u0) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? creators {creator-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? artworks {artwork-id: artwork-id})) ERR_NOT_FOUND)
    
    (let ((artwork (unwrap! (map-get? artworks {artwork-id: artwork-id}) ERR_NOT_FOUND)))
      (asserts! (get curated artwork) ERR_UNAUTHORIZED)
      
      (map-set appreciation-tokens 
        {artwork-id: artwork-id, appreciator: caller} 
        {appreciation-level: appreciation-level, appreciated-at: (var-get action-log)})
      
      (let ((new-appreciation-count (+ (get appreciation-count artwork) appreciation-level))
            (artwork-creator (unwrap! (map-get? creators {creator-id: (get creator artwork)}) ERR_NOT_FOUND)))
        
        (map-set artworks 
          {artwork-id: artwork-id} 
          (merge artwork {appreciation-count: new-appreciation-count}))
        
        (map-set creators 
          {creator-id: (get creator artwork)} 
          (merge artwork-creator {
            tokens: (+ (get tokens artwork-creator) (* CURATOR_REWARD appreciation-level))
          }))
        
        (ok new-appreciation-count)
      )
    )
  )
)

(define-public (score-artwork-quality (artwork-id uint) (score uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-artwork-id artwork-id) ERR_INVALID_ARTWORK_ID)
    (asserts! (and (>= score u1) (<= score MAX_APPRECIATION_SCORE)) ERR_INVALID_SCORE)
    (asserts! (is-some (map-get? creators {creator-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? artworks {artwork-id: artwork-id})) ERR_NOT_FOUND)
    
    (let ((artwork (unwrap! (map-get? artworks {artwork-id: artwork-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get creator artwork))) ERR_SELF_APPRECIATION)
      (asserts! (is-none (map-get? quality-scores {artwork-id: artwork-id, scorer: caller})) ERR_ALREADY_APPRECIATED)
      
      (map-set quality-scores 
        {artwork-id: artwork-id, scorer: caller} 
        {score: score})
      
      (let ((current-total-score (* (get quality-score artwork) (get scorer-count artwork)))
            (new-scorer-count (+ (get scorer-count artwork) u1))
            (new-total-score (+ current-total-score score))
            (new-average-score (/ new-total-score new-scorer-count))
            (artwork-creator (unwrap! (map-get? creators {creator-id: (get creator artwork)}) ERR_NOT_FOUND))
            (scorer-creator (unwrap! (map-get? creators {creator-id: caller}) ERR_NOT_FOUND)))
        
        (map-set artworks 
          {artwork-id: artwork-id} 
          (merge artwork {
            quality-score: new-average-score,
            scorer-count: new-scorer-count
          }))
        
        (map-set creators 
          {creator-id: caller} 
          (merge scorer-creator {
            tokens: (+ (get tokens scorer-creator) u4),
            followers: (+ (get followers scorer-creator) u1)
          }))
        
        (if (>= score u4)
          (map-set creators 
            {creator-id: (get creator artwork)} 
            (merge artwork-creator {
              tokens: (+ (get tokens artwork-creator) VIRAL_BONUS),
              followers: (+ (get followers artwork-creator) u10)
            }))
          true)
        
        (ok new-average-score)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-creator-profile (creator-id principal))
  (map-get? creators {creator-id: creator-id})
)

(define-read-only (get-artwork (artwork-id uint))
  (map-get? artworks {artwork-id: artwork-id})
)

(define-read-only (get-artwork-curation (artwork-id uint) (curator principal))
  (map-get? artwork-curations {artwork-id: artwork-id, curator: curator})
)

(define-read-only (get-appreciation (artwork-id uint) (appreciator principal))
  (map-get? appreciation-tokens {artwork-id: artwork-id, appreciator: appreciator})
)

(define-read-only (get-quality-score (artwork-id uint) (scorer principal))
  (map-get? quality-scores {artwork-id: artwork-id, scorer: scorer})
)

(define-read-only (get-total-artworks)
  (- (var-get next-artwork-id) u1)
)