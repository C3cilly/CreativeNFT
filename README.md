# CreativeNFT

A blockchain-based digital creator portfolio and artwork verification platform. Enables creators to publish, get artwork curated, and earn tokens through community appreciation and quality scoring.

## Features

- Creator profile and portfolio management
- Artwork publishing with metadata storage
- Community curation system
- Quality scoring mechanism
- Appreciation token system
- Follower and featured artwork tracking

## Getting Started

1. Register as a creator with display name and genre
2. Publish artworks to your portfolio
3. Get artworks curated by the community
4. Receive appreciation and quality scores
5. Earn tokens and grow your follower base

## Smart Contract API

### Creator Functions
- `register-creator` - Create artist profile
- `update-creator` - Update profile information
- `publish-artwork` - Add artwork to portfolio
- `curate-artwork` - Validate community member's artwork
- `appreciate-artwork` - Show appreciation with tokens
- `score-artwork-quality` - Rate artwork quality

### Query Functions
- `get-creator-profile` - View creator details
- `get-artwork` - Get artwork information
- `get-total-artworks` - Count total artworks

## Token Economics

- Artwork curation: 7 tokens
- Quality scoring: 4 tokens
- High quality score (4+): 75 bonus tokens
- Featured artwork (2+ curations): 30 tokens
- Each appreciation multiplies rewards

## Verification

Run `clarinet check` to ensure contract compiles successfully.