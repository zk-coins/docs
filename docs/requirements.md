---
sidebar_position: 2
title: Requirements
---

# Protocol Requirements

The non-negotiable requirements zkCoins must satisfy. Each is a property of the protocol, independent of how it is implemented; implementation choices (commitment batching, the off-chain transport mechanism, key derivation, the replication factor, and similar) are not requirements.

### 1. Bitcoin L1 as the only base

zkCoins settles exclusively on Bitcoin mainnet Layer 1. It introduces no separate blockchain, no native token, and no separate consensus or validator set, and it requires no change to Bitcoin's consensus rules (no soft-fork, no hard-fork). It must run against Bitcoin as it exists today.

### 2. Private

From public on-chain data alone, no observer can determine a payment's amount, asset, sender, or receiver, nor link two on-chain events to the same coin, account, or user. The anonymity set is global — every coin in the system — not a fixed decoy ring or a per-round participant set. Only the existence and timing of an opaque on-chain event may be observable.

### 3. Trustless

The integrity of funds is enforced by cryptography and Bitcoin alone. No party — a node operator, a public node, any setup procedure, trusted hardware, or a federation — can steal, forge (create coins it is not entitled to), double-spend, or freeze coins it does not own. A node's only residual powers are over the privacy of its own users (it sees the data they entrust to it) and over availability (it can withhold service); it can never violate this guarantee.

### 4. Client-side validation

A receiver accepts a coin only after independently verifying its full validity proof. Correctness never depends on trusting the sender, the node, or any third party.

### 5. Custody only in the wallet

The key that authorizes spending exists only on the user's wallet and is never transmitted to or stored on any node or server.

### 6. Recovery

Under normal operation a node operator restores from their own backup; the seed is the root from which all keys are deterministically derived. As an emergency fallback after total loss of local data, the complete state must be reconstructable from the seed, the public Bitcoin chain, and the coin data replicated across other nodes.

### 7. Self-hostable

Anyone can run their own node. Using zkCoins must never require trusting or depending on any specific operator; a user who runs their own node trusts no third party for the integrity of their funds.

### 8. Multi-asset

The protocol supports multiple distinct asset types, each identified by a globally unique asset id. Every other requirement applies equally to every asset.
