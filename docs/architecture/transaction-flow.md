---
sidebar_position: 4
title: Transaction Flow
---

# Transaction Flow

zkCoins supports three operations: **create account** (mint), **send**, and **receive**. All operations interact with the Rust backend, which manages account state and publishes commitments to Bitcoin.

:::info Current implementation vs. normative spec
The flows on this page document the **current implementation** (per-transaction commitment inscriptions, an in-process publisher, SMT + MMR state). The normative target is the batched publisher flow of the [Specification §3](/specification#3--on-chain-layer): off-chain `SpendRecord`s aggregated into `BatchBundle`s, attested by an `AggregateBatchProof`, and anchored by one constant 231-byte `BatchInscription` per batch. The *Publisher selection and fees* section below describes that target design.
:::

## Create Account (Mint)

Account creation generates a new HD wallet and mints initial testnet coins.

```
Browser (WASM)                    Backend                     Bitcoin
 │                                  │                           │
 │  Generate BIP32 master key       │                           │
 │  Derive address from pubkey[0]   │                           │
 │  Store encrypted in IndexedDB    │                           │
 │                                  │                           │
 │  POST /api/mint {address}        │                           │
 │─────────────────────────────────>│                           │
 │                                  │                           │
 │                                  │  Create CoinProof         │
 │                                  │  Generate Plonky2 proof   │
 │                                  │  Publish commitment       │
 │                                  │──────────────────────────>│
 │                                  │                           │
 │                                  │  Taproot Inscription      │
 │                                  │  (commitment)             │
 │                                  │                           │
 │          {proof_id}              │                           │
 │<─────────────────────────────────│                           │
```

**Steps:**

1. User chooses auth method: **Passkey** (biometric) or **Seed Phrase** (12 words)
2. BIP-39 mnemonic is generated (or derived from Passkey PRF via HKDF)
3. BIP32 master key (Xpriv) is derived from the mnemonic seed
4. Address is derived deterministically: `SHA-256(PublicKey[0])`
5. Account is encrypted (AES-256-GCM) and stored in IndexedDB
6. Backend mints initial coins from its minting account via the Plonky2 prover
7. Commitment is published as a Bitcoin Taproot Inscription

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
 │                                  │  4. Build circuit inputs  │
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
5. The Plonky2 circuit generates a recursive Zero-Knowledge proof
6. Output coins are created: one for the recipient, one for change (if needed)
7. Commitment is published as a Bitcoin Taproot Inscription
8. Recipient's coin proof is stored for later retrieval

## Key Rotation

Each transaction rotates the account's public key:

- The sender provides `sender_public_key` (current) and `sender_next_public_key` (next)
- Both are derived from the BIP32 master key at sequential indices
- The Plonky2 circuit commits to the key rotation
- This ensures forward secrecy — compromising a past key doesn't help an attacker

## Publisher selection and fees (spec design)

In the normative batched design ([spec §3.8](/specification#38-fees-and-economics)), anchoring is performed by a permissionless **publisher** the wallet chooses:

1. **Selection.** The wallet picks a publisher from its signed Nostr **publisher profile** — `{ publisher_pubkey, fee_address, fee_asset_id, fee, relays }`, signed by the publisher's node identity, so the advertised key is bound to the operator.
2. **Fee coin.** The wallet adds one ordinary output coin paying the publisher's `fee_address` to the very transition being anchored — **under the same `ocr`** (output-coins root) as the payment itself. On-chain it is indistinguishable from any other output.
3. **Atomicity.** Because the fee coin and the payment are outputs of the transition's single `SpendRecord`/`ocr`, the publisher cannot collect the fee without anchoring the payment: the fee coin of an un-anchored transition never reaches `completed`.
4. **Censorship handling.** If the chosen publisher fails to anchor within its retry window, the wallet re-builds the transition against a different publisher (with a fresh fee coin). Nullifier idempotence guarantees at most one of the competing transitions is ever admitted, so the spender pays exactly one fee — to whichever publisher actually anchors.

## Blockchain Scanner

The backend runs an event-driven scanner that:

1. Subscribes to an Esplora WebSocket and processes new blocks as they are announced — event-driven, not polling
2. Filters transactions by the marker prefix (`4242`)
3. Extracts Taproot Inscription data from witness
4. Deserializes and verifies Schnorr signatures on commitments
5. Updates the Sparse Merkle Tree and Merkle Mountain Range
