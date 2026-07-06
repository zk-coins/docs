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

When you send zkCoins, the protocol generates a Zero-Knowledge proof that the transaction is valid — without revealing amounts, sender, receiver, or transaction history. The coin data itself (amounts, balances, history) never touches the chain. On Bitcoin, a permissionless **publisher** aggregates many spends into a batch and anchors it with a single, constant-size **`BatchInscription`** — 231 bytes per batch, no matter how many spends the batch covers ([spec §3.5](/specification#35-inscription-format)).

```
Normal Bitcoin TX:    full transaction — sender, receiver, amount, all visible
zkCoins batch:        one 231-byte inscription — constant, covering every spend in the batch
```

The standard commit + reveal transaction pair that publishes a batch is **~318 vBytes**, independent of how many spends the batch carries — so the per-spend on-chain cost amortises toward zero as batches grow. The spec's worked example: **~3.2 vBytes per record for a 100-record batch** ([spec §3.8](/specification#38-fees-and-economics)).

The blockchain serves one purpose: anchoring the nullifier-accumulator state transitions that prove each coin is spent only once. Everything else — validation, balances, history — happens off-chain between sender, receiver, and their nodes.

## Key properties

- **Private by default**: amounts, sender, receiver, and transaction graph are hidden
- **No protocol changes**: works on Bitcoin as it exists today, no soft fork
- **Constant on-chain footprint**: one 231-byte `BatchInscription` per batch — per-spend cost amortises toward zero as batches grow (~3.2 vBytes per record at 100 records, [spec §3.8](/specification#38-fees-and-economics))
- **Constant proof size**: verification cost is independent of transaction history
- **No coordinator**: publishing is permissionless — anyone can run a publisher, and wallets can switch or self-publish
- **Self-custodial**: keys are generated and stored locally in the browser

## Protocol

zkCoins implements the [Shielded CSV protocol](https://eprint.iacr.org/2025/068) by Jonas Nick (Blockstream), Liam Eagen (Alpen Labs), and Robin Linus (ZeroSync).

## Quick links

- [Specification](/specification)
- [Requirements](/requirements)
- [Protocol Details](/protocol)
- [Known Risks](/risks)
- [GitHub](https://github.com/zk-coins)
