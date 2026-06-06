---
sidebar_position: 3
title: Nullifier Design
---

# Nullifier Design

In the Shielded CSV design, the nullifier is the compact spent-marker that anchors a spend on Bitcoin. Understanding its design is key to understanding how Shielded CSV achieves both privacy and double-spend protection.

:::note Paper design vs. current implementation
The **64-byte half-aggregated nullifier** and the **on-chain nullifier accumulator** described on this page are the Shielded CSV **paper's design target**. The **current zkCoins implementation** instead inscribes the *full commitment* (signing public key + Schnorr signature + message, on the order of ~177 bytes) in the Taproot reveal, and enforces double-spend protection **inside the proof circuit** (proof of non-inclusion in the per-account coin history) — not via a verifier-queryable on-chain nullifier set. Schnorr half-aggregation and a global, queryable accumulator are roadmap items (strand **S2**). See [Information Flow](information-flow) → *Status & caveats*.
:::

## What is a nullifier?

In the paper's final (step 5) design, a nullifier is a **64-byte cryptographic commitment** that marks a coin as spent. It is published on the Bitcoin blockchain as a Taproot Inscription, and full nodes verify one Schnorr signature per nullifier — nothing else. (As noted above, today's implementation inscribes the full commitment rather than the compressed nullifier.)

## Evolution (from the paper)

The Shielded CSV paper describes a 5-step optimization that compresses nullifiers from hundreds of bytes to exactly 64:

| Step | Size | Mechanism |
|---|---|---|
| 1 (naive) | Per coin | `Nullifier = (CoinID, TxHash)` — no signature protection |
| 2 | Per TX | `Nullifier = (PubKey, TxHash)` — public key replaces CoinID |
| 3 | 96 bytes | `+ Schnorr signature` — protects against unauthorized updates |
| 4 | 128 bytes | `Aggregated signatures` — multiple nullifiers per TX |
| **5 (final)** | **64 bytes** | **Accounts + Sign-to-Contract + Schnorr Half-Aggregation** |

## Sign-to-Contract

The transaction hash is embedded into the Schnorr signature itself via Sign-to-Contract:

```
R' = kG                          (random nonce point)
R  = R' + H(R', txHash) * G     (commit txHash into nonce)
s  = k + H(R', txHash) + e * sk (standard Schnorr with committed nonce)
```

After half-aggregation, the nonce `R_i` remains the transaction commitment for the i-th nullifier. No additional data is needed on-chain.

## Half-Aggregation

Multiple Schnorr signatures are non-interactively aggregated into a single signature approximately half the size. Publishers collect nullifiers from multiple transactions and post them in a single Bitcoin Taproot Inscription.

## Publisher role

Publishers are permissionless — anyone can run one:

1. Collect nullifiers from users
2. Aggregate signatures via half-aggregation
3. Post the batch as a single Bitcoin Taproot Inscription
4. Charge a fee to cover the inscription cost

The current implementation uses a single publisher built into the backend server. The publisher creates Taproot Inscriptions with a commit/reveal pattern and a marker prefix (`4242`) for identification.

## Nullifier Accumulator

Users maintain a local **Nullifier Accumulator** — a sorted Merkle tree of all published nullifiers:

- On each new block: scan for nullifiers, insert into accumulator
- Old subtrees can be pruned without losing the ability to prove non-membership
- Reduces wallet storage and limits data exposure on wallet compromise

## Blockchain reorganization

If Bitcoin reorganizes, nullifiers in orphaned blocks must be removed from the accumulator. The protocol handles this through a **Conditional Nullifier Accumulator Value (NAV)** — the accumulator state is tied to a specific chain tip.
