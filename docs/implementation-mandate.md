---
title: Implementation Mandate
---

# Implementation Mandate

> *A standing instruction to every implementor (human or agent) building zkCoins. It is deliberately short on "how to code" and exact on **what done means**, **what the source of truth is**, and **how to make decisions without asking**.*

## 0. Status: green field

zkCoins is **green field**. Nothing in production must be preserved. There is **no data to migrate**, **no API contract to keep stable**, and **no backward compatibility to honour**. Every existing artefact in the `node`, `sdk`, and `app` repositories is a prototype and MAY be rewritten, replaced, or deleted in full. You are free to design the codebase from scratch. The only fixed point is the protocol defined in the [Specification](./specification.md).

This freedom is also a responsibility: where the current code disagrees with the spec, **the spec wins** and the code is changed — never the other way around without a spec change going through this repo first.

## 1. Source of truth

The single normative source is **`docs/specification.md`** in the `zk-coins/docs` repository (this site). It is complete: every key, hash, identifier, byte layout, circuit bound, proof-system parameter, wire format, Nostr event kind, Blossom endpoint, REST route, and economic rule needed to build the system is fixed there. If you believe something is still ambiguous, that is a spec bug — open a PR against `docs` to resolve it, then implement; do not resolve it silently in code.

## 2. Scope and order

The work is **not finished** when the node compiles. It is finished only when all three layers conform to the spec and interoperate end to end:

1. **`node`** (Rust) — build to the spec: the `C` and `C_batch` Plonky2 circuits ([spec §2.5](./specification.md), §1.7.9), the canonical hashing/serialization ([§1.7](./specification.md)), the Bitcoin inscription layer ([§3](./specification.md)), the Nostr relay + Blossom store + ZBE ([§4](./specification.md), §7.3, §7.4), the capability-gated REST API ([§5](./specification.md), §7.5), and the publisher interface ([§3.4](./specification.md), §7.6).
2. **`sdk`** (TypeScript) — rebuild the **thin** typed client and account adapter against the **new** `/v1/` API: BIP-39/32 derivation, BIP-340 signing with the sign-to-contract tweak, the transition proving handshake (`/v1/tx` → `awaiting_signature` → `/sign`), and the capability/pull REST flows. The SDK is the reference for all client-side **crypto** (derivation, hashing, signing) — byte-equivalent at the hash and derivation level, verification-checked for signatures (§3) — and nothing more. It does **not** verify proofs, run scan loops, decrypt bundles, or talk to Nostr/Blossom directly; those live in the node (see "Thin-client rule" below). It talks only to the wallet's own node over REST.
3. **`app`** (Next.js) — rebuild on top of the rewritten SDK. Migrate the app's crypto path **off** its in-tree WASM onto the SDK's pure-TS primitives (the SDK exists to be that single implementation), and drive the full user journey (onboard, receive, send with the publisher-fee flow, balance, history, disclosure links) through the SDK against a local node. The app stays thin too: it renders what its node serves and signs with keys it holds; it does not re-implement node-side verification or scanning. The one client-side-crypto exception the spec allows is the **stateless explorer** applying a bearer view secret to an already-encrypted blob ([spec §5](./specification.md)) — that is presentation, not wallet trust-reduction.

**Thin-client rule (hard, project-wide).** zkCoins follows the Bitcoin full-node model: the wallet trusts **its own** node. There is **no anti-node logic** in the wallet/SDK/app — no client-side proof verification, no scan loops, no view-key/spend-key consistency checks against a second node, no "node integrity" UI. Anything whose purpose is to reduce trust in the node belongs **node-side**, or the answer is self-hosting. This rule is stated verbatim in every repo's `CONTRIBUTING.md` and constrains where each piece of functionality lives. The spec's client-side verification language ([§2.3.3](./specification.md), [§4.4](./specification.md)) is always "the receiver **or its node, on its behalf**" — i.e. the node does it; the thin client delegates to the node it operates.

Done = node ✓ **and** sdk ✓ **and** app ✓, each conformant and the three proven to work together locally (§3, §4 below).

## 3. Definition of done

A layer is done only when **all** of the following hold:

- **Spec-conformant.** Every normative MUST/MUST NOT in `docs/specification.md` that applies to the layer is implemented. The conformance test vectors ([spec test-vector section](./specification.md#test-vectors-conformance-harness)) are generated and pinned (§4 below), and node and SDK each reproduce the values in their scope bit-for-bit (the SDK the hash- and derivation-level values; the two `circuit_digest`s come from the node's deterministic §1.7.9 build; the V.5/V.6 `signature` vectors validate by BIP-340 verification including the sign-to-contract tweak check, not byte equality).
- **A-to-Z tested end to end.** Beyond unit coverage there is a full-journey test that exercises a real flow across all three layers running locally: create two accounts, mint, pay (with a real publisher batching the `SpendRecord` and inscribing a `BatchInscription` against a local/regtest Bitcoin), the recipient discovers + verifies + credits the coin, and a confirmation link renders. No mocks on the protocol path — real proofs, real inscriptions, real Nostr/Blossom transport.

## 4. Conformance vectors come first

The spec's Poseidon-dependent values are marked `<REGEN>` because they must be **produced**, not invented (the spec explicitly forbids guessing Poseidon digests). The **first** node task is to implement [spec §1.7.1/§1.7.2](./specification.md) (Poseidon-Goldilocks + the `E(·)` field encoding) and the §1.7.9 circuit build, then compute every `<REGEN>` value (the empty roots, `asset_id`, `ash`, `coin.identifier`, `nf`, the Merkle roots, and the two `circuit_digest`s per network) and **submit them back to `docs/specification.md` as a PR**. Once the node produces them and the SDK's independent primitive-level re-implementation (derivation, hashing, signing) reproduces the hash- and derivation-level values bit-for-bit, those values are locked and become the conformance baseline (the SDK cross-Rust parity suite, `sdk/test/cross-rust/`, builds on them); the two `circuit_digest`s are reachable only through the §1.7.9 circuit build and are locked by the node's deterministic build alone, and the V.5/V.6 `signature` vectors are locked by BIP-340 verification — including the sign-to-contract tweak check — rather than byte equality, because BIP-340 nonce derivation includes auxiliary randomness ([spec §3.2](./specification.md)). There is deliberately no second full protocol implementation; the independent assurance a second client would provide comes from the [Assurance Roadmap](./assurance.md) instead. Do not treat any `<REGEN>` row as authoritative until it is generated and pinned.

## 5. Working method: autonomous, logged, professional, consistent

Both the implementor **and** the agent that maintains/completes this spec work the same way:

- **Be autonomous.** Do not stop to ask which option to take. When the spec leaves a genuine implementation choice (a data-structure shape, an internal module boundary, a library, a test layout), pick the option that is most **professional and consistent** with the rest of the system, and proceed. Run the work to completion rather than pausing for confirmation.
- **Log decisions, don't request them.** Every non-obvious choice is recorded — in the relevant repo's `DECISIONS.md` (or a PR description / ADR), with a one-line *why*. The point is a durable trail, not a question. Only escalate to a human if the **same** issue blocks twice after genuine attempts, or if a choice would change a user-visible or architectural property in a way the spec does not cover — in which case the resolution goes into the **spec** first.
- **Spec changes flow through `docs`.** If implementation reveals a spec gap or error, fix it by a PR to `docs/specification.md` (and regenerate any affected vectors), then implement against the corrected spec. Code and spec never diverge silently.
- **Professional & consistent is the tie-breaker.** Whenever two designs are otherwise comparable, choose the one a careful engineer would defend in review: consistent naming and structure across node/sdk/app, no half-finished paths, no speculative abstraction, tests that prove behaviour rather than restate it.

---

## Appendix A — Decisions taken while completing the spec

These are the decisions made to close the open implementation questions, recorded here so the rationale is durable. Each is now normative in `docs/specification.md`; the *why* is "professional & consistent" applied to the facts found in the `node` and `research` repos.

| # | Decision | Where | Why |
|---|---|---|---|
| D1 | **Proof system pinned** to Plonky2 `1.1.0` (crates.io), Goldilocks field, `PoseidonGoldilocksConfig`, `D = 2`, cyclic recursion. | §1.7.9 | Already the working, tested choice in `node`; bit-stable. |
| D2 | **Circuit config = `standard_recursion_zk_config()`** (zero-knowledge **on**); FRI `rate_bits 3 / cap_height 4 / pow 16 / 28 queries / ConstantArityBits(4,5)`, 100-bit FRI security. | §1.7.9 | ZK is mandatory (proofs travel to receivers/scanners and carry `nk` in the witness — [Req 2](./requirements.md)). The node currently uses the non-ZK config; corrected here. FRI values are the Plonky2 standard the node already runs. |
| D3 | **Circuit bounds** `MAX_TX_INPUTS = 8`, `MAX_TX_OUTPUTS = 8` (outputs count recipients + change + fee coin); wallet splits larger transactions. | §2.5 | Matches the node's proven `MAX_IN/OUT_COINS = 8`; covers a payment + change + fee with margin. |
| D4 | **`C_batch` = binary recursive aggregator** (arity 2, cyclic; leaf = 1 member, inner = 2 child proofs), uniform public inputs `(prev_root, new_root, m, member_root)`, `MAX_BATCH_MEMBERS = 2^16`. `bundle_locator = Hc("BatchBundle", prev ‖ new ‖ u32(m) ‖ member_root)` where `member_root` is a bottom-up binary `BatchMember` hash tree; left-to-right leaf order = SMT insert order = `member_root` order, enforced in-circuit. | §2.5, §2.2, §1.4 | The only way to keep the `AggregateBatchProof` constant-size in `m` within fixed-shape circuits; the `member_root` (vs a flat hash over all records) is what makes the locator computable bottom-up and binds member order. Mirrors the node's cyclic/`conditionally_verify` composition. |
| D5 | **Canonical proof serialization = Plonky2 `to_bytes()`** for all hashed/content-addressed proofs; `bincode` only for private at-rest storage. | §1.7.9, §3.2 | Portable and stable across implementations; `bincode` layout is serde-version-fragile and must never enter a content address. |
| D6 | **ZBE** (chunked ChaCha20-Poly1305, 64 KiB chunks, counter nonce, index-binding AAD) for bundle blobs; plain NIP-44 v2 only for the small control events. | §4.2.1 | NIP-44 v2's 65 535-byte cap cannot carry ~100 KB proof bundles; ZBE reuses the same AEAD primitive family, so no new assumption. |
| D7 | **Nostr event kinds** fixed: gift-wrap 1059 / seal 13 (NIP-59), delivery rumor 1420, ACK rumor 1421, recipient profile 30420 (addressable, `d`=address), publisher profile 30421 (addressable, `d`=publisher_pubkey). **Blossom** BUD-01/02 under `/blossom`. | §7.3, §7.4 | A coherent, collision-free kind block; addressable kinds for the two discoverable profiles; Blossom is the de-facto Nostr content-addressed blob standard, and its SHA-256 key equals the spec's `blob_id`. |
| D8 | **Versioned `/v1/` REST API** (public projection, submit+proving job handshake with wallet-held signing, capability-gated pull, publisher interface), JSON for control, canonical binary for artefacts, decimal-string big integers. | §7.1, §7.5, §7.6 | Green field allows a clean design; keeps the proven async-job proving model from the node but reframes it onto the spec's submit/pull/publish interfaces and custody boundary. |
| D9 | **Fee-coin mechanism**: spender picks a publisher from its `op`-signed profile (flat `fee` per `SpendRecord`), adds a fee output coin to the publisher's `fee_address` **under the same `ocr`** as the payment, hands over `SpendRecord` + fee `CoinProof`. Atomicity comes from the shared `ocr` (one `SpendRecord` per transition): the publisher cannot collect the fee without anchoring the payment, and an un-anchored transition's fee never reaches `completed`, so a censoring publisher collects nothing. Re-pick on censorship is safe (idempotent nullifiers). | §3.8, §7.6 | Trustless, needs no new on-chain field, reuses the coin model exactly. The paper's first-to-publish fee design is noted as a later privacy upgrade. |

If any of these is contradicted by a future cryptographic review ([spec §1.7.8](./specification.md)) or a hard implementation constraint, change it **in the spec first**, regenerate affected vectors, then implement.
