---
sidebar_position: 2
title: Requirements
---

# Protocol Requirements

The non-negotiable requirements zkCoins must satisfy. Each is a property of the protocol, independent of how it is implemented; implementation choices (commitment batching, the off-chain transport mechanism, key derivation, the replication factor, and similar) are not requirements.

### 1. Bitcoin L1 as the only base

zkCoins settles exclusively on Bitcoin mainnet Layer 1. It introduces no separate blockchain, no native token, and no separate consensus or validator set, and it requires no change to Bitcoin's consensus rules (no soft-fork, no hard-fork). It must run against Bitcoin as it exists today.

### 2. Private

From public on-chain data alone, no observer can determine a payment's amount, asset, sender, or receiver, nor link two on-chain events to the same coin, account, or user. The anonymity set is global — every coin in the system — not a fixed decoy ring or a per-round participant set.

### 3. Trustless

The integrity of funds is enforced by cryptography and Bitcoin alone. No party — a node operator, a public node, any setup procedure, trusted hardware, or a federation — can steal, forge (create coins it is not entitled to), double-spend, or freeze coins it does not own.

### 4. Client-side validation

A receiver accepts a coin only after independently verifying its full validity proof; correctness never depends on trusting the sender, the node, or any third party.

### 5. Custody only in the wallet

The key that authorizes spending exists only on the user's wallet and is never transmitted to or stored on any node or server.

### 6. Recovery

The seed is the root from which all keys are deterministically derived. The complete state must be recoverable: normally from the node operator's own backup, and — as an emergency fallback after total loss of local data — from the seed, the public Bitcoin chain, and the coin data replicated across other nodes.

### 7. Self-hostable

Anyone can run their own node; using zkCoins must never require trusting or depending on any specific operator.

### 8. Multi-asset

The protocol supports multiple distinct asset types, each identified by a globally unique asset id. Every other requirement applies equally to every asset.

### 9. Explorer (shareable confirmation)

A sender can generate a shareable link that grants its holder a full view of exactly one transaction — amount, asset, time, and status — and nothing beyond it. The link carries a scoped view capability, never a public identifier and never the spend key. The confirmation must be cryptographically verifiable against Bitcoin rather than asserted by the explorer, and the explorer must be self-hostable.

### 10. Node portability

A wallet — the holder of the seed — can switch nodes at any time and can use multiple nodes simultaneously. A wallet must not depend on any node-specific state; every conforming node is interchangeable, and no node can lock a wallet in.
