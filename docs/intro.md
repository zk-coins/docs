---
slug: /
sidebar_position: 1
title: Introduction
---

# zkCoins

zkCoins is a wallet for **Shielded CSV** — a protocol that brings true privacy to Bitcoin through Client-Side Validation and Zero-Knowledge Proofs. No soft fork required. No new consensus rules. Bitcoin as it exists today.

## What can users do?

| Action | Description |
|---|---|
| **Create Wallet** | Generate a BIP32 HD wallet locally. Keys never leave the browser. |
| **Receive** | Share your address. Incoming coins appear automatically. |
| **Send** | Send coins to any zkCoins address. Only sender and receiver see the details. |
| **Faucet** | Mint testnet coins for testing (testnet only). |

## How it works

When you send zkCoins, the protocol generates a Zero-Knowledge proof that the transaction is valid — without revealing amounts, sender, receiver, or transaction history. Only a **64-byte nullifier** is written to the Bitcoin blockchain, an opaque blob that prevents double-spending. Nothing more.

```
Normal Bitcoin TX:    ~560 weight units — sender, receiver, amount, all visible
zkCoins TX:          ~64 weight units  — one nullifier, completely opaque
```

The blockchain serves one purpose: proving that each coin is spent only once. Everything else — validation, balances, history — happens client-side between sender and receiver.

## Key properties

- **Private by default**: amounts, sender, receiver, and transaction graph are hidden
- **No protocol changes**: works on Bitcoin as it exists today, no soft fork
- **~100 TPS**: 8.75x more efficient than regular Bitcoin transactions
- **Constant proof size**: verification cost is independent of transaction history
- **No coordinator**: peer-to-peer, no central service to shut down
- **Self-custodial**: keys are generated and stored locally in the browser

## Protocol

zkCoins implements the [Shielded CSV protocol](https://eprint.iacr.org/2025/068) by Jonas Nick (Blockstream), Liam Eagen (Alpen Labs), and Robin Linus (ZeroSync). This wallet builds on the [ZeroSync prototype](https://github.com/ZeroSync/ZKCoins).

## Quick links

- [Architecture Overview](/architecture/overview)
- [Privacy Model](/architecture/privacy-model)
- [Protocol Details](/protocol)
- [Wallet Guide](/wallet)
- [Known Risks](/risks)
- [GitHub](https://github.com/zk-coins/zkcoins-app)
