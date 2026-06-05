---
sidebar_position: 3
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
3. Only a **compact commitment** is written to the blockchain (today the full commitment — signing public key, Schnorr signature, and message, ~177 bytes; the paper targets a 64-byte half-aggregated nullifier — see [Nullifier Design](architecture/nullifier-design))
4. The receiver verifies the proof **client-side**
5. The blockchain provides the **immutable ordering of commitments** that prevents double-spending (today enforced in-circuit via a non-inclusion proof; a verifier-queryable on-chain nullifier set is a roadmap item)

## Key innovations

### 1. Proof-Carrying Data (PCD)

Each coin carries a proof of its entire history, compressed into a constant-size Zero-Knowledge proof. Unlike RGB or Taproot Assets, where proof size grows with transaction history, Shielded CSV proofs are always the same size.

### 2. 64-byte nullifiers (paper design target)

In the **paper's** final design, a combination of the account model, Sign-to-Contract, and Schnorr Half-Aggregation compresses the on-chain footprint from a full Bitcoin transaction to exactly 64 bytes per transaction. The **current zkCoins implementation** does not yet half-aggregate: it inscribes the full commitment (~177 bytes) in the Taproot reveal. See [Nullifier Design](architecture/nullifier-design) for the paper-vs-implementation breakdown.

### 3. Privacy by construction

The ZK proofs hide all transaction details — amounts, sender, receiver, transaction graph. The only information revealed is that a transaction occurred and an approximate creation time for the coin.

## Performance

The table below states the **Shielded CSV paper's design targets** (after half-aggregation), contrasted with a regular Bitcoin transaction. The **current implementation** inscribes the full commitment (~177 bytes) rather than the 64-byte half-aggregated nullifier, so its on-chain footprint and throughput are correspondingly larger; treat the throughput figures as the paper's qualitative goal, not measured implementation numbers.

| Metric | Bitcoin (regular) | Shielded CSV (paper target) |
|---|---|---|
| On-chain data per TX | full transaction | compact commitment (~64 bytes half-aggregated) |
| Throughput | baseline | substantially higher {/* TODO: verify against current implementation */} |
| Privacy | None | Full |
| Verification per TX | Full script execution | one Schnorr signature per nullifier |
| Proof size | N/A | Constant |

## What Shielded CSV is NOT

- **Not a sidechain** — it uses Bitcoin L1 directly
- **Not a rollup** — no sequencer, no data availability layer
- **Not a mixer** — privacy is structural, not obfuscation
- **Not a token** — no new asset, just a different way to transact BTC
- **Not a soft fork** — works on Bitcoin as it exists today

## Cryptographic primitives

| Primitive | Usage |
|---|---|
| Schnorr signatures | Nullifier authorization (one verification per nullifier) |
| Sign-to-Contract | Embed transaction hash into Schnorr signature |
| Schnorr Half-Aggregation | Compress multiple nullifier signatures |
| Proof-Carrying Data | Recursive ZK proofs of transaction validity |
| Recursive zkSNARKs / STARKs | PCD instantiation |
| Sorted Merkle Trees | Nullifier accumulator, non-inclusion proofs |

## Open research areas

The paper identifies several areas for future work:

- **Light clients** — how to receive transactions without full blockchain access
- **Payment channels** — Shielded CSV coins in Lightning-like channels
- **Atomic swaps** — trustless exchange between Shielded CSV and regular Bitcoin
- **Shared accounts** — t-of-n threshold schemes
- **Post-quantum security** — migration path to quantum-resistant cryptography
- **Data availability** — addressed in [ePrint 2025/569](https://eprint.iacr.org/2025/569)
