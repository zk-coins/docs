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
3. Only a **compact commitment** is written to the blockchain — a **~64-byte half-aggregated nullifier per transition**, published on Bitcoin (a publisher may half-aggregate many; a wallet's own node may self-publish one), so the on-chain cost is independent of how many coins the transition spends ([spec §3.5](/specification#35-inscription-format), [§3.8](/specification#38-fees-and-economics))
4. The receiver verifies the proof **client-side**
5. The blockchain provides the **immutable ordering** that prevents double-spending: because the nullifiers are on-chain, every node rebuilds the global nullifier accumulator by first-occurrence (first-spend-wins) directly from Bitcoin ([spec §3.7](/specification#37-the-nullifier-accumulator)) — two honest nodes at the same tip can never diverge

## Key innovations

### 1. Proof-Carrying Data (PCD)

Each coin carries a proof of its entire history, compressed into a constant-size Zero-Knowledge proof. Unlike RGB or Taproot Assets, where proof size grows with transaction history, Shielded CSV proofs are always the same size.

### 2. Compact nullifiers — 64 bytes on Bitcoin

A combination of the account model, Sign-to-Contract, and Schnorr Half-Aggregation compresses the on-chain footprint from a full Bitcoin transaction to a **~64-byte half-aggregated nullifier per transition** — the pair `(Pkᵢ, Rᵢ)` of the transition's account-state nullifier public key and a sign-to-contract nonce that commits its off-chain validity proof. zkCoins v1 writes that nullifier **to Bitcoin exactly as the paper does**, so the chain itself guarantees the availability of the data every verifier needs for its double-spend checks — there is no off-chain data-availability assumption for the accumulator (an earlier framing that presented off-chain nullifiers as going "further" than the paper was corrected in PR #94 following the paper authors' feedback; the design now literally *is* the paper model). See [spec §3.5](/specification#35-inscription-format) for the inscription format and [spec §3.7](/specification#37-the-nullifier-accumulator) for the full accumulator design.

The per-coin `CoinProof` bundle — the recipient's custody of a coin's value and history — still travels off-chain, replicated to `k = 3` independent holders ([spec §4.6](/specification#46-data-availability--replication-factor-k)); that is a different object from the on-chain nullifier and its data-availability story is unchanged.

### 3. Privacy by construction

The ZK proofs hide all transaction details — amounts, assets, sender, receiver, transaction graph. Because there is one on-chain nullifier per transition, the per-block **transaction count** becomes public — the chain reveals *how many* transitions occurred, but never who, what, or how much ([spec §3.5](/specification#35-inscription-format)). The only other leak is an approximate creation time disclosed to a coin's receiver.

## Performance

The table below contrasts a regular Bitcoin transaction with **zkCoins v1**, which is the **Shielded CSV paper model**.

| Metric | Bitcoin (regular) | zkCoins v1 = Shielded CSV |
|---|---|---|
| On-chain data | full transaction (~140 vBytes typical) | ~64-byte half-aggregated nullifier per transition, independent of how many coins it spends |
| Per-spend cost | ~140 vBytes | ~64 bytes of witness data (≈ 16 vB) per transition ([spec §3.8](/specification#38-fees-and-economics)) |
| Privacy | None | Full (amounts, assets, parties, graph hidden; per-block transaction count public) |
| Verification | full script execution per TX | one Schnorr verification per nullifier + client-side recursive proof check |
| Proof size | N/A | constant |

## What Shielded CSV is NOT

- **Not a sidechain** — it uses Bitcoin L1 directly
- **Not a rollup** — no sequencer, no coordinator; validity proofs move peer-to-peer between sender and receiver, while the per-transition nullifiers anchor to Bitcoin L1, so the chain carries everything a verifier needs for its double-spend checks
- **Not a mixer** — privacy is structural, not obfuscation
- **Not a token** — no native protocol token to bootstrap; value lives in client-side-validated coins (multi-asset by issuance, [spec §6.5](/specification#65-issuance--token-standards))
- **Not a soft fork** — works on Bitcoin as it exists today

## Cryptographic primitives

| Primitive | Usage |
|---|---|
| Schnorr signatures | Nullifier authorization (one verification per nullifier) |
| Sign-to-Contract | Embed transaction hash into Schnorr signature |
| Schnorr Half-Aggregation | Compress the per-transition nullifier signatures published on-chain into one inscription |
| Proof-Carrying Data | Recursive ZK proofs of transaction validity |
| Recursive zkSNARK (Plonky2, cyclic recursion + FRI) | PCD instantiation |
| Sparse Merkle Trees | Nullifier accumulator, membership + non-membership proofs (zkCoins v1: 256-bit-depth SMT, [spec §1.7.6](/specification#176-nullifier-accumulator-sparse-merkle-tree)) |
