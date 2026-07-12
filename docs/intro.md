---
slug: /
title: Introduction
---

# zkCoins

zkCoins is a protocol and system — node, wallet, and explorer — realizing **Shielded CSV**, which brings true privacy to Bitcoin through Client-Side Validation and Zero-Knowledge Proofs. No soft fork required. No new consensus rules. Bitcoin as it exists today.

## What can users do?

| Action | Description |
|---|---|
| **Create Wallet** | Generate a BIP32 HD wallet locally. Keys never leave the browser. |
| **Receive** | Share your address. Incoming coins appear automatically. |
| **Send** | Send coins to any zkCoins address. Only sender and receiver see the details. |
| **Faucet** | Mint testnet coins for testing (testnet only). |

## How it works

When you send zkCoins, the protocol generates a Zero-Knowledge proof that the transaction is valid — without revealing amounts, sender, receiver, or transaction history. The coin data itself (amounts, balances, history) never touches the chain. On Bitcoin, each spend publishes a single **~64-byte half-aggregated nullifier** — a permissionless **publisher** may half-aggregate many nullifiers into one inscription, or a wallet may self-publish its own ([spec §3.5](/specification#35-inscription-format)).

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
- **No coordinator**: publishing is permissionless — contention-free, anyone can run a publisher, and wallets can self-publish
- **Self-custodial**: keys are generated and stored locally in the browser

## Protocol

zkCoins implements the [Shielded CSV protocol](https://eprint.iacr.org/2025/068) by Jonas Nick (Blockstream), Liam Eagen (Alpen Labs), and Robin Linus (ZeroSync).

## Quick links

- [Specification](/specification)
- [Requirements](/requirements)
- [Protocol Details](/protocol)
- [Known Risks](/risks)
- [GitHub](https://github.com/zk-coins)
