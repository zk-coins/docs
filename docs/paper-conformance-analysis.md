---
title: Paper-Deviation Analysis
---

# Paper-Deviation Analysis: zkCoins Specification vs. the Original Papers

> **Docs snapshot of the complete source review.** Canonical research source: [research PR #22](https://github.com/zk-coins/research/pull/22), mirrored from commit [`e612ac8`](https://github.com/zk-coins/research/blob/e612ac8467e3fcb742b0baf8c5879c4100394abc/audit/2026-07-12-paper-conformance.md). Mirrored source SHA-256: `7078513d6e3c2e988352ff96ddeca281afcc745dbc999ce4b9cb97806d91bf17`. The remediation derived from this analysis is documented in [Paper-Conformance Remediation](/paper-conformance-remediation).

**Status:** independent internal architecture and conformance review

**Date:** 2026-07-12

**Language:** English

**Verdict:** **core-concept compatible, but not paper-conformant as a protocol construction; several material deviations are not yet sufficiently proven**

This document is intended to be stable, reviewable and linkable. It separates:

1. what is inherited from the original papers;
2. what the current specification changes or adds;
3. which deviations are already supported by a convincing argument;
4. which deviations still require a proof, implementation result, incentive analysis or specification fix.

It is not an implementation audit and not a cryptographic audit report. It is a source-to-specification conformance review from ten expert perspectives.

Selected remediation proposal: [`zk-coins/docs#96`](https://github.com/zk-coins/docs/pull/96). It converts the findings below into one coherent paper-model v3 port, exact specification edit map, and testnet/mainnet acceptance gates.

**Post-baseline architecture decision.** After the specification baseline reviewed here, [`research@f392fa0`](https://github.com/zk-coins/research/blob/f392fa0e4f55d68e6135e7eced15ef719118e545/zkcoins-design/ACCUMULATOR_SELF_PUBLISH.md) accepted on-chain half-aggregated state nullifiers, Bitcoin first occurrence and conditional NAV as the project plan of record. That later decision does not retroactively change this audit's findings against `docs@6816fc3`; it controls their selected remediation. `docs#96` is aligned to it, and the former full-batch-envelope alternative is rejected because it would retain the serialized `prev_root` writer.

**Register maintenance note (2026-07-22).** The audit text on this page is a pinned snapshot against `docs@6816fc3` and is not edited. The **register table below is the living deviation index** the [contribution rule](https://github.com/zk-coins/docs/blob/develop/CONTRIBUTING.md) points to: a **Status (current develop)** column tracks each row against the current normative specification, and rows **D-17–D-20** register the accepted v1 boundaries adopted on 2026-07-22. Where a row's *Current specification* column still describes the retired pre-#97 construction, the **status column is authoritative** for what holds today. Sections 5–12 below (perspectives, evidence tables, recommended status) are part of the pinned snapshot and are **not** release-governing: the v1 release gates are solely the [Paper-Conformance Remediation](/paper-conformance-remediation) Gates A–C, the [Assurance Roadmap](/assurance) gates, and the [implementation-mandate runbook](/implementation-mandate) — none of which contains an external-review step (project decision 2026-07-22). For rows graded AMBER in the historical columns whose Status (current develop) is CURRENT/DECIDED/ACCEPTED, the v1 disposition is the [Risks](/risks) verdict table plus the executable harness — the historical grade is not a v1 gate. In particular, the "obtain an external audit" / "subject to external audit" action items in the pinned Sections 8–10 (e.g. §8 required-actions, §9 P3 step 4, §10 recommended status) are **superseded** and are **not** v1 release gates — an autonomous implementer follows the Gates A–C / Assurance / runbook path, which has no external-audit step (project decision 2026-07-22).

## 0. Executive summary

The reviewed zkCoins specification adopts the CSV/PCD core of the two source works but is **not a construction-identical implementation**. Among other things it replaces the account-state Schnorr nullifiers, the on-chain `AggregateNullifier`, the ToS accumulator, the fee scheme and the reorg handling. In their place it introduces a serial global SMT, off-chain `BatchBundle`s, recursive publisher aggregation, its own per-coin nullifiers and a new recovery/transport layer.

These changes can work in principle, but do not automatically inherit the papers' security arguments. The most open questions are data availability, honest-node convergence, publisher incentives, deep-reorg recovery and the concrete Plonky2 implementation. Eight new findings are additionally documented. The most important are:

1. The publisher sign-to-contract check needs `R'`, but no normative published batch object transports that `R'`.
2. The on-chain `bundle_locator` is not the Blossom `blob_id`; a new node first needs a foreign mapping index just to locate a bundle at all.
3. The assumption "no reorgs deeper than five blocks" contradicts the claim that no finality assumption beyond Bitcoin is introduced.
4. Un-batched mints can be accepted with no Bitcoin artefact, which qualifies the claim that the system "settles exclusively on Bitcoin L1".
5. The specification pins Plonky2 1.1.0, although upstream now marks Plonky2 as deprecated and unmaintained.
6. The existing formal certificate targets an older spec commit and does not fully cover the reviewed version.

Overall verdict: **a paper-inspired, core-compatible successor design; material deviations are not yet fully proven or backed by implementation evidence.**

After this pinned baseline, the architecture decision `research@f392fa0` was accepted and subsequently made normative by [PR #97](https://github.com/zk-coins/docs/pull/97): the serial 231-byte batch path is rolled back in favour of the paper construction with on-chain state nullifiers, first occurrence and conditional NAV. [Paper-Conformance Remediation](/paper-conformance-remediation) tracks that closure path and the executable-conformance and assurance gates that remain open; it does not retroactively change this audit's findings against `docs@6816fc3`.

## 1. Pinned review baseline

### Current specification

- Repository: [`zk-coins/docs`](https://github.com/zk-coins/docs)
- Branch: `develop`
- Commit: [`6816fc398ea35284e640ed8e0b326fa96880cf7d`](https://github.com/zk-coins/docs/commit/6816fc398ea35284e640ed8e0b326fa96880cf7d)
- Normative file: [`docs/specification.md`](https://github.com/zk-coins/docs/blob/6816fc398ea35284e640ed8e0b326fa96880cf7d/docs/specification.md)
- SHA-256 of the reviewed file: `61d78f5fc462b463abfda4d3b6b03f342ea92ede70f80fdac1c3b733f55d61d4`

### Original sources

1. **zkCoins**, Robin Linus, 2023:
   - mutable [GitHub gist](https://gist.github.com/RobinLinus/d036511015caea5a28514259a1bab119)
   - exact reviewed gist revision: [`c86d4818c44e975442f739a7faaf73db112f5501`](https://gist.github.com/RobinLinus/d036511015caea5a28514259a1bab119/c86d4818c44e975442f739a7faaf73db112f5501), committed 2025-05-15; this is the final text revision in the gist history at review time and the exact baseline used for every zkCoins comparison below
   - reviewed raw gist Markdown SHA-256: `2cb303563ab4d49cf77cfc1e3afb578ac77f8f0e9dfd9ffb61a9d4bd7cebbf9a`
   - pinned project typographic reproduction: [`papers-typst/zkcoins.typ`](https://github.com/zk-coins/research/blob/7048503c564787bf0f775e28c5b65efab6ba79be/papers-typst/zkcoins.typ)
   - reproduction SHA-256: `75cc60755398a126e1f6186e67a78267cf6106e65bfea073079a644a643bddc0`

2. **Shielded CSV: Private and Efficient Client-Side Validation**, Jonas Nick, Liam Eagen and Robin Linus:
   - exact original paper release reviewed: [`ShieldedCSV/ShieldedCSV`, release `2024-09-20`](https://github.com/ShieldedCSV/ShieldedCSV/releases/download/2024-09-20/shieldedcsv.pdf)
   - later canonical bibliographic record: [IACR ePrint 2025/068](https://eprint.iacr.org/2025/068)
   - pinned project PDF: [`shieldedcsv-paper.pdf`](https://github.com/zk-coins/research/blob/7048503c564787bf0f775e28c5b65efab6ba79be/shieldedcsv-paper.pdf)
   - original-release and project-PDF SHA-256 (byte-identical): `889acc4223d519aaea685d79fbb61d4dff2fb1b900a481d2d20a9faa37a6a96a`
   - searchable project reproduction: [`papers-typst/shielded-csv.typ`](https://github.com/zk-coins/research/blob/7048503c564787bf0f775e28c5b65efab6ba79be/papers-typst/shielded-csv.typ)
   - Typst SHA-256: `67482012c33124fe7420a310aeb1bd305ca8d7bd2d5b5883877ce2b8ca6e8f29`

### Version caveat

The GitHub gist has a revision history and was edited after 2023. This review therefore pins revision `c86d4818…`; a future review MUST cite an exact revision rather than the mutable gist landing page. For Shielded CSV, “original paper” means the byte-pinned `2024-09-20` release above; the ePrint page is cited as the later canonical bibliographic record. These distinctions prevent a future revision from silently changing the comparison baseline.

## 2. Meaning of “conformant”

The two source documents do not define a byte-level interoperability standard. Therefore this review uses four distinct levels:

| Level | Meaning |
|---|---|
| **Core-conformant** | Retains the CSV/PCD idea, off-chain coin proofs, privacy goal and Bitcoin ordering role. |
| **Construction-conformant** | Retains the paper’s actual nullifier, accumulator, publishing, fee and reorg construction. |
| **Extension** | Adds functionality without changing a source construction’s security argument. |
| **Protocol deviation** | Replaces a source construction or moves a load-bearing trust/security boundary. |

The current specification is **core-conformant**, contains many legitimate extensions, but is **not construction-conformant**. Calling it merely “a concrete instantiation” understates the amount of protocol redesign.

## 3. Executive verdict

The specification faithfully retains these source ideas:

- Bitcoin is the immutable ordering surface used to prevent double spending.
- Transaction data and proof material are communicated off-chain.
- A recipient validates a constant-size proof rather than replaying an unbounded history.
- A PCD/recursive-proof construction hides amounts and the transaction graph.
- Publishing is intended to be permissionless.
- A transparent proof system without a trusted setup is preferred.
- Carrying actual BTC requires a separate bridge or Bitcoin-side verification mechanism.

However, the specification replaces the paper construction in several load-bearing places:

- account-state Schnorr nullifiers become keyed per-coin Poseidon nullifiers;
- on-chain aggregate nullifiers become an on-chain batch root plus an off-chain bundle;
- the paper’s ToS accumulator becomes a globally serial sparse Merkle accumulator;
- the paper’s publisher fee construction becomes a selected-publisher fee coin;
- conditional NAV reorg handling is replaced by deterministic replay plus a hard five-block reorg assumption;
- publisher-side recursive aggregation is added even though the zkCoins gist explicitly motivates a design without a sequencer coordinating global proof aggregation;
- delivery, recovery, disclosure, naming, Nostr and Blossom are new protocol layers.

Some changes are promising. They still need their own security treatment. The source papers’ proofs and arguments do not automatically transfer to a different nullifier relation, accumulator, availability model or publisher state machine.

## 4. Conformance and deviation register

Legend:

- **GREEN** — source-conformant or a low-risk extension with sufficient argument.
- **AMBER** — plausible, but evidence is incomplete or conditional.
- **RED** — material deviation without adequate current proof.
- **DEFECT** — internally incomplete or contradictory specification text.

| ID | Topic | Source construction | Current specification | Status | Required evidence or action | Status (current develop) |
|---|---|---|---|---|---|---|
| D-01 | CSV and PCD core | Recipient validates a PCD proof; proof size and verification do not grow with history. | Cyclic recursive `C` proofs and recursive receive transitions. | GREEN | Preserve in implementation and conformance tests. | UNCHANGED — cyclic recursive `C` remains the construction ([spec §2.2](/specification#22-proof-types)). |
| D-02 | On-chain data | Shielded CSV publishes aggregate nullifiers; the headline cost approaches 64 bytes per transaction. | One 231-byte `BatchInscription` per batch; member nullifiers and aggregate proof are off-chain. | RED | New security proof plus DA/convergence proof. The original proof does not cover unavailable nullifier data. | RETIRED by PR #97 — every state nullifier is published on-chain ([spec §3.1](/specification#31-the-on-chain-object), [§3.5](/specification#35-inscription-format)); this deviation no longer exists. |
| D-03 | Nullifier semantics | A fresh Schnorr public key nullifies an account state and commits to its transaction. | `nf = Hc("Nullifier", nk, coin.identifier)` nullifies each input coin. | RED | Formal game definition and reduction covering forgery, account forks, cross-account binding and deterministic uniqueness. | RETIRED by PR #97 — the on-chain nullifier is the paper's account-state `(Pkᵢ, Rᵢ)`; per-coin `nf` is in-circuit bookkeeping only ([spec §2.1 clause 4](/specification#21-the-compliance-predicate)). |
| D-04 | Publishing proof | NISSHAC half-aggregates committed Schnorr signatures; users verify on-chain aggregate nullifiers. | Publisher recursively proves a batch and signs roots; half-aggregation is optional and remains off-chain. | RED | Proof that `C_batch`, member binding, S2C and accumulator insertion jointly imply the paper-level no-double-spend and no-forgery properties. | RETIRED by PR #97 — the publisher only NISSHAC-half-aggregates, no recursive batch proof ([spec §3.3](/specification#33-half-aggregation), [§1.7.10](/specification#1710-half-aggregation-with-commitments-nisshac-normative)). |
| D-05 | Accumulator | Per-user ToS accumulator over sets of on-chain nullifiers; supports prefix/distinct-element/reorg logic. | Global **append-only RFC-6962 Merkle log** over the first-occurrence sequence; `prefix` is a constant-size log-consistency proof, membership a position-bound inclusion proof (spec §1.7.6, §3.7); rebuilt from Bitcoin alone given the network's pinned parameters. Because the log is **global and position-bound** (unlike the paper's **per-user** ToS-accumulator, which has no global position index), it requires one pinned per-network **scan origin** `activation_height` — a consensus constant absent from the paper's model, a pinned network constant (though, unlike `circuit_digest`, not cryptographically bound — see the parameter-agreement residual (iv) below) (spec §3.6, §1.7.9). **Faithfulness note:** the RFC-6962 log **shares the broad Merkle-authenticated ordered-history motif** of the paper's own §A.2 instantiation (`ToSAccMT`, itself a Merkle-tree, position-indexed ToS-accumulator whose `IsPrefix` is over an outer Merkle-tree value and whose `DistinctElement` uses the position index) — so an ordered Merkle structure is **within the paper's own family**. The **concrete construction differs**, however: v1 uses a **global, flat, per-nullifier** log with **RFC-6962 log-consistency** between flat tree heads, whereas §A.2's `ToSAccMT` is a **per-user, two-level (outer/inner), per-block** tuple whose prefix is proven by outer-tree membership of the prior root. The residual deviations are therefore (i) **global vs per-user**, (ii) the **flat per-nullifier log + constant-size in-circuit consistency**, (iii) dropping the `DistinctElement` no-op (D-16), and (iv) the **parameter-agreement assumption** for the global scan origin `activation_height` (not cryptographically bound, unlike `circuit_digest`; §3.6). | RED | **V.11 differential-test** of the in-circuit RFC-6962 log-consistency + inclusion arithmetization against an independent reference ([spec §1.7.8](/specification#178-reference-instantiation-status-final-for-v1), V.11). **Release gate:** the V.11 differential-test above — required before mainnet. | DECIDED — the nullifier accumulator is now an **append-only Merkle log** (RFC 6962 / RFC 9162 log consistency over Poseidon, [spec §1.7.6](/specification#176-nullifier-accumulator-append-only-merkle-log), [§3.7](/specification#37-the-nullifier-accumulator)); the prefix relation is a constant-size **log-consistency** proof, fixing the succinctness/soundness gap the SMT-submap relation left open. The V.11 differential-test against an independent RFC-6962 reference is the **release gate** (executed at the conformance step, spec §1.7.8/V.11) — the reference implementation performs it; this register does not assert it already passed. Still a **pure function of the on-chain nullifiers**, rebuilt from Bitcoin alone given the network's pinned parameters (activation_height, tag, digests). Registered as a **CT-consistency port** — an *ordered-sequence* prefix, distinct from the paper's ordered-**set** ToS IsPrefix. |
| D-06 | Reorg handling | Conditional NAV permits a safe no-op branch if dependencies disappear in a reorg. | Replays root transitions, but treats a reorg deeper than five blocks as protocol failure and `completed` as absolute under that assumption. | RED | Either restore a cryptographic conditional-reorg path or state a probabilistic finality model and prove recovery for arbitrary Bitcoin reorgs. (Superseded for v1 by D-16: bounded 6-confirmation finality is adopted instead of restoring an arbitrary-depth conditional-reorg path.) | SUPERSEDED by D-16 — bounded 6-confirmation finality ([spec §3.9](/specification#39-finality-and-reorg-handling)). |
| D-07 | Data availability | Coin proofs are off-chain, but double-spend nullifiers remain on-chain. | Coin proofs, nullifiers, member records and the aggregate proof depend on off-chain storage. | RED | Protocol-level retrievability/availability design, not only an operator `MUST retain` statement. | RETIRED by PR #97 — double-spend data is fully on-chain; replication covers only private bearer data ([spec §4.6](/specification#46-data-availability--replication-factor-k)). |
| D-08 | Publisher role | Permissionless publisher collects and posts aggregate nullifiers; no global recursive proof coordinator is required by the gist. | Publisher selects a serial root, aggregates proofs and is the sole writer for that root transition. | RED | Incentive/equilibrium analysis, censorship and stale-work bounds, and a decentralization argument under contention. | RETIRED by PR #97 — publishing is permissionless and contention-free with self-publish ([spec §3.4](/specification#34-the-publisher)). |
| D-09 | Publisher fees | First publisher to post can complete `payment_finalize_fee`. | Spender chooses a publisher and includes its fee coin under the same `ocr`. | AMBER | None for v1 — verdict **holds** in the [Risks](/risks) table (publisher censorship/delay row); Gate-B fee-path tests. Historical cell superseded. | CURRENT, registered deviation — spender-picks-publisher fee coin; the paper's first-to-publish-wins design is explicitly deferred ([spec §3.8](/specification#38-fees-and-economics)); incentive verdict **holds** — fee atomicity via the shared `ocr` plus permissionless self-publish re-pick; recorded in the [Risks](/risks) verdict table under publisher censorship/delay (fee **pricing** risk is the separate D-20). |
| D-10 | Recovery | Paper explicitly says loss of wallet state can make funds irretrievable. | Seed plus Bitcoin plus replicated bundles is claimed as emergency recovery. | AMBER/RED | None for v1 — recovery normative (spec §4.5–§4.8); A-to-Z restore control + Gate-B recovery tests. Historical cell superseded. | CURRENT — recovery layer normative ([spec §4.5](/specification#45-recovery)–[§4.8](/specification#48-durability--the-store-everything-invariant)); the A-to-Z suite's restore control tests it ([Implementation Mandate](/implementation-mandate)). |
| D-11 | Offline delivery | Static donation-address delivery is future work in Shielded CSV. | Nostr NIP-44/59, Blossom, detect tags, ACKs and replication. | AMBER | None for v1 — transport normative (spec §4, §7.3–§7.4); A-to-Z end-to-end delivery. Historical cell superseded. | CURRENT — Nostr/Blossom transport is normative ([spec §4](/specification#4--transport--recovery), [§7.3](/specification#73-nostr-event-kinds-normative)–[§7.4](/specification#74-blossom-blob-store-normative)). |
| D-12 | Proof instantiation | Shielded CSV explicitly permits recursive STARKs/Plonky-style PCD without trusted setup. | Plonky2 1.1.0, Goldilocks, Poseidon and concrete FRI parameters are pinned. | AMBER | None for v1 — backend frozen by project decision; executable vectors + Gate B stand in. Historical cell: external review (superseded). | DECIDED 2026-07-22 — the immutable `plonky2 = "1.1.0"` release stays pinned, final for v1 ([spec §1.7.8](/specification#178-reference-instantiation-status-final-for-v1), [§1.7.9](/specification#179-proof-system-parameters-normative)); F-05 closed. |
| D-13 | Multi-asset | Shielded CSV includes multi-asset support as an extension direction; issuance predicate is application-specific. | Creator-bound v1 assets with no protocol-enforced or publicly auditable supply cap. | AMBER | None for v1 — token standard 2 provides the auditable cap (spec §6.5); standard-1 issuer trust documented ([Risks](/risks)). Historical cell superseded. | PARTIALLY SUPERSEDED — token standard 2 (`IssuanceTerms_v2`) adds a protocol-enforced, auditable supply cap ([spec §6.5](/specification#65-issuance--token-standards)); token standard 1 remains issuer-trust and is documented as such ([Risks](/risks)). |
| D-14 | Selective disclosure | Not part of the base construction. | Transaction links, balance attestations and account views. | AMBER | None for v1 — normative §5 + the accepted Req-9(b) limit; residual disclosure bounds catalogued in [Risks](/risks). Historical cell: independent privacy review (superseded). | CURRENT — selective disclosure normative ([spec §5](/specification#5--access--explorer)); the Requirement-9(b) single-anchor limit is an accepted, final v1 limit ([Requirements](/requirements)). |
| D-15 | Naming layer and contact discovery | Not part of either source. | Every wallet account has an email-style NIP-05 name and the signed payment object bound to it, but the name is **operational, not cryptographic**: served by a node or any name provider rather than by the wallet, never seed-derived, in no signature preimage, plural per account, replaceable without touching keys or funds, and survivable on loss (reachability under that name ends; nothing else does). Contact records are keyed by `op_pubkey`. First discovery through a name searches the union of recommended NIP-05 hints and configured profile/discovery/bootstrap relays, then TOFU-pins the **key** using only relays that returned valid relevant events. It retains an IP endpoint only after original-hostname-authenticated TLS and a successful relay WebSocket upgrade on the original path. Known contacts preserve that original scheme/host/port/path without DNS. | AMBER | None for v1 — the naming layer carries no value and no authority, so its failure modes are display and reachability only: an invalidated name drops its label while the pinned key, payment identity, and conversation survive. Residual DNS-outage boundary: at least one previously reached retained endpoint must still serve its authenticated WebSocket relay path; relay failure or signed rotation solely to unknown hostnames is not survivable without DNS. | CURRENT — mandatory but non-cryptographic naming layer over seed-derived identity, mandatory kind-0 payment profile for wallet accounts, key-pinned contact discovery ([spec §4.3](/specification#43-addressing-for-delivery), [V.12](/specification#v12-kind-0-zkcoins-profile-and-nip-17-interoperability)); app-layer name requirements in the [Implementation Mandate](/implementation-mandate#app-layer-identity-and-contacts-normative). |
| D-16 | Reorg model and accumulator history relation — bounded finality replaces arbitrary-depth conditional NAV | ToS accumulator with `IsPrefix`/`DistinctElement` exactly-one-of relation; conditional-NAV no-op makes reorgs of arbitrary depth defined and survivable (paper §3.2, §3.6, §4.2). | Append-only RFC-6962 Merkle-log accumulator (log-consistency prefix, D-05), no `DistinctElement` no-op branch; hard 6-confirmation finality bound; a ≥6-block reorg MAY break zkCoins (accepted). (spec §3.7, §3.9) A consequence of dropping the `DistinctElement` no-op: a wallet **MUST wait for a dependency to reach 6-confirmation finality before building a transition against it** — the paper permits assembling/signing against still-unconfirmed inputs (safe there via the no-op reorg branch), v1 does not. This is a deliberate new spend-latency, not proving-pipelining: an "build early, don't broadcast until final" opt-in was rejected because the broadcast gate is not adversarially enforceable (a signed non-final nullifier a node publishes early would strand `Pkᵢ` under a tolerated reorg — spec §2.3.2 step 5, §3.9). | AMBER | The paper's no-op branch has no satisfiable witness in the single-circuit design (#105); building a novel sound no-op is out of scope for v1; the 6-confirmation bound is the established Bitcoin-consistent finality default and is stated as an explicit accepted limitation rather than an unproven survivability claim. Release gate: v1 — documented directive; revisit only if a sound `DistinctElement` no-op construction is adopted. Refs: #105, #106. | CURRENT — the governing reorg deviation: bounded 6-confirmation finality ([spec §3.9](/specification#39-finality-and-reorg-handling)). |
| D-17 | Hosted-prover trust (send intent) | Not addressed by the papers (wallet≡prover there). | The thin wallet delegates witness building to its (self-)selected node; only **no-inflation** (`Out(a) ≤ In(a)+Mint(a)`) is enforced in-circuit, not the return of the per-asset difference as change — a dishonest prover can redirect **or drop (burn)** send outputs, including that change ([spec §2.1 clause 3](/specification#21-the-compliance-predicate)). A compromised **selected prover** (own or a vetted foreign node) can also **freeze** the account (consume `Pkᵢ` with a never-finalizing/unsatisfiable ProofData), not only redirect/burn; mitigated by self-hosting or vetting the prover. | ACCEPTED-V1 | None — accepted boundary, final for v1 (2026-07-22); operational mitigation (self-host / vet the prover) catalogued in [Risks](/risks). | ACCEPTED, final for v1 — [spec §6.7 precise privacy statement](/specification#67-security-properties-summary), [Risks](/risks). |
| D-18 | Intra-transaction co-output visibility | The paper documents the same leak class (paper §6.3). | Every output of one transition shares one `ocr`; any output's holder learns other outputs exist ([spec §2.1 clauses 5–6](/specification#21-the-compliance-predicate)). | ACCEPTED-V1 | None — accepted boundary, final for v1; single-output guidance catalogued in [Risks](/risks). | ACCEPTED, final for v1 — bounded to one transition's co-holders. |
| D-19 | Publisher ash-chain linkage on reuse | Not addressed by the papers (no fee coin there). | A publisher reused across consecutive transitions links them via fee-coin `CoinProof` fields ([spec §3.8](/specification#38-fees-and-economics)). | ACCEPTED-V1 | None — accepted boundary, final for v1; rotation/self-publish removes the edge at no protocol cost ([Risks](/risks)). | ACCEPTED, final for v1 — voided by publisher rotation. |
| D-20 | Fee pricing is off-protocol | Paper defers fee mechanics similarly. | No on-protocol price discovery/hedging; publishers quote and bear exchange risk ([spec §3.8](/specification#38-fees-and-economics)). | ACCEPTED-V1 | None — incentive verdict **holds under stated assumptions**, recorded in [Risks](/risks). | ACCEPTED, final for v1 — market-priced, never correctness-relevant. |
| D-21 | Wallet-verifiable key rotation | not in the papers (wallet ≡ prover there) | a sixth hiding ProofData field `npk_commit = H("zkCoins/v1/NpkCommit" ‖ next_pubkey ‖ npk_rand)` (SHA-256), serialize 192 bytes; the thin wallet recomputes it and refuses to sign a substituted rotation key (fail-closed, [spec §2.1 clause 2](/specification#21-the-compliance-predicate), [§7.5](/specification#75-node-rest-api-normative)) | GREEN (extension) | None for v1 — wallet-native SHA-256, byte-pinned V.8 fixture. | CURRENT — an **extension** closing the hosted-prover rotation-capture ([Requirement 5](/requirements)); not a deviation from a paper construction, and no release gate beyond the executable harness (V.8 192-byte fixture). |

## 5. Ten expert perspectives

### Perspective 1 — protocol genealogy and paper conformance

**Verdict:** The specification is a successor design, not merely a concrete encoding of the papers.

The paper’s main construction is identifiable by four linked components: account-state nullifier keys, NISSHAC commitments, on-chain aggregate nullifiers and a ToS accumulator. The current specification replaces all four. It retains the high-level CSV/PCD philosophy, but the security inheritance stops where these components change.

The introductory statement that the specification only chooses options “wherever the source papers leave a choice open” should be replaced by an explicit deviation statement. Moving double-spend data off-chain and replacing the nullifier relation were not choices left open by Shielded CSV; they change its central construction.

**Required action:** Add a normative “Relationship to source papers” appendix, using this document’s D-01 through D-15 register.

### Perspective 2 — applied cryptography

**Verdict:** The primitives are individually conventional, but their new composition lacks a current paper proof.

Positive elements include domain separation, deterministic key derivation, explicit byte encodings, BIP-340, HKDF-SHA256, authenticated encryption, Poseidon Merkle structures and circuit-digest pinning.

The load-bearing new composition is:

```text
account-bound nk
    -> per-coin nf
    -> SpendRecord.inr
    -> member_root
    -> C_batch(prev_root, new_root, m, member_root)
    -> publisher S2C signature
    -> Bitcoin inscription
```

The Shielded CSV security argument does not prove this composition. At minimum, the project needs games and reductions for:

- uniqueness of a coin’s valid nullifier;
- account-fork and genesis-equivocation resistance;
- binding of amount, asset, recipient and coin index;
- binding of `SpendRecord.nullifiers` to `input_nullifiers_root`;
- binding of the exact proof bytes to the on-chain object;
- no cross-network or cross-circuit proof reuse;
- privacy against chain observers, bundle observers, publishers and relays as separate adversaries.

**Additional DEFECT F-01 — publisher S2C opening is not transported.** Section 3.2 says a verifier confirms `R = R' + H(R' || H_agg)G`. That requires the pre-tweak point `R'`. The published `BatchInscription` contains only the ordinary BIP-340 signature `(R,s)`, and the normative `BatchBundle` schema contains no publisher `R'`. A verifier cannot reconstruct `R'` from `(R,H_agg)` without solving the hash fixed-point/preimage problem. Therefore the claimed publisher-to-proof S2C binding is not verifiable from the specified wire objects.

**Required fix:** Either (a) add a publisher `s2c_nonce = R'` to an authenticated retrievable object and bind its encoding, (b) remove publisher S2C and sign a digest of the exact published batch body, or (c) remove the root-transition publisher layer and adopt paper-style NISSHAC state-nullifier commitments whose per-member openings travel in the corresponding private proof data. The accepted architecture decision and [`docs#96`](https://github.com/zk-coins/docs/pull/96) select option (c). Add commitment-substitution negative vectors and regenerate the signature/aggregation vectors.

### Perspective 3 — zero-knowledge proof-system engineering

**Verdict:** Feasibility remains conditional and the pinned backend has acquired lifecycle risk.

The specification requires cyclic recursion, non-native secp256k1 arithmetic, tagged SHA-256 in-circuit, exact 132-bit-or-wider balance arithmetic, 256-level SMT updates and recursive batch aggregation. It correctly labels proving costs as needing measurement.

The selected upstream project now states that **Plonky2 is deprecated and will no longer receive updates or support**, recommends Plonky3, warns that audits do not eliminate bugs, and notes that the pinned Poseidon parameters may provide about 95 bits rather than the targeted 100 bits. See the [official Plonky2 repository](https://github.com/0xPolygonZero/plonky2).

The research repository already contains a Plonky3 migration investigation, while the normative specification still pins Plonky2 1.1.0. This creates a fork in the protocol roadmap: changing field, hash, recursion or proof serialization is a protocol version change, not an internal library update.

**Required actions:**

1. Decide whether v1 intentionally ships on deprecated Plonky2.
2. If yes, vendor and maintain the full trusted code base and obtain an external audit.
3. If no, change the specification before filling `<REGEN>` vectors.
4. Benchmark the exact `C` and `C_batch` circuits, not proxy circuits.
5. Publish verifier-data digests and proof-size/proving-time distributions at maximum supported bounds.

### Perspective 4 — Bitcoin protocol and finality

**Verdict:** Bitcoin ordering is used correctly in principle, but finality and reorg claims are too absolute.

The Taproot commit/reveal mechanism requires no Bitcoin consensus change. Bitcoin can order competing inscriptions, and a strict canonical scan can select one root successor.

The specification simultaneously says:

- no reorg deeper than five blocks is assumed;
- a deeper reorg is a protocol failure;
- `completed` is absolute under that assumption; and
- zkCoins adds no finality assumption beyond Bitcoin.

The last statement is misleading. Bitcoin provides probabilistic finality; it does not guarantee a maximum reorg depth. The Shielded CSV conditional-NAV construction explicitly handles dependency loss rather than declaring deeper reorgs outside the protocol.

**Required actions:**

- Replace “absolute” with a probabilistic security statement tied to adversarial hash power and confirmation depth, or support arbitrary canonical replays.
- Specify how already-received and subsequently spent coins are repaired after a deep reorg.
- Test multi-batch rollback, stale rebatching and competing same-block inscriptions on regtest.
- Treat relay/miner policy acceptance of inscription-shaped transactions as an operational assumption separate from Bitcoin consensus validity.

### Perspective 5 — distributed systems and data availability

**Verdict:** DA is the dominant unresolved architectural risk and is worse in blast radius than in Shielded CSV.

Shielded CSV already has a bearer-data problem: losing a coin proof can destroy spendability. The new design adds a global problem: losing a `BatchBundle` can prevent a fresh verifier from validating an accumulator transition. A node that saw and retained the bundle can advance; a later node without it cannot independently reproduce that decision.

An operator rule such as “every scanner MUST retain indefinitely” is not a Byzantine availability protocol. `k = 3` also does not imply three independent failure domains unless independence is discoverable and enforced.

The related paper [Solving Data Availability Limitations in CSV with UTxO Binding, ePrint 2025/569](https://eprint.iacr.org/2025/569) independently identifies data loss and malicious withholding as fundamental CSV limitations. Its solution adds an auxiliary-chain binding, which may conflict with zkCoins’ Bitcoin-only requirement, but it confirms that replication prose alone is not a solved DA model.

**Additional HIGH finding F-02 — locator resolution is not self-contained.** Bitcoin carries a Poseidon `bundle_locator`; Blossom fetches by a different SHA-256 `blob_id`. A scanner must ask an existing holder for the mapping `bundle_locator -> blob_id` before it can fetch and verify the bundle. Consequences:

- possession of the on-chain locator is insufficient to discover the blob;
- a surviving blob can be practically lost if the mapping index is lost;
- bootstrap depends on a holder serving an unverified lookup response;
- content addressing proves a candidate after discovery but does not solve discovery.

**Required fix:** Put a directly fetchable content address on-chain, or define a deterministic, enumerable resolution layer whose availability and collision/security properties are part of the protocol. At minimum replicate and authenticate the locator mapping as a first-class object and include it in recovery tests. This closes discoverability only; preventing selective-serving ledger splits additionally requires the objective-availability repair tracked under F-06.

### Perspective 6 — mechanism design and publisher economics

**Verdict:** Permissionless entry does not establish decentralised equilibrium or liveness.

Every publisher builds a root-specific proof before knowing whether its `prev_root` will win Bitcoin ordering. Losing work cannot be reused. A conflicting spender can send variants to multiple publishers and externalise proof cost. These mechanics favour the fastest and best-capitalised publisher.

The fee coin is cryptographically atomic with the selected transition, which is good. But the fee asset may be illiquid or issuer-controlled, while Bitcoin fees must be paid in BTC. Publishers therefore bear exchange-rate, inventory and settlement risk. A market may converge on one publisher or a narrow accepted-asset list even without a protocol permission gate.

Self-publishing is not automatically a practical censorship escape: the user needs BTC, proving resources, bundle distribution and Bitcoin transaction access. It is an enabled operation, not a liveness guarantee for a thin mobile user.

**Required actions:**

- Model honest publishing, fee sniping, stale-root races and conflicting-record griefing.
- Quantify expected proof loss at realistic arrival rates.
- Define a fee quote validity window and exchange-rate risk policy.
- Separate “permissionless” from “censorship resistant for a normal user” in claims.
- Require a mainnet gate verdict of `holds` or `holds under explicit assumptions` for every publisher mechanism.

### Perspective 7 — privacy and metadata

**Verdict:** On-chain privacy is strong in shape; end-to-end privacy is conditional on network behaviour and account usage.

The design improves chain-only privacy by placing only publisher identity, roots, locator, block anchor and signature on-chain. Hiding the next-key rotation edge is important. Fresh ECDH keys and NIP-59 gift wrapping also reduce obvious relay-level linkability.

However:

- relays and Blossom stores observe timing, sizes, source IPs and fetch patterns;
- recipients scan the global candidate stream, creating bandwidth and session-correlation surfaces;
- a delegated node holding `ivk`, `ovk`, `op`, `nk` and `op_secret` has a lifetime full-account view;
- the public plaintext `BatchBundle` reveals batch membership, input count and nullifiers even if it hides amounts and recipients;
- multiple recipients of one transaction retain the source paper’s output-linkability concern;
- publisher identity and batch timing create a protocol fingerprint;
- the clear `0x4242` marker enables protocol-wide miner, relay or observer classification.

NIP-44 and NIP-59 specify payload encryption and gift wrapping, not IP anonymity or guaranteed relay retention. See the [official Nostr NIPs repository](https://github.com/nostr-protocol/nips).

**Required actions:** Publish separate privacy games for chain, bundle, publisher, relay, delegated-node and colluding-recipient adversaries. State Tor/mixnet requirements where metadata privacy is claimed rather than merely recommended.

### Perspective 8 — wallet recovery and user safety

**Verdict:** Recovery is improved over the source paper but the user-facing claim remains too strong.

The seed can restore keys, addresses, detection ability and deterministic account secrets. It cannot recreate coin amounts, received proof bytes or a lost batch’s membership data. Those are choices made by other parties and exist only in off-chain bundles.

“The seed is the only thing a user backs up” is therefore only true under a strong external availability assumption. A safer formulation is:

> The seed is the only user-managed secret backup; spendable recovery additionally requires at least one surviving, discoverable and verifiable replica of every required off-chain object.

**Required actions:**

- Define recovery completeness separately from recovery availability.
- Surface “coin discovered but proof unavailable” as a first-class wallet state.
- Test recovery with zero local state, missing delivery events, missing locator mappings, one unavailable relay, two unavailable replicas and a deep reorg.
- Explain that a valid seed cannot rescue universally lost bearer data.

### Perspective 9 — implementation, standards and interoperability

**Verdict:** The document is detailed, but it is not yet an executable interoperability specification.

Open `<REGEN>` values include empty roots, asset identifiers, nullifiers, Merkle roots, account hashes, anchor commitments and both circuit digests. Until these are generated by a real implementation and independently reproduced where possible, two implementations cannot prove byte-for-byte agreement.

Other interoperability risks include:

- Plonky2 native proof serialization is library-version-sensitive and tied to a deprecated codebase;
- several custom Nostr event kinds and tags are application-specific rather than standard NIPs;
- Bech32m strings beyond the BIP-173/350 90-character limit require non-standard decoder behaviour;
- Blossom availability and retention are deployment policy, not guaranteed by content addressing;
- exact Bitcoin witness parsing must be tested against multiple valid Taproot envelope shapes and malformed inputs;
- the repository’s older `PROTOCOL_STATUS.md` still describes a different SP1/ZeroSync implementation and paper-conformance roadmap, so target specification and implementation status must not be confused.

**Required actions:**

1. Fill and pin every vector before claiming v1 interoperability.
2. Add malformed-vector and cross-language suites.
3. Run a real node-SDK-app-regtest A-to-Z test with no mocked protocol step.
4. Publish the exact status difference between target spec and running implementation.
5. Register or document custom wire conventions sufficiently for an independent implementer.

### Perspective 10 — formal methods and assurance

**Verdict:** Existing formal work is valuable but does not certify the current specification.

The existing Apalache certificate targets [`docs@ed7fdece`](https://github.com/zk-coins/docs/commit/ed7fdece), not the reviewed `6816fc3`. Between those points, `docs/specification.md` changed by 742 insertions and 271 deletions, including load-bearing receive, anchor, nullifier, coin-identifier, key-rotation and balance-conservation changes.

Model checking also composes axiomatized cryptographic properties; it does not establish that Poseidon, Plonky2 recursion, non-native BIP-340 gadgets or the implementation satisfy those axioms. Liveness and indistinguishability properties have explicit scope reductions.

The project’s own [Assurance Roadmap](https://github.com/zk-coins/docs/blob/6816fc398ea35284e640ed8e0b326fa96880cf7d/docs/assurance.md) correctly requires security definitions, paper reductions, machine checking, implementation conformance and external audit before real value.

**Required actions:**

- Rebase every formal property onto the exact current commit.
- Add properties for the selected F-01 NISSHAC commitment opening and F-02 Bitcoin-only ledger reconstruction (or the equivalent properties of another explicitly selected alternative).
- Model honest-node convergence under asymmetric bundle availability.
- Add arbitrary-depth reorg traces or explicitly prove only a bounded model and state the assumption.
- Keep formal safety, cryptographic proof, implementation audit, liveness and incentive analysis as separate evidence classes.

## 6. Additional findings beyond the initial comparison

### F-01 — publisher S2C proof binding is not verifiable from specified objects

- **Severity:** HIGH for specification conformance/interoperability; the direct forgery impact is narrower because the aggregate proof is still verified against its public statement
- **Type:** specification completeness / cryptographic binding
- **Evidence:** `R'` is required by the verification equation but absent from both published normative object schemas.
- **Impact:** A scanner can verify an ordinary publisher signature and separately verify an aggregate proof, but cannot execute the specified S2C check binding those exact proof bytes to that signature. This is an impossible normative verification step, not by itself evidence that a forged root can pass the independently checked aggregate proof.
- **Fix acceptance:** Either a wire-carried publisher `R'`, an ordinary exact-body signature, or replacement by paper-style NISSHAC member commitments with explicitly transported openings; exact encoding plus positive and commitment/proof-substitution negative vectors in every case. The accepted plan selects the third form.

### F-02 — `bundle_locator` does not directly locate a Blossom blob

- **Severity:** HIGH for recovery/liveness; LOW for integrity
- **Type:** data discoverability
- **Evidence:** on-chain Poseidon locator and off-chain SHA-256 fetch key require a holder-maintained mapping.
- **Impact:** Existing content can become undiscoverable; new nodes cannot bootstrap from Bitcoin plus blob stores alone.
- **Fix acceptance:** direct content address or deterministic authenticated resolution with tested reconstruction from zero local state.

### F-03 — five-block reorg bound contradicts the “no added finality assumption” wording

- **Severity:** HIGH for extreme-value correctness; low-probability operationally
- **Type:** consensus/finality model
- **Impact:** A six-block reorg is possible under Bitcoin’s model but is outside zkCoins’ guaranteed state machine; already-folded receipts may require a repair path the spec does not define.
- **Fix acceptance:** probabilistic finality statement plus arbitrary reorg recovery, or an explicit accepted trust/availability assumption with user-facing limits.

### F-04 — non-batched mints weaken the “settles exclusively on Bitcoin L1” claim

- **Severity:** MEDIUM
- **Type:** requirement consistency / issuance
- **Evidence:** a mint may be accepted as `mint-verified` solely from its recursive proof and need not have a `BatchInscription`.
- **Impact:** Asset creation and unlimited follow-up issuance can occur without a public Bitcoin artefact. The asset may later be spent through an anchored batch, but issuance itself did not settle on L1.
- **Fix acceptance:** require initial and follow-up mints to anchor, or narrow Requirement 1 to state that **spends/double-spend ordering**, not every issuance event, settle on Bitcoin.

### F-05 — Plonky2 deprecation is now a protocol-maintenance risk

- **Severity:** HIGH before mainnet
- **Type:** proof-system lifecycle
- **Impact:** Frozen dependencies accumulate compiler, security and ecosystem risk. Migrating later changes proof encodings, circuit digests and possibly field/hash assumptions.
- **Fix acceptance:** explicit v1 backend decision, maintained fork and audit, or pre-v1 migration.

### F-06 — DA independence and indefinite retention are asserted but not verifiable

- **Severity:** HIGH
- **Type:** operational assumption presented as protocol guarantee
- **Impact:** three replicas may share one operator, jurisdiction, storage provider or deletion policy. There is no proof of retrievability or payment for indefinite retention.
- **Fix acceptance:** for public-ledger data, eliminate the off-chain dependency or define a complete DA protocol with an explicit failure model; for private bearer data, state replica independence, retention/retrievability policy and irreducible-loss conditions separately. The accepted plan puts state nullifiers on Bitcoin and limits replication claims to private recovery.

### F-07 — current formal certificate is stale for the reviewed baseline

- **Severity:** HIGH if cited as current assurance
- **Type:** evidence versioning
- **Impact:** reviewers may infer that recently added security-critical clauses are mechanically verified when they are not covered by the pinned certificate.
- **Fix acceptance:** certificate front matter naming `6816fc3` and successful re-verification of updated models and new properties.

### F-08 — source-paper, target-spec and running-implementation status are conflated across documents

- **Severity:** MEDIUM
- **Type:** project governance/documentation
- **Impact:** `PROTOCOL_STATUS.md` describes an older ZeroSync/SP1 path while the docs repository mandates a different Plonky2 batched target design. A reviewer can reach contradictory conclusions depending on which document they read.
- **Fix acceptance:** one current status table with three columns: paper, target specification, running implementation; each row pinned to commits.

## 7. Claim corrections recommended before public linking

| Current claim shape | Safer claim |
|---|---|
| “faithfully builds on the whitepapers wherever they leave choices open” | “retains the whitepapers’ CSV/PCD core and introduces documented protocol deviations in nullifiers, batching, DA, recovery and publishing.” |
| “no central element anywhere” | “no protocol-mandated custodial operator or permissioned validator; publisher and storage concentration remain open economic risks.” |
| “seed is the only thing a user backs up” | “seed is the only user-managed secret backup; recovery also requires surviving off-chain proof data.” |
| “two honest nodes at the same tip classify identically” | “two honest nodes with the same available and verified bundle prefix classify identically; under the current observer-dependent admission text, asymmetric/selective DA can cause divergent root prefixes until an objective admission rule resolves them.” |
| “adds no finality assumption beyond Bitcoin” | “uses Bitcoin ordering and defines application finality at six confirmations; deeper reorgs are currently outside the guaranteed state machine.” |
| “trustless” without qualifier | “custody/integrity are intended to be cryptographic; privacy, availability and liveness depend on the selected node, relays, publishers and DA assumptions.” |

## 8. Evidence required for each kind of deviation

A deviation is not adequately supported merely because the specification contains a rationale paragraph. The minimum evidence depends on its type:

| Deviation type | Minimum acceptable evidence |
|---|---|
| Cryptographic relation | Security game, reduction under named assumptions, external review. |
| State-machine change | Executable model, invariants, negative controls and reorg/race traces. |
| Proof-system choice | Real circuit, pinned verifier data, benchmarks, audit and reproducible vectors. |
| Data availability | Failure model, discoverability, retention mechanism, retrievability tests and quantified residual probability. |
| Incentive mechanism | Actor/budget model, equilibrium or simulation, griefing costs and mainnet gate verdict. |
| Privacy extension | Explicit adversary views and indistinguishability/unlinkability analysis per observer class. |
| Recovery claim | Zero-state restore test under defined replica failures and documented irreducible loss cases. |
| Wire-format extension | Independent implementation or cross-language parser/vector suite. |

## 9. Recommended closure plan

### P0 — specification blockers

1. Fix F-01 as selected in `docs#96`: retire the publisher root-transition signature and transport each paper-style NISSHAC state-nullifier commitment opening in its private proof data.
2. Fix F-02 and F-06 together for the selected architecture by publishing state nullifiers on Bitcoin and rebuilding first occurrence without a public-ledger bundle lookup; keep private `CoinProof` recovery as a separate DA class.
3. Reconcile F-03 finality language and deep-reorg behaviour.
4. Reconcile F-04 unanchored mints with the Bitcoin-only settlement requirement.
5. Decide Plonky2 versus pre-v1 migration before generating canonical vectors.

### P1 — proof and verification

1. Add formal security definitions for the redesigned state-nullifier/NISSHAC construction and its composition with the zkCoins account relation.
2. Publish paper reductions for no forgery, no double spend, conservation and privacy.
3. Update Apalache models to the final normative remediation commit, not merely `6816fc3`.
4. Add first-occurrence convergence, commitment-opening substitution, conditional-NAV and arbitrary-reorg properties.

### P2 — executable evidence

1. Implement the exact v3 account/conditional-NAV relation and NISSHAC verification/commitment gadgets; remove the retired `C_batch` root-transition path.
2. Fill all `<REGEN>` vectors and circuit digests.
3. Run cross-language primitive tests.
4. Run a non-mocked regtest A-to-Z payment and clean-room recovery.
5. Publish worst-case proof time, memory, proof size, aggregation latency, on-chain bytes per member and scan bandwidth.

### P3 — operations and economics

1. Complete publisher incentive analysis.
2. Define and test DA retention/retrievability.
3. Test independent failure domains rather than replica count alone.
4. Obtain an external cryptographic and implementation audit.

## 10. Release decision

The current specification is suitable as a **research target design**. It is not yet supported strongly enough to be described as:

- a fully conformant implementation of zkCoins and Shielded CSV;
- a proven replacement for the papers’ nullifier construction;
- fully recoverable from a seed in the Bitcoin-wallet sense;
- demonstrably decentralised under publisher incentives;
- ready to carry real mainnet value.

Recommended public status:

> **zkCoins is a paper-inspired, core-compatible successor design. Its PCD/CSV foundation follows zkCoins and Shielded CSV, while its batching, nullifier accumulator, data-availability, recovery and publisher mechanisms are documented protocol deviations that remain subject to current-baseline proofs, implementation evidence and external audit.**

## 11. Primary and project sources

- Robin Linus, [zkCoins gist](https://gist.github.com/RobinLinus/d036511015caea5a28514259a1bab119).
- Jonas Nick, Liam Eagen, Robin Linus, [Shielded CSV original 2024-09-20 release](https://github.com/ShieldedCSV/ShieldedCSV/releases/download/2024-09-20/shieldedcsv.pdf); later bibliographic record [IACR ePrint 2025/068](https://eprint.iacr.org/2025/068).
- Liu, Wang, Zhang, [Solving Data Availability Limitations in CSV with UTxO Binding](https://eprint.iacr.org/2025/569).
- [`zk-coins/docs` reviewed specification](https://github.com/zk-coins/docs/blob/6816fc398ea35284e640ed8e0b326fa96880cf7d/docs/specification.md).
- [`zk-coins/docs` Assurance Roadmap](https://github.com/zk-coins/docs/blob/6816fc398ea35284e640ed8e0b326fa96880cf7d/docs/assurance.md).
- [`zk-coins/docs` known risks](https://github.com/zk-coins/docs/blob/6816fc398ea35284e640ed8e0b326fa96880cf7d/docs/risks.md).
- [`zk-coins/research` formal certificate](https://github.com/zk-coins/research/blob/7048503c564787bf0f775e28c5b65efab6ba79be/formal/CERTIFICATE.md), which pins the older `docs@ed7fdece` baseline.
- [ShieldedCSV reference repository](https://github.com/ShieldedCSV/ShieldedCSV).
- [Plonky2 official repository and deprecation/security notice](https://github.com/0xPolygonZero/plonky2).
- [Nostr NIPs, including NIP-44 and NIP-59](https://github.com/nostr-protocol/nips).
- Bitcoin BIP-340, [Schnorr Signatures for secp256k1](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki).
- Bitcoin BIP-341 and BIP-342, [Taproot](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki) and [Tapscript](https://github.com/bitcoin/bips/blob/master/bip-0342.mediawiki).

## 12. Review limitations

- No claim is made that a listed RED deviation is impossible; RED means the current evidence is insufficient to inherit the source-paper guarantee.
- No production binary or deployed node was audited.
- No independent cryptographic reduction was constructed as part of this review.
- External links and upstream lifecycle status should be rechecked at the next review.
- Any material specification commit after `6816fc3` requires a delta review before this verdict is cited as current.
