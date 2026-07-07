---
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

A receiver — itself, or its own node acting on its behalf — accepts a coin only after independently verifying its full validity proof; correctness never depends on trusting the sender, a foreign node, or any third party. (Following the Bitcoin full-node model, the thin wallet trusts *its own* node exactly as a Bitcoin wallet trusts its own `bitcoind`; the trustless path is self-hosting that node, not bolting verification onto the wallet.)

### 5. Custody only in the wallet

The key that authorizes spending exists only on the user's wallet and is never transmitted to or stored on any node or server.

### 6. Recovery

The seed is the root from which all keys are deterministically derived. The complete state must be recoverable: normally from the node operator's own backup, and — as an emergency fallback after total loss of local data — from the seed, the public Bitcoin chain, and the coin data replicated across other nodes.

### 7. Self-hostable

Anyone can run their own node; using zkCoins must never require trusting or depending on any specific operator.

### 8. Multi-asset

The protocol supports multiple distinct asset types, each identified by a globally unique asset id. Every other requirement applies equally to every asset.

### 9. Selective disclosure

The holder of an account can voluntarily disclose, to a recipient of its choosing, a precisely bounded view of its own activity — and nothing beyond that bound. The protocol supports at least three granularities: (a) a single transaction; (b) the current balance of one asset, revealing no transaction or history; and (c) the account's full transaction history. Every disclosure is read-only — it never confers spend authority — and every disclosed fact must be cryptographically verifiable against Bitcoin rather than asserted by any node or explorer. Disclosure is opt-in: absent one, the privacy of Requirement 2 holds in full. Any explorer that presents such disclosures must be self-hostable.

### 10. Node portability

A wallet — the holder of the seed — can switch nodes at any time and can use multiple nodes simultaneously. A wallet must not depend on any node-specific state; every conforming node is interchangeable, and no node can lock a wallet in.
