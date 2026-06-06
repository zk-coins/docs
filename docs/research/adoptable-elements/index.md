---
sidebar_position: 1
title: Adoptable Elements
---

# Adoptable Elements from Related Protocols

For every protocol catalogued in [Comparisons](/comparisons), we studied how it actually works and asked one question: **which concrete element could zkCoins evaluate adopting?** This section is the result — a deliberate scan of the field for ideas worth importing, with an honest account of what does *not* transfer.

:::note These are candidates, not decisions
Everything here is a **candidate to evaluate**, not an accepted design choice. Each idea is rated for **Fit** (how naturally it maps onto Client-Side Validation + ZK + Bitcoin) and **Effort** (Low / Med / High / Research-grade). Adoption decisions happen later, per item.
:::

## The guardrail

zkCoins' identity is a rare combination — **Bitcoin-anchored · Shielded (anonymity set) · Trustless**. An element only qualifies if it strengthens one corner *without* forcing zkCoins to abandon another (no own chain, no own token, no custodian, no trusted hardware). Many of the richest-looking features in other systems fail this test; those are documented under each project's **"Doesn't transfer"** so we don't cargo-cult them.

## Where each idea applies

Candidates are mapped to zkCoins' known roadmap gaps:

| Gap | Meaning |
|---|---|
| **S1** | Trustless receive — re-verify the full recursive proof on receipt (today the node only checks the inclusion proof) |
| **S2** | Double-spend / nullifier accumulator — a verifier-queryable global spent-coin set (today enforced only in-circuit) |
| **S5** | Trustless emission — issuance is node-signed and off-circuit today |
| **Delivery** | Off-chain transport of the value-bearing CoinProof bundle (Nostr direction) |
| **Note-discovery** | Detecting which incoming bundles are yours over an untrusted relay |
| **Recovery** | Restoring full state from seed + Bitcoin chain + an honest, replicated network |
| **View-keys** | The spend-vs-view split and delegated, scoped view grants |
| **Addressing / UX** | Reusable receiver addresses, payment URIs, offline receive |
| **Economics / Anti-spam** | Paying to publish/store without doxxing; relay abuse resistance |
| **Encoding / Explorer** | On-chain message format and a public commitment explorer |
| **Multi-asset / State-size** | Confidential multi-asset support; bounding node/accumulator growth |

## Highest-priority shortlist

The ideas that recur across clusters or carry the most leverage:

1. **View-key hierarchy (spend-vs-view split).** Zcash's FVK/IVK/OVK — independently validated by Monero, Firo, and Zano — is the textbook form of the proposed two-key model (operational key *sees*, spend key *spends*) and scoped view grants. **Fit High · Effort Med.**
2. **Note discovery over an untrusted relay.** Zcash trial-decryption of key-private ciphertexts + Aztec deterministic note-tags + Penumbra Fuzzy Message Detection — three proven recipes for "find my own bundles without telling the relay which are mine." Directly powers the Nostr delivery + recovery scan. **Fit High · Effort Med–High.**
3. **Deterministic seed-based recovery.** Cashu NUT-13 (derive secrets from seed, batch-scan with a bounded counter) maps almost 1:1 onto "seed re-derives keys + pull-tags." **Fit High · Effort Med.**
4. **Bitcoin-anchored spent-coin set (S2).** The Tornado Cash public nullifier set and the Cashu spent-secret ledger show the *interface* of the accumulator zkCoins lacks; the open work is anchoring it to Bitcoin rather than a contract or a mint DB. **Fit High · Effort Research.**
5. **Broadcaster paid from shielded funds.** Railgun's pattern — a third party publishes your transaction and is reimbursed from the value moved — is the cleanest way to pay the Bitcoin commitment fee without the spender revealing a funding UTXO. **Fit High · Effort Med.**
6. **Replicated availability as a precondition.** Taproot Assets universe stores + Fedimint t-of-n replication + Plasma's "data loss = fund loss" lesson turn "honest + replicated network" from advice into an enforced replication factor with acknowledgements. **Fit High · Effort Med.**

## Candidates by roadmap gap

### View keys & the two-key model

| Element | Source | Fit | Effort | Cluster |
|---|---|---|---|---|
| FVK/IVK/OVK key hierarchy (spend-vs-view split) | Zcash (echoed by Monero, Firo, Zano) | High | Med | [Shielded ZK Chains](./shielded-zk-chains.md) |
| Viewing-key / read-grant UX (selective disclosure) | Shade | High | Low | [Other Trust Models](./other-trust-models.md) |

### Note discovery & delivery

| Element | Source | Fit | Effort | Cluster |
|---|---|---|---|---|
| Trial decryption of key-private ciphertexts | Zcash | High | Med | [Shielded ZK Chains](./shielded-zk-chains.md) |
| Deterministic note tags (shared-secret + counter) | Aztec | High | Med | [EVM Privacy](./evm-privacy.md) |
| Fuzzy Message Detection (detection key, no false negatives) | Penumbra | High | High | [Shielded ZK Chains](./shielded-zk-chains.md) |
| Bearer-token serialization + offline hand-off | Cashu / Ark | Med–High | Med | [Ecash](./ecash.md) |

### Recovery & data availability

| Element | Source | Fit | Effort | Cluster |
|---|---|---|---|---|
| Deterministic secrets from seed (NUT-13) | Cashu | High | Med | [Ecash](./ecash.md) |
| Universe-style federated proof store over the relay mesh | Taproot Assets | High | Med | [CSV on Bitcoin](./csv-bitcoin.md) |
| t-of-n replication quorum for the bundle store | Fedimint | High | Med | [Ecash](./ecash.md) |
| Replication-as-precondition + sender-holds-until-ACK | Plasma / Intmax2 | High | Med | [Stateless Rollups](./stateless-rollups.md) |
| Four-limitation CSV audit taxonomy (DA, coherence, discovery, integrity) | ePrint 2025/569 | High | Low | [Stateless Rollups](./stateless-rollups.md) |
| Compact light-client pull + client-side decryption (ZIP-307) | Zcash | High | High | [Shielded ZK Chains](./shielded-zk-chains.md) |

### Double-spend / nullifier accumulator (S2)

| Element | Source | Fit | Effort | Cluster |
|---|---|---|---|---|
| Public, queryable nullifier set | Tornado Cash | High | Research | [EVM Privacy](./evm-privacy.md) |
| Spent-secret ledger as a double-spend oracle (interface shape) | Cashu | High | Research | [Ecash](./ecash.md) |
| Proof-of-publication / non-publication check | Single-use seals | High | Research | [CSV on Bitcoin](./csv-bitcoin.md) |
| Signature/transfer aggregation at publishing (BLS, mass transfers) | Intmax2 | Med | High | [Stateless Rollups](./stateless-rollups.md) |

### Trustless emission (S5)

| Element | Source | Fit | Effort | Cluster |
|---|---|---|---|---|
| Open-mint terms grammar (cap + per-mint amount + height window) | Runes | High | Research | [Bitcoin Asset Overlays](./bitcoin-asset-overlays.md) |
| Deterministic asset ID from genesis (no registry) | Open Assets / Omni | High | Med | [Bitcoin Asset Overlays](./bitcoin-asset-overlays.md) |

### Economics & anti-spam

| Element | Source | Fit | Effort | Cluster |
|---|---|---|---|---|
| Broadcaster paid from shielded funds | Railgun | High | Med | [EVM Privacy](./evm-privacy.md) |

### Addressing & UX

| Element | Source | Fit | Effort | Cluster |
|---|---|---|---|---|
| Diversified / stealth / sub-addresses (reuse without linkage) | Zcash / Firo / Monero | Med–High | Med | [Shielded ZK Chains](./shielded-zk-chains.md) |
| Payment-request URIs (ZIP-321) | Zcash | Med | Low | [Shielded ZK Chains](./shielded-zk-chains.md) |
| Blinded destination in invoice + one-shot addresses | RGB / Taproot Assets | High | Low–Med | [CSV on Bitcoin](./csv-bitcoin.md) |
| Offline / async receive via pre-signed transfer | Ark | High | Med | [Ecash](./ecash.md) |

### On-chain encoding & explorer

| Element | Source | Fit | Effort | Cluster |
|---|---|---|---|---|
| Self-describing tag/value encoding + invalid-message rule | Runes | High | Med | [Bitcoin Asset Overlays](./bitcoin-asset-overlays.md) |
| Reorg-aware indexer (chaintip monitor + rollback) | Runes / `ord` | High | Med | [Bitcoin Asset Overlays](./bitcoin-asset-overlays.md) |

### Multi-asset confidentiality & state-size

| Element | Source | Fit | Effort | Cluster |
|---|---|---|---|---|
| Blinded asset tags + per-asset balance constraint | Liquid Confidential Assets | High | Med–Research | [Other Trust Models](./other-trust-models.md) |
| Cut-through (drop spent intermediate state) | MimbleWimble | High | Research | [Other Trust Models](./other-trust-models.md) |

## Cluster deep dives

Each page covers how the projects work, the full element-by-element analysis, and what explicitly does **not** transfer:

- [Client-Side Validation on Bitcoin](./csv-bitcoin.md) — RGB, Taproot Assets, single-use seals
- [Shielded ZK Chains](./shielded-zk-chains.md) — Zcash, Monero, Penumbra, Namada, Iron Fish, Firo, Zano, Aleo
- [Privacy on Smart-Contract Chains](./evm-privacy.md) — Railgun, Aztec, Tornado Cash
- [Client-Data / Stateless ZK Rollups](./stateless-rollups.md) — Intmax/Intmax2, Plasma, CSV data-availability research
- [Bitcoin Asset Overlays](./bitcoin-asset-overlays.md) — Omni, Counterparty, Colored Coins, Ordinals/Runes/BRC-20
- [Off-chain Bitcoin Value & Chaumian Ecash](./ecash.md) — Cashu, Fedimint, Ark, Statechains/Mercury
- [Confidential & Other Trust Models](./other-trust-models.md) — Liquid, MimbleWimble, Shade

## What does not transfer

A recurring theme across every cluster: the *trust model* of a system almost never transfers, only its *mechanism*. The full-history consignments of RGB/Taproot Assets break the anonymity set; the custody of Cashu, the federation of Fedimint/Liquid/Mercury, and the trusted hardware (TEE/SGX) of Shade all contradict trustlessness; the own-chain security budgets of Zcash/Monero/Namada and the EVM exit contracts of Tornado/Intmax2 have no Bitcoin-only analogue; and every transparent overlay (Omni, Counterparty, Runes) leaks exactly what zkCoins hides. The per-cluster pages spell each of these out.
