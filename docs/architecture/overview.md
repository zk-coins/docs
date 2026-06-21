---
sidebar_position: 1
title: Overview
---

# Architecture Overview

## Design principles

1. **Privacy first** — every architectural decision prioritizes hiding transaction details from observers
2. **No consensus changes** — the protocol works on Bitcoin today, no soft fork needed
3. **Client-side validation** — receivers validate transactions, not the network
4. **Minimal on-chain footprint** — nothing on Bitcoin but the constant-size anchor (spec design: one 231-byte `BatchInscription` per publisher batch)
5. **Self-custodial** — keys are generated and controlled by the user, never sent to a server

## Component overview

The normative component model — the node (validator · prover · transport · store), the thin wallet, the stateless explorer, and the optional API layer — is defined in [spec §6.1](/specification#61-components-and-responsibilities). The cryptographic core of the proving stack:

| Component | Technology | Purpose |
|---|---|---|
| [Proof System](/architecture/proof-system) | Plonky2 + Poseidon-Goldilocks | Recursive Zero-Knowledge proof circuit (cyclic recursion) |

## What's different from traditional CSV

Shielded CSV improves on existing Client-Side Validation protocols (RGB, Taproot Assets):

| Feature | RGB / Taproot Assets | Shielded CSV |
|---|---|---|
| **Privacy** | Transaction history visible to sender & receiver | Full privacy via ZK proofs |
| **Proof size** | Grows with transaction history | Constant (independent of history) |
| **On-chain data** | Full Bitcoin transaction (~560 WU) | Constant 231-byte `BatchInscription` per batch, amortised per spend ([spec §3.8](/specification#38-fees-and-economics)) |
| **Verification** | Receiver validates full history | Receiver verifies one ZK proof |
| **Double-spend** | Full Bitcoin transaction | Publisher signature + one `AggregateBatchProof` per batch against the nullifier accumulator ([spec §3.7](/specification#37-the-nullifier-accumulator)) |
