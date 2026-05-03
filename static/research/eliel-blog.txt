---
type: resource
status: active
area: neben
tags: [crypto, bitcoin, privacy, quelle, analyse]
updated: 2026-04-21
---

# Eliel Blog — My Thoughts on the Shielded CSV Protocol

Zurück zur [[zkCoins/quellen|Quellen & Links]]

**Quelle:** [eliel.nfinic.com](https://eliel.nfinic.com/2025/04/07/my-thoughts-on-the-shielded-csv-protocol/)
**Autor:** elielmathe
**Datum:** 7. April 2025
**Kategorien:** Blockchain, Web3, Zero-Knowledge Proof

---

Last week, we had a technical discussion on the **SoloSafe project**, an offline payment system designed to work over Bluetooth and Wi-Fi hotspots, serving millions of people without reliable internet access. During the session, we discussed the **zero-knowledge (ZK) commitments** for transactions and their similarity to a protocol outlined in a **September 2024 paper**. I wasn't previously aware of this paper, but I was excited to see teams working on solutions to **offload Bitcoin's consensus mechanism**, which currently limits scalability in off-chain systems and which could be used in our protocol.

## The Shielded CSV Protocol

The **Shielded CSV protocol** addresses some of blockchain's core scalability issues. Most major blockchains rely on a consensus architecture where **every transaction must be broadcast to all nodes** for verification. While protocols like **Zcash and Monero** replace transactions with **validity proofs**, this increases communication, storage, and computational costs. For example, **Neptune Cash** requires miners to have at least **512 GB of RAM** to participate in block mining.

Shielded CSV introduces **Client-Side Validation (CSV)**, a paradigm that **decouples validation from blockchain consensus rules**. Instead of relying on global verification, a **coin is sent alongside its validity proof**. While CSV isn't new -- protocols like **Intmax2** already use it -- many still require **Bitcoin transactions to be published**. Shielded CSV improves upon this by minimizing on-chain data submissions.

## Key Concepts in Shielded CSV

1. **Nullifiers** — Prevent **double-spending** by combining a **coin identifier** and **transaction hash** into a unique nullifier.

2. **Publishers** — A dedicated blockchain for **aggregating nullifiers**, optimizing Bitcoin submissions.

3. **Proof-Carrying Data (PCD) Scheme** — Enhances coin proofs by **compressing transaction history** into succinct proofs. Each transaction generates a **computation proof**, and since subsequent transactions depend on prior proofs, their outputs remain **trustworthy**.

The paper introduces:

- **Non-interactive signature half-aggregation with commitments** — Uses signing/public keys to generate message signatures and defines functions like `verify`, `aggregate`, and `commit`.

- **ToS-Accumulator (Tuple of Sets)** — Manages state initialization, appending sets, proving union membership, and verifying distinct elements.

## Discussion Points

1. **Communication Channels** — Coins and proofs must be securely transmitted. **Interception risks** could expose transaction history. **Peer proximity** is suggested but presents challenges.

2. **Wallet State** — Unlike traditional wallets, **recovery via a seed phrase is impossible**. Losing the wallet means **losing all funds**.

3. **Coin Linkability** — If a sender transacts with multiple recipients in one transaction, **privacy leaks** may occur. The solution? **Use multiple coins**.

4. **Instantiation** — Shielded CSV is abstract but can be implemented via **SNARKs, folding schemes**, etc.

## Lessons for SoloSafe

> "Shielded CSV closely aligns with SoloSafe's goals, and we'll likely adopt concepts like PCD schemes to reduce transaction history overhead."

The remaining challenge is **preventing replay attacks** — since SoloSafe won't submit nullifiers to Starknet or a publisher after each transaction.

> "I strongly believe that bringing trust to the edge is the future, especially as internet access remains unreliable for many and blockchain consensus becomes a bottleneck."

**Links:**
- Shielded CSV paper: https://eprint.iacr.org/2025/068
- Shielded CSV Github: https://github.com/ShieldedCSV/ShieldedCSV
- SoloSafe: https://solosafe.xyz
