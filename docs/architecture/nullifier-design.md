---
sidebar_position: 3
title: Nullifier Design
---

# Nullifier Design

In the Shielded CSV design, the nullifier is the compact spent-marker that anchors a spend on Bitcoin. Understanding its design is key to understanding how Shielded CSV achieves both privacy and double-spend protection.

:::note Three layers: paper, zkCoins v1 spec, current implementation
This page distinguishes three things. (a) The Shielded CSV **paper's** design: per-transaction **64-byte half-aggregated nullifiers** on-chain — historical context for the construction. (b) The **normative zkCoins v1 design** ([spec §3.7](/specification#37-the-nullifier-accumulator)): nullifiers never appear on Bitcoin at all — they travel in the off-chain `BatchBundle`, and the chain carries only the global accumulator's `prev_root → new_root` transition inside a constant 231-byte `BatchInscription` per batch, attested by the publisher's `AggregateBatchProof`. (c) **Current implementation status**: the running node inscribes a full per-transaction commitment (signing public key + Schnorr signature + message, ~177 bytes) and enforces double-spend protection inside the proof circuit (non-inclusion in the per-account coin history); the batched layer and the accumulator are not yet implemented. See [Information Flow](information-flow) → *Status & caveats*.
:::

## What is a nullifier?

In the paper's final (step 5) design, a nullifier is a **64-byte cryptographic commitment** that marks a coin as spent. It is published on the Bitcoin blockchain as a Taproot Inscription, and full nodes verify one Schnorr signature per nullifier — nothing else. In the zkCoins v1 spec, the nullifier is `nf = Hc("Nullifier", nk ‖ coin.identifier)` and is carried only in the off-chain `BatchBundle` — never on Bitcoin ([spec §3.7](/specification#37-the-nullifier-accumulator)). (As noted above, today's implementation inscribes the full per-transaction commitment instead.)

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

Multiple Schnorr signatures are non-interactively aggregated into a single signature approximately half the size. In the **paper's** design, publishers collect nullifiers from multiple transactions and post the half-aggregated set in a single Bitcoin Taproot Inscription. The **zkCoins v1 spec** replaces this with proof aggregation: the batch inscribes only the accumulator's root transition (231 bytes, constant in batch size), and the per-member signatures are verified inside the publisher's `AggregateBatchProof` ([spec §3.5](/specification#35-inscription-format)).

## Publisher role

Publishers are permissionless — anyone can run one. In the normative v1 design ([spec §3.4](/specification#34-the-publisher), [§3.8](/specification#38-fees-and-economics)) a publisher:

1. Collects `SpendRecord`s (each carrying its nullifiers) from spenders
2. Builds the `BatchBundle` and proves the batch with one recursive `AggregateBatchProof`
3. Anchors the batch with a single constant 231-byte `BatchInscription` (Taproot commit/reveal)
4. Is compensated by the **fee-coin mechanism**: each spender adds one fee coin under the same `ocr` as its payment, so the publisher cannot collect without anchoring

Current implementation status: a single non-batching publisher is built into the backend server; it creates per-transaction Taproot Inscriptions with a commit/reveal pattern and a marker prefix (`4242`) for identification.

## Nullifier accumulator (normative v1 design)

Double-spend protection in zkCoins v1 is anchored by exactly one **global** structure ([spec §1.6](/specification#16-trees-one-global-structure-one-per-account-structure), [§3.7](/specification#37-the-nullifier-accumulator)):

- a **256-bit-depth sparse Merkle tree (SMT)** over every admitted nullifier `nf`, supporting both membership and non-membership proofs;
- advanced exactly by inscribed transitions: every `BatchInscription` commits `prev_root → new_root`, and the publisher's `AggregateBatchProof` attests in zero knowledge that `new_root = SMT.insert_many(prev_root, batch_nullifiers)`;
- trustlessly verifiable along two paths: maintain the accumulator yourself by verifying every batch bundle (**Path A**), or follow only the inscribed roots and check compact (~512-byte) SMT paths served by any Path-A node (**Path B**).

There is **no on-chain nullifier list** — only the accumulator roots reach Bitcoin; the nullifiers themselves travel in the off-chain, replicated `BatchBundle`s. (Current implementation status: the accumulator is not yet implemented; the running node enforces double-spend in-circuit in the meantime.)

## Blockchain reorganization

If Bitcoin reorganizes, batches admitted only in orphaned blocks are reverted and the accumulator is replayed deterministically in the new canonical order. Every membership/non-membership answer is therefore evaluated relative to a stated chain tip — the spec's anchored value `NAV(tip) = (accumulator, tip_block_hash, tip_height)` ([spec §3.7](/specification#37-the-nullifier-accumulator)).
