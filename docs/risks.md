---
sidebar_position: 8
title: Risks
---

# Known Risks & Limitations

Transparency about limitations is essential. This page documents every known risk, limitation, and open problem.

## Wallet recovery

**Risk: Losing the wallet means losing the coins.**

Unlike regular Bitcoin wallets, seed phrase recovery alone is insufficient. Shielded CSV coins require the **coin proofs** — Zero-Knowledge proofs of each coin's validity — to be preserved. Without them, the coins exist on-chain (as nullifiers) but cannot be spent.

**Mitigation:** Planned backup/restore feature for wallet state export. Users must back up the entire wallet file, not just the seed phrase.

## Proof generation cost

**Risk: Creating a transaction requires significant computation.**

ZK proof generation is CPU-intensive. Research benchmarks show ~49 seconds per proof step. On mobile devices, this may be impractical.

**Mitigation:** Server-side proving (current approach). The prover is a service that generates proofs on behalf of users. Users can self-host for privacy.

## Proof generation latency

**Note: Production uses real SP1 CPU proving.**

The SP1 prover runs in CPU mode, generating legitimate compressed STARK proofs for every transaction. Proof generation takes seconds to minutes depending on transaction complexity.

**Impact:** Transactions are not instant — users wait for proof generation before the inscription is broadcast to Bitcoin.

**Scaling path:** GPU proving (CUDA) or the Succinct Prover Network can reduce latency if CPU becomes a bottleneck.

## Backend trust

**Risk: The centralized backend sees transaction details.**

The current architecture routes all transactions through the Rust backend, which has full visibility into amounts, senders, and receivers.

**Mitigation:** The backend is fully open-source and designed to be self-hosted. With a self-hosted backend, no third party sees transaction data.

## Coin creation time leak

**Risk: The approximate creation time of a coin is revealed.**

The sender must disclose an upper bound on when the coin was created, so the receiver knows how many confirmations to expect. Additionally, outputs of the same transaction may be linkable.

**Mitigation:** Wallets should create only a single output per transaction. The protocol authors acknowledge this leak and are exploring mitigations (see [paper section 6.3](https://eprint.iacr.org/2025/068)).

## Key storage

**Status: Keys are encrypted at rest.**

The BIP32 master key is stored encrypted using AES-256-GCM in the browser's IndexedDB via the Web Crypto API. Decryption requires user authentication (password for seed-phrase wallets, biometric via passkey for passkey wallets).

**Remaining risk:** Browser-based storage is inherently less secure than hardware wallets or OS-level secure storage. A compromised browser extension with IndexedDB access could potentially extract encrypted data.

## Data availability

**Risk: Loss of coin proofs means loss of funds.**

Client-Side Validation protocols are inherently vulnerable to data loss. The blockchain stores only nullifiers, not transaction data. If the wallet's coin proofs are lost, the coins become unspendable.

**Mitigation:** Planned backup/restore feature. Research on UTxO binding for data availability is ongoing ([ePrint 2025/569](https://eprint.iacr.org/2025/569)).

## No smart contracts

**Risk: Shielded CSV supports only payments.**

There is no global state, no programmability, no DeFi capabilities. Lending, DEX, or other smart contract use cases are not possible with this protocol.

**Possible future:** Combination with RGB for programmable logic on Bitcoin L1.

## BitVM bridge

**Risk: Trustless bridging between Shielded CSV and Bitcoin is not yet possible.**

Currently, bridging requires a trusted party or federation. The goal is a trustless bridge via BitVM (1-of-n trust model), but this is still under active research.

## Interactivity requirement

**Risk: The receiver must be reachable to receive a payment.**

Shielded CSV transactions are interactive — the sender must deliver the coin proof to the receiver. Offline or asynchronous receiving is not currently supported.

## Network effect

**Risk: Privacy depends on usage volume.**

If very few people use Shielded CSV, the anonymity set is small. Timing analysis on nullifiers could reveal patterns. The protocol's privacy guarantees strengthen as adoption grows.

## Regulatory uncertainty

**Risk: Privacy protocols face increasing regulatory scrutiny.**

Tornado Cash (OFAC-sanctioned 2022), Samourai Wallet (founders arrested 2024), and the GENIUS Act (2025) show that privacy tools attract regulatory attention.

**Structural advantage:** Unlike mixers, Shielded CSV has no coordinator, no smart contract address, and no central service that can be sanctioned. It is a peer-to-peer protocol, comparable to Bitcoin itself.
