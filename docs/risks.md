---
title: Risks
---

# Known Risks & Limitations

This page documents the known risks, limitations, and open problems of the zkCoins **target design** — the protocol defined in the [Specification](/specification), which is the single normative source ([Implementation Mandate](/implementation-mandate)). Current implementation status — what the running node does today versus the spec — is **not** in scope here; it is tracked in the project's implementation roadmap (in the [node repository](https://github.com/zk-coins/node)). How the project verifies the design against these risks — and the gates that verification imposes before launch — is defined in the [Assurance Roadmap](/assurance). Transparency about limitations is essential.

:::warning Remediation in progress
The [paper-deviation analysis](/paper-conformance-analysis) records paper-conformance, publisher-contention and ledger-availability findings against an earlier fixed-size off-chain-batch design (`docs@6816fc3`, pre-#97). [PR #97](https://github.com/zk-coins/docs/pull/97) landed the accepted architecture direction — on-chain half-aggregated state nullifiers, Bitcoin first occurrence and conditional NAV — in the normative spec; [Paper-Conformance Remediation](/paper-conformance-remediation) tracks the executable-conformance and assurance gates that remain. Until those gates close, the target design is research-stage and must not carry real value.
:::

## Verdicts at a glance (v1 — closed)

Every incentive/residual verdict for v1, closed per the [Assurance Roadmap](/assurance) Workstream 1 (project decision 2026-07-22 — no open verdicts remain). `accepted v1 boundary` entries are registered in the [Paper-Deviation Analysis](/paper-conformance-analysis).

| Section | Verdict | Basis |
|---|---|---|
| Reorg finality bounded at 6 confirmations | **accepted v1 boundary** (D-16) | hard project directive; canonical replay ≤5, fail-stop ≥6 |
| Accumulator history relation vs ToS | CT-log consistency port fixed (**D-05**); bounded finality remains a separate **accepted v1 boundary** (D-16) | RFC-6962 Merkle-log consistency port — prefix succinctness/soundness fixed (D-05); the paper's DistinctElement no-op branch is still deliberately not built (D-16, bounded finality) |
| Data availability and recovery | **holds under stated assumptions** | store-everything + §4.3 seed-discoverable overlap (relay for the event, blob store for the blob) + encrypted Nostr/blob redundancy + operator backup duty; no fixed replica count, no quorum |
| Node storage growth | **holds** | linear operator cost, no adversarial lever; append-only-log storage (log or Merkle peaks + local `Pk → (pos, R)` index; no sparse key space, cannot prune by age) |
| Proving cost and latency | **holds under stated assumptions** | measured in the build report; impracticality resolves as a version bump, never silently |
| Node plaintext visibility | **holds under stated assumptions** (own-node trust model, [spec §6.6](/specification#66-threat-model-and-trust-configurations); not a register deviation — register D-17 is the hosted-prover redirect/burn) | operational bundle only to the account's own node |
| Send-output redirection, change-drop (burn), or **account freeze** by a dishonest **selected prover** (own or a vetted foreign node; consumes `Pkᵢ`) | **accepted v1 boundary** (D-17) | thin-client rule; self-host/vet mitigations |
| Wallet key custody | **holds** | SPEND branch never leaves the wallet; seed custody is the user's, as in Bitcoin |
| Coin creation time leak / co-output visibility | **accepted v1 boundary** (D-18) | bounded to one transition's co-holders (+ output-count bucket) |
| Publisher-observed spend linkage | **accepted v1 boundary** (D-19) | rotation/self-publish removes the edge at no cost |
| Anonymity set depends on usage | **holds under stated assumptions** | global set grows with adoption; no protocol lever |
| Publisher censorship and delay | **holds** | permissionless, contention-free publishing + self-publish escape; v1 publishing is sponsored, so a censored spender simply re-picks a publisher or self-publishes and forfeits nothing (covers D-09) |
| Sponsorship sustainability and unmetered admission | **holds under stated assumptions** (D-20) | a sponsor has no revenue and no admission proof; self-publish is the universal escape, and neither correctness nor custody depends on a publisher existing |
| Interactive receive | **holds under stated assumptions** | the receiver's own 24/7 node stands in; liveness-only, never safety |
| Availability is a multi-holder guarantee, not cryptographic | **accepted v1 boundary** | recovery needs ≥1 live holder (a seed-discoverable relay for the event + blob store for the blob, the sender's node, a self-hosted sync, or an operator backup); simultaneous total loss of every copy is unrecoverable, by design — the same rule as the seed |
| Open asset provenance reveals a token's name/terms by `asset_id` | **accepted v1 boundary** | deliberate open `asset_id → terms` lookup (Class B) bounded to issuer-originated terms; no transfer, holder, or amount; not a `name → asset_id` registry |
| Manifest `blob_store` open recovery-overlap upload (Sybil spam) | **accepted operational residual** | per-source admission control bounds but cannot cryptographically prevent Sybil-rotated spam — the same open-acceptance surface as an open `seed_relay`; operator admission policy |
| Operator backup duty enforced operationally, not by protocol | **holds under stated assumptions** | operator MUST keep a real-time backup of the PostgreSQL database and blob store; deliberately an out-of-repo hosting concern |
| Unobservable total supply (token standard 1) | **accepted v1 boundary** | documented issuer-trust (register D-13); token standard 2 provides the auditable cap |
| Carrying real Bitcoin requires a bridge | **holds** (out of core scope) | bridges are explicit, off-by-default operator extensions |
| No smart contracts | **holds** (by scope) | deliberate non-goal of v1 |
| Regulatory uncertainty | **n/a — not a protocol mechanism** | environment risk, catalogued for operators |

## Reorg finality is bounded at 6 confirmations (v1 project directive)

**Risk: a Bitcoin reorg of 6 or more blocks can orphan a final nullifier and break an account — v1 does not provide the paper's arbitrary-depth reorg recovery, fixing finality at 6 confirmations and treating a ≥6-block reorg as an accepted break.**

*Shielded CSV* makes reorgs of any depth survivable through a conditional-NAV no-op: an `exactly-one-of` predicate with a prefix branch **and** a provable `DistinctElement` no-op branch ([paper §4.2](https://eprint.iacr.org/2025/068)). The zkCoins circuit has only the unconditional `prefix(prev.nav, w.nav)` — no `DistinctElement` branch — so that no-op has no satisfiable witness ([issue #105](https://github.com/zk-coins/docs/issues/105)). Rather than build a novel no-op construction, zkCoins v1 adopts a **deliberate hard finality bound** ([spec §3.9](/specification#39-finality-and-reorg-handling)): 6 confirmations = final; reorgs ≤5 blocks are absorbed by canonical replay and strand no account (nothing final depends on a non-final nullifier); a reorg of **≥6 blocks MAY break zkCoins** and has no recovery path. This is an explicit, accepted v1 limitation, registered as a deviation in the [paper-deviation analysis](/paper-conformance-analysis) per the [paper-conformance rule](https://github.com/zk-coins/docs/blob/develop/CONTRIBUTING.md). The former "faithful conditional-NAV / arbitrary-depth" language has been removed from the spec.

## Accumulator history relation deviates from the paper's ToS accumulator

**Risk: the accumulator's history relation is a deliberate CT-consistency port, not the paper's ToS IsPrefix; the paper's DistinctElement no-op branch remains unbuilt (bounded finality).**

*Shielded CSV* uses a tuple-of-sets (ToS) accumulator whose history relations are an ordered `IsPrefix` and a `DistinctElement` at the same tuple position (paper §3.2, §3.6). The **prefix-succinctness defect** of the earlier design — an SMT leaf-preserving submap proof was linear in the intervening foreign insertions and could not be made constant-size in the circuit — is **fixed**: [spec §1.7.6](/specification#176-nullifier-accumulator-append-only-merkle-log) replaces the SMT with an append-only Merkle log and [spec §3.7](/specification#37-the-nullifier-accumulator) makes `prefix` an RFC 6962 / RFC 9162 **log-consistency** proof — constant size, independent of the gap, closing the buried-fork-loser the SMT-submap weakening left open.

**Two honest caveats:** (1) an ordered Merkle log is **more** reorg-order-sensitive than the order-independent SMT (reordering the same nullifier set changes the log root), so the non-final suffix of `NAV(tip)` beyond `size_final` may reshuffle — but a committed `nav`, always `size_final`, never does after a ≤5-block reshuffle — a **liveness** cost only, bounded by the [spec §3.9](/specification#39-finality-and-reorg-handling) 6-confirmation finality gate (`size ≤ size_final`), never a double-spend lever; (2) this is a **CT-consistency (ordered-sequence) port**, not the paper's tuple-of-**sets** `IsPrefix` — both peer-reviewed, different relations. The narrow consumed-key `ToSAccVVerifyUnionMembership` port ([§2.1](/specification#21-the-compliance-predicate)) remains faithful. A third, related caveat: the global position-bound log needs a pinned per-network **`activation_height`** scan origin — a consensus constant the paper's per-user model does not need; it is a pinned network constant (though — unlike `circuit_digest` — **not** cryptographically bound; a weaker parameter-agreement assumption, D-05 residual (iv)) and reconciles with "rebuilt from Bitcoin alone" ([spec §3.6](/specification#36-chain-scanning)).

**Unchanged:** the hard 6-confirmation finality (D-16) still stands and its rationale is unchanged — it comes from the absence of a satisfiable `DistinctElement` no-op branch ([issue #105](https://github.com/zk-coins/docs/issues/105)), which this construction still omits by design. Fixing prefix succinctness does **not** change D-16. The **succinctness/soundness** part of the deviation is now **resolved**; the (unchanged) bounded finality remains an **accepted v1 boundary**, registered in the [paper-deviation analysis](/paper-conformance-analysis).

**Mitigation:** registered as a deliberate deviation ([issue #106](https://github.com/zk-coins/docs/issues/106), [Paper-Deviation Analysis D-05 / D-16](/paper-conformance-analysis)): prefix is now the RFC-6962 log-consistency relation (succinctness/soundness fixed); the paper's `DistinctElement` no-op remains deliberately unbuilt and is bounded by the 6-confirmation finality directive ([spec §3.9](/specification#39-finality-and-reorg-handling)).

## Data availability and recovery

**Risk: Losing your coin data means losing the coins.**

zkCoins is client-side-validated: a coin's spendability lives entirely in its off-chain `CoinProof` bundle and the recursive proof it carries. Bitcoin holds the on-chain state nullifiers needed to rebuild the public double-spend set, but it does **not** hold the private coin value or proof and therefore cannot reconstruct a lost `CoinProof` ([spec §3.1](/specification#31-the-on-chain-object), [§4.5](/specification#45-recovery)). Unlike a regular Bitcoin wallet, **seed-phrase recovery alone is insufficient**: the seed re-derives every key and detection tag, but a coin's *value* is a choice someone else made and exists only inside the bundle.

**Mitigation:** The protocol makes durability a hard requirement, not best-effort caching. A node MUST persist every value-bearing artefact before acting on it and MUST never delete it (the store-everything invariant, [spec §4.8](/specification#48-durability--the-store-everything-invariant)); every value-bearing artefact is additionally published, encrypted, to the Nostr/blob plane rather than kept captive to one node's database ([spec §4.6](/specification#46-data-availability) *Encrypted network redundancy*), and the recovery-discoverable overlap rule guarantees that at least one seed-discoverable relay holds every artefact's delivery event and at least one seed-discoverable blob store holds its blob ([spec §4.3](/specification#43-addressing-for-delivery)); change/state bundles are self-delivered to the owner's own advertised relay set under the same overlap rule, so a second device — or a wallet recovering from seed alone — can rebuild the full spendable state ([spec §4.2](/specification#42-bundle-delivery), [§4.5](/specification#45-recovery)). There is no fixed replica count, no quorum, and no durability-receipt object to track — availability is an operational multi-holder guarantee, not a counted one ([spec §4.10](/specification#410-responsibility-boundaries-and-the-availability-model-normative)). The residual risk is irreducible: if every holder of a `CoinProof` bundle is lost at once — the node's store, its operator backup, and every seed-discoverable relay and blob store carrying the encrypted event and blob — that coin is unspendable forever. Availability is never a custody risk — an unavailable bundle can never be spent by anyone else — and it cannot make two honest scanners disagree on the public accumulator, which both rebuild from Bitcoin alone ([spec §3.6](/specification#36-chain-scanning), [§4.6](/specification#46-data-availability)). Research on UTxO binding for data availability is ongoing ([ePrint 2025/569](https://eprint.iacr.org/2025/569)).

## Open asset provenance reveals a token's name and terms to anyone holding its `asset_id`

**Risk: Anyone who knows an asset's `asset_id` can resolve its issuer-originated name and terms.**

The open `asset_id → terms` lookup ([spec §4.6](/specification#46-data-availability) Class B, [spec §7.5](/specification#75-node-rest-api-normative) `GET /v1/token/<asset_id>/provenance`) serves any requester the `IssuanceTerms` preimage a node holds for that `asset_id`, with no capability and no authentication. This is a deliberate widening of the asset-metadata surface, chosen so a self-issued token remains transferable and displayable after its issuer disappears ([spec §6.5](/specification#65-issuance--token-standards)). The exposed information is bounded to what the terms themselves say — name, decimals, creator public key, and (token standard 2) the capped-supply parameters — never a transfer, a holder, an amount, or any `CoinProof` plaintext; the ZK transfer graph and Requirement 2's privacy hold in full regardless of who knows an `asset_id`.

**Mitigation:** The boundary is structural, not policy: Class B is defined to contain only the self-verifying `IssuanceTerms` preimage — a requester recomputes `asset_id` from the served terms and rejects a mismatch, so a lying holder cannot inject false terms — and explicitly excludes anything from Class A (a subject's own private records). There is still no `name → asset_id` registry and no name uniqueness; the residual is limited to *this* asset's own already-public identifier resolving to *this* asset's own already-chosen terms.

## Availability is a multi-holder guarantee, not a cryptographic one

**Risk: If every holder of a piece of value-bearing data is lost at the same time, that data — and the funds it represents — is gone.**

Data availability in zkCoins depends on the recovering wallet reaching one node to fetch and verify the current signed Bootstrap Manifest, and on at least one live, reachable holder of the relevant artefact: the node's own store (with its operator's backup), a self-hosted relay and blob store, or a seed-discoverable relay (for the delivery event) and blob store (for the blob) carrying the encrypted copy ([spec §4.10](/specification#410-responsibility-boundaries-and-the-availability-model-normative)). This is deliberately operational rather than cryptographic — the same dual as the Wallet key custody risk below: if the seed is a self-custody, single-point-of-failure secret by design, so is the network-side data it takes to reconstruct state from that seed. No amount of redundancy converts liveness into a guarantee that cannot fail; it only makes the failure vanishingly unlikely.

**Mitigation:** Three independent redundancy layers back this: the node operator's own real-time backup, encrypted publication to the Nostr/blob plane so the corpus is not captive to one database, and the [spec §4.3](/specification#43-addressing-for-delivery) recovery-discoverable overlap invariant, which makes a seed-only scan find everything addressed to the account as long as the wallet can reach one node to fetch the current manifest and one seed-discoverable relay (holding the delivery event) and one seed-discoverable blob store (holding the blob) are still alive (manifest rotation preserves recovery-discoverability, [spec §4.3](/specification#43-addressing-for-delivery)). Losing a bundle is never a custody risk in the other direction — an unavailable bundle can never be spent by anyone but its rightful owner — so the failure mode is pure loss, never theft.

## Operator backup duty is enforced operationally, not by the protocol

**Risk: A node operator that skips the real-time backup of its PostgreSQL database and blob store silently weakens the primary recovery path.**

The node's operator must maintain a real-time, restorable backup of the node's value-bearing store — its PostgreSQL database and its blob store ([Requirement 12](/requirements#12-data-permanence), [spec §4.8](/specification#48-durability--the-store-everything-invariant) *Operator durability duty*); this is the primary recovery path, ahead of the network redundancy layers. The backup mechanism is deliberately out of scope for the node software — standard PostgreSQL replication and point-in-time recovery for the database, and the equivalent content-addressed replication for the blob store, provisioned by the operator's own hosting setup — so the node repository ships no backup subsystem and cannot itself verify that a given deployment complies.

**Mitigation:** Compliance is a deployment/hosting responsibility, not a code guarantee, and must be documented and audited operationally rather than assumed. The network redundancy layers ([spec §4.6](/specification#46-data-availability), [spec §4.3](/specification#43-addressing-for-delivery)) remain a fallback even for an operator that neglects this duty, but they were never designed to substitute for it, and relying on them alone measurably weakens recovery.

## Node storage growth

**Risk: A validating node's nullifier accumulator only ever grows.**

A Path-A node maintains the global nullifier accumulator by scanning Bitcoin, and its state grows with the total number of state-advancing transitions ever made ([spec §3.7](/specification#37-the-nullifier-accumulator)). The accumulator **cannot prune by age**: every position must remain to answer inclusion, membership, and non-membership queries against the current tip, so entries are never discardable regardless of age ([spec §3.7](/specification#37-the-nullifier-accumulator)).

**Mitigation:** This is an inherent local validation cost of any client-side-validated, first-occurrence accumulator — the same monotonic-set property Zcash's nullifier set and Shielded CSV carry — not a free-rider structure or a safety issue. The on-chain footprint stays ~64 bytes per transition regardless ([spec §3.8](/specification#38-fees-and-economics)); the growth is confined to a validating node's own local index: a Path-A node stores the **append-only Merkle log** (or its Merkle peaks) plus a local `Pk → (pos, R)` index ([spec §3.7](/specification#37-the-nullifier-accumulator)); there is **no** 256-bit sparse key space and **no** default-subtree pruning — those belonged to the retired SMT — so the store grows with admitted nullifiers and cannot prune by age.

## Proving cost and latency

**Risk: Building a transition is computationally expensive, so payments are not instant.**

Each state-advancing transition — send, receive, or mint — carries a recursive zero-knowledge validity proof. Generating it is CPU-intensive — on the order of seconds to minutes — with the foreign-field BIP-340 verification and in-circuit SHA-256 dominating the cost ([spec §2.6](/specification#26-in-circuit-non-native-cryptography-normative)). The account advancing its state waits for proving and signing before the transition nullifier can be handed to a publisher and anchored.

**Mitigation:** Proving is **node-side**: the node runs the prover, while the wallet stays a thin key-holder that only signs ([spec §6.1](/specification#61-components-and-responsibilities), [§6.2](/specification#62-wallet--node)). Self-hosting means you bear the proving cost on your own hardware; using a public proving service offloads it at the privacy cost below. Verification of an already-built recursive proof, by contrast, is **constant-time** regardless of a coin's history ([spec §2.2](/specification#22-proof-types)).

## Node plaintext visibility

**Risk: A node you delegate to sees your transaction details.**

A node you delegate to holds the operational bundle (`ivk` / `ovk` / `op` / `nk` / `op_secret`) and therefore sees the account's plaintext — amounts, assets, senders, and recipients ([spec §6.1](/specification#61-components-and-responsibilities), [§6.2](/specification#62-wallet--node), [§6.6](/specification#66-threat-model-and-trust-configurations)). A **public proving service** is exactly such a delegate — a hosted account gives the provider the full operational bundle, including `ivk` ([spec §6.4](/specification#64-external-interfaces-abstract)) — so its view is **not** scoped to the transitions it proves: it gains a standing, whole-account decrypt view of every coin sent to the account for as long as it holds the bundle, and an abandoned node keeps that view because the account's viewing keys cannot be rotated without moving to a new account ([spec §6.3](/specification#63-node-portability-and-multi-node-operation)). Your **own** node holds the same bundle and sees the same plaintext, but leaks nothing because you are the operator. A foreign node used only for bounded reads receives a scoped view grant rather than the operational bundle, but it still learns everything released within that grant's scope ([spec §5.2](/specification#52-view-grant)).

**Mitigation:** Self-host. Your own node verifies your transactions and sees your plaintext, and since you are the operator, nothing leaks — trustlessness and privacy at once ([spec §6.6](/specification#66-threat-model-and-trust-configurations)). The SPEND branch never leaves the wallet in any configuration ([spec §1.2](/specification#12-key-hierarchy)), so a node — yours or foreign — can never forge a signature, double-spend, or spend without your key. A foreign node's correctness is trusted more broadly than that, though: because it alone builds a send's proving witness, it can also misdirect that send's outputs within one cooperative signature (see the risk below) — so privacy, liveness, **and** send-output correctness, not only custody, are what a foreign node is trusted for. Revoking a hosted node's bundle ([spec §7.7](/specification#77-wallet--node-bootstrapping-normative)) stops its *future* access but — like any disclosed secret — cannot erase what it already saw or compel a compromised operator to delete its copy; and because none of `ivk`/`ovk`/`op`/`nk`/`op_secret` can be rotated independently of the account, recovering confidentiality after a suspected leak means moving to a new account, not merely revoking.

## Send-output redirection or change-drop (burn) by a dishonest prover

**Risk: A single foreign node acting as prover can redirect or drop (burn) a send's outputs — including its change — within one cooperative signature.**

The wallet is a thin client and runs no Poseidon (the thin-client rule, [CONTRIBUTING](https://github.com/zk-coins/docs/blob/develop/CONTRIBUTING.md)): it posts its intended `output_templates[]` to the node, which alone builds the witness and surfaces the six `ProofData` fields — including the wallet-verifiable `npk_commit`, on which the wallet **fail-closes** before signing ([spec §7.5](/specification#75-node-rest-api-normative), negative control N-16) — plus `proof_data_hash`; the wallet recomputes `H(ProofData)` itself before signing ([spec §7.5](/specification#75-node-rest-api-normative)) — but it still cannot recompute `ocr` from its own templates (no Poseidon in the wallet), so it binds the node-reported `ocr` on trust that the node built the proof from those templates and not others. A dishonest or compromised node can substitute different recipients, or omit an output — including the per-asset change coin — entirely, and still obtain a validly signed, validly proved transition: the circuit enforces only **no-inflation** ([conservation](/specification#21-the-compliance-predicate) as `Out(a) ≤ In(a)+Mint(a)`), never that the difference is returned to the sender, so the node can redirect the sender's funds to a party of its choosing, or destroy them outright (burn). Custody in the strict sense still holds: no node can forge a signature, double-spend, or spend without the wallet's key ([spec §6.6](/specification#66-threat-model-and-trust-configurations)). This is a correctness failure of the party building the proof, not a key theft — but its effect on the sender is the same as theft.

**Mitigation:** Self-host, or use only a node vetted for correctness, not merely liveness — the same trade-off [spec §6.6](/specification#66-threat-model-and-trust-configurations) already documents for balances and history, now stated to include send-time output selection. No wallet-side check closes this without violating the thin-client rule (client-side Poseidon or proof verification is out of scope by design, [CONTRIBUTING](https://github.com/zk-coins/docs/blob/develop/CONTRIBUTING.md)). A wallet configured with more than one independent prover could, in principle, submit the same signed intent to each and require their reported `ocr` to agree before signing — deterministically catching a single lying prover the same way [spec §6.3](/specification#63-node-portability-and-multi-node-operation) fan-out already catches a single lying reader — at the cost of proving the same transition more than once before knowing which answer to trust. This trade-off is deliberately **not adopted in v1** (thin-client rule); the residual — a dishonest self-selected prover can redirect or drop (burn) a send's outputs, including its change — is an **accepted v1 boundary, final for v1** (registered as D-17 in the [Paper-Deviation Analysis](/paper-conformance-analysis)). The operational mitigation stands: self-host, or vet the node you delegate proving to ([spec §6.6](/specification#66-threat-model-and-trust-configurations)). A compromised **selected prover** (own or a vetted foreign node) can also **freeze** an account (not only redirect a payment): by publishing a nullifier bound to a **never-finalizing** (fork-loser) or **unsatisfiable** `ProofData` (a merely-pending dependency that later finalizes freezes nothing), it consumes `Pkᵢ` (first-occurrence, §3.6) with no valid successor. This is the same accepted thin-client trust boundary as D-17 — the wallet verifies neither chain state nor the recursive proof itself — and is mitigated by **self-hosting or vetting the prover** (§6.6); it is not a protocol soundness break (an honest node never does it, and the removal of proving-pipelining closes the honest-node reorg race).

## Wallet key custody

**Risk: The wallet device is the custody boundary.**

The wallet holds the seed and is the sole custodian of the SPEND branch (`skᵢ`); the spend key never leaves it ([spec §1.2](/specification#12-key-hierarchy)). A compromised wallet endpoint can extract it. (`nk` — own hardened branch `A/3'` — is derived from the seed but delegated to the wallet's *own* node as part of the operational bundle so the node can build proving witnesses; it cannot spend, only link the account's own spends.)

**Mitigation:** The key hierarchy is hardened so that the operational bundle a wallet delegates to a node (`ivk` / `ovk` / `op` / `nk` / `op_secret`) **cannot** derive the SPEND branch ([spec §1.2](/specification#12-key-hierarchy)) — a captured node, or a leaked view grant, never yields spend authority. Securing the wallet device itself (key storage at rest, authentication) is the user's responsibility, as with any self-custodial wallet.

## Coin creation time leak

**Risk: The approximate creation time of a coin is revealed to its receiver, and outputs of the same transaction are linkable to each other.**

The creating transition's on-chain block anchor is already public ([spec §3.5](/specification#35-inscription-format)), so the receiver knows how many confirmations to expect from it alone; by default the proving-time `nav_opening` the coin carries reveals only the **shared** `size_final` global ordinal — identical for every prover building against that tip ([spec §3.9](/specification#39-finality-and-reorg-handling)) — not an account-specific creation-time fingerprint. Separately: every output of one transition — every recipient coin and the per-asset change coin(s), plus a publisher fee coin under the deferred fee mechanism — shares one `output_coins_root` (`ocr`), committed by the transition's single on-chain nullifier `(Pkᵢ, Rᵢ)` whose `Rᵢ` sign-to-contract-binds `H(ProofData)`, hence `ocr` ([spec §2.1 clauses 5–6](/specification#21-the-compliance-predicate), [§3.1](/specification#31-the-on-chain-object)). That `ocr` and the consumed key `Pkᵢ` travel inside every recipient's own delivered `CoinProof` ([spec §2.3.2](/specification#232-send)). Any holder of **one** output's `CoinProof` — which in v1 never includes the publisher, since a sponsored hand-off carries no coin at all, but would under the deferred fee mechanism — therefore learns that its coin shares a transition with other, still-unidentified outputs (same `ocr`, same consumed `Pkᵢ`) — though not the co-outputs' own recipients, amounts, or assets. (A co-output holder also learns the power-of-two output-count bucket of the transition, via its own `inclusion_proof.depth`, [spec §1.7.5](/specification#175-poseidon-merkle-tree-used-for-ocr-and-inr).)

**Mitigation:** Wallets should create a single output per transaction where unlinkability matters. This intra-transaction leak does not by itself chain an account's separate transitions together — the shared root and the spender's one-time key are both transition-fresh (see "Publisher-observed spend linkage" below for the mechanism that can chain transitions). Hiding `output_coins_root` from co-output holders structurally is **not part of v1**: the leak is bounded to the co-output holders of a single transition and does not chain an account's transitions, and it is an **accepted v1 boundary, final for v1** (registered as D-18 in the [Paper-Deviation Analysis](/paper-conformance-analysis)); a structural fix would be a future protocol version. (The source paper documents the same class of leak, [paper section 6.3](https://eprint.iacr.org/2025/068).)

## Publisher-observed spend linkage

**Risk: the hand-off shows a publisher the transition's on-chain key before it is anchored.**

The rotated spend key an account's next transition will sign with never appears on Bitcoin — it lives only inside the off-chain, hashed `new_account_state_hash` ([spec §2.1 clause 2](/specification#21-the-compliance-predicate)) — so the rotation edge `Pkᵢ → Pkᵢ₊₁` cannot chain an account's consecutive on-chain nullifiers. The hand-off nonetheless discloses something: a v1 spender sends `{public_key, r, s, r_prime, block_anchor}` to the publisher's REST endpoint ([spec §7.6](/specification#76-publisher-interface-normative)), so that publisher — and any API layer or network observer in front of it — learns the exact `Pkᵢ` that will shortly appear on Bitcoin, together with whatever transport identity the request carries: source address, TLS session, and any account or credential the API layer sees. When the nullifier surfaces on-chain it can be attributed to that requester, and a spender that reuses one publisher lets it correlate transitions whose on-chain keys are otherwise unlinkable.

Sponsorship removed the sharper form of this leak rather than the leak itself. Under the deferred fee mechanism the spender additionally handed over a fee `CoinProof` carrying `creating_prev_ash` in the clear beside an unblinded `new_account_state_hash`, which chains two consecutive transitions of one account outright ([spec §3.8.1](/specification#381-fee-coin-mechanism-deferred)); v1 hands over no `CoinProof` at all, so that chaining is not available to a v1 publisher. D-19 is registered with the general scope: **any** party holding `CoinProof`s of two consecutive transitions of one account can chain them, whether or not it is a publisher.

**Mitigation:** Varying the publisher across transitions — self-publishing, or rotating among publishers — breaks the correlation at no protocol cost, and publisher choice is a free per-transition decision. Self-publishing removes the disclosure entirely: the account's own node inscribes and no third party sees `Pkᵢ` before the chain does. What remains is a metadata exposure to a chosen counterparty, not a custody or correctness dependency, and it is bounded by that choice — the verdict is **holds under stated assumptions**. A transport that hides the requester from the publisher (an anonymised or gift-wrapped hand-off) is a possible later hardening and is **not** specified in v1; a wallet that needs it today self-publishes.

**Risk: a sponsored publisher cannot tell real work from junk before paying for it.**

A fee-less hand-off is permissionless and carries no proof: the publisher can verify the nullifier's BIP-340 signature, but with no fee `CoinProof` it has no source for `H(ProofData)` and therefore cannot check the sign-to-contract opening ([spec §7.6](/specification#76-publisher-interface-normative)). An attacker can generate arbitrary keys, sign the fixed `m_state`, and submit unlimited distinct `Pk` values that a sponsor pays real BTC to inscribe and that every scanner then appends to its accumulator permanently. Even a declining publisher performs a signature verification before its policy runs.

Note precisely what changed and what did not. A fee never made junk *invalid* — a fee-paying attacker could always buy inscription of a meaningless nullifier. What the fee provided was a **price**, and sponsorship removes the price, not a validity check.

**Mitigation:** Admission is entirely publisher policy, which the specification deliberately leaves to the operator ([spec §3.8](/specification#38-fees-and-economics)): a sponsor sets its own quotas, per-requester budgets, and BTC ceiling, and declines anything beyond them. The API layer in front of it rate-limits before the kernel is reached ([spec §6.1](/specification#61-components-and-responsibilities)). Nothing here touches correctness or custody — a junk nullifier consumes a sponsor's BTC and accumulator space, and can neither forge a coin nor block a legitimate transition, since first-occurrence is keyed per `Pk` and an attacker's keys collide with nobody's. The residual is economic and falls entirely on the volunteer paying the bill: **holds under stated assumptions**, with the assumption stated plainly — a public, unmetered sponsor is a standing invitation, and running one without quotas is an operator error rather than a protocol failure.

**Risk: Privacy strengthens with adoption.**

The anonymity set is global — every coin in the system — but if very few people transact, that set is small and timing analysis on the stream of nullifier inscriptions could reveal patterns. The privacy guarantees strengthen as adoption grows.

**Structural note:** The set is global by construction (the asset and amount are hidden, so coins never partition per-asset, [spec §3.5](/specification#35-inscription-format)), so it grows with total usage rather than per-round participation — but it is still bounded by real adoption.

## Publisher censorship and delay

**Risk: A chosen publisher can refuse to publish a valid transition or delay it.**

A publisher receives a transition nullifier, half-aggregates signatures, and broadcasts the inscription. It holds no SPEND key and no consensus-critical off-chain data, and it never sees the plaintext of the sender's payment or change coins — so it cannot forge a signature, double-spend, or spend without the wallet's key. (Under the deferred fee mechanism it *would* be a recipient of the one fee coin it is paid, whose `CoinProof` — recursive proof and plaintext — it verifies and decrypts, the basis of the *Publisher-observed spend linkage* above; but that is the fee coin alone, never the payment.) Its only protocol-level power is to withhold or delay publication ([spec §3.4](/specification#34-the-publisher)).

**Mitigation:** Publishing is permissionless and contention-free. A nullifier references no shared accumulator root and cannot go stale merely because another publisher writes first, so the account can submit the same nullifier to another publisher or have its own node self-publish it; redundant publication is idempotent under the first-occurrence rule ([spec §3.4](/specification#34-the-publisher), [§3.6](/specification#36-chain-scanning)). Half-aggregation lowers fees but is not required for correctness or liveness.

## Sponsorship sustainability and unmetered admission

**Risk: a sponsored publisher has no revenue at all.**

v1 publishing is **sponsored**: a publisher pays the Bitcoin inscription fee in BTC, bears its signature-aggregation cost in real compute ([spec §3.4](/specification#34-the-publisher), [§3.8](/specification#38-fees-and-economics)), and is reimbursed with nothing. There is no protocol fee, no fee coin, and no fee asset — so the exchange-rate exposure the earlier fee-coin design carried does not arise, and neither does any revenue. Whether anyone is willing to carry that cost is an economic property of a deployment, not one the protocol establishes.

**Mitigation:** Liveness never depended on a publisher existing. Self-publish is permissionless and contention-free ([spec §3.4](/specification#34-the-publisher)), so the failure mode of sponsorship drying up is that a spender pays its own Bitcoin inscription cost — measurably worse economics, never a denial of access, and never a correctness or custody dependency. The paid design is retained and deferred rather than discarded ([spec §3.8.1](/specification#381-fee-coin-mechanism-deferred)), so the answer to sponsorship failing is a specified upgrade rather than a redesign. Verdict **holds under stated assumptions**. Registered as D-20 in the [Paper-Deviation Analysis](/paper-conformance-analysis).

## Interactive receive

**Risk: Receiving a payment requires the recipient to be reachable.**

A payment is delivered as an off-chain `CoinProof` bundle that the sender hands to the recipient over the relay mesh ([spec §4.2](/specification#42-bundle-delivery)); the recipient must fetch and verify it before the coin is credited ([spec §2.3.3](/specification#233-receive)). There is no purely on-chain receive: Bitcoin carries the creating transition's opaque state nullifier, not the coin value, proof, or encryption envelope.

**Mitigation:** Delivery is store-and-forward, so the recipient need not be online at send time — only eventually reachable. Relays retain the gift-wrapped bundle until the recipient (or its always-on node) comes online and runs the `detect_tag` scan ([spec §4.2](/specification#42-bundle-delivery), [§4.4](/specification#44-note-discovery)); the always-on node, not the wallet, holds the live subscription and verifies on the wallet's behalf ([spec §4.9](/specification#49-real-time-push-delivery)). The sender retains its copy indefinitely regardless of acknowledgement — only the re-publish retry loop stops once a valid acknowledgement arrives; the acknowledgement is a durability confirmation, never a licence to drop the sender's own copy ([spec §4.2](/specification#42-bundle-delivery)).

## Unobservable total supply

**Risk: A token-standard-1 asset's aggregate supply is unobservable, so a creator's over-issuance is undetectable as to quantity.**

Token-standard-1 issuance is bound to the creator's spend key but uncapped. Because coin amounts are zero-knowledge, no party — holder, node, or explorer — can sum an asset's total supply. Every mint is nevertheless a state-advancing transition that anchors on Bitcoin by publishing an on-chain nullifier `(Pkᵢ, Rᵢ)` ([spec §2.3.1](/specification#231-mint--issuance), [§3.10](/specification#310-transaction-states)). Issuance frequency and timing are therefore chain-visible; only the minted amount stays hidden, so a creator can inflate supply undetectably only as to quantity, not as to the fact that mints happened.

This anchoring closes the mint-fork: two mints advancing from the same prior state share the same `current_pubkey = Pkᵢ` and publish the same nullifier key. The global accumulator admits each `Pkᵢ` at most once by first-occurrence ([§3.6](/specification#36-chain-scanning)), so a creator cannot issue two conflicting coins against one state.

**Mitigation:** Holders trust the creator as they would any single-issuer asset. Protocol-enforced, auditable supply is available in `IssuanceTerms_v2`, which bounds total emission with an in-circuit `cap_total` ([spec §6.5](/specification#65-issuance--token-standards)).

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
