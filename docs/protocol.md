---
title: Protocol
---

# Shielded CSV Protocol

zkCoins implements the **Shielded CSV** protocol — "Private and Efficient Client-Side Validation." This page summarizes the protocol's key innovations. For the full specification, see the [ePrint paper](https://eprint.iacr.org/2025/068).

## Origin

| | |
|---|---|
| **Paper** | [Shielded CSV: Private and Efficient Client-Side Validation](https://eprint.iacr.org/2025/068) |
| **Authors** | Jonas Nick (Blockstream), Liam Eagen (Alpen Labs), Robin Linus (ZeroSync) |
| **Published** | January 2025 (ePrint), September 2024 (whitepaper) |
| **Predecessor** | [zkCoins](https://gist.github.com/RobinLinus/d036511015caea5a28514259a1bab119) by Robin Linus (2023) |
| **Builds on** | Peter Todd's Client-Side Validation (2013), Single-Use Seals (2016), RGB, Taproot Assets |

## The core idea

> "Use the chain for what the chain is good for, which is an immutable ordering of commitments to prevent double-spending." — Robin Linus

Traditional blockchains require every node to validate every transaction. Shielded CSV inverts this:

1. The **sender** creates a transaction and generates a validity proof
2. The proof is sent **directly to the receiver** (off-chain)
3. Only a **compact commitment** is written to the blockchain. In the paper's final design that is a 64-byte half-aggregated nullifier per transaction; in the **zkCoins v1 specification** a publisher batches many spends and inscribes one constant **231-byte `BatchInscription` per batch**, so the per-spend on-chain cost amortises toward zero ([spec §3.5](/specification#35-inscription-format), [§3.8](/specification#38-fees-and-economics))
4. The receiver verifies the proof **client-side**
5. The blockchain provides the **immutable ordering** that prevents double-spending: the global nullifier accumulator's `prev_root → new_root` transitions are inscribed per batch and attested by the publisher's `AggregateBatchProof` ([spec §3.7](/specification#37-the-nullifier-accumulator)) — the normative v1 design

## Key innovations

### 1. Proof-Carrying Data (PCD)

Each coin carries a proof of its entire history, compressed into a constant-size Zero-Knowledge proof. Unlike RGB or Taproot Assets, where proof size grows with transaction history, Shielded CSV proofs are always the same size.

### 2. Compact nullifiers — 64 bytes in the paper, batched off-chain in zkCoins v1

In the **paper's** final design, a combination of the account model, Sign-to-Contract, and Schnorr Half-Aggregation compresses the on-chain footprint from a full Bitcoin transaction to exactly 64 bytes per transaction. The **zkCoins v1 specification** goes further by aggregation: nullifiers never appear on Bitcoin at all — they travel in the off-chain `BatchBundle`, and the chain carries only the accumulator's root transition inside one constant 231-byte `BatchInscription` per batch, so the per-spend cost falls well below the paper's 64-byte witness figure (64 B of witness data ≈ 16 vB): ~3.2 vBytes per record at 100 records ([spec §3.8](/specification#38-fees-and-economics)). See [spec §3.7](/specification#37-the-nullifier-accumulator) for the full accumulator design.

### 3. Privacy by construction

The ZK proofs hide all transaction details — amounts, sender, receiver, transaction graph. In the paper's per-spend design, the only information revealed is that a transaction occurred and an approximate creation time for the coin; in the zkCoins v1 batched design even the per-batch record count stays off-chain ([spec §3.5](/specification#35-inscription-format)).

## Performance

The table below contrasts a regular Bitcoin transaction with the **Shielded CSV paper's** final design and the **zkCoins v1 specification's** batched design.

| Metric | Bitcoin (regular) | Shielded CSV (paper) | zkCoins v1 (spec) |
|---|---|---|---|
| On-chain data | full transaction (~140 vBytes typical) | 64-byte half-aggregated nullifier per TX | 231-byte `BatchInscription` per **batch** (~318 vBytes commit + reveal pair), constant in batch size |
| Per-spend cost | ~140 vBytes | 64 bytes of witness data (≈ 16 vB) | amortised toward zero — ~3.2 vBytes per record at 100 records ([spec §3.8](/specification#38-fees-and-economics)) |
| Privacy | None | Full | Full |
| Verification | full script execution per TX | one Schnorr signature per nullifier | one `AggregateBatchProof` per batch |
| Proof size | N/A | constant | constant |

## What Shielded CSV is NOT

- **Not a sidechain** — it uses Bitcoin L1 directly
- **Not a rollup** — no sequencer, no data availability layer
- **Not a mixer** — privacy is structural, not obfuscation
- **Not a token** — no native protocol token to bootstrap; value lives in client-side-validated coins (multi-asset by issuance, [spec §6.5](/specification#65-issuance--versioned-schemas-v1-minimal))
- **Not a soft fork** — works on Bitcoin as it exists today

## Cryptographic primitives

| Primitive | Usage |
|---|---|
| Schnorr signatures | Nullifier authorization (one verification per nullifier) |
| Sign-to-Contract | Embed transaction hash into Schnorr signature |
| Schnorr Half-Aggregation | Compress multiple nullifier signatures |
| Proof-Carrying Data | Recursive ZK proofs of transaction validity |
| Recursive zkSNARK (Plonky2, cyclic recursion + FRI) | PCD instantiation |
| Sparse Merkle Trees | Nullifier accumulator, membership + non-membership proofs (zkCoins v1: 256-bit-depth SMT, [spec §1.7.6](/specification#176-nullifier-accumulator-sparse-merkle-tree)) |
