---
sidebar_position: 2
title: Requirements
---

# Protocol Requirements

The non-negotiable requirements zkCoins must satisfy. Implementation choices — how commitments are batched, the off-chain transport mechanism, key-derivation specifics, the replication factor, and similar — are documented elsewhere and are **not** requirements.

1. **Bitcoin L1 as the only base** — no own chain, token, or consensus; no soft-fork.
2. **Private** — nothing is readable on-chain (amount, sender, receiver, asset, or linkage); global anonymity set.
3. **Trustless** — no one (node, operator, setup, TEE, federation) can steal, forge, double-spend, or freeze coins they do not own; enforced cryptographically.
4. **Client-side validation** — the receiver verifies validity itself and trusts no third party.
5. **Custody only in the wallet** — the spend key never resides on a node or server.
6. **Recovery** — primarily from the node operator's own backup; the seed is the root of all keys. Emergency fallback: state is reconstructable from the seed + the Bitcoin chain + the coin data replicated across the network.
7. **Self-hostable** — anyone can run their own node.
8. **Multi-asset**.
