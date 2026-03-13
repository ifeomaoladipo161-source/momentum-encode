;; Momentum Encode - Dynamic NFT Evolution Gaming Ecosystem
;; Version: 1.0.0

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-token-not-found (err u103))
(define-constant err-invalid-momentum (err u104))
(define-constant err-insufficient-momentum (err u105))
(define-constant err-game-not-found (err u106))
(define-constant err-already-registered (err u107))

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var total-momentum-generated uint u0)
(define-data-var platform-active bool true)

;; NFT Definition
(define-non-fungible-token momentum-nft uint)

;; Data Maps

;; Core NFT metadata
(define-map nft-metadata
    uint
    {
        owner: principal,
        base-template: (string-ascii 50),
        total-momentum: uint,
        skill-level: uint,
        evolution-stage: uint,
        created-at: uint
    }
)

;; Encoded momentum data - compressed player behavior patterns
(define-map momentum-encoding
    uint
    {
        combat-skill: uint,
        puzzle-mastery: uint,
        building-expertise: uint,
        collaboration-score: uint,
        achievement-count: uint,
        encoded-traits: (list 10 uint)
    }
)

;; Mini-game registry
(define-map registered-games
    (string-ascii 30)
    {
        game-id: uint,
        active: bool,
        momentum-multiplier: uint,
        total-players: uint
    }
)

;; Player profiles
(define-map player-profiles
    principal
    {
        total-nfts: uint,
        lifetime-momentum: uint,
        governance-weight: uint,
        skill-achievements: (list 20 uint),
        last-activity: uint
    }
)

;; Cross-game compatibility tracking
(define-map nft-game-unlocks
    {token-id: uint, game-id: uint}
    {
        unlocked: bool,
        bonus-applied: uint,
        unlock-timestamp: uint
    }
)

;; Creator partnerships
(define-map creator-templates
    principal
    {
        templates-created: uint,
        total-nfts-minted: uint,
        revenue-share: uint,
        active: bool
    }
)

;; Governance proposals
(define-map governance-votes
    {proposal-id: uint, voter: principal}
    {
        vote-weight: uint,
        vote-direction: bool,
        timestamp: uint
    }
)

;; Read-only functions

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? momentum-nft token-id))
)

(define-read-only (get-nft-metadata (token-id uint))
    (ok (map-get? nft-metadata token-id))
)

(define-read-only (get-momentum-encoding (token-id uint))
    (ok (map-get? momentum-encoding token-id))
)

(define-read-only (get-player-profile (player principal))
    (ok (map-get? player-profiles player))
)

(define-read-only (get-game-info (game-name (string-ascii 30)))
    (ok (map-get? registered-games game-name))
)

(define-read-only (get-nft-game-unlock (token-id uint) (game-id uint))
    (ok (map-get? nft-game-unlocks {token-id: token-id, game-id: game-id}))
)

(define-read-only (get-total-momentum)
    (ok (var-get total-momentum-generated))
)

(define-read-only (calculate-governance-weight (player principal))
    (let
        (
            (profile (unwrap! (map-get? player-profiles player) (ok u0)))
            (momentum-weight (/ (get lifetime-momentum profile) u100))
            (achievement-weight (* (len (get skill-achievements profile)) u10))
        )
        (ok (+ momentum-weight achievement-weight))
    )
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some "ipfs://momentum-encode-metadata"))
)

;; Public functions

;; Mint new momentum NFT
(define-public (mint-momentum-nft (template (string-ascii 50)))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
            (current-profile (default-to 
                {
                    total-nfts: u0,
                    lifetime-momentum: u0,
                    governance-weight: u0,
                    skill-achievements: (list),
                    last-activity: block-height
                }
                (map-get? player-profiles tx-sender)
            ))
        )
        (try! (nft-mint? momentum-nft token-id tx-sender))
        
        (map-set nft-metadata token-id
            {
                owner: tx-sender,
                base-template: template,
                total-momentum: u0,
                skill-level: u1,
                evolution-stage: u1,
                created-at: block-height
            }
        )
        
        (map-set momentum-encoding token-id
            {
                combat-skill: u0,
                puzzle-mastery: u0,
                building-expertise: u0,
                collaboration-score: u0,
                achievement-count: u0,
                encoded-traits: (list)
            }
        )
        
        (map-set player-profiles tx-sender
            (merge current-profile {
                total-nfts: (+ (get total-nfts current-profile) u1),
                last-activity: block-height
            })
        )
        
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

;; Transfer NFT
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (try! (nft-transfer? momentum-nft token-id sender recipient))
        
        ;; Update metadata owner
        (let
            (
                (metadata (unwrap! (map-get? nft-metadata token-id) err-token-not-found))
            )
            (map-set nft-metadata token-id
                (merge metadata {owner: recipient})
            )
            (ok true)
        )
    )
)

;; Encode momentum from gameplay
(define-public (encode-gameplay-momentum 
    (token-id uint)
    (combat-points uint)
    (puzzle-points uint)
    (building-points uint)
    (collaboration-points uint)
)
    (let
        (
            (metadata (unwrap! (map-get? nft-metadata token-id) err-token-not-found))
            (encoding (unwrap! (map-get? momentum-encoding token-id) err-token-not-found))
            (total-new-momentum (+ (+ combat-points puzzle-points) (+ building-points collaboration-points)))
            (player-profile (default-to
                {
                    total-nfts: u0,
                    lifetime-momentum: u0,
                    governance-weight: u0,
                    skill-achievements: (list),
                    last-activity: block-height
                }
                (map-get? player-profiles tx-sender)
            ))
        )
        (asserts! (is-eq (get owner metadata) tx-sender) err-not-token-owner)
        
        (map-set momentum-encoding token-id
            (merge encoding {
                combat-skill: (+ (get combat-skill encoding) combat-points),
                puzzle-mastery: (+ (get puzzle-mastery encoding) puzzle-points),
                building-expertise: (+ (get building-expertise encoding) building-points),
                collaboration-score: (+ (get collaboration-score encoding) collaboration-points)
            })
        )
        
        (map-set nft-metadata token-id
            (merge metadata {
                total-momentum: (+ (get total-momentum metadata) total-new-momentum),
                skill-level: (calculate-skill-level (+ (get total-momentum metadata) total-new-momentum))
            })
        )
        
        (map-set player-profiles tx-sender
            (merge player-profile {
                lifetime-momentum: (+ (get lifetime-momentum player-profile) total-new-momentum),
                last-activity: block-height
            })
        )
        
        (var-set total-momentum-generated (+ (var-get total-momentum-generated) total-new-momentum))
        (ok total-new-momentum)
    )
)

;; Register a new mini-game
(define-public (register-game 
    (game-name (string-ascii 30))
    (game-id uint)
    (momentum-multiplier uint)
)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? registered-games game-name)) err-already-registered)
        
        (map-set registered-games game-name
            {
                game-id: game-id,
                active: true,
                momentum-multiplier: momentum-multiplier,
                total-players: u0
            }
        )
        (ok true)
    )
)

;; Unlock cross-game content
(define-public (unlock-game-content (token-id uint) (game-id uint))
    (let
        (
            (metadata (unwrap! (map-get? nft-metadata token-id) err-token-not-found))
            (encoding (unwrap! (map-get? momentum-encoding token-id) err-token-not-found))
            (momentum-threshold (* game-id u100))
        )
        (asserts! (is-eq (get owner metadata) tx-sender) err-not-token-owner)
        (asserts! (>= (get total-momentum metadata) momentum-threshold) err-insufficient-momentum)
        
        (map-set nft-game-unlocks {token-id: token-id, game-id: game-id}
            {
                unlocked: true,
                bonus-applied: (/ (get total-momentum metadata) u10),
                unlock-timestamp: block-height
            }
        )
        (ok true)
    )
)

;; Register as creator
(define-public (register-as-creator)
    (begin
        (asserts! (is-none (map-get? creator-templates tx-sender)) err-already-registered)
        
        (map-set creator-templates tx-sender
            {
                templates-created: u0,
                total-nfts-minted: u0,
                revenue-share: u15,
                active: true
            }
        )
        (ok true)
    )
)

;; Add skill achievement
(define-public (add-achievement (token-id uint) (achievement-id uint))
    (let
        (
            (metadata (unwrap! (map-get? nft-metadata token-id) err-token-not-found))
            (encoding (unwrap! (map-get? momentum-encoding token-id) err-token-not-found))
        )
        (asserts! (is-eq (get owner metadata) tx-sender) err-not-token-owner)
        
        (map-set momentum-encoding token-id
            (merge encoding {
                achievement-count: (+ (get achievement-count encoding) u1)
            })
        )
        (ok true)
    )
)

;; Cast governance vote
(define-public (cast-vote (proposal-id uint) (vote-direction bool))
    (let
        (
            (vote-weight (unwrap! (calculate-governance-weight tx-sender) (ok u0)))
        )
        (map-set governance-votes {proposal-id: proposal-id, voter: tx-sender}
            {
                vote-weight: vote-weight,
                vote-direction: vote-direction,
                timestamp: block-height
            }
        )
        (ok vote-weight)
    )
)

;; Private functions

(define-private (calculate-skill-level (momentum uint))
    (if (>= momentum u10000)
        u10
        (if (>= momentum u5000)
            u9
            (if (>= momentum u2500)
                u8
                (if (>= momentum u1000)
                    u7
                    (if (>= momentum u500)
                        u6
                        (if (>= momentum u250)
                            u5
                            (if (>= momentum u100)
                                u4
                                (if (>= momentum u50)
                                    u3
                                    (if (>= momentum u10)
                                        u2
                                        u1
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

;; Administrative functions

(define-public (toggle-platform-status)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-active (not (var-get platform-active)))
        (ok (var-get platform-active))
    )
)

(define-public (update-game-status (game-name (string-ascii 30)) (active bool))
    (let
        (
            (game-info (unwrap! (map-get? registered-games game-name) err-game-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set registered-games game-name
            (merge game-info {active: active})
        )
        (ok true)
    )
)