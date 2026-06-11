---
sidebar_position: 1
title: Overview
---

# Architecture Overview

zkCoins is a web wallet built on the Shielded CSV protocol. The architecture separates cryptographic operations (browser-side WASM), account management (Rust backend), and commitment anchoring (Bitcoin blockchain).

:::info Current implementation vs. normative spec
This page describes the **current implementation** ([zk-coins/node](https://github.com/zk-coins/node)): a Plonky2 prover that inscribes a simple per-transaction commitment (~177 bytes) and keeps SMT + MMR state. The **normative target** is the batched publisher design of the [Specification](/specification): off-chain `SpendRecord`s aggregated into `BatchBundle`s, anchored by one constant 231-byte `BatchInscription` per batch, with the MMR removed ([spec §1.6](/specification#16-trees-one-global-structure-one-per-account-structure)). See the [Implementation Mandate](/implementation-mandate).
:::

## System diagram

```
┌──────────────────────────────────────────────────────────┐
│                        Browser                           │
│                                                          │
│  ┌─────────────┐   ┌──────────────┐   ┌──────────────┐  │
│  │  Wallet UI  │──▶│  WASM Crypto │   │  Zustand     │  │
│  │  (Next.js)  │   │  (Rust→WASM) │   │  (State)     │  │
│  │             │   │              │   │              │  │
│  │  - Balance  │   │  - BIP32 HD  │   │  - Account   │  │
│  │  - Send     │   │  - Schnorr   │   │  - TX Log    │  │
│  │  - Receive  │   │  - secp256k1 │   │  - Storage   │  │
│  └──────┬──────┘   └──────────────┘   └──────────────┘  │
│         │                                                │
└─────────┼────────────────────────────────────────────────┘
          │ REST API
          ▼
┌──────────────────────┐     ┌──────────────────────┐
│  Rust/Axum Backend   │────▶│  Bitcoin Blockchain   │
│  (api.zkcoins.app)   │     │                      │
│                      │     │  Taproot Inscriptions │
│  - Account Server    │     │  (commitment data)    │
│  - Plonky2 Prover    │     └──────────────────────┘
│  - Chain Scanner     │
│  - Publisher         │     ┌──────────────────────┐
│                      │────▶│  Plonky2 prover      │
│  State:              │     │  (in-process)        │
│  - Sparse Merkle Tree│     │  Poseidon-Goldilocks │
│  - Merkle Mt. Range  │     │  cyclic recursion    │
└──────────────────────┘     └──────────────────────┘
```

## Design principles

1. **Privacy first** — every architectural decision prioritizes hiding transaction details from observers
2. **No consensus changes** — the protocol works on Bitcoin today, no soft fork needed
3. **Client-side validation** — receivers validate transactions, not the network
4. **Minimal on-chain footprint** — nothing on Bitcoin but the constant-size anchor (spec design: one 231-byte `BatchInscription` per publisher batch)
5. **Self-custodial** — keys are generated and controlled by the user, never sent to a server

## Component overview

| Component | Technology | Purpose |
|---|---|---|
| [Wallet](/wallet) | Next.js 14, Tailwind, Zustand | User interface for sending and receiving |
| [WASM Crypto](/architecture/key-management) | Rust → WebAssembly | BIP32 key derivation, Schnorr signatures |
| [Backend](https://github.com/zk-coins/node) | Rust, Axum | Account management, proof generation, chain scanning |
| [Proof System](/architecture/proof-system) | Plonky2 + Poseidon-Goldilocks | Recursive Zero-Knowledge proof circuit (cyclic recursion) |
| [Publisher](/architecture/transaction-flow) | Rust | Bitcoin Taproot Inscription broadcasting |

## What's different from traditional CSV

Shielded CSV improves on existing Client-Side Validation protocols (RGB, Taproot Assets):

| Feature | RGB / Taproot Assets | Shielded CSV |
|---|---|---|
| **Privacy** | Transaction history visible to sender & receiver | Full privacy via ZK proofs |
| **Proof size** | Grows with transaction history | Constant (independent of history) |
| **On-chain data** | Full Bitcoin transaction (~560 WU) | Constant 231-byte `BatchInscription` per batch, amortised per spend ([spec §3.8](/specification#38-fees-and-economics)); current implementation: ~177 B per transaction |
| **Verification** | Receiver validates full history | Receiver verifies one ZK proof |
| **Double-spend** | Full Bitcoin transaction | Single Schnorr signature |
