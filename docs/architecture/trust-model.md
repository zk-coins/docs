---
title: Trust Model
---

# Trust Model

zkCoins follows the **Bitcoin full-node model: your wallet trusts _your_ node, exactly as a Bitcoin wallet trusts your own `bitcoind`.** "Trusted node" means _your_ node — never a third party. Running your own node is the trustless, private way to use zkCoins, and it is the model the whole system is designed around.

## Why there is a node

zkCoins splits into two pieces:

- **The node** — a validator. It scans Bitcoin, verifies zero-knowledge proofs, maintains the commitment history, and publishes commitments.
- **The wallet** — a thin key-holder. It stores your seed, derives keys, and signs.

This split is packaging, not a trust boundary. It is the same separation as `bitcoind` (the validator) and a Bitcoin wallet (the key-holder). The only line the node never crosses is your private key — that never leaves the wallet.

## What a node cannot do

A node — including a public one you do not control — **can never steal, forge, or double-spend your coins.** That is enforced cryptographically: every transfer carries a recursive zero-knowledge validity proof, and every spend is anchored to an immutable on-chain commitment. Double-spend protection is enforced **inside the proof circuit** today (a proof of non-inclusion in the per-account coin history); a verifier-queryable global on-chain nullifier set is a roadmap item (see [Nullifier Design](nullifier-design)). A dishonest operator cannot fabricate value or take yours.

## What changes when the node is not yours

If you use someone else's node, two things are delegated to that operator:

- **Privacy** — the node builds your proofs, so it sees your transaction details in the clear.
- **Liveness** — if that operator goes down or refuses service, you cannot transact through it until you switch.

This is the same spectrum as Bitcoin: using a public node is like using an Electrum/SPV server, and running your own node is like running your own `bitcoind`. Neither can steal from you; the difference is what the operator sees and whether you depend on it.

## Run your own node

Self-hosting gives you **trustlessness and privacy at once**: your node verifies your transactions and sees your plaintext — and you are the operator, so nothing leaks. The node ships as a single container with documented configuration and no operator-specific dependencies, so running your own is straightforward.

The wallet can always point at a different node by changing a single configuration value. You are never locked to one operator.

## What you keep custody of

Transaction data lives off-chain — only opaque commitments go on Bitcoin — so **you hold your own coin data**, much like a seed phrase. Back it up. This is the cost of keeping transactions private and off-chain: no operator holds a recoverable copy on your behalf.
