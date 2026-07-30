---
title: Paper-Conformance Remediation
---

# Paper-Conformance Remediation Plan

> Status: **the accepted architecture direction is now normative.** [PR #97](https://github.com/zk-coins/docs/pull/97) landed the on-chain half-aggregated state-nullifier model in [`specification.md`](./specification.md). This page is the **remediation register and mainnet gate**: it traces each paper-conformance finding to its disposition in the current spec and defines the executable-conformance and assurance gates that remain open before the protocol carries real value.

Complete source review: [Paper-Deviation Analysis](/paper-conformance-analysis), mirrored from [`zk-coins/research#22`](https://github.com/zk-coins/research/pull/22). Controlling architecture decision: [`ACCUMULATOR_SELF_PUBLISH.md`](https://github.com/zk-coins/research/blob/f392fa0e4f55d68e6135e7eced15ef719118e545/zkcoins-design/ACCUMULATOR_SELF_PUBLISH.md), accepted 2026-07-12.

## Decision summary

The pre-#97 specification moved public state nullifiers into an off-chain `BatchBundle` and put only a 231-byte chained accumulator-root transition on Bitcoin. That created two load-bearing departures from Shielded CSV: ledger reconstruction depended on off-chain batch availability, and every publisher competed to extend one serial `prev_root`.

PR #97 returned the global double-spend boundary to the paper model, now normative in `specification.md`:

1. Publish account-state nullifiers on Bitcoin as NISSHAC half-aggregated signatures.
2. Key first-occurrence by the state being consumed, represented by its rotating `current_pubkey = Pk_i`; remove the chained global `prev_root -> new_root` object.
3. Let every verifier rebuild the same first-occurrence map and nullifier accumulator from canonical Bitcoin data alone.
4. Commit each on-chain signature nonce to the exact off-chain transition essence and carry the opening in the recipient proof bundle, as Shielded CSV does.
5. Bound reorg finality at 6 confirmations: absorb reorgs of ≤5 blocks by canonical replay and treat a reorg of ≥6 blocks as an accepted break, rather than the paper's arbitrary-depth conditional-NAV no-op — a deliberate deviation ([Paper-Deviation Analysis D-16](/paper-conformance-analysis), issues #105/#106).
6. Route every state-advancing transition, including issuance, through that same on-chain state-nullifier path.
7. Keep recursive `CoinProof` data encrypted and off-chain; its loss remains a bearer-data recovery risk but cannot split the public double-spend view.

This gives up constant size per batch and makes transaction count visible. It restores contention-free self-publication, objective Bitcoin-only reconstruction and the source paper's asymptotic 64-byte-per-state-update construction. zkCoins' multi-asset account relation and concrete recursive backend remain extensions and therefore still require independent proofs.

## Why the former full-envelope repair is not selected

An earlier revision of this PR proposed putting the complete `SpendRecord` list and recursive aggregate proof in a large Bitcoin witness. That would repair ledger availability, but it would retain the serial `prev_root` writer and conflict with the accepted self-publish decision. It is therefore rejected as the normative path, not presented as a second selected design.

The relevant trade-off is:

| Construction | Bitcoin-visible nullifiers | Contention-free self-publish | Objective reconstruction | Constant per-batch size | Decision |
|---|---:|---:|---:|---:|---|
| pre-#97 231-byte root chain | no | no | no, needs `BatchBundle` | yes | retired by #97 |
| full validation envelope with root chain | yes | no | yes | no | rejected |
| independent off-chain batches + first occurrence | no | yes | no; selective serving breaks safety | yes | rejected |
| Shielded CSV state nullifiers + first occurrence | yes | yes | yes | no, asymptotic 64 B/update | **selected** |

A later coordinator lane may offer optional constant-size batching only if the direct self-publish path remains available and the additional trust/liveness assumptions are explicit.

## Findings and mandatory disposition

**F-01, F-02, F-04 and F-06 are resolved in the normative spec** by PR #97: the on-chain `(Pk_i, R_i)` state nullifier ([spec §3.1](/specification#31-the-on-chain-object), [§1.7.10](/specification#1710-half-aggregation-with-commitments-nisshac-normative)), first-occurrence rebuild from Bitcoin alone ([spec §3.6](/specification#36-chain-scanning)), predecessor-nullifier anchoring of every state-advancing transition including issuance ([spec §2.1](/specification#21-the-compliance-predicate), [§2.3.1](/specification#231-mint--issuance), [§3.10](/specification#310-transaction-states)), and replication reserved for private bearer data ([spec §4.6](/specification#46-data-availability)). What remains open is the executable-conformance evidence (canonical vectors, Gate B) and F-08's commit-pinned status matrix; F-05 and F-07 are closed by project decision (see the table below), and Gate C contains no external-review step (project decision 2026-07-22). The **selected disposition** column records the design decision each finding drove; the **release gate** column records what still gates mainnet.

| ID | Severity | Problem | Selected disposition | Release gate |
|---|---:|---|---|---|
| F-01 | high | The current publisher S2C check requires a pre-tweak point absent from its wire objects. | Delete the publisher root-transition signature. Use paper-style per-state NISSHAC commitments and transport every member's opening in its proof bundle. | vectors + testnet |
| F-02 | high | `bundle_locator` does not directly resolve the Blossom `blob_id`. | Remove public-ledger bundle discovery from admission; the first-occurrence index is rebuilt from Bitcoin. | clean sync |
| F-03 | high | A five-block reorg bound is treated as absolute. | **Resolved as deliberate deviation**: v1 fixes finality at a hard 6-confirmation bound instead of the paper's conditional-NAV no-op — reorgs of ≤5 blocks are absorbed by canonical replay, and a reorg of ≥6 blocks MAY break zkCoins as an accepted v1 limitation ([spec §3.9](/specification#39-finality-and-reorg-handling)). Refs: #105, #106. | resolved — no further gate; revisit only if a sound `DistinctElement` no-op construction is adopted |
| F-04 | medium | A mint can be accepted without a Bitcoin state nullifier. | Every issuance is a state update whose consumed `Pk_i` must win first occurrence. | issuance-fork tests |
| F-05 | high | Plonky2 is deprecated upstream. | **Resolved by project decision (2026-07-22):** v1 pins the immutable crates.io release `plonky2 = "1.1.0"` ([spec §1.7.9](/specification#179-proof-system-parameters-normative)); upstream deprecation is a maintenance risk, not a correctness gate — the pinned artefact is deterministic and sufficient for v1, and migration to a maintained system is a future **version bump**. | closed |
| F-06 | high | `k = 3` retention cannot guarantee public-ledger DA or operator independence. | Put every state nullifier on Bitcoin; use replication only for private proof recovery. | clean sync |
| F-07 | high when cited | The formal certificate targets an older specification. | **Superseded for v1:** the certificate is not cited as evidence for the current model; the executable Gate-B negative-control vectors stand in. Re-modelling remains welcome but is not a release gate (project decision: no human-gated mainnet step). | closed for v1 |
| F-08 | medium | Paper, target and implementation status are conflated. | Publish a commit-pinned three-column status matrix. | filled at the vectors-pin PR; re-affirmed every release |

## 1. Version-3 aggregate state nullifier

### 1.1 Semantic object

For each state transition `i`, the consumed account state contains a one-time Schnorr public key `Pk_i = current_pubkey`. The holder signs one fixed protocol message with NISSHAC while committing the signature nonce to the exact transition essence:

```text
state_nullifier_key = Pk_i

# The transition essence is realized in the shipped spec as ProofData (§1.4);
# the signature nonce commits H(ProofData), not a separate
# SHA256("zkCoins/v3/TransitionEssence" || ...) digest.
transition_commit = H(ProofData)            # ProofData := TransitionEssenceV3 (§1.4)

m_state = ASCII("zkCoins/v1/StateUpdate")   # the fixed signed message (§1.4, §2.1, §3.2)

(R_i, s_i, opening_i) = NISSHAC.SignCommit(
  sk_i,
  m_state,
  transition_commit
)
```

In the shipped spec `TransitionEssenceV3` is realized as `ProofData` (§1.4): it binds the new account-state hash, output-coins root, input-nullifiers root, coin-history root, the conditional-NAV commitment, and the rotated-key commitment `npk_commit = H("zkCoins/v1/NpkCommit" ‖ next_pubkey ‖ npk_rand)` — the sixth field that makes the rotated key wallet-verifiable, rather than bound only through `new_account_state_hash` (spec §1.4, §2.1 clause 2). `H(ProofData)` over its fixed **192 bytes** of `serialize(ProofData)` across these **six** fields is the single normative essence hash the nonce commits (§3.2); no JSON or implementation serialization may enter it.

**Updated 2026-07-23:** `serialize(ProofData)` is now **192 bytes** (six fields; the sixth, `npk_commit`, makes the rotated key wallet-verifiable, [spec §2.1 clause 2](/specification#21-the-compliance-predicate)), and the nullifier accumulator is an RFC-6962 append-only Merkle log (not a leaf-preserving SMT), [spec §1.7.6](/specification#176-nullifier-accumulator-append-only-merkle-log).

The publisher non-interactively half-aggregates entries into the `AggregateStateNullifierV3` inscription payload ([spec §3.5](/specification#35-inscription-format)):

```text
offset  size  field
  0       2   marker                  = 0x42 0x42      ("BB", zkCoins prefix)
  2       1   version                 = 0x03           (0x01/0x02 retired, rejected)
  3       1   format                  0x00 raw | 0x01 half-aggregated (§3.3)
  4       2   count m                 u16-be
  6      32   block_anchor.block_hash                  (§3.9 freshness anchor)
 38       4   block_anchor.height     u32-be
 42       …   body:
             format 0x00:  Pk_i (x-only) || R_i (x-only, §3.2) || s_i (BIP-340 scalar)
             format 0x01:  m x ( Pk_j (x-only) || R_j (x-only) ) then one shared s_agg (§3.3)
```

This is the paper's `Aggregate Nullifier := (Nullifier Public Keys, Aggregate Signature)` with explicit version/format/anchor framing. A one-entry payload (`count = 1`) is valid, so self-publication never depends on finding another participant. The inscription carries **no** on-chain fee field, accumulator root, or transition message: v1 carries no publisher fee at all, publishing being sponsored, and the deferred fee would be an ordinary output coin claimed off-chain ([spec §3.8](/specification#38-fees-and-economics)), and network separation is by verifier-data domain, not an on-chain byte.

The normative specification reproduces the complete NISSHAC algorithms, completeness argument, and encoding rules (spec §1.7.10); the paper's formal security definition is referenced as the source work and is a non-gating Workstream-2 write-up ([Assurance Roadmap](/assurance)). Ordinary BIP-340 batch verification is not a substitute: the commitment-opening relation and half-aggregate equation are protocol-critical.

### 1.2 Exact encoding constraints

- integers are unsigned big-endian; `count m` is `u16-be` and `block_anchor.height` is `u32-be`;
- `version` MUST be `0x03` (`0x01`/`0x02` are retired earlier-draft payloads and are rejected); `format` is `0x00` (raw) or `0x01` (half-aggregated);
- `count m >= 1`, and exactly `m` records must decode with no bytes left over (other than the single `s_agg` of `format 0x01`);
- `Pk_j`/`R_j` are x-only and `s_j`/`s_agg` are BIP-340 scalars in the canonical secp256k1 encodings; infinity, non-curve points, out-of-range scalars and non-canonical encodings are rejected;
- the fixed signed message is the exact ASCII bytes of `m_state` (§3.2); network separation is by verifier-data domain (§2.2), **not** an on-chain field;
- the `block_anchor` bound is normative: `block_anchor.height < inclusion_height`, the anchor is a strict ancestor of the inclusion block, and `inclusion_height − block_anchor.height ≤ 100` (§3.5, §3.9); a batch outside the bound carries zero valid nullifiers;
- trailing bytes, count mismatches and a second zkCoins object in one reveal transaction are rejected;
- the reveal carrier uses canonical pushes inside `OP_FALSE OP_IF ... OP_ENDIF`; a payload larger than the standardness limit is split across reveal inputs/transactions, each with its own marker and header.

The 64-byte figure is asymptotic: each member contributes one 32-byte public key and one 32-byte commitment, while the shared `s_agg`, the 42-byte header/anchor framing and Bitcoin transaction overhead are amortized. The specification MUST publish measured sizes for 1, 10, 100 and the maximum supported member count.

### 1.3 Binding carried in private proof data

The recipient's `CoinProof` material MUST contain the exact `TransitionEssenceV3`, the NISSHAC commitment opening, and the coin's `nav_opening`; anchoring is established by the receiver's own Path-A scan of the on-chain nullifiers, not by a transported on-chain location or membership index in the proof (spec §2.3.3 step 4, §3.7). Verification MUST establish all of the following:

1. `transition_id` is recomputed from the canonical essence;
2. `opening_i` opens on-chain `R_i` to that `transition_id` under the NISSHAC commitment relation;
3. `Pk_i` is the `current_pubkey` of the consumed account state proven by the recursive relation;
4. the aggregate NISSHAC signature verifies for the complete ordered key/commitment list and fixed message;
5. this `(Pk_i, R_i)` is the canonical first occurrence of `Pk_i`;
6. the committed transition is the single execution branch selected by conditional NAV (v1 has no reorg no-op branch — §3.2).

This resolves F-01 without a publisher-level S2C object. The pre-tweak/opening value is now explicitly transported wherever the paper's commitment verification needs it.

## 2. Deterministic Bitcoin scanning

Every verifier processes valid v3 aggregates in `(block height, transaction index, entry index)` order on its current best Bitcoin chain:

1. parse and canonically decode the aggregate;
2. verify network, bounds, curve/scalar encodings and the NISSHAC half-aggregate signature;
3. for each entry in encoded order, insert `(Pk_i -> R_i, Bitcoin location)` only if `Pk_i` is absent;
4. ignore later valid entries with the same `Pk_i` for state-transition purposes;
5. append the set of newly admitted entries to the nullifier accumulator — the registered **deviation D-05** (RFC-6962 append-only-log accumulator; the paper's ToS `IsPrefix`/`DistinctElement` relation is not ported), not paper-compatible — and record its historical value for receiver checks.

First occurrence is determined solely by canonical Bitcoin order. Relay timing, private bundle availability and publisher identity cannot change it. A duplicate does not replace the earlier commitment.

There is no `prev_root`, `new_root`, `BatchBundle`, `bundle_locator`, public `AggregateBatchProof` or `pending-DA` state in the v3 ledger path. Implementations MAY cache private proof objects by content hash, but a cache is never part of public first-occurrence admission.

## 3. Reorgs and conditional NAV

### 3.1 Canonical-chain state

`observed` means present on the current best chain. `accepted` means still present after the 6-confirmation finality floor ([spec §3.9](/specification#39-finality-and-reorg-handling); deployments MAY require more, never fewer). Neither means absolute finality.

On a reorg within the tolerated window (≤5 blocks; the 6-confirmation finality bound, [spec §3.9](/specification#39-finality-and-reorg-handling)), a node MUST:

1. remove nullifier entries introduced by disconnected blocks in reverse order;
2. restore any earlier duplicate that becomes first after removal;
3. roll back historical accumulator values;
4. replay connected blocks in canonical order;
5. re-evaluate affected coins, transition branches and account lineage heads.

A reorg of ≥6 blocks can displace a **final** nullifier and MAY break zkCoins — an accepted v1 limitation with no recovery path ([spec §3.9](/specification#39-finality-and-reorg-handling)), not a case this replay resolves.

### 3.2 Conditional execution rule

Each `TransitionEssenceV3` commits to a conditional NAV covering all chain dependencies of its previous account state and input coins. The recursive predicate proves the single **execute** branch: the conditional NAV is set to the shared `size_final` prefix (the ≥6-confirmation-final prefix, not the live chain tip); v1 has **no** early build against still-pending dependencies — a not-yet-final dependency means the wallet waits, so `nav` is always exactly `size_final` — a verifier checks `nav` is canonical and `size ≤ size_final` on its own scan (spec §2.3.2 step 5, §3.7, §3.9) — and every input object's NAV is a prefix of it, and it applies the committed balance, spent-set, output and key-rotation transition. There is **no reorg no-op branch**.

zkCoins v1 deliberately does **not** adopt the paper's conditional-NAV no-op (an exactly-one-of predicate with a `distinct-element` branch that lets an account continue after a dependency is orphaned). It fixes a hard **6-confirmation finality bound** instead ([spec §3.9](/specification#39-finality-and-reorg-handling)): reorgs of ≤5 blocks touch only non-final nullifiers and are absorbed by canonical replay; a reorg of ≥6 blocks MAY break zkCoins as an accepted v1 limitation. Accordingly the accumulator is an **RFC-6962 append-only Merkle log**; `prefix` is a **constant-size log-consistency** proof, and membership is an **inclusion proof at a position-bound leaf** ([spec §1.7.6](/specification#176-nullifier-accumulator-append-only-merkle-log), [§3.7](/specification#37-the-nullifier-accumulator); register [D-05](/paper-conformance-analysis)) — and does **not** implement the paper's `distinct-element` no-op relation — a deliberate, registered deviation ([Paper-Deviation Analysis D-16](/paper-conformance-analysis), issues #105/#106).

Required tests include one-to-five-block reorgs, arbitrary removed suffixes within the tolerated window, duplicate-first-occurrence reversal, dependent receives/spends, equality with clean replay, and confirmation that a ≥6-block reorg is surfaced as the accepted break boundary ([spec §3.9](/specification#39-finality-and-reorg-handling)) rather than silently mis-handled.

## 4. Account transitions and issuance

The v3 invariant is: **no successor account state is spendable unless the transition consuming its predecessor's `current_pubkey` is the canonical first occurrence on Bitcoin and the recursive proof binds the corresponding commitment.**

Consequences:

- ordinary sends consume `Pk_i`, commit the transition, and rotate to `Pk_(i+1)`;
- a pure receive may not silently create a competing successor state; either fold the received coin into the next on-chain state update or publish a state-nullifying receive transition;
- every mint, including a creator's first mint under `Pk_0`, is an on-chain state update under the current one-time key;
- two mint/send/receive forks from the same predecessor reuse `Pk_i`; only the first occurrence can produce accepted outputs;
- no separate synthetic issuance nullifier is needed under this selected paper model;
- creator authorization, per-asset conservation and the explicitly unlimited v1 creator-supply policy remain separate in-circuit checks.

PR #97 removed the unanchored `mint-verified` path: a recipient credits issuance only after the creating state nullifier reaches the 6-confirmation finality floor ([spec §3.9](/specification#39-finality-and-reorg-handling); deployments MAY require more, never fewer) and its transition commitment opens correctly.

## 5. Fees and open publishing

The publisher role remains open and non-custodial:

- **v1 is sponsored**: the spender picks a publisher from its `op`-signed profile and hands off **fee-lessly**; the publisher pays the Bitcoin inscription cost and is not reimbursed ([spec §3.8](/specification#38-fees-and-economics)). The paid variant below is retained as the deferred mechanism of [spec §3.8.1](/specification#381-fee-coin-mechanism-deferred) and is **not** v1 behaviour: there, the profile would specify a flat `fee` per transition in the publisher's chosen `fee_asset_id`, and the spender would include exactly one fee output coin `{recipient = fee_address, amount >= fee, asset_id = fee_asset_id}` in the transition that publisher will anchor ([spec §3.8]);
- (deferred) the fee coin would sit under the transition's single `output_coins_root` (`ocr`), atomically bound with the payment by the one on-chain nullifier through sign-to-contract, so a paid publisher could not collect without anchoring the payment, and an un-anchored transition's fee coin would never reach `completed`;
- (deferred) the fee would be an ordinary output coin the sender includes for the publisher, addressed to the publisher's off-chain payout address ([spec §3.8](/specification#38-fees-and-economics)) — there is no on-chain fee field;
- if the selected publisher censors, the spender re-picks another publisher — in v1 at no cost, since nothing was paid — or self-publishes; first-occurrence nullifier semantics make competing transitions idempotent, so at most one is anchored; under the deferred fee mechanism exactly one fee would be paid, to the publisher that actually anchors it, and in v1 none is paid at all;
- a wallet may publish a one-entry aggregate itself;
- no publisher signature, registry, sequencer, exclusive root lease or coordinator is required;
- the paper's first-to-publish-wins gossip race, in which multiple publishers compete without being selected in advance, is deferred as a forward-compatible privacy upgrade because it requires a two-step payment structure that v1 does not fix.

Publisher economics, front-running resistance and hand-off privacy are closed by the [Risks](/risks) verdict table (publisher censorship/delay: holds; sponsorship sustainability and unmetered admission: holds under stated assumptions) ; there is no fee path to test in v1. “Permissionless” does not by itself prove that the market remains decentralized.

## 6. Data availability and recovery boundary

### Public ledger data

Keys, commitments, aggregate signatures and order are Bitcoin data. A clean node reconstructs first occurrence and every historical NAV from Bitcoin witness history alone. A pruned node may retrieve old blocks from an untrusted source but must verify them against its header chain.

### Private bearer data

`CoinProof`, transition essence, NISSHAC opening, note plaintext and recovery metadata remain encrypted off-chain. Seed recovery alone still cannot reconstruct values chosen by senders. Availability for this private bearer data follows from store-everything retention plus the recovery-discoverable overlap — every delivery published to ≥1 network `seed_relay` and every blob to ≥1 network `blob_store` ([spec §4.3](/specification#43-addressing-for-delivery)) — not a fixed replica count and not a public-ledger consensus assumption.

## 7. Proof backend and assurance

**Decided (2026-07-22):** v1 stays on the immutable `plonky2 = "1.1.0"` release; exact verifier/circuit digests are frozen at the vectors-pin PR ([spec §1.7.8 v1 freeze](/specification#178-reference-instantiation-status-final-for-v1)). No fork audit and no migration are v1 gates; a migration to a maintained proof system is a future version bump with new digests and lineages.

Desirable post-v1 cryptographic write-ups (a quality goal, **not** a v1 release gate — [Assurance Roadmap](/assurance) Workstream 2):

- NISSHAC CK-AEUF-CC-CMA security and commitment hiding/binding for the instantiated curve/hash suite;
- no double spend from first occurrence plus recursive state-key continuity;
- conditional-NAV dependency-anchoring safety and the 6-confirmation reorg-finality bound (a ≥6-block reorg is an accepted break with no recovery path, not a property to prove recoverable — §3.9);
- per-asset conservation and creator-only issuance;
- privacy under the now chain-visible transaction count, rotating keys and commitments;
- correctness of the concrete recursive circuit and implementation.

Model checking cannot replace primitive proofs; v1 ships without an implementation audit or gating formal proofs by project decision — the executable harness (Gate B) and the in-spec arguments are the v1 assurance basis ([Assurance Roadmap](/assurance)).

## 8. Required negative controls

| Property | Negative control |
|---|---|
| Aggregate authorization | change a key, `R_i`, fixed message or `aggregate_s`; verification fails |
| Commitment binding | substitute transition essence or opening; `R_i` no longer opens |
| First occurrence | publish two valid commitments under one `Pk_i`; only the earlier canonical entry controls |
| Reorg replay | remove the winner's block; the next canonical occurrence becomes first exactly as clean replay predicts |
| Reorg finality | a ≤5-block reorg orphaning a non-final dependency is absorbed by canonical replay; a ≥6-block reorg displacing a final dependency is the accepted break boundary ([spec §3.9](/specification#39-finality-and-reorg-handling)) |
| State continuity | use a key not committed by the predecessor state; proof fails |
| Mint fork exclusion | publish two same-state mints; at most the first produces accepted outputs |
| Network separation | replay an object or proof under another network's verifier-data domain; verification fails |
| Encoding | non-canonical point/scalar, count mismatch, trailing bytes or duplicate object; parser rejects |
| Conservation | overflow/wrapped-field and unauthorized-issuance witnesses fail |

## 9. Specification edit map (applied by #97)

PR #97 applied the following edits to the normative spec; this map remains the traceability record from the audit findings to the shipped sections.

| Specification area | Edit |
|---|---|
| §1.1/§1.7 | add v3 domains, NISSHAC primitives, encodings, verifier data and network binding |
| §1.4–§1.6 | replace per-coin global nullifiers/root-chain objects with rotating account-state nullifiers and append-only-log NAV history (registered deviation **D-05**; not paper-compatible) |
| §2.1–§2.3 | bind transition essence/opening, first occurrence, state-key continuity and the single conditional-NAV execute branch (no reorg no-op branch, §3.2) |
| §2.5–§2.6 | remove `C_batch`; dimension NISSHAC and conditional-NAV gadgets; freeze backend |
| §3.1–§3.8 | replace `BatchInscription`/`BatchBundle` admission with `AggregateStateNullifierV3`, scanning, half-aggregation and paper-style fees |
| §3.9–§3.10 | define `size_final` (the shared ≥6-confirmation-final log prefix, replacing tip-relative state), bounded ≤5-block canonical replay and the 6-confirmation finality bound (a ≥6-block reorg is an accepted break) |
| §4 | separate private `CoinProof` recovery from public ledger reconstruction; remove batch-locator mapping |
| §5 | remove `mint-verified`; make acceptance/opening/reorg checks explicit |
| §6 | distinguish paper-derived target, implementation status and residual trust/economic claims |
| §7 | replace batch APIs/events with state-nullifier gossip, aggregation and Bitcoin-scan APIs |
| vectors | add NISSHAC, encoding, first-occurrence, conditional-NAV, issuance and reorg vectors |
| requirements/risks/protocol | remove 231-byte and hidden-count claims; state the asymptotic 64-byte and private-recovery trade-offs |

## 10. Acceptance gates

### Gate A — specification completeness

**Closed by [PR #97](https://github.com/zk-coins/docs/pull/97)** — the criteria below hold in the current `specification.md`; the only residual item is generating and pinning the canonical vectors under Gate B — re-verified after the 2026-07-23 append-only-log (D-05) and npk_commit (D-21) changes.

- one normative version contains no mixed v2 root-chain/v3 first-occurrence path;
- NISSHAC, transition essence, opening, NAV operations, carrier and rejection rules are byte-exact;
- every state advance and mint follows one first-occurrence rule;
- the 6-confirmation reorg-finality bound is stated consistently ([spec §3.9](/specification#39-finality-and-reorg-handling)), with ≥6-block reorgs marked as the accepted break boundary;
- all performance and privacy claims match the selected construction.

### Gate B — executable conformance

- the node reproduces the canonical vectors and the SDK's primitive-level re-implementation reproduces the byte-equal subset (the spec V.7 parity matrix);
- one-entry self-publish and multi-entry aggregation work on regtest and public testnet;
- a clean node reconstructs state from Bitcoin without Nostr, Blossom or a zkCoins index;
- mutation, duplicate, malformed-encoding, wrong-network and proof-substitution vectors fail;
- ≤5-block reorg-replay tests converge across two nodes, and a ≥6-block reorg is surfaced as the accepted break boundary (§3.9);
- private zero-local-state recovery is tested after loss of both the node's database and its own paired relay, restoring from the seed and Bitcoin plus the Bootstrap Manifest's seed-discoverable `seed_relay`s (delivery events) and `blob_store`s (blob bytes) — the two-plane recovery-discoverable overlap (Requirement 13, [spec §4.3](/specification#43-addressing-for-delivery)).

### Gate C — assurance

- the specification's soundness summary ([spec §2.4](/specification#24-soundness-summary)) and security-properties summary ([spec §6.7](/specification#67-security-properties-summary)) exist, every clause reference they cite resolves, every Requirement 1–13 has a row, and D-17–D-19 appear in the [§6.7 precise privacy statement](/specification#67-security-properties-summary), D-16 is stated in [spec §3.9](/specification#39-finality-and-reorg-handling), and D-20 has its row in the [Risks](/risks) verdict table (machine-checkable link/row checks);
- **D-05** passes its release gate: the **V.11 differential-test** of the in-circuit RFC-6962 log-consistency/inclusion arithmetization against an independent reference ([spec §1.7.8](/specification#178-reference-instantiation-status-final-for-v1), V.11) — executed at the negative-controls / conformance step ([Implementation Mandate](/implementation-mandate) step 5/6) as part of the executable gate, not a separate human review — alongside the existing D-16/D-17–D-20 checks above;
- **D-05 network-parameter agreement gate:** `network-params.json` is a byte-exact canonical artefact (spec §3.6); every node MUST load the pinned per-network `activation_height` and refuse readiness (`/health/ready` `503`) on mismatch; and a conformance test MUST confirm two independent nodes scanning the same tip from the **same** pinned `activation_height` produce the identical `(size, mth)` / `nav_root`, while a **differing** `activation_height` diverges them **whenever a valid nullifier is admitted in the interval between the two heights** — the conformance fixture **MUST** include at least one such nullifier so the divergence is observably guaranteed — the executable check for the parameter-agreement residual (D-05 (iv)).
- the [Risks](/risks) verdict table has no open and no broken row;
- the reference instantiation and backend are final and frozen for v1 ([spec §1.7.8](/specification#178-reference-instantiation-status-final-for-v1), [§1.7.9](/specification#179-proof-system-parameters-normative));
- a vulnerability disclosure process is published ([SECURITY.md](https://github.com/zk-coins/docs/blob/develop/SECURITY.md)).

By explicit project decision (2026-07-22) there is **no external audit, external proof review, or other human-gated step** in Gate C; the executable Gate-B evidence plus the in-spec arguments above are the v1 assurance basis.

No real-value deployment proceeds until all three gates are complete.

## 11. Release-status matrix

Every release must distinguish:

| Feature | Source paper | Target specification | Running implementation | Evidence |
|---|---|---|---|---|
| nullifier | rotating state key + NISSHAC commitment | v3 paper-model port | [`4739d80`](https://github.com/zk-coins/node/commit/4739d80) `aggregate_verify` / `AggregateStateNullifierV3` (`script-plonky2/src/half_agg.rs`); open draft [`node#231`](https://github.com/zk-coins/node/pull/231) only — **not** on `develop` | unit: `nisshac_completeness_for_one_two_and_three_members`, `nisshac_matches_the_normative_v8_fixture`, `comm_verify_accepts_honest_opening_and_rejects_wrong_values` |
| ordering | Bitcoin first occurrence | canonical scan/reorg replay | [`d7e4328`](https://github.com/zk-coins/node/commit/d7e4328) `NfLogAccumulator::fold` (`shared/src/spec_v1/accumulator.rs`); scanner rebuild [`54b7e06`](https://github.com/zk-coins/node/commit/54b7e06) (`script-plonky2/src/scanner.rs`); open [`node#231`](https://github.com/zk-coins/node/pull/231) only — **not** on `develop` | unit: `first_occurrence_duplicate_pk_does_not_move_position`, `v1_scan_fold_canonical_order_first_occurrence_wins`; live bitcoind regtest: `regtest_scanner_first_occurrence_double_spend`, `regtest_scanner_mid_scan_reorg_matches_fresh`¹ |
| reorg finality | ToS accumulator, `IsPrefix`/`DistinctElement` exactly-one-of, arbitrary-depth conditional-NAV no-op (paper §3.2/§3.6/§4.2) | RFC-6962 append-only Merkle-log accumulator + hard 6-confirmation finality, no DistinctElement no-op (D-05 succinctness fixed; D-16 unchanged) | Partial — open [`node#231`](https://github.com/zk-coins/node/pull/231) only, **not** on `develop`: host RFC-6962 log [`d7e4328`](https://github.com/zk-coins/node/commit/d7e4328) (`shared/src/spec_v1/nflog.rs`, `accumulator.rs`); in-circuit inclusion/consistency [`0619610`](https://github.com/zk-coins/node/commit/0619610) (`program-plonky2/.../nflog_consistency.rs`); hard 6-conf `size_final` (`FINALITY_CONFIRMATIONS = 6`); ≥6 fail-stop [`1b9b980`](https://github.com/zk-coins/node/commit/1b9b980) (`MAX_RECOVERABLE_REORG_DEPTH = 5`). No DistinctElement no-op path (D-16).² | unit: `size_final_confirmation_boundary`, `reorg_replay_benign_non_final_displacement`, `reorg_replay_detects_finality_breaking_displacement`, `offline_reorg_deeper_than_recoverable_limit_refuses`, `symbolic_boundary_suite_accepts_k_0_through_63`; live bitcoind: `regtest_scanner_real_reorg` |
| recovery | private coin proof required | encrypted bearer data retained by seed-discoverable relays + blob stores | Partial — open [`node#231`](https://github.com/zk-coins/node/pull/231) only, **not** on `develop`: ZBE-encrypted delivery over Nostr/Blossom (`node/src/v1/delivery.rs`), seed-only SDR-replay recovery (`node/src/v1/recovery.rs`, [spec §4.5](/specification#45-recovery)), and issuer-terms capture (`node/src/v1/db_token_provenance.rs`, §4.6 Class B). The [spec §4.3](/specification#43-addressing-for-delivery) recovery-discoverable **overlap publish-enforcement** (Requirement 13) is **not yet enforced in code**. Local engine / `op_secret` snapshot restore is a separate property. | seed-only SDR-replay restore (`recovery.rs`); the §4.3 two-plane overlap restore test is pending |
| issuance | application-defined | creator-bound, unlimited, anchored | [`c82a8cd`](https://github.com/zk-coins/node/commit/c82a8cd) / [`1e10e29`](https://github.com/zk-coins/node/commit/1e10e29) `StateEngine::begin_mint` (`script-plonky2/src/state_engine.rs`); circuit `enforce_mint` (`program-plonky2/.../compliance/skeleton.rs`); open [`node#231`](https://github.com/zk-coins/node/pull/231) only — **not** on `develop` | unit: `begin_mint_std1_remint_into_existing_account_updates_supply`, `begin_mint_predecessor_absent_from_nflog_is_dependency_not_final`, `compliance_v1_mint_proves` |
| proof backend | abstract PCD | named frozen backend | crates.io pin `plonky2 = "1.1.0"` on `develop` ([`937925a`](https://github.com/zk-coins/node/commit/937925a)); per-network `circuit_digest(C)` / `circuit_digest(C_balance)` generated on open [`node#231`](https://github.com/zk-coins/node/pull/231) @ [`0fbd0a6`](https://github.com/zk-coins/node/commit/0fbd0a6) — **not** merged | `Cargo.lock` pin; digests pinned in docs V.4; **`build-report.md` absent** in the node repository (Implementation Mandate §4 artefact not present)³ |

Target properties must never be labelled implemented without a code commit and passing evidence.

¹ Ordering evidence is accumulator unit tests plus single-process dual-scanner regtest against a live `bitcoind` (fresh scanner vs continuing scanner). There is no separate multi-process two-node suite yet.

² Reorg-finality claims checked separately: RFC-6962 host log + in-circuit gadget + hard 6-confirmation bound + ≥6 fail-stop are present on the open review branch; paper `DistinctElement` no-op is intentionally absent (D-16). None of this is on `develop`.

³ The Evidence column's build-report link targets a normative node artefact that does not yet exist; do not treat benchmarks as published.

## 12. Consequences accepted

- On-chain cost is linear in state updates and only asymptotically approaches 64 bytes each.
- Transaction count and rotating state-nullifier keys/commitments become chain-visible; amounts, assets, parties and graph are intended to remain zero-knowledge, subject to the required new proof.
- Public first-occurrence state becomes independently reconstructable and publisher races no longer invalidate unrelated transitions.
- Recursive proving, private bundle growth, mobile scanning and private bearer-data loss remain open engineering risks.
- This port is closer to Shielded CSV but is not automatically covered by its proof: zkCoins changes the account contents, multi-asset issuance, hashes, recursive backend and recovery system.

## 13. Primary references

- [Shielded CSV original 2024-09-20 release](https://github.com/ShieldedCSV/ShieldedCSV/releases/download/2024-09-20/shieldedcsv.pdf) — aggregate state nullifiers, NISSHAC, first occurrence, publisher fee and conditional NAV.
- [IACR ePrint 2025/068](https://eprint.iacr.org/2025/068) — later bibliographic record.
- [Accepted accumulator/self-publish decision](https://github.com/zk-coins/research/blob/f392fa0e4f55d68e6135e7eced15ef719118e545/zkcoins-design/ACCUMULATOR_SELF_PUBLISH.md) — project plan of record and trilemma rationale.
- [BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki) and [BIP-342](https://github.com/bitcoin/bips/blob/master/bip-0342.mediawiki) — Taproot/Tapscript carrier and limits.
- [Bitcoin Core transaction policy](https://github.com/bitcoin/bitcoin/blob/master/src/policy/policy.h) — pin the supported release's standard transaction-weight rules.
- [Official Plonky2 repository](https://github.com/0xPolygonZero/plonky2) — upstream deprecation/security-margin notice.

PR #97 performed the versioned normative specification rewrite this plan called for. This document does not by itself declare any implementation conformant or secure — the executable-conformance and assurance gates above remain open.
