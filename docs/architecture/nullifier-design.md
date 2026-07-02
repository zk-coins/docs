---
sidebar_position: 3
title: Nullifier Design
---

# Nullifier Design

In the Shielded CSV design, the nullifier is the compact spent-marker that anchors a spend on Bitcoin. Understanding its design is key to understanding how Shielded CSV achieves both privacy and double-spend protection.

:::note The normative v1 nullifier design
The **normative zkCoins v1 design** ([spec §3.7](/specification#37-the-nullifier-accumulator)): nullifiers never appear on Bitcoin at all — they travel in the off-chain `BatchBundle`, and the chain carries only the global accumulator's `prev_root → new_root` transition inside a constant 231-byte `BatchInscription` per batch, attested by the publisher's `AggregateBatchProof`.
:::

## What is a nullifier?

In the zkCoins v1 spec, the nullifier is `nf = Hc("Nullifier", nk ‖ coin.identifier)` and is carried only in the off-chain `BatchBundle` — never on Bitcoin ([spec §3.7](/specification#37-the-nullifier-accumulator)).

## On-chain footprint

The **zkCoins v1 spec** keeps signatures off-chain through proof aggregation: the batch inscribes only the accumulator's root transition (231 bytes, constant in batch size), and the per-member signatures are verified inside the publisher's `AggregateBatchProof` ([spec §3.5](/specification#35-inscription-format)).

## Publisher role

Publishers are permissionless — anyone can run one. In the normative v1 design ([spec §3.4](/specification#34-the-publisher), [§3.8](/specification#38-fees-and-economics)) a publisher:

1. Collects `SpendRecord`s (each carrying its nullifiers) from spenders
2. Builds the `BatchBundle` and proves the batch with one recursive `AggregateBatchProof`
3. Anchors the batch with a single constant 231-byte `BatchInscription` (Taproot commit/reveal)
4. Is compensated by the **fee-coin mechanism**: each spender adds one fee coin under the same `ocr` as its payment, so the publisher cannot collect without anchoring

## Nullifier accumulator (normative v1 design)

Double-spend protection in zkCoins v1 is anchored by exactly one **global** structure ([spec §1.6](/specification#16-trees-one-global-structure-one-per-account-structure), [§3.7](/specification#37-the-nullifier-accumulator)):

- a **256-bit-depth sparse Merkle tree (SMT)** over every admitted nullifier `nf`, supporting both membership and non-membership proofs;
- advanced exactly by inscribed transitions: every `BatchInscription` commits `prev_root → new_root`, and the publisher's `AggregateBatchProof` attests in zero knowledge that `new_root = SMT.insert_many(prev_root, batch_nullifiers)`;
- trustlessly verifiable along two paths: maintain the accumulator yourself by verifying every batch bundle (**Path A**), or follow only the inscribed roots and check compact (~512-byte) SMT paths served by any Path-A node (**Path B**).

There is **no on-chain nullifier list** — only the accumulator roots reach Bitcoin; the nullifiers themselves travel in the off-chain, replicated `BatchBundle`s.

## Blockchain reorganization

If Bitcoin reorganizes, batches admitted only in orphaned blocks are reverted and the accumulator is replayed deterministically in the new canonical order. Every membership/non-membership answer is therefore evaluated relative to a stated chain tip — the spec's anchored value `NAV(tip) = (accumulator, tip_block_hash, tip_height)` ([spec §3.7](/specification#37-the-nullifier-accumulator)).
