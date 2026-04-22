---
sidebar_position: 1
title: Overview
---

# Architecture Overview

zkCoins is a web wallet built on the Shielded CSV protocol. The architecture separates cryptographic operations (browser-side WASM), account management (Rust backend), and commitment anchoring (Bitcoin blockchain).

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
│  - Account Server    │     │  (64-byte nullifiers) │
│  - SP1 Prover        │     └──────────────────────┘
│  - Chain Scanner     │
│  - Publisher         │     ┌──────────────────────┐
│                      │────▶│  SP1 zkVM            │
│  State:              │     │  (Succinct)          │
│  - Sparse Merkle Tree│     │                      │
│  - Merkle Mt. Range  │     │  Recursive ZK Proofs │
└──────────────────────┘     └──────────────────────┘
```

## Design principles

1. **Privacy first** — every architectural decision prioritizes hiding transaction details from observers
2. **No consensus changes** — the protocol works on Bitcoin today, no soft fork needed
3. **Client-side validation** — receivers validate transactions, not the network
4. **Minimal on-chain footprint** — 64 bytes per transaction, nothing more
5. **Self-custodial** — keys are generated and controlled by the user, never sent to a server

## Component overview

| Component | Technology | Purpose |
|---|---|---|
| [Wallet](/wallet) | Next.js 14, Tailwind, Zustand | User interface for sending and receiving |
| [WASM Crypto](/architecture/key-management) | Rust → WebAssembly | BIP32 key derivation, Schnorr signatures |
| [Backend](/infrastructure/backend) | Rust, Axum | Account management, proof generation, chain scanning |
| [SP1 Circuit](/architecture/proof-system) | SP1 zkVM (Succinct) | Recursive Zero-Knowledge proof circuit |
| [Publisher](/architecture/transaction-flow) | Rust | Bitcoin Taproot Inscription broadcasting |

## What's different from traditional CSV

Shielded CSV improves on existing Client-Side Validation protocols (RGB, Taproot Assets):

| Feature | RGB / Taproot Assets | Shielded CSV |
|---|---|---|
| **Privacy** | Transaction history visible to sender & receiver | Full privacy via ZK proofs |
| **Proof size** | Grows with transaction history | Constant (independent of history) |
| **On-chain data** | Full Bitcoin transaction (~560 WU) | 64-byte nullifier |
| **Verification** | Receiver validates full history | Receiver verifies one ZK proof |
| **Double-spend** | Full Bitcoin transaction | Single Schnorr signature |
