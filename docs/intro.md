---
slug: /
title: Introduction
---

# zkCoins

zkCoins is a protocol and system — node, wallet, and explorer — realizing **Shielded CSV**, which brings true privacy to Bitcoin through Client-Side Validation and Zero-Knowledge Proofs. No soft fork required. No new consensus rules. Bitcoin as it exists today. zkCoins implements the **Shielded CSV construction** with registered v1 deviations (see the [Paper-Deviation Analysis](/paper-conformance-analysis) — notably D-05 the append-only-log accumulator and D-16 bounded finality).

## What can users do?

| Action | Description |
|---|---|
| **Create Wallet** | Generate a BIP32 HD wallet locally. The seed and SPEND keys remain in the wallet; only the non-spending operational bundle may be delegated to the wallet's own node. |
| **Receive** | Share your address. Incoming coins appear automatically. |
| **Send** | Send coins to any zkCoins address. Details are visible only to the participants and any node they deliberately trust with plaintext. |
| **Faucet** | Mint testnet coins for testing (testnet only). |

## How it works

Every state-advancing transition — send, receive, or mint — generates a Zero-Knowledge proof that it is valid without revealing amounts, sender, receiver, or transaction history. The coin data itself (amounts, balances, history) never touches the chain. On Bitcoin, each transition publishes one **~64-byte half-aggregated nullifier** — a permissionless **publisher** may half-aggregate many nullifiers into one inscription, or the wallet's own node may self-publish its nullifier ([spec §3.4](/specification#34-the-publisher), [§3.5](/specification#35-inscription-format)).

```
Normal Bitcoin TX:    full transaction — sender, receiver, amount, all visible
zkCoins:              one ~64-byte nullifier per transition — amounts, parties, graph hidden
```

The on-chain cost is **~16 vBytes per transition**, independent of how many coins the transition spends ([spec §3.8](/specification#38-fees-and-economics)).

The blockchain serves one purpose: anchoring the per-transition nullifiers that let every node rebuild the double-spend set from Bitcoin, proving each coin is spent only once. Everything else — validation, balances, history — happens off-chain between sender, receiver, and their nodes.

## Key properties

- **Private by default**: amounts, sender, receiver, and transaction graph are hidden
- **No protocol changes**: works on Bitcoin as it exists today, no soft fork
- **Compact on-chain footprint**: a ~64-byte half-aggregated nullifier per transition (~16 vB), independent of how many coins it spends ([spec §3.8](/specification#38-fees-and-economics))
- **Constant proof size**: verification cost is independent of transaction history
- **No coordinator**: publishing is permissionless — contention-free, anyone can run a publisher, and a wallet can use its own node to self-publish
- **Self-custodial**: the seed and SPEND keys stay in the wallet; no node receives spend authority

## Protocol

zkCoins implements the **Shielded CSV construction** with registered v1 deviations (see the [Paper-Deviation Analysis](/paper-conformance-analysis) — notably D-05 the append-only-log accumulator and D-16 bounded finality), as described in the [Shielded CSV protocol paper](https://eprint.iacr.org/2025/068) by Jonas Nick (Blockstream), Liam Eagen (Alpen Labs), and Robin Linus (ZeroSync).

## Quick links

- [Specification](/specification)
- [Requirements](/requirements)
- [Protocol Details](/protocol)
- [Known Risks](/risks)
- [GitHub](https://github.com/zk-coins)
