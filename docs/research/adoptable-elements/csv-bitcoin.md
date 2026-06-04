---
title: Learnings — CSV on Bitcoin
---

# Learnings — Client-Side Validation on Bitcoin

This cluster is the closest family to zkCoins: protocols that keep transaction data off-chain, anchor only a cryptographic commitment on Bitcoin L1, and have the recipient (not a global consensus) validate what they receive. RGB and Taproot Assets are the two production CSV-on-Bitcoin systems, and single-use seals are the shared primitive both build on. They have solved — in production — exactly the layers zkCoins still has on its roadmap (off-chain delivery, proof distribution, addressing, recovery/data-availability), which makes their *mechanisms* the most directly transferable. The single sharpest contrast is confidentiality: both reveal full provenance to the counterparty, whereas zkCoins' whole point is a ZK anonymity set — so the lesson is "adopt their plumbing, not their privacy model."

## RGB

**How it works** — RGB is a CSV smart-contract/asset system on Bitcoin: all state lives off-chain, and only a deterministic commitment to a state transition is anchored in a Bitcoin transaction output, bound to a [single-use seal](https://docs.rgb.info/distributed-computing-concepts/client-side-validation). To pay, the recipient issues an **RGB invoice** encoding a seal (a UTXO, either in clear or in *blinded* form) plus the contract/asset; the sender then hands the recipient a **consignment** — the final state transition plus *the entire validated history back to genesis* — out of band ([contract transfers](https://docs.rgb.info/annexes/contract-transfers)). The recipient validates the whole DAG against the Bitcoin anchors themselves. In [v0.12](https://rgb.tech/blog/release-v0-12-consensus/), consignments became *streams* validated incrementally (never more than a few hundred bytes in memory, decoupled from chain-index sync), and the two seal-closing methods (tapret/opret) were unified.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Blinded seal in the invoice | Recipient puts a *blinded* (committed, not revealed) destination in the invoice; the payer commits to it without learning the underlying UTXO | A receiver-supplied blinding factor lets zkCoins addresses/invoices be advertised without the payer (or relay) being able to link them to past payments — directly attacks address reuse linkage | Addressing | Med | Med |
| Streamed/incremental bundle validation | Validate a transfer as bytes arrive, bounded memory, never holding the whole blob | zkCoins' CoinProof bundle carries a ~100 KB+ Plonky2 proof; streaming verification keeps mobile/light clients viable and matches the "proof is a large disk-backed object" reality | UX / Delivery | Med | Med |
| Multi-channel consignment encoding | Same consignment serialized as Base58 / QR / URL, and (planned) carried over Nostr or Lightning | zkCoins already plans Nostr transport; RGB's channel-agnostic encoding is a template for a transport-independent bundle format (QR/URL fallback when no relay is reachable) | Delivery | High | Low |
| Genesis-anchored audit chain | Every transfer is verifiable back to a genesis commitment on Bitcoin, with no trusted issuer in the loop | A concrete model for **trustless emission (S5)**: tie an asset's genesis to an on-chain commitment so issuance is auditable from the chain, not node-signed | S5 | Med | High |
| Invoice = seal + asset + amount | Compact, structured payment request the payer consumes to build the transfer | Validates zkCoins' invoice direction (`{amount, recipient, asset_id}`) and suggests adding an explicit seal/anchor reference and one-shot semantics | Addressing / UX | High | Low |

**Doesn't transfer**

- **Full-provenance disclosure to the recipient.** RGB's recipient sees the entire lineage back to genesis. This is the *opposite* of zkCoins' shielding — adopting RGB's consignment-as-full-history model would destroy the anonymity set. zkCoins must keep its constant-size recursive proof, which reveals only validity.
- **AluVM / Turing-complete contracts.** RGB's contract VM is out of scope; zkCoins is a payment layer, and a general-purpose VM is a different (and conflicting) design axis.
- **Manual file backups for data availability.** RGB largely leaves consignment durability to the user (save the file). That is the very failure mode zkCoins' network-pull-verified-against-Bitcoin recovery is meant to avoid — so it is an anti-pattern to copy, useful only as the baseline to beat.
- **Per-UTXO seal binding to a specific output.** RGB binds state to named Bitcoin UTXOs; zkCoins commits via an inscription carrying a rotating key + signature + state hashes, not a spend of a designated UTXO. The *single-use* property transfers conceptually (see below), the UTXO-binding mechanism does not.

## Taproot Assets

**How it works** — Taproot Assets (Lightning Labs) commits an asset into a **Merkle-sum sparse Merkle tree (MS-SMT)** whose root is tweaked into a Taproot output; the sum dimension proves non-inflation and the sparse dimension proves non-inclusion ([protocol overview](https://docs.lightning.engineering/the-lightning-network/taproot-assets/taproot-assets-protocol)). A recipient creates a bech32m **asset address** (asset ID + script hash + internal key + amount) and should not reuse it. Transfer correctness is carried by **proof files** that audit the asset back to its genesis output; these proofs are distributed off-chain through **universe servers** — repositories that store issuance and transfer proofs and that nodes push to / pull from over a REST API, organized into **federations** that sync, with a **multiverse** view across many assets ([universes](https://docs.lightning.engineering/lightning-network-tools/taproot-assets/universes.md), [glossary](https://docs.lightning.engineering/the-lightning-network/taproot-assets/glossary)). A **proof courier** is the agreed endpoint (often a universe) the sender posts the new proof to and the receiver fetches it from.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Universe server as proof-availability layer | A push/pull repository of issuance + transfer proofs that any party can query and that federates/syncs with peers | This is the canonical answer to zkCoins' **recovery / data-availability** gap: the node-as-Nostr-relay mesh *is* a universe-like store; federation/sync is the replication precondition the recovery model already names | Recovery / Delivery | High | Med |
| Proof courier as an explicit role | A named, swappable endpoint the sender posts to and the receiver pulls from, decoupled from either party's liveness | Formalizes zkCoins' "where does the bundle wait" question: define a courier role over Nostr (post gift-wrapped bundle, recipient pulls when online), with the courier trusted only for availability | Delivery | High | Med |
| Federated sync / multiverse | Nodes mirror each other's proof sets; a multiverse aggregates many assets' roots | Concrete pattern for replicating bundles across the relay mesh so one dead node can't lose coins — turns "honest + replicated" from aspiration into a sync protocol | Recovery | High | Med |
| MS-SMT (sum + sparse) commitment | One tree proves both *value conservation* (sum) and *non-existence* (sparse) in a single membership proof | zkCoins already uses an SMT + MMR; the *sum* dimension is a cheap, queryable supply/non-inflation check that could back **trustless emission (S5)** and a verifier-side sanity check | S5 / S2 | Med | High |
| Public universe ≈ public explorer | A universe exposes public issuance/aggregate data without revealing private holdings | Maps onto zkCoins' two-explorer design: the public commitment/roots stream is the "public universe"; gated pull is the authorized view | View-keys / UX | High | Low |
| Single-shot, non-reusable address | Asset addresses are per-asset/per-amount and explicitly should not be reused | Reinforces zkCoins' linkage warning (the stable address links payments); argues for invoice-scoped, ideally one-time receive identities | Addressing | High | Low |

**Doesn't transfer**

- **Transparent proofs.** A Taproot Assets proof reveals the asset ID, amount, and full genesis-to-tip lineage to whoever holds it. Universes therefore store *plaintext-meaningful* proofs. zkCoins must distribute only ZK proofs + encrypted bundles — so a zkCoins "universe" stores ciphertext addressed to ephemeral keys, never readable provenance. Copy the *availability/federation* mechanics, not the data model.
- **Universe trust drift.** In practice many wallets rely on Lightning Labs' default universe, creating a soft centralization. zkCoins should treat that as a warning: default-relay convenience must not become a de facto single point — hence advertise multiple relays including a self-hosted one.
- **Genesis-output / UTXO-anchored asset model.** Taproot Assets ties assets to specific Bitcoin outputs and Taproot tweaks; zkCoins' anchor is an inscribed commitment with a rotating key. The address *structure* (typed, scoped, non-reusable) transfers; the UTXO-tweak addressing does not.
- **vPSBT / on-chain asset spend ergonomics.** vPSBTs model asset spends as virtual PSBTs over real Bitcoin transactions. zkCoins does not spend a designated UTXO per transfer, so the vPSBT machinery has no direct analogue.

## Single-use seals (Peter Todd)

**How it works** — A single-use seal is an abstract primitive: an object that can be *closed over a message exactly once*, producing a publicly verifiable witness, such that no second valid closing over a different message can ever exist ([RGB Blackpaper](https://black-paper.rgb.tech/consensus-layer/3.-client-side-validation/3.2.-single-use-seals), [LNPBP-0008](https://github.com/LNP-BP/LNPBPs/blob/master/lnpbp-0008.md)). On Bitcoin it is realized as a *deterministic commitment* tied to spending a UTXO, so the chain enforces "closed once." Todd's companion idea is **proof-of-publication**: a verifier checks both that a commitment *was* published and that no conflicting commitment appeared *earlier*, anchored in Bitcoin so maintainers can censor but cannot forge — "trustless w.r.t. validity, trusted w.r.t. censorship resistance" ([proof-of-publication asset transfer](https://petertodd.org/2017/scalable-single-use-seal-asset-transfer)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Single-use-seal framing for the nullifier | "Closed exactly once over a message" is the abstract spec of a spent-marker | Gives zkCoins a clean correctness statement for **S2**: a global nullifier/spent-coin set is precisely a single-use-seal registry; a double-spend is a second valid closing | S2 | High | Low (framing) / High (build) |
| Proof-of-publication: publish + *non-*publication | Verify a commitment exists *and* that no earlier conflicting one does | This is exactly the verifier-queryable double-spend check zkCoins lacks: a global accumulator answering "has this coin been nullified before?" against Bitcoin order | S2 | High | Research |
| "Trustless on validity, trusted on availability" lens | Explicitly separates correctness (cryptographic, trustless) from liveness (can be censored/withheld) | The precise trust framing zkCoins already uses for nodes/relays/couriers — formalizes *why* withhold-but-never-forge is acceptable across delivery + recovery | Delivery / Recovery | High | Low |
| log(n) non-inclusion proofs over a published ledger | Compact membership/non-membership proofs so clients verify without full history | Backs an efficient, light-client-friendly nullifier non-inclusion proof — the data-structure shape S2's accumulator should target | S2 / UX | Med | High |

**Doesn't transfer**

- **UTXO-spend-as-seal-closing.** Todd's canonical seal is closed by *spending a specific Bitcoin output*. zkCoins closes its "seal" by inscribing a signed commitment, not by spending a designated UTXO — so the primitive transfers as a *concept* and a correctness spec, not as the literal mechanism.
- **Per-token dedicated ledgers.** The 2017 design contemplates a published ledger per asset/token. zkCoins wants one global anonymity set and one accumulator, not per-asset ledgers — adopting per-token publication would fragment the anonymity set.
- **Plaintext message in the witness.** Classic single-use-seal witnesses commit to a readable message. zkCoins must keep the closed message opaque (hash/ZK), so only the *uniqueness* guarantee carries over, not message visibility.

## Top candidates from this cluster

1. **Universe-style federated proof store over the node/relay mesh** — Taproot Assets — Recovery/Delivery — High / Med. The production-proven shape for "honest + replicated" bundle availability; maps almost one-to-one onto node-as-Nostr-relay + federation sync.
2. **Proof-of-publication (publish + non-publication) as the S2 double-spend check** — Single-use seals — S2 — High / Research. The exact verifier-queryable spent-coin guarantee zkCoins is missing; the right correctness target for a global nullifier accumulator.
3. **Explicit proof-courier role, transport-agnostic** — Taproot Assets (+ RGB encoding) — Delivery — High / Med. Names the swappable, availability-only endpoint that holds the bundle until the receiver pulls; fits Nostr gift-wrap with QR/URL fallback.
4. **Blinded destination in the invoice + one-shot non-reusable addresses** — RGB / Taproot Assets — Addressing — High / Low–Med. Cheap, well-understood defenses against the address-reuse linkage zkCoins' own docs flag.
