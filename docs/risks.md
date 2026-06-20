---
sidebar_position: 8
title: Risks
---

# Known Risks & Limitations

This page documents the known risks, limitations, and open problems of the zkCoins **target design** — the protocol defined in the [Specification](/specification), which is the single normative source ([Implementation Mandate](/implementation-mandate)). Current implementation status — what the running node does today versus the spec — is **not** in scope here; it is tracked in the [Roadmap](/roadmap). Transparency about limitations is essential.

## Data availability and recovery

**Risk: Losing your coin data means losing the coins.**

zkCoins is client-side-validated: a coin's spendability lives entirely in its off-chain `CoinProof` bundle and the recursive proof it carries. Bitcoin holds only the opaque `BatchInscription` ([spec §3.1](/specification#31-the-on-chain-object)), which cannot reconstruct a lost proof. Unlike a regular Bitcoin wallet, **seed-phrase recovery alone is insufficient**: the seed re-derives every key and detection tag, but a coin's *value* is a choice someone else made and exists only inside the bundle ([spec §4.5](/specification#45-recovery)).

**Mitigation:** The protocol makes durability a hard requirement, not best-effort caching. A node MUST persist every value-bearing artefact before acting on it (the store-everything invariant, [spec §4.8](/specification#48-durability--the-store-everything-invariant)); every bundle is replicated to at least `k = 3` independent holders ([spec §4.6](/specification#46-data-availability--replication-factor-k)); and change/state bundles are self-delivered to the owner's own relay set, so a second device — or a wallet recovering from seed alone — rebuilds the full spendable state ([spec §4.2](/specification#42-bundle-delivery), [§4.5](/specification#45-recovery)). The residual risk is irreducible: if every replica of a `CoinProof` bundle is lost, that coin is unspendable forever. Availability is never a custody risk — an unavailable bundle can never be spent by anyone else ([spec §4.6](/specification#46-data-availability--replication-factor-k)). Research on UTxO binding for data availability is ongoing ([ePrint 2025/569](https://eprint.iacr.org/2025/569)).

## Proving cost and latency

**Risk: Building a transition is computationally expensive, so payments are not instant.**

Each transition carries a recursive zero-knowledge validity proof. Generating it is CPU-intensive — on the order of seconds to minutes — with the foreign-field BIP-340 verification and in-circuit SHA-256 dominating the cost ([spec §2.6](/specification#26-in-circuit-non-native-cryptography-normative)). The sender waits for proving before the `SpendRecord` can be handed to a publisher and anchored.

**Mitigation:** Proving is **node-side**: the node holds the operational bundle and runs the prover, while the wallet stays a thin key-holder that only signs ([spec §6.1](/specification#61-components-and-responsibilities), [§6.2](/specification#62-wallet--node)). Self-hosting means you bear the proving cost on your own hardware; delegating to a node offloads it (at the privacy cost below). Receipt verification, by contrast, is **constant-time** regardless of a coin's history ([spec §2.2](/specification#22-proof-types)), so the cost falls on the sender, never the receiver.

## Node plaintext visibility

**Risk: A node you delegate to sees your transaction details.**

A node that proves and serves on your behalf holds your operational bundle (`ivk` / `ovk` / `op`) and therefore sees your plaintext — amounts, assets, senders, and recipients ([spec §6.1](/specification#61-components-and-responsibilities), [§6.6](/specification#66-threat-model-and-trust-configurations)). Using someone else's node discloses this to that operator — the same spectrum as pointing a Bitcoin wallet at someone else's Electrum server.

**Mitigation:** Self-host. Your own node verifies your transactions and sees your plaintext, and since you are the operator, nothing leaks — trustlessness and privacy at once ([spec §6.6](/specification#66-threat-model-and-trust-configurations)). The SPEND branch never leaves the wallet in any configuration ([spec §1.2](/specification#12-key-hierarchy)), so a node — yours or foreign — can never steal, forge, or double-spend; only privacy and liveness are delegated.

## Wallet key custody

**Risk: The wallet device is the custody boundary.**

The wallet holds the seed and is the sole custodian of the SPEND branch (`skᵢ`, `nk`); these keys never leave it ([spec §1.2](/specification#12-key-hierarchy)). A compromised wallet endpoint can extract them.

**Mitigation:** The key hierarchy is hardened so that the view/operational keys a wallet delegates to a node (`ivk` / `ovk` / `op`) **cannot** derive the SPEND branch ([spec §1.2](/specification#12-key-hierarchy)) — a captured node, or a leaked view grant, never yields spend authority. Securing the wallet device itself (key storage at rest, authentication) is the user's responsibility, as with any self-custodial wallet.

## Coin creation time leak

**Risk: The approximate creation time of a coin is revealed to its receiver.**

The sender discloses an upper bound on when the coin was created, so the receiver knows how many confirmations to expect. Additionally, multiple outputs of the same transaction may be linkable to each other.

**Mitigation:** Wallets should create a single output per transaction where unlinkability matters. The protocol authors acknowledge this leak and are exploring mitigations (see [paper section 6.3](https://eprint.iacr.org/2025/068)).

## Anonymity set depends on usage

**Risk: Privacy strengthens with adoption.**

The anonymity set is global — every coin in the system — but if very few people transact, that set is small and timing analysis on the stream of `BatchInscription`s could reveal patterns. The privacy guarantees strengthen as adoption grows.

**Structural note:** The set is global by construction (the asset and amount are hidden, so coins never partition per-asset, [spec §3.5](/specification#35-inscription-format)), so it grows with total usage rather than per-round participation — but it is still bounded by real adoption.

## Publisher concentration

**Risk: The serial accumulator plus prove-before-ordering pressures the publisher role toward a single dominant operator.**

The nullifier accumulator advances strictly sequentially: every `BatchInscription` must declare `prev_root` equal to the most recently admitted `new_root`, so at most one batch is admitted per ordering slot ([spec §3.4](/specification#34-the-publisher), [§3.6](/specification#36-chain-scanning)). A publisher must build the recursive `AggregateBatchProof` — the dominant proving cost of the system ([spec §2.6](/specification#26-in-circuit-non-native-cryptography-normative)) — *before* it knows whether it wins the Bitcoin-ordering race for that `prev_root`. A losing publisher's proof is bound to the now-consumed `prev_root`, is unrecoverable, and earns no fee (the fee coin of an un-anchored transition never reaches `completed`, [spec §3.8](/specification#38-fees-and-economics)). Unlike Bitcoin mining, where a losing miner's work is fungible and rolls into the next block, here the work is batch-specific and lost. The expected-value asymmetry favours the fastest, best-capitalised, lowest-latency operator — a centralization pressure on a role the protocol describes as permissionless.

**Mitigation:** Publishing is permissionless and self-publishing is always available — a wallet may act as its own publisher with a single-member batch at trivial proving cost ([spec §3.4](/specification#34-the-publisher)), which caps any dominant publisher's rent and preserves censorship resistance. Publishers also batch over a bounded interval, which desynchronizes most batches so that head-to-head races on the same `prev_root` are the exception, not the steady state. No publisher holds custody or is trusted for correctness, so concentration never endangers funds; the worst a publisher can do is censor or delay. Publisher incentive and permissionless-batching economics are tracked as open design work (see the [roadmap](/roadmap)).

## Publisher griefing via conflicting SpendRecords

**Risk: A spender can fan out conflicting SpendRecords to many publishers, forcing all but one to waste a batch proof at near-zero cost to the spender.**

A spender can sign N conflicting `SpendRecord`s that share the same input nullifiers but differ in their output or fee coin — each verifies individually, because a per-account proof makes no in-circuit claim of global non-membership ([spec §2.1](/specification#21-the-compliance-predicate)). Handing one to each of N publishers makes each independently build a full `AggregateBatchProof`. Once one batch is admitted, the shared `nf` enters the accumulator; every competing batch is then stale ([spec §3.6](/specification#36-chain-scanning)) and, because admission is all-or-nothing ([spec §3.10](/specification#310-transaction-states)), any innocent co-members batched alongside the conflicting record are dropped from that admission and must be re-batched. The losing publishers collect nothing ([spec §3.8](/specification#38-fees-and-economics)), so the spender can impose N − 1 dominant-cost proofs plus collateral re-batching for at most one forfeited fee coin.

**Mitigation:** The attack is wasted-work griefing, not a safety break: nullifier idempotence guarantees at most one of the competing transitions ever settles ([spec §3.7](/specification#37-the-nullifier-accumulator)), funds are never lost or double-spent, and innocent co-members are re-batched rather than dropped permanently. A publisher may non-membership-check each offered `nf` against the live accumulator and verify the fee coin before committing proving cost ([spec §3.8](/specification#38-fees-and-economics)), and may price fees to cover expected wasted-proof risk; the irreducible loss is bounded by the concurrent-race window. No deposit-based or on-chain defence is specified in v1; this ties to the open publisher-economics work (see the [roadmap](/roadmap)).

## BatchBundle data availability and retention incentive

**Risk: Perpetual BatchBundle retention is an unbounded, unrewarded cost, and universal loss of a bundle is a network soft fork.**

The accumulator cannot prune by age (nullifiers are uniformly distributed, so "old" maps to no discardable region, [spec §3.7](/specification#37-the-nullifier-accumulator)), and value-bearing data has no expiry ([spec §4.8](/specification#48-durability--the-store-everything-invariant)), so storage grows monotonically. The only payment in the system, the fee coin ([spec §3.8](/specification#38-fees-and-economics)), pays a publisher for anchoring its own batch; nothing pays a scanner to retain *other* publishers' bundles. A `CoinProof` has a natural self-interested holder (the recipient — it is their custody), but a `BatchBundle` does not, so the spec supplies one via an unrewarded MUST to retain every admitted bundle indefinitely ([spec §4.6](/specification#46-data-availability--replication-factor-k)). This is a free-rider structure: a rational operator's incentive is to rely on others to retain, and the prune guard (drop only once `k = 3` peers still hold it) can drive the replica count toward `k` rather than monotonic growth. Universal long-term unavailability of an admitted bundle leaves its accumulator transition forever unconfirmable — a soft fork between nodes that admitted it before the loss and nodes that never could ([spec §4.6](/specification#46-data-availability--replication-factor-k)).

**Mitigation:** Availability is a liveness property, never a safety property: an unavailable bundle can never cause theft or a forged credit, and a missing bundle leaves an inscription `pending`, never silently admitted ([spec §3.6](/specification#36-chain-scanning), [§4.6](/specification#46-data-availability--replication-factor-k)). To be a trustless Path-A verifier a node must itself hold and verify every `BatchBundle` to maintain its own nullifier set ([spec §3.7](/specification#37-the-nullifier-accumulator)), so retention is partly the operator's own validation cost rather than pure altruism — the Bitcoin full-node model the system targets. The `k = 3` replication plus the store-everything retention regime ([spec §4.6](/specification#46-data-availability--replication-factor-k), [§4.8](/specification#48-durability--the-store-everything-invariant)) makes universal loss require the simultaneous failure of every honest scanner that processed the bundle. No archival incentive (paid pinning, proof-of-retention reward) exists in v1.

## Interactive receive

**Risk: Receiving a payment requires the recipient to be reachable.**

A payment is delivered as an off-chain `CoinProof` bundle that the sender hands to the recipient over the relay mesh ([spec §4.2](/specification#42-bundle-delivery)); the recipient must fetch and verify it before the coin is credited ([spec §2.3.3](/specification#233-receive)). There is no purely on-chain receive — the chain carries only the opaque `BatchInscription`.

**Mitigation:** Delivery is store-and-forward, so the recipient need not be online at send time — only eventually reachable. Relays retain the gift-wrapped bundle until the recipient (or its always-on node) comes online and runs the `detect_tag` scan ([spec §4.2](/specification#42-bundle-delivery), [§4.4](/specification#44-note-discovery)); the always-on node, not the wallet, holds the live subscription and verifies on the wallet's behalf ([spec §4.9](/specification#49-real-time-push-delivery)). The sender retains and replicates its copy until it receives an acknowledgement ([spec §4.2](/specification#42-bundle-delivery)).

## Carrying real Bitcoin requires a bridge

**Risk: The protocol moves shielded coins, not on-chain BTC.**

zkCoins settles its own coins on Bitcoin L1 for ordering and anchoring, but a coin in the system is not itself on-chain BTC. Carrying real Bitcoin value in and out requires a **bridge**, and a fully trustless bridge is not yet available: the launch path is an N-of-M federation, and the target is a 1-of-n BitVM bridge still under active research ([Bridging](/architecture/bridging)).

**Mitigation:** The bridge is explicitly outside the shielded-payment protocol ([Bridging](/architecture/bridging)); the core's trustless guarantees do not depend on it, and permissionless native assets need no bridge at all. A federation can censor or, at its threshold, collude — a known limitation of the launch bridge, removed by the BitVM target (1-of-n honesty, funds burned rather than stolen if all operators cheat).

## No smart contracts

**Risk: zkCoins supports only payments.**

There is no global state, no programmability, no DeFi. Lending, a DEX, or other smart-contract use cases are out of scope for the protocol.

**Possible future:** Combination with RGB for programmable logic on Bitcoin L1.

## Regulatory uncertainty

**Risk: Privacy protocols face increasing regulatory scrutiny.**

Tornado Cash (OFAC-sanctioned 2022), Samourai Wallet (founders arrested 2024), and the GENIUS Act (2025) show that privacy tools attract regulatory attention.

**Structural advantage:** Unlike mixers, zkCoins has no coordinator, no smart-contract address, and no central service that can be sanctioned. It is a peer-to-peer protocol, comparable to Bitcoin itself.
