---
title: Requirements
---

# Protocol Requirements

The non-negotiable requirements zkCoins must satisfy. Each is a property of the protocol, independent of how it is implemented; implementation choices (commitment batching, the off-chain bundle transport mechanism, the concrete key-derivation scheme, the concrete operator-backup mechanism, and similar) are not requirements.

### 1. Bitcoin L1 as the only base

zkCoins settles exclusively on Bitcoin mainnet Layer 1. It introduces no separate blockchain, no native token, and no separate consensus or validator set, and it requires no change to Bitcoin's consensus rules (no soft-fork, no hard-fork). It must run against Bitcoin as it exists today.

### 2. Private

From public on-chain data alone, no observer can determine a payment's amount, asset, sender, or receiver, nor link two on-chain events to the same coin, account, or user. The anonymity set is global — every coin in the system — not a fixed decoy ring or a per-round participant set.

### 3. Trustless

The integrity of funds is enforced by cryptography and Bitcoin alone. No party — a node operator, a public node, any setup procedure, trusted hardware, or a federation — can steal, forge (create coins it is not entitled to), double-spend, or freeze coins it does not own. One boundary is the holder's **own delegation choice**: the prover a holder itself selects to build a proof can, within that one cooperatively-signed transition, misdirect or destroy the outputs it was asked to produce — it can never forge, double-spend, rotate the account's keys, or act without the holder's signature. This is a documented, registered limit ([D-17](/paper-conformance-analysis)) whose trustless path is self-hosting, exactly parallel to Requirement 4's own-node model.

### 4. Client-side validation

A receiver — itself, or its own node acting on its behalf — accepts a coin only after independently verifying its full validity proof; correctness never depends on trusting the sender, a foreign node, or any third party. (Following the Bitcoin full-node model, the thin wallet trusts *its own* node exactly as a Bitcoin wallet trusts its own `bitcoind`; the trustless path is self-hosting that node, not bolting verification onto the wallet.)

### 5. Custody only in the wallet

The key that authorizes spending exists only on the user's wallet and is never transmitted to or stored on any node or server. The wallet is exclusively a seed custodian — its sole job is holding the seed and the keys derived from it — and must not be relied upon to store any other information, such as coin bundles or account state. Losing the wallet software and the seed backup at the same time makes any funds it controlled permanently and irrecoverably lost; this is not a defect but a direct consequence of self-custody, exactly as with a Bitcoin seed.

### 6. Recovery

The seed is the root from which all keys are deterministically derived. The complete state must be recoverable: normally from the node operator's own backup, and — as an emergency fallback after total loss of local data — from the seed, the public Bitcoin chain, and the coin data retained by the network's seed-discoverable relays and blob stores — recoverable under the §4.10 operational conditions (a reachable bootstrap node, ≥1 live holder per plane, and continuity-preserving manifest rotation) ([spec §4.3](/specification#43-addressing-for-delivery), [spec §4.10](/specification#410-responsibility-boundaries-and-the-availability-model-normative)).

### 7. Self-hostable

Anyone can run their own node; using zkCoins must never require trusting or depending on any specific operator.

### 8. Multi-asset

The protocol supports multiple distinct asset types, each identified by a globally unique asset id. Every other requirement applies equally to every asset.

### 9. Selective disclosure

The holder of an account can voluntarily disclose, to a recipient of its choosing, a precisely bounded view of its own activity — and nothing beyond that bound. The protocol supports at least three granularities: (a) a single transaction; (b) the current balance of one asset, revealing no transaction amounts or counterparties and no transaction beyond the single on-chain anchor the attestation stands on (a documented v1 limit; a leak-free set-membership anchor is the planned upgrade — see [spec §5.7](/specification#57-balance-attestation-history-private) — accepted as final for v1 by explicit project decision (2026-07-22)) — the balance attestation stands on the account's most recent anchored state, and because **every** state-advancing transition (send, receive, and mint) now publishes an on-chain state nullifier ([spec §3.10](/specification#310-transaction-states)), that anchor tracks the latest state; and (c) the account's full transaction history. Every disclosure is read-only — it never confers spend authority — and every disclosed fact must be cryptographically verifiable — never asserted by any node or explorer — against Bitcoin: each state-advancing transition in a coin's lineage is checked to be the **first occurrence** of its account-state nullifier on Bitcoin (see [spec §3.10](/specification#310-transaction-states), [§5.6](/specification#56-shareable-confirmation-links)). Disclosure is opt-in: absent one, the privacy of Requirement 2 holds in full. Any explorer that presents such disclosures must be self-hostable.

### 10. Node portability

A wallet — the holder of the seed — can switch nodes at any time and can use multiple nodes simultaneously. A wallet must not depend on any node-specific **value-bearing** state; every conforming node is interchangeable for custody and transacting, and no node can lock a wallet's funds in. Non-value-bearing operational state and its portability limits — including the retained contact record required to preserve DNS-free known-contact behavior across a node switch — must be stated explicitly ([spec §6.3](/specification#63-node-portability-and-multi-node-operation)).

### 11. Standard identity and messaging

An account's Nostr identity key is one of the keys [Requirement 6](#6-recovery) derives from the seed, and its payment identifier is fixed by those keys alone. Human one-to-one messaging is standard Nostr NIP-17 carried by that same seed-derived Nostr identity key; it must interoperate bidirectionally with ordinary Nostr clients and must never require a zkCoins-specific message kind, endpoint, profile field, or capability marker. NIP-17 remains the mandatory one-to-one profile in v1. Marmot/MLS group chat (`group_chat`, [Group chat](/group-chat)) is a **v2 feature — NOT applicable in v1**.

The app and API layers give every account they serve an email-style NIP-05 name such as `alice@example.com`, resolve names, and publish the signed payment object bound to the name, so the account is reachable and payable by it. The node kernel works from public keys.

An account has one name in force at a time, and the account holder attests it with the wallet-only spend key, so a consumer can establish that the seed holder — not merely whoever holds the node-held Nostr key — put that name on that identity. Every app verifies that attestation before it accepts a name for a counterparty. A name is not derived from the seed, enters no value-bearing structure, and carries no payment authority; it can be replaced without affecting keys, funds, or an established contact, and losing it costs reachability under that name and nothing else. Lightning/LNURL and SMTP/email remain independent, optional operator services in v1 and are prerequisites for nothing. Marmot/MLS group chat is a **v2 feature — NOT applicable in v1**, not a v1-optional service.

*(That end-user applications present names rather than raw identifiers is an application requirement, stated for the `app` layer in the [Implementation Mandate](/implementation-mandate#app-layer-identity-and-contacts-normative).)*

### 12. Data Permanence

A node never deletes data it has received or stored. Every artefact a node takes in — a `CoinProof` bundle, a delivery event, a `SelfDeliveryRecordV1`, a stored blob, any record it persists on an account's behalf — is stored **completely** and retained **indefinitely**. Deletion, dropping, expiry, pruning, garbage collection, retention-policy eviction, and "supersession" clean-up are **not** operations the protocol supports: there is no path by which a conforming node or API discards received data. The same holds for every layer — the kernel, the API, and any relay or blob store a node operates — because a coin's spendability and an account's next-transition credential live entirely in these off-chain artefacts, and losing any of them is losing funds permanently ([spec §4.8](/specification#48-durability--the-store-everything-invariant)).

A sender therefore keeps its own copy of everything it has sent, for good; a recipient and every holder keep everything they receive, for good. Redundancy across independent holders only adds copies — it is never a licence to drop one. An acknowledgement or a durability confirmation tells a sender its data survived elsewhere; it never permits the sender to delete its own.

Access revocation withdraws authorization but erases nothing: it permanently ceases use of the operational bundle while all stored data remains retained. Revoking a node's grant to an account's operational bundle makes that node **immediately and permanently cease all use** of the bundle (proving, discovery, decryption, serving) — a custody/access control, not a deletion of the account's value-bearing records, which remain stored under Data Permanence.

A node is data-retentive by default: everything it can capture, it captures and keeps. At the moment it accepts an incoming coin it takes in the coin's complete token provenance — its `asset_terms`, when the bundle carries them — alongside the bundle itself, so the token remains alive and transferable even if its issuer later disappears ([spec §4.6](/specification#46-data-availability), [spec §4.8](/specification#48-durability--the-store-everything-invariant)). Because losing this data can lose funds, the node operator must maintain a real-time, restorable backup of the node's value-bearing PostgreSQL store and its blob store at all times; the backup mechanism itself is a deployment and hosting concern, deliberately out of scope for the node software, but operating a node without one violates this requirement ([spec §4.8](/specification#48-durability--the-store-everything-invariant) *Operator durability duty*).

**Exception — Marmot application messages only (v2 only — NOT applicable in v1).** When protocol v2 has activated `group_chat`, Marmot MLS **application** messages **MAY** follow the group's Marmot `message-retention` / NIP-40 expiry ([Group chat](/group-chat)). This exception does **not** apply in v1, and does **not** apply to value-bearing artefacts (`CoinProof` bundles, delivery events, `SelfDeliveryRecordV1`, blobs, `asset_terms`), to stored NIP-17 messages, or to Marmot commits and proposals, which never expire. A relay the node operates **MAY** honour that NIP-40 tag on a kind-445 application message only.

### 13. Recovery availability from the seed alone

A wallet that has lost everything except its seed can fully recover its state — every value-bearing artefact addressed to it — as long as it can reach one node to fetch and verify the current signed Bootstrap Manifest (a reachable node base URL) and at least one holder of each plane of that data is still live and reachable: its own node's backup, a self-hosted relay and blob store, or a seed-discoverable relay (for the delivery event) together with a seed-discoverable blob store (for the blob). This is guaranteed by the recovery-discoverable overlap invariant — the publishing node **must** publish every delivery event to at least one of the network's seed-discoverable relays **and** store every value-bearing blob in at least one of the network's seed-discoverable blob stores, so a seed-only scan of that set finds both the locator and the bytes of everything ever addressed to the account, as long as manifest rotation has preserved recovery-discoverability ([spec §4.3](/specification#43-addressing-for-delivery)). Every value-bearing artefact is additionally published, encrypted, to the Nostr relay plane (its event) and the Blossom blob plane (its blob) as a second redundancy layer, and any participant may run and sync their own relay and blob store rather than depend on any one node ([spec §4.6](/specification#46-data-availability)). A token survives the loss of its issuer: it remains transferable from its own `CoinProof` bundle and the chain alone, and its display terms are openly resolvable by `asset_id` from any holder that has retained them, as long as ≥1 such holder exists ([spec §4.5](/specification#45-recovery), [spec §4.10](/specification#410-responsibility-boundaries-and-the-availability-model-normative)).
