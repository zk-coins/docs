---
sidebar_position: 2
title: Privacy Model
---

# Privacy Model

Shielded CSV provides strong privacy guarantees, but with well-understood limitations. This page describes exactly what is hidden, what is visible, and what the threat model covers.

## What is hidden

For any observer looking at the Bitcoin blockchain:

- **Transaction amounts** — how much was transferred
- **Sender identity** — who initiated the transaction
- **Receiver identity** — who received the coins
- **Transaction graph** — which coins flow where
- **Account balances** — how much any user holds
- **Transaction history** — the full lineage of any coin

This is achieved through Proof-Carrying Data (PCD) — each transaction produces a Zero-Knowledge proof that hides all details while proving validity.

## What is visible

Two things are visible on-chain:

### 1. Nullifier existence

The 64-byte nullifier is published as a Bitcoin Taproot Inscription. An observer can see that *some* Shielded CSV transaction occurred, but not its contents. Nullifiers look like random data — they are indistinguishable from each other.

### 2. Approximate coin creation time

The sender must reveal an upper bound on when the coin was created ("this coin is older than block height X"). This allows the receiver to determine how many confirmations the coin has. It does not reveal the exact block or the specific nullifier that created the coin.

:::warning Known privacy leak
Outputs of the same transaction may be linkable through the coin creation time. The protocol recommends wallets create only a single output per transaction to mitigate this.
:::

## Comparison with other privacy approaches

| Approach | Anonymity Set | Amounts Hidden | Graph Hidden | Coordinator |
|---|---|---|---|---|
| **Shielded CSV** | All coins ever created | Yes | Yes | None |
| **Monero** | Ring of 16 decoys | Yes | Partially | None |
| **Zcash (shielded)** | Shielded pool (~10-20%) | Yes | Yes | None |
| **CoinJoin** | Round participants | No | No | Required |
| **Silent Payments** | N/A (receive only) | No | No | None |

## Regulatory advantage

Unlike CoinJoin (Wasabi, Samourai) or mixer contracts (Tornado Cash), Shielded CSV has:

- **No coordinator** — no central service that can be sanctioned
- **No smart contract** — no on-chain address to blacklist
- **Peer-to-peer** — the protocol is as decentralized as Bitcoin itself
- **64-byte opaque nullifiers** — technically difficult to filter without breaking legitimate Bitcoin usage

## Backend visibility

The current implementation uses a server-side prover — a real, in-process Plonky2 prover that produces genuine Zero-Knowledge proofs. The trust boundary is therefore the node operator: the backend processes transactions and therefore sees:

- Which accounts are sending and receiving
- Transaction amounts
- Account balances

:::info Self-hosting eliminates this
The backend is fully open-source. Users can run their own instance, eliminating any trust requirement. With a self-hosted backend, no third party sees any transaction data.
:::

This is comparable to the trust model of any web wallet: you trust the server you connect to. The difference is that the zkCoins backend is open-source, stateless, and designed to be self-hosted.
