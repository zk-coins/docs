---
title: Risks
---

# Known Risks & Limitations

This page documents the known risks, limitations, and open problems of the zkCoins **target design** — the protocol defined in the [Specification](/specification), which is the single normative source ([Implementation Mandate](/implementation-mandate)). Current implementation status — what the running node does today versus the spec — is **not** in scope here; it is tracked in the project's implementation roadmap (in the [node repository](https://github.com/zk-coins/node)). How the project verifies the design against these risks — and the gates that verification imposes before launch — is defined in the [Assurance Roadmap](/assurance). Transparency about limitations is essential.

:::warning Remediation in progress
The [paper-deviation analysis](/paper-conformance-analysis) records paper-conformance, publisher-contention and ledger-availability findings against an earlier fixed-size off-chain-batch design (`docs@6816fc3`, pre-#97). [PR #97](https://github.com/zk-coins/docs/pull/97) landed the accepted architecture direction — on-chain half-aggregated state nullifiers, Bitcoin first occurrence and conditional NAV — in the normative spec; [Paper-Conformance Remediation](/paper-conformance-remediation) tracks the executable-conformance and assurance gates that remain. Until those gates close, the target design is research-stage and must not carry real value.
:::

## Data availability and recovery

**Risk: Losing your coin data means losing the coins.**

zkCoins is client-side-validated: a coin's spendability lives entirely in its off-chain `CoinProof` bundle and the recursive proof it carries. Bitcoin holds the on-chain state nullifiers needed to rebuild the public double-spend set, but it does **not** hold the private coin value or proof and therefore cannot reconstruct a lost `CoinProof` ([spec §3.1](/specification#31-the-on-chain-object), [§4.5](/specification#45-recovery)). Unlike a regular Bitcoin wallet, **seed-phrase recovery alone is insufficient**: the seed re-derives every key and detection tag, but a coin's *value* is a choice someone else made and exists only inside the bundle.

**Mitigation:** The protocol makes durability a hard requirement, not best-effort caching. A node MUST persist every value-bearing artefact before acting on it (the store-everything invariant, [spec §4.8](/specification#48-durability--the-store-everything-invariant)); every encrypted `CoinProof` bundle and its delivery event are replicated to at least `k = 3` independent holders ([spec §4.6](/specification#46-data-availability--replication-factor-k)); and change/state bundles are self-delivered to the owner's own relay set, so a second device — or a wallet recovering from seed alone — can rebuild the full spendable state ([spec §4.2](/specification#42-bundle-delivery), [§4.5](/specification#45-recovery)). The residual risk is irreducible: if every replica of a `CoinProof` bundle is lost, that coin is unspendable forever. Availability is never a custody risk — an unavailable bundle can never be spent by anyone else — and it cannot make two honest scanners disagree on the public accumulator, which both rebuild from Bitcoin alone ([spec §3.6](/specification#36-chain-scanning), [§4.6](/specification#46-data-availability--replication-factor-k)). Research on UTxO binding for data availability is ongoing ([ePrint 2025/569](https://eprint.iacr.org/2025/569)).

## Node storage growth

**Risk: A validating node's nullifier accumulator only ever grows.**

A Path-A node maintains the global nullifier accumulator by scanning Bitcoin, and its state grows with the total number of state-advancing transitions ever made ([spec §3.7](/specification#37-the-nullifier-accumulator)). The accumulator **cannot prune by age**: nullifier keys are uniformly distributed, so "old" maps to no discardable region, and every inserted `Pkᵢ` must stay represented to answer both membership and arbitrary non-membership against the current tip ([spec §3.7](/specification#37-the-nullifier-accumulator)). Only never-occupied key-space is free.

**Mitigation:** This is an inherent local validation cost of any client-side-validated, first-occurrence accumulator — the same monotonic-set property Zcash's nullifier set and Shielded CSV carry — not a free-rider structure or a safety issue. The on-chain footprint stays ~64 bytes per transition regardless ([spec §3.8](/specification#38-fees-and-economics)); the growth is confined to a validating node's own local index, and a node MAY exploit the tree's sparseness, since never-occupied regions of the 256-bit key space are implicit default subtrees that need not be stored ([spec §3.7](/specification#37-the-nullifier-accumulator)).

## Proving cost and latency

**Risk: Building a transition is computationally expensive, so payments are not instant.**

Each state-advancing transition — send, receive, or mint — carries a recursive zero-knowledge validity proof. Generating it is CPU-intensive — on the order of seconds to minutes — with the foreign-field BIP-340 verification and in-circuit SHA-256 dominating the cost ([spec §2.6](/specification#26-in-circuit-non-native-cryptography-normative)). The account advancing its state waits for proving and signing before the transition nullifier can be handed to a publisher and anchored.

**Mitigation:** Proving is **node-side**: the node runs the prover, while the wallet stays a thin key-holder that only signs ([spec §6.1](/specification#61-components-and-responsibilities), [§6.2](/specification#62-wallet--node)). Self-hosting means you bear the proving cost on your own hardware; using a public proving service offloads it at the privacy cost below. Verification of an already-built recursive proof, by contrast, is **constant-time** regardless of a coin's history ([spec §2.2](/specification#22-proof-types)).

## Node plaintext visibility

**Risk: A node you delegate to sees your transaction details.**

A node you delegate to holds the operational bundle (`ivk` / `ovk` / `op` / `nk` / `op_secret`) and therefore sees the account's plaintext — amounts, assets, senders, and recipients ([spec §6.1](/specification#61-components-and-responsibilities), [§6.2](/specification#62-wallet--node), [§6.6](/specification#66-threat-model-and-trust-configurations)). A **public proving service** is exactly such a delegate — a hosted account gives the provider the full operational bundle, including `ivk` ([spec §6.4](/specification#64-external-interfaces-abstract)) — so its view is **not** scoped to the transitions it proves: it gains a standing, whole-account decrypt view of every coin sent to the account for as long as it holds the bundle, and an abandoned node keeps that view because the account's viewing keys cannot be rotated without moving to a new account ([spec §6.3](/specification#63-node-portability-and-multi-node-operation)). Your **own** node holds the same bundle and sees the same plaintext, but leaks nothing because you are the operator. A foreign node used only for bounded reads receives a scoped view grant rather than the operational bundle, but it still learns everything released within that grant's scope ([spec §5.2](/specification#52-view-grant)).

**Mitigation:** Self-host. Your own node verifies your transactions and sees your plaintext, and since you are the operator, nothing leaks — trustlessness and privacy at once ([spec §6.6](/specification#66-threat-model-and-trust-configurations)). The SPEND branch never leaves the wallet in any configuration ([spec §1.2](/specification#12-key-hierarchy)), so a node — yours or foreign — can never steal, forge, or double-spend; only privacy and liveness are delegated.

## Wallet key custody

**Risk: The wallet device is the custody boundary.**

The wallet holds the seed and is the sole custodian of the SPEND branch (`skᵢ`); the spend key never leaves it ([spec §1.2](/specification#12-key-hierarchy)). A compromised wallet endpoint can extract it. (`nk` — own hardened branch `A/3'` — is derived from the seed but delegated to the wallet's *own* node as part of the operational bundle so the node can build proving witnesses; it cannot spend, only link the account's own spends.)

**Mitigation:** The key hierarchy is hardened so that the operational bundle a wallet delegates to a node (`ivk` / `ovk` / `op` / `nk` / `op_secret`) **cannot** derive the SPEND branch ([spec §1.2](/specification#12-key-hierarchy)) — a captured node, or a leaked view grant, never yields spend authority. Securing the wallet device itself (key storage at rest, authentication) is the user's responsibility, as with any self-custodial wallet.

## Coin creation time leak

**Risk: The approximate creation time of a coin is revealed to its receiver.**

The sender discloses an upper bound on when the coin was created, so the receiver knows how many confirmations to expect. Additionally, multiple outputs of the same transaction may be linkable to each other.

**Mitigation:** Wallets should create a single output per transaction where unlinkability matters. The protocol authors acknowledge this leak and are exploring mitigations (see [paper section 6.3](https://eprint.iacr.org/2025/068)).

## Anonymity set depends on usage

**Risk: Privacy strengthens with adoption.**

The anonymity set is global — every coin in the system — but if very few people transact, that set is small and timing analysis on the stream of nullifier inscriptions could reveal patterns. The privacy guarantees strengthen as adoption grows.

**Structural note:** The set is global by construction (the asset and amount are hidden, so coins never partition per-asset, [spec §3.5](/specification#35-inscription-format)), so it grows with total usage rather than per-round participation — but it is still bounded by real adoption.

## Publisher censorship and delay

**Risk: A chosen publisher can refuse to publish a valid transition or delay it.**

A publisher receives a transition nullifier and fee `CoinProof`, half-aggregates signatures, and broadcasts the inscription. It holds no spend key, recursive proof, coin plaintext, or consensus-critical off-chain data, so it cannot forge a transition or steal funds; its only protocol-level power is to withhold or delay publication ([spec §3.4](/specification#34-the-publisher)).

**Mitigation:** Publishing is permissionless and contention-free. A nullifier references no shared accumulator root and cannot go stale merely because another publisher writes first, so the account can submit the same nullifier to another publisher or have its own node self-publish it; redundant publication is idempotent under the first-occurrence rule ([spec §3.4](/specification#34-the-publisher), [§3.6](/specification#36-chain-scanning)). Half-aggregation lowers fees but is not required for correctness or liveness.

## Interactive receive

**Risk: Receiving a payment requires the recipient to be reachable.**

A payment is delivered as an off-chain `CoinProof` bundle that the sender hands to the recipient over the relay mesh ([spec §4.2](/specification#42-bundle-delivery)); the recipient must fetch and verify it before the coin is credited ([spec §2.3.3](/specification#233-receive)). There is no purely on-chain receive: Bitcoin carries the creating transition's opaque state nullifier, not the coin value, proof, or encryption envelope.

**Mitigation:** Delivery is store-and-forward, so the recipient need not be online at send time — only eventually reachable. Relays retain the gift-wrapped bundle until the recipient (or its always-on node) comes online and runs the `detect_tag` scan ([spec §4.2](/specification#42-bundle-delivery), [§4.4](/specification#44-note-discovery)); the always-on node, not the wallet, holds the live subscription and verifies on the wallet's behalf ([spec §4.9](/specification#49-real-time-push-delivery)). The sender retains and replicates its copy until it receives an acknowledgement ([spec §4.2](/specification#42-bundle-delivery)).

## Unobservable total supply

**Risk: A v1 asset's aggregate supply is unobservable, so a creator's over-issuance is undetectable as to quantity.**

v1 issuance is bound to the creator's spend key but uncapped. Because coin amounts are zero-knowledge, no party — holder, node, or explorer — can sum an asset's total supply. Every mint is nevertheless a state-advancing transition that anchors on Bitcoin by publishing an on-chain nullifier `(Pkᵢ, Rᵢ)` ([spec §2.3.1](/specification#231-mint--issuance), [§3.10](/specification#310-transaction-states)). Issuance frequency and timing are therefore chain-visible; only the minted amount stays hidden, so a creator can inflate supply undetectably only as to quantity, not as to the fact that mints happened.

This anchoring closes the mint-fork: two mints advancing from the same prior state share the same `current_pubkey = Pkᵢ` and publish the same nullifier key. The global accumulator admits each `Pkᵢ` at most once by first-occurrence ([§3.6](/specification#36-chain-scanning)), so a creator cannot issue two conflicting coins against one state.

**Mitigation:** Holders trust the creator as they would any single-issuer asset. Protocol-enforced, auditable supply is deferred to a future issuance schema (`IssuanceTerms_v2`), which would bound total emission with an in-circuit `cap_total` ([spec §6.5](/specification#65-issuance--versioned-schemas-v1-minimal)).

## Carrying real Bitcoin requires a bridge

**Risk: The protocol moves shielded coins, not on-chain BTC.**

zkCoins settles its own coins on Bitcoin L1 for ordering and anchoring, but a coin in the system is not itself on-chain BTC — permissionless native assets are the protocol's value model. Carrying real Bitcoin value in and out requires a **bridge**, which is outside the protocol; a fully trustless bridge is an open research problem (an N-of-M federation at launch, a 1-of-n BitVM bridge as the target — see the [bridge research](https://github.com/zk-coins/research/blob/develop/zkcoins-design/BITVM_BRIDGE.md)).

**Mitigation:** The protocol's trustless guarantees do not depend on a bridge, and native assets need none. A bridge is a separate, out-of-protocol component: a federation can censor or, at its threshold, collude, while the BitVM target needs only 1-of-n honesty (funds are burned rather than stolen if all operators cheat).

## No smart contracts

**Risk: zkCoins supports only payments.**

There is no programmable application state, no smart-contract execution, and no DeFi. The global nullifier accumulator serves only double-spend detection; lending, a DEX, or other smart-contract use cases are out of scope for the protocol.

**Possible future:** Combination with RGB for programmable logic on Bitcoin L1.

## Regulatory uncertainty

**Risk: Privacy protocols face increasing regulatory scrutiny.**

Tornado Cash (OFAC-sanctioned 2022), Samourai Wallet (founders arrested 2024), and the GENIUS Act (2025) show that privacy tools attract regulatory attention.

**Structural advantage:** Unlike mixers, zkCoins has no coordinator, no smart-contract address, and no central service that can be sanctioned. It is a peer-to-peer protocol, comparable to Bitcoin itself.
