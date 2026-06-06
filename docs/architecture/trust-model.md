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

## Wallet–node configurations

Because the wallet can switch nodes at any time and use several at once, a user picks where on this spectrum to sit. In **every** configuration custody is cryptographically safe — no node can steal, forge, or double-spend your coins; only privacy and whom you trust for correctness and availability change.

| Configuration | Privacy | Correctness / fraud | Custody |
|---|---|---|---|
| Own wallet + **own node** | full | trustless | safe |
| Own wallet + **multiple foreign nodes** | disclosed to all of them | safe **as long as ≥1 is honest** | safe |
| Own wallet + **a single foreign node** | disclosed to it | you trust it (it can lie or omit) | safe |

**Why multiple nodes protect you.** The "at least one honest node" guarantee holds only because the wallet can **verify delivered data against Bitcoin**: an honest node supplies verifiable truth, a dishonest one cannot forge a valid proof, so the wallet keeps the verifiable answer and ignores the rest. Without client-side verification, more nodes would not help. (Full receive-side re-verification of the recursive proof is the trustless-receive roadmap item — see [Information Flow](information-flow).)

**The eclipse case.** The Bitcoin analogy extends to its limit: if _all_ of a node's peers lie (an eclipse attack), even a self-hosted node is vulnerable — the "at least one honest peer" assumption. zkCoins inherits this network-liveness assumption directly, because it anchors on Bitcoin.

## Run your own node

Self-hosting gives you **trustlessness and privacy at once**: your node verifies your transactions and sees your plaintext — and you are the operator, so nothing leaks. The node ships as a single container with documented configuration and no operator-specific dependencies, so running your own is straightforward.

The wallet can point at a different node at any time — or use several simultaneously — by configuration alone. You are never locked to one operator.

## What you keep custody of

Transaction data lives off-chain — only opaque commitments go on Bitcoin — so **you hold your own coin data**, much like a seed phrase. Back it up. This is the cost of keeping transactions private and off-chain: no operator holds a recoverable copy on your behalf.
