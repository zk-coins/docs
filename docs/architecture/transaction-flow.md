---
sidebar_position: 4
title: Transaction Flow
---

# Transaction Flow

zkCoins supports three operations: **create account** (mint), **send**, and **receive**. All operations interact with the Rust backend, which manages account state and publishes nullifiers to Bitcoin.

## Create Account (Mint)

Account creation generates a new HD wallet and mints initial testnet coins.

```
Browser (WASM)                    Backend                     Bitcoin
 │                                  │                           │
 │  Generate BIP32 master key       │                           │
 │  Derive address from pubkey[0]   │                           │
 │  Store account in localStorage   │                           │
 │                                  │                           │
 │  POST /api/mint {address}        │                           │
 │─────────────────────────────────>│                           │
 │                                  │                           │
 │                                  │  Create CoinProof         │
 │                                  │  Generate SP1 proof       │
 │                                  │  Publish commitment       │
 │                                  │──────────────────────────>│
 │                                  │                           │
 │                                  │  Taproot Inscription      │
 │                                  │  (64-byte nullifier)      │
 │                                  │                           │
 │          {proof_id}              │                           │
 │<─────────────────────────────────│                           │
```

**Steps:**

1. WASM module generates a random 256-bit seed
2. BIP32 master key (Xpriv) is derived
3. Address is derived from the first public key, blinded with random bytes for privacy
4. Account is stored in localStorage: `{address, numPubkeys, xpriv}`
5. Backend mints initial coins from its minting account
6. Commitment is published as a Bitcoin Taproot Inscription

## Send Coins

Sending transfers coins from one account to another with a Zero-Knowledge proof.

```
Browser                           Backend                     Bitcoin
 │                                  │                           │
 │  POST /api/send                  │                           │
 │  {sender, recipient, amount,     │                           │
 │   sender_public_key,             │                           │
 │   sender_next_public_key}        │                           │
 │─────────────────────────────────>│                           │
 │                                  │                           │
 │                                  │  1. Verify balance        │
 │                                  │  2. Collect received coins│
 │                                  │  3. Get Merkle proofs     │
 │                                  │  4. Build SP1 inputs      │
 │                                  │  5. Generate ZK proof     │
 │                                  │  6. Create output coins   │
 │                                  │  7. Publish commitment    │
 │                                  │──────────────────────────>│
 │                                  │                           │
 │          {proof_id}              │                           │
 │<─────────────────────────────────│                           │
 │                                  │                           │
 │  Increment numPubkeys            │                           │
 │  Update localStorage             │                           │
```

**Steps:**

1. Browser sends transfer request with sender/recipient addresses and amount
2. Backend verifies the sender has sufficient balance
3. Backend collects unspent coins from the sender's queue
4. Merkle proofs are fetched for all input coins (Sparse Merkle Tree + MMR)
5. SP1 circuit generates a recursive Zero-Knowledge proof
6. Output coins are created: one for the recipient, one for change (if needed)
7. Commitment is published as a Bitcoin Taproot Inscription
8. Recipient's coin proof is stored for later retrieval

## Key Rotation

Each transaction rotates the account's public key:

- The sender provides `sender_public_key` (current) and `sender_next_public_key` (next)
- Both are derived from the BIP32 master key at sequential indices
- The SP1 circuit commits to the key rotation
- This ensures forward secrecy — compromising a past key doesn't help an attacker

## Blockchain Scanner

The backend runs a continuous scanner that:

1. Polls Bitcoin every 30 seconds for new blocks
2. Filters transactions by the marker prefix (`4242`)
3. Extracts Taproot Inscription data from witness
4. Deserializes and verifies Schnorr signatures on commitments
5. Updates the Sparse Merkle Tree and Merkle Mountain Range
