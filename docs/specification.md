---
title: Specification
---

# zkCoins Protocol Specification

This document is **a possible** technical specification of the **zkCoins protocol** — one concrete, buildable realization of the zkCoins concept (Robin Linus) and the **Shielded CSV** construction (Jonas Nick, Liam Eagen, Robin Linus), designed around a single principle: **the full self-sovereignty of every participant, with no central element anywhere in the system.**

> Private payments on Bitcoin — no new chain, no token, no consensus change, no trusted operator. Only Bitcoin, zero-knowledge proofs, and the user's own keys.

:::tip In one paragraph (plain language)
zkCoins lets you send value on Bitcoin without anyone seeing the amount, the asset, who paid, or who received. Bitcoin stores only **opaque markers** that transitions happened — *not* the coin's contents, which travel privately between sender and receiver as a small encrypted bundle. **Double-spend protection** is the chain's job: every state-advancing transition — a send, a receive, and a mint — publishes a one-time, random-looking *nullifier* on Bitcoin — about 64 bytes — that can enter the Bitcoin-anchored global nullifier set only once; a publisher may half-aggregate many transitions' nullifiers into one inscription (or a wallet publishes its own), and any second transition against the same account state is rejected. Your **seed phrase** derives every key, your **wallet** is the only thing that can spend, **any node** can serve you, and your own node checks every figure against Bitcoin on your behalf (the Bitcoin full-node model — trustlessness comes from self-hosting that node, [Requirement 4](/requirements)).
:::

:::info What this is — and what it isn't
This is **one** concrete realization, not the only one possible: wherever the source papers leave a choice open, this specification takes the established, Bitcoin-consistent option and defines it exactly. It follows the whitepapers' construction — registering every load-bearing deviation in the [Paper-Deviation Analysis](/paper-conformance-analysis) ([relationship section](#relationship-to-the-source-papers)) — and carries their philosophy into every layer they did not formalize — delivery, recovery, access, and operation. It describes the **target design** and is intentionally independent of any current implementation.
:::

## One principle, carried all the way

Every decision below follows from one idea — **complete self-sovereignty, zero central elements** — applied without exception:

| Design decision | follows from the principle |
|---|---|
| Settles only on Bitcoin L1 — no own chain, token, or consensus | inherit the most decentralized base; build no new one |
| Client-side validation; constant-size ZK proofs | each participant verifies for themselves, trusting no one |
| Spend key lives only in the wallet | the participant alone holds custody |
| Off-chain delivery over an operator-run relay mesh | no central delivery service |
| Recovery from seed + Bitcoin + the network | no central backup custodian |
| Capability-gated disclosure; self-hostable, verifiable explorer | the owner alone decides who sees what; no trusted authority |
| Any node — switchable, several at once | no lock-in to any operator |
| Permissionless asset creation | anyone can create their own asset; each asset's minter is its creator |

These are not features bolted on. They are the same principle, followed to its conclusion.

## The triad it guarantees

- **Bitcoin-anchored** — settled on Bitcoin L1, exactly as it exists today.
- **Shielded** — amounts, sender, receiver, and the transaction graph are hidden, behind a global anonymity set.
- **Trustless** — correctness is enforced by cryptography and Bitcoin alone.

Each is rare on its own elsewhere; here they hold **together** — see [Comparisons](/comparisons).

## How the data moves

**What lives where.** Bitcoin holds only opaque markers; everything that says *which coin, how much, between whom* lives off-chain and is encrypted to the recipient:

```
    BITCOIN L1 (Public)                  OFF-CHAIN (Private — wallet + node)
    ────────────────────                 ───────────────────────────────────

    ┌──────────────────┐                 ┌───────────────────────────────┐
    │ Nullifier        │  sign-to-       │  AccountState                 │
    │ ────────────     │  contract       │   balances · keys · counters  │
    │ Pkᵢ  (x-only)    │  binds          │   coin_history_root           │
    │ Rᵢ   (S2C nonce) │ ◀ H(ProofData)─ ├───────────────────────────────┤
    │                  │                 │  SpendRecord {Pkᵢ, signature} │
    │ (~64 bytes/tx,   │                 │   per-transition authorization │
    │  half-aggregated │                 │   (96 bytes, off-chain)       │
    │  by a publisher) │                 ├───────────────────────────────┤
    └──────────────────┘                 │  CoinProof bundle  ──▶ to B   │
            ▲                            │   (coin + proof + creating    │
            │ inscribed in a             │    nullifier + nav opening +   │
            │ Taproot reveal-tx          │    encryption envelope) —      │
            │ envelope                   │   relay mesh (indefinitely     │
            │                            │    retained; optional          │
            │                            │    redundant copies)           │
            │                            │                               │
            └────────────────────────────┴───────────────────────────────┘
```

**A payment, end to end.** A pays B; both run their own wallet+node; only Bitcoin is shared:

```
    Alice                 Nostr relay     Publisher       Bitcoin       Bob
      │                       │              │              │           │
      │ 1. build SpendRecord  │              │              │           │
      │    + recursive proof  │              │              │           │
      │                       │              │              │           │
      │ 2. publish encrypted CoinProof bundle (NIP-44 / NIP-59)         │
      ├──────────────────────▶│              │              │           │
      │                       │              │              │           │
      │ 3. hand nullifier (Pkᵢ,Rᵢ,sᵢ,R') to publisher (fee-less, v1) │
      │    (off-chain; or self-publish)                                 │
      ├─────────────────────────────────────▶│              │           │
      │                       │              │              │           │
      │                       │              │ 4. half-aggregate many   │
      │                       │              │  nullifiers' signatures  │
      │                       │              │              │           │
      │                       │              │ 5. inscribe one          │
      │                       │              │  half-aggregated set     │
      │                       │              │  (~64 B / tx)            │
      │                       │              ├─────────────▶│           │
      │                       │              │              │           │
      │                       │  every node folds each Pkᵢ into the     │
      │                       │  global accumulator by first-occurrence │
      │                       │  — a pure function of Bitcoin           │
      │                       │              │              │           │
      │                       │ 6. scan CoinProof candidates · match    │
      │                       │    detect_tag (1 ECDH+hash/evt)         │
      │                       ◀──────────────────────────────────────────
      │                       │              │              │           │
      │                       │ 7. gift-wrapped bundle blob             │
      │                       ├─────────────────────────────────────────▶
      │                       │              │              │           │
      │                       │            8. decrypt with K_tx         │
      │                       │              verify recursive proof,    │
      │                       │              creating nullifier is      │
      │                       │              first-occurrence anchored, │
      │                       │              and nav is canonical       │
      │                       │              │              │           │
      │                       │            9. receive transition folds  │
      │                       │               the coin in (trustless)   │
      │                       │              │              │           │
      │10. encrypted ACK · A keeps her copy (Data Permanence)           │
      ◀──────────────────────────────────────────────────────────────────
      │                       │              │              │           │
```

## Scope

The specification covers every component that will exist: the **node** (validator · prover · relay · data store), the **wallet** (thin key-holder), and the **explorer** (public and authorised views) — together with the cryptography that binds them. For every key, hash, and identifier it states exactly **how it is derived**; for every requirement, **how it is met**.

## The thirteen requirements

The whole specification exists to satisfy these (in full on the [Requirements](/requirements) page):

1. Bitcoin L1 as the only base · 2. Private · 3. Trustless · 4. Client-side validation · 5. Custody only in the wallet · 6. Recovery · 7. Self-hostable · 8. Multi-asset · 9. Selective disclosure · 10. Node portability · 11. Standard identity and messaging · 12. Data Permanence · 13. Recovery availability from the seed alone.

## Contents

| # | Section | What it gives you |
|---|---|---|
| 1 | [Foundations](#1--foundations-normative) | The single source of truth: primitives, the full key hierarchy and exact derivations, every identifier, the data structures and the global nullifier accumulator |
| 2 | [Proofs & State Transitions](#2--proofs--state-transitions) | The compliance predicate, recursion, and the mint / send / receive algorithms |
| 3 | [On-chain Layer](#3--on-chain-layer) | The on-chain nullifier `(Pkᵢ, Rᵢ)` (~64 bytes per transition, half-aggregated), transition signing, publisher half-aggregation, and the global nullifier accumulator |
| 4 | [Transport & Recovery](#4--transport--recovery) | Off-chain delivery, note discovery, seed recovery, data availability |
| 5 | [Access & Explorer](#5--access--explorer) | Capability-gated pull, view grants, and the disclosure spectrum: per-transaction links, balance attestations, full-account views |
| 6 | [System Architecture](#6--system-architecture) | Node, wallet, explorer; portability, multi-node, issuance, threat model |
| 7 | [Wire Formats & Node Interfaces](#7--wire-formats--node-interfaces) | Concrete bytes: serialization, Nostr event kinds, Blossom blob store, the versioned `/v1/` REST API, publisher interface |
| — | [Glossary](#glossary) | Every term, identifier, and notation, alphabetical, one line each |
| — | [Test vectors](#test-vectors-conformance-harness) | Worked-example values and a conformance harness for implementations |

New here? Read **Foundations** first — everything else builds on it. Stuck on a term? Jump to the **Glossary**. Looking for one key, secret, or capability and who holds it? [Keys and identities](/keys-and-identities) lists every one of them and points back here.

## Requirements traceability

Where each requirement is satisfied:

| Requirement | Satisfied by |
|---|---|
| **1 · Bitcoin-only base** | §1 (no native token; secp256k1/BIP-340), §3 (a per-transition ~64-byte nullifier `(Pkᵢ, Rᵢ)`, half-aggregated and inscribed by a publisher; no chain/consensus change) |
| **2 · Private** | §1.3 (per-coin encryption), §1.4 (the on-chain nullifier `(Pkᵢ, Rᵢ)` carries only a rotating key and a sign-to-contract nonce — no amounts, parties, per-coin nullifiers, or account link on chain), §2 (ZK proof hides amounts/parties/graph) |
| **3 · Trustless** | §2 (proof soundness ⇒ no forgery), §3 (nullifier accumulator ⇒ no double-spend), §1.2 (no key a node holds can spend), §6 (threat model); §3.4 + §6.3 (permissionless publish and node portability — freeze resistance) |
| **4 · Client-side validation** | §2 (the receiver — its own node on its behalf, thin-client rule — re-verifies the full recursive proof), §4 (receive flow) |
| **5 · Custody only in wallet** | §1.2 (SPEND branch is wallet-only; hardened separation); §2.1 clause 2 + §7.5 (`npk_commit` makes the rotated key wallet-verifiable, fail-closed) |
| **6 · Recovery** | §1.3 (seed-derived detection/scan keys), §4 (seed reconstruction, Data Permanence, data availability) |
| **7 · Self-hostable** | §6 (one `docker compose` stack — node · bitcoind · nostr-relay · PostgreSQL · explorer — each a pluggable, own-or-external building block, no operator-specific dependencies), §4 (paired Nostr relay) |
| **8 · Multi-asset** | §1.4 (`asset_id`), §1.5 (per-asset balances), §2 (per-asset conservation), §6 (issuance) |
| **9 · Selective disclosure** | §5 (three opt-in tiers — per-transaction §5.6, balance attestation §5.7, full-history view grant §5.8; each verifiable against Bitcoin, rendered by a self-hostable explorer) |
| **10 · Node portability** | §1.2/§4.5/§4.8 (value-bearing wallet state is seed-/chain-derived or content-addressed, permanently retained, fetchable, and independently verifiable; none is tied to one node), §6 (switch / multi-node and explicit non-value portability residuals) |
| **11 · Standard identity and messaging** | §1.2 (identity keys seed-derived), §4.1/§4.3 (the app and API layers give every account they serve one name and a signed kind-0 payment object; the holder attests the name with `sk₀` via `name_sig`; the name is replaceable and survivable on loss; contacts keyed by `op_pubkey`), §7.3/V.12 (mandatory NIP-17/kind-10050 and external-client interoperability), Lightning/mail bridge pages (independently optional) |
| **12 · Data Permanence** | §4.8 (never delete received data — store everything indefinitely and unconditionally; no drop, no expiry, no pruning, no supersession clean-up); §4.2/§4.5 (sender and every holder retain their copy forever; recovery therefore needs no central backup custodian); §7.4 (blob store is append-only — no `DELETE`) |
| **13 · Recovery availability from the seed alone** | §4.3 (recovery-discoverable overlap — every delivery event reaches ≥1 network `seed_relay`, every blob ≥1 network `blob_store`); §4.5 (seed-only reconstruction complete on both planes after loss of the node's database and its own relay, under the §4.10 operational conditions); §4.6 (encrypted network redundancy; self-hostable relay/blob store; open Class-B token provenance so a token survives its issuer); §4.10 (responsibility tiers; the ≥1-live-holder guarantee, operational not cryptographic) |

## Conventions

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) follow RFC 2119. All notation, primitives, and domain-separation tags are defined once in [Foundations](#1--foundations-normative) and used unchanged throughout; sizes, encodings, and input orderings are exact.

## Protocol versions, token standards, and document editions

This document defines **every** zkCoins protocol version and **every** token standard in one file; there is no separate per-version specification. Three independent version axes appear throughout, each named so it can never be read as another:

- **Protocol version (`v1`, `v2`, …).** One pinned circuit family: a fixed `circuit_digest(C)` and `circuit_digest(C_balance)` ([§1.7.9](#179-proof-system-parameters-normative)) and the lineages built on them. A protocol version governs the domain-separation namespace `"zkCoins/v<N>/…"`, the `/v<N>/` REST prefix ([§7.5](#75-node-rest-api-normative)), the `kernel.v<N>` RPC package ([§7.8](#78-kernel-rpc--the-internal-interface-normative)), and the [§7](#7--wire-formats--node-interfaces) wire formats. There is exactly one pinned circuit family per protocol version, and a change to any frozen element defines a **new** protocol version with new digests and new lineages ([§1.7.8](#178-reference-instantiation-status-final-for-v1)); a frozen version's artefacts are never edited in place. This document currently specifies **protocol version v1**. Items marked as a later "v2" feature in the text (for example the Passkey-derived seed of [§1.2](#12-key-hierarchy)) are normative for the **next** protocol version and are recorded here for continuity; a **v1** implementation **MUST NOT** activate them. Domain-separation tags record the version under which a construction is **pinned**, not the version that first activates it: a construction pinned under an earlier version keeps its tag unchanged when a later version activates it, so its derivation stays byte-stable across the version boundary — the Passkey seed derivation of [§1.2](#12-key-hierarchy), a v2 feature, therefore retains its `"zkCoins/v1/…"` tags.

- **Token standard (`issuance_version` 1, 2, 3, …).** An issuance schema in the token-standards catalog of [§6.5](#65-issuance--token-standards) — the rules governing an asset's supply and minting. This is an **independent** counter and is **not** a protocol version: the trailing `V<n>` / `_v<n>` in a token standard's derivation tags (`AssetIdV<n>`, `IssuanceTerms_v<n>`) denotes the **token-standard number**, never the protocol version. The standard **number** is an independent counter, but the circuit machinery a standard needs is not: a token standard is realised as an in-circuit version branch of the circuit `C` ([§6.5](#65-issuance--token-standards) *Adding new token standards*). A standard already built into a protocol version's **pinned** circuit (standards 1 and 2 in v1) needs no new protocol version; a standard that requires a branch **not** present in an already-pinned circuit changes `C` and therefore ships only as part of a **new** protocol version ([§1.7.8](#178-reference-instantiation-status-final-for-v1)). A token standard keeps its own number across whichever protocol version first provides its machinery.

- **Document edition (`spec-v<X>.<Y>`).** A released snapshot of this document is tagged `spec-v<X>.<Y>`, where `X` is the **protocol version** it specifies and `Y` is an **editorial revision** introducing no change to a frozen normative artefact of that protocol version. The first edition that introduces a new protocol version is `spec-v<X>.0`.

**Parallel operation (normative).** A node **MUST** be able to validate and serve, in parallel, every protocol version and every token standard it has enabled; a node **MAY** enable or disable support for a given protocol version, and independently for a given token standard, by configuration. Assets, accounts, and coins of different protocol versions and different token standards **coexist**: each coin is validated under the circuit of its own protocol version and carries its own token standard, the way distinct Bitcoin address types — or distinct token standards on one chain — coexist under a single node. The protocol defines **no** conversion of value between protocol versions or between token standards: a coin never changes its protocol version or its token standard, and there is **no** in-protocol swap or migration primitive between them. (Where a token standard itself defines redemption to an external asset, that redemption is a property of that standard, not a conversion between zkCoins versions.)

## 1 · Foundations (normative)

> *In one sentence: every key, hash, identifier, and byte-level rule the rest of the spec uses, defined exactly once here.*

This page is the **single source of truth** for the zkCoins specification. Every other spec page builds on the primitives, keys, identifiers, and structures defined here. It is written against the **target design** (the [Requirements](/requirements)), not against any current implementation.

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) are used per RFC 2119.

### 1.1 Cryptographic primitives

The protocol fixes one concrete instantiation. Where a choice was open, the established, Bitcoin-consistent option is taken.

| Role | Primitive |
|---|---|
| Signature curve & scheme | **secp256k1**, **BIP-340 Schnorr** (x-only public keys, 32-byte) |
| On-chain / signature hash | **SHA-256** (BIP-340 uses tagged SHA-256 internally) |
| In-circuit hash | **Poseidon** over the proof field `𝔽` (Goldilocks, `p = 2^64 − 2^32 + 1`); reference instance: Plonky2 `PoseidonGoldilocksConfig` — state width 12, rate 8, capacity 4, 8 full + 22 partial rounds, round constants and MDS as in `plonky2/src/hash/poseidon.rs`. Parameters and absorption MUST match this instance (§1.7) |
| General hash (addresses, off-circuit ids) | **SHA-256** |
| Recursive proof system | A **proof-carrying-data (PCD)** scheme via **cyclic recursion**; reference instantiation: a FRI-based recursive proof (Plonky-style) over Goldilocks with Poseidon |
| Key derivation | **BIP-32** (secp256k1) for the key tree; **HKDF-SHA256** for symmetric/derived secrets |
| Transport encryption | **NIP-44 v2** (ECDH-secp256k1 → HKDF-SHA256 → ChaCha20 + HMAC-SHA256) |
| Metadata privacy | **NIP-59** gift-wrap |
| Text encoding | **Bech32m** for the address (HRP `zk`); transport identifiers as `bech32m` with role HRPs |

Notation:

- `H(x)` — SHA-256 of byte string `x`.
- `Hc(tag, a, b, …)` — Poseidon over `𝔽`, **domain-separated** by `tag`, applied to the field-encoded inputs.
- `P = k·G` — secp256k1 scalar multiplication; `G` the generator.
- `ECDH(k, P) = x(k·P)` — the 32-byte big-endian x-coordinate of the shared point. When `P` is given **x-only** (32 bytes — `epk`, `IVPK`), it is lifted to the even-y point (`lift_x`, BIP-340) before the multiplication; the lift's sign ambiguity is immaterial because `x(k·lift_x(P))` is identical for both candidate points.
- `a ‖ b` — byte concatenation. Inside the argument list of an `Hc(tag, …)` call, `‖` instead separates the hash's typed **input list** ([§1.7.2](#172-field-encoding-e-of-hc-inputs)); it never denotes prior byte concatenation there.
- **Secret vs. public.** A lowercase key name (`skᵢ`, `ivk`, `ovk`, `op`, `nk`) denotes the **secret scalar**; its public point is written `<name>·G` or a named pubkey (e.g. `Pkᵢ = skᵢ·G`, `IVPK = ivk·G`, `op_pubkey = op·G`). BIP-340 public keys are **x-only** (32 bytes).

**Domain separation.** Every `Hc`, `HKDF`, and `H` call that takes a literal context string **MUST** use the prefix form `"zkCoins/v1/<context>"`. The contexts reserved by this spec are:

- **Identifiers and per-coin derivations** — `AssetId`, `AssetIdV2` (the token-standard-2 capped-asset id, [§6.5](#token-standard-2--auditable-capped-supply)), `Coin`, `AccountState`, `NkCommit` (account nullifier-key commitment, §1.5/§2.1 clause 4), `Nullifier`, `NoteKey`, `DetectTag`, `OutKey` (outgoing-recovery key, §1.3).
- **Per-transition Merkle roots** — `CoinsRoot`, `CoinsRoot/Leaf`, `CoinsRoot/Node`, `NullifiersRoot`, `NullifiersRoot/Leaf`, `NullifiersRoot/Node`.
- **Nullifier-accumulator Merkle log** — `NfLog/Leaf`, `NfLog/Node`, `NfLog/Root`, `NfLog/Empty` (the global append-only nullifier-accumulator log, RFC 6962 over Poseidon, §1.7.6). **Coin-history SMT** — `CoinHist/Leaf`, `CoinHist/Node` (per-account coin-history sparse Merkle tree, §1.7.6).
- **Conditional NAV** — `NavCommit` (the hiding commitment to a transition's conditional nullifier-accumulator value `nav` that a proof exposes publicly, §1.4/§3.9); `NavRand` (the HKDF context for the per-transition `nav_rand` derivation, §1.4); `NpkCommit` (the wallet-native SHA-256 commitment to the rotated `next_pubkey`, §2.1 clause 2); `Network` (the public-input `network_id = Hc("Network", network_tag_bytes)`, §1.4/§2.2/§2.5).
- **On-chain / off-chain protocol messages** — `Grant`, `Invoice`, `NameConsent` (the [§4.3](#43-addressing-for-delivery) name attestation, whose `name_len` counts the canonical UTF-8 byte sequence of the normalized name), `PullChallenge`, `PullHost` (channel binding, [Access & Explorer §5.1](#51-capability-gated-pull)), `AttestBalanceChallenge`, `IssueGrantChallenge` (action-bound ownership challenges for [§7.5](#75-node-rest-api-normative) `/v1/attest/balance` and `/v1/grants`), `AttestBalance`, `IssueGrant` (canonical request-hash tags for those same endpoints), `IssuanceTerms`, `IssuanceTermsV2` (the token-standard-2 capped-asset terms hash, [§6.5](#token-standard-2--auditable-capped-supply)), `HalfAgg` (the on-chain half-aggregation transcript, [§3.3](#33-half-aggregation)), `BalanceProof`, `Ack` (delivery acknowledgement, §4.2), `BootstrapManifest` (per-network infrastructure bootstrap signature domain, [§4.3](#43-addressing-for-delivery)), `OperatorEndpoint` (signed operator/endpoint gossip, [§4.3](#43-addressing-for-delivery)).
- **Transport** — `BlobKey`, `Blob` (ZBE blob encryption key derivation and per-chunk AAD, [§4.2.1](#421-bundle-blob-encryption-zbe-normative)).
- **Seed derivation** — `PasskeySeed` (HKDF context for deriving the seed from a Passkey PRF output, §1.2) **(v2 feature — not applicable in v1)**.

The fixed string `zkCoins/v1/genesis` (an `Hc` *input* constant, [§1.4](#14-identifiers-and-hashes)) and the test-vector labels (V.1) reuse the version prefix for namespacing but are **not** domain-separation contexts — they never select an `Hc`/`HKDF`/`H` domain and are therefore not listed above. The network tags `zkCoins/v1/mainnet` / `zkCoins/v1/testnet` / `zkCoins/v1/regtest` (verifier-data parameters, [§2.2 network/chain separation](#22-proof-types)) **do** feed a domain-separation context: each is absorbed as the byte-string input of `Hc("Network", network_tag_bytes)` that yields the public-input `network_id` ([§1.4](#14-identifiers-and-hashes), [§2.5](#25-circuit-dimensioning-normative)); the tag strings themselves are not contexts, but they are the sole input that selects the `Network` domain.

Reusing a context for two purposes is forbidden. Where a later section writes shorthand such as `Hc("Coin", …)` or `H("Invoice" ‖ …)`, this is equivalent to the full prefixed form `Hc("zkCoins/v1/Coin", …)` / `H("zkCoins/v1/Invoice" ‖ …)`; **implementations MUST use the full prefixed string**, the shorthand is a notation convenience. The address derivation `address = H(Pk₀ ‖ nk_commit)` ([§1.4](#14-identifiers-and-hashes)) is the one identifier with no context prefix — by design, since its input `Pk₀ ‖ nk_commit` is already SHA-256-collision-bound.

**HKDF parameter mapping (normative).** Every `HKDF(tag, material)` call in this document — `K_tx`, `K_out` ([§1.3](#13-per-coin-keys-note-encryption--detection)), `nav_rand` ([§1.4](#14-identifiers-and-hashes)), the Passkey seed ([§1.2](#12-key-hierarchy)), and the ZBE `kb` ([§4.2.1](#421-bundle-blob-encryption-zbe-normative)) — denotes HKDF-SHA-256 per RFC 5869 with one fixed parameter mapping:

- **`IKM`** = `material` — the raw byte-concatenation of the shorthand's `‖`-joined arguments ([§1.7.2](#172-field-encoding-e-of-hc-inputs)'s note that HKDF preimages absorb raw bytes, not the `Hc` length-prefixed input-list encoding), each argument in its existing fixed-width byte encoding used throughout this document.
- **`salt`** = 32 zero bytes.
- **`info`** = `tag` — the full `"zkCoins/v1/<context>"` string, ASCII bytes, no length prefix or terminator.
- **`L`** (output length) = 32 bytes.

That is, `HKDF(tag, material) = HKDF-Expand(HKDF-Extract(salt = 0x00×32, IKM = material), info = tag, L = 32)`. [§4.2.1](#421-bundle-blob-encryption-zbe-normative)'s `kb = HKDF-SHA256(IKM = K_tx, salt = 32 zero bytes, info = "zkCoins/v1/BlobKey", L = 32)` is this same mapping spelled out for the single-argument case `material = K_tx`; it applies identically to every other `HKDF` call site, so `K_tx`, `K_out`, `nav_rand`, and the ZBE `kb` are bit-reproducible across implementations.

### 1.2 Key hierarchy

All key material descends deterministically from a single **seed** that roots the BIP-32 tree. The seed is the only thing a user backs up ([Requirement 6](/requirements)).

**v1 seed derivation (normative).** In v1 the BIP-32 root seed is the **512-bit** BIP-39 seed (`seed64`), computed from the 12-word mnemonic by PBKDF2-HMAC-SHA512 (2048 iterations) with an **empty passphrase**. A v1 wallet **MUST NOT** apply a non-empty BIP-39 passphrase — the optional passphrase (BIP-39 "25th word") is a **v2** feature, not applicable in v1. The pinned end-to-end derivation is V.2-ext.

```
seed  (v1: 512-bit BIP-39 seed64 from the 12-word mnemonic, empty passphrase — Passkey PRF → HKDF is a v2 feature, not applicable in v1)
  └─ BIP-32 ─▶ m  (master)
        └─ m / 1798' / account'                              = A   (per-account root; 1798' = zkCoins purpose)
              ├─ A / 0'        = SPEND branch   (wallet only)
              │     ├─ A/0'/0'            = sk₀   → Pk₀   (initial signing key; fixes the address)
              │     └─ A/0'/i'            = skᵢ   → Pkᵢ   (rotating per-transition signing key)
              ├─ A / 1'        = VIEW branch    (delegable to a node)
              │     ├─ A/1'/0'            = ivk           (incoming viewing key)
              │     └─ A/1'/1'            = ovk           (outgoing viewing key)
              ├─ A / 2'        = op            (operational / Nostr identity key)
              ├─ A / 3'        = nk            (account-level nullifier key; part of the operational bundle)
              ├─ A / 4'        = op_secret     (nav-rand secret; keys the nav_rand HKDF, §1.4)
              └─ A / 5' / j'   = op_j          (RESERVED for op rotation; unused in v1, where op = A/2')
```

`A/5'` is **reserved and unused in v1**: v1's Nostr identity is `op = A/2'` and nothing derives under `A/5'`. It exists because `op` is the only member of the operational bundle whose compromise is **active** rather than passive — a holder can sign, impersonate, and mint view grants as the account ([§6.6](#66-threat-model-and-trust-configurations)) — and without a reserved position, replacing it would require abandoning the account and moving funds. Reserving the index now costs one number and keeps `op = A/2'` byte-identical to the pinned [V.2-ext](#v2-address-derivation-sha-256--bech32m--pinned) chain; the rotation procedure itself (announcement, contact re-pinning, re-issued `name_sig`) is **not specified in v1** and **MUST NOT** be implemented. Note honestly what rotation would and would not buy: it would stop a former operator acting *as* the account, but `ivk` is fixed into the address through `nk_commit`, so it would **not** end that operator's ability to decrypt future incoming coins — the "move to a new account on suspected bundle compromise" rule of [§7.7](#77-wallet--node-bootstrapping-normative) stands either way.

`1798'` is the chosen BIP-43 purpose index for zkCoins (hardened). All branch separations are **hardened**: the VIEW, `op`, `nk`, and `op_secret` branches are hardened children of `A`, so a party holding them **cannot** derive the SPEND branch. `op_secret` (`A/4'`) is a dedicated 256-bit secret that keys the deterministic `nav_rand` HKDF (§1.4); like `nk` it is part of the operational bundle the wallet entrusts to its own node. It has a branch of its own for a specific reason: **`nav_rand` is disclosed.** The opening `{nav, nav_rand}` travels to every coin recipient and every disclosure verifier ([§1.4](#14-identifiers-and-hashes), [§2.3.2](#232-send)), so the key feeding that HKDF hands out a stream of its own outputs by design. It must therefore be a secret with **no other role** — which rules out deriving `nav_rand` from `nk`, a circuit witness bound to the address through `nk_commit`, or from `ivk`, whose public half appears in every profile, even though either would otherwise satisfy every stated constraint. Keeping it clear of `op` follows from the same rule and is not the whole of it.

**Passkey seed source (v2 feature — NOT applicable in v1).** A v1 wallet derives the seed **exclusively** from the BIP-39 12-word mnemonic (V.2-ext below); for a v1 account it **MUST NOT** offer, select, or use the passkey-derived-seed path. The specification below is **normative for a later protocol version (v2)** and documented here for continuity.

**Passkey seed source (normative for v2) — a custody trade-off ([Requirement 5](/requirements)).** When (under the v2 feature above) the seed is taken from a **Passkey PRF** rather than a BIP-39 mnemonic, the wallet **MUST** derive it exactly as follows. Custody of the seed inherits the passkey's storage model. A **platform-synchronised** passkey (e.g. iCloud Keychain or Google Password Manager) replicates the credential material from which the seed is derived to the provider's servers, so whoever controls that account can reconstruct the seed. For strict custody a wallet **SHOULD** back the seed with a **device-bound** (non-syncable) passkey or a BIP-39 mnemonic. This is a deployment trade-off about *where the seed lives*, not a break in the protocol's custody model — the SPEND branch still never leaves the wallet in use ([Requirement 5](/requirements)).

**WebAuthn PRF → seed (normative for v2 only — NOT applicable in v1; fail-closed).** The numbered steps below apply **only** to the v2 Passkey seed path defined above; a **v1** wallet **MUST NOT** execute them and derives the seed **exclusively** from the BIP-39 mnemonic (V.2-ext).

1. **Fixed PRF salt.** Let `prf_salt = SHA-256(UTF8("zkCoins/v1/PasskeyPRF"))` (32 bytes). This salt is a protocol constant — not per-user, not per-credential, not per-device.
2. **PRF evaluation.** The wallet **MUST** obtain `prf_output` exclusively via the WebAuthn **PRF** extension (`prf`) with `eval.first = prf_salt` (the salt of step 1 as the first evaluation point). The authenticator's PRF result for `eval.first` **MUST** be used as `prf_output`. Any other salt, a second evaluation point (`eval.second`), or a non-PRF secret **MUST NOT** feed the seed derivation.
3. **Length.** `prf_output` **MUST** be **exactly 32 bytes**. A missing PRF result, an empty result, or a result of any other length **MUST** fail the derivation (no truncation, no padding, no hashing-down).
4. **HKDF.** `seed = HKDF-SHA256(IKM = prf_output, salt = 0x00×32, info = "zkCoins/v1/PasskeySeed", L = 32)` — i.e. the [§1.1](#11-cryptographic-primitives) mapping `HKDF("zkCoins/v1/PasskeySeed", prf_output)` under the reserved `PasskeySeed` context. The resulting 32-byte `seed` is the account-tree root of this section.
5. **Credential selection.** On **first** Passkey-backed seed creation the wallet **MUST** create (or select) a WebAuthn credential that advertises PRF support, request the PRF extension with `eval.first = prf_salt` at creation/assertion, and **persist** that credential's `credentialId` as the sole seed-derivation credential for this wallet instance. On every subsequent unlock the wallet **MUST** assert **exactly that** stored credential (not a discoverable-credential picker over unrelated passkeys) with the same `eval.first = prf_salt`. If several zkCoins-bound credentials exist (e.g. multi-device), each device uses the credential **it** stored for seed derivation; cross-device seed equality holds only when the authenticators yield the same PRF output for `prf_salt` (platform-sync or the same hardware-bound secret).
6. **Unsupported PRF — fail-closed.** If the platform, authenticator, or credential does **not** support the PRF extension, if the extension is omitted from the assertion result, if `eval.first` is absent, or if step 3's length check fails, the wallet **MUST** refuse Passkey seed derivation and **MUST NOT** fall back to any other secret (user handle, credential id, signature bytes, clientDataJSON, authenticatorData, or a password). The user may instead use a BIP-39 mnemonic. Silent substitution of a non-PRF secret is forbidden.

A deterministic seed test vector (SHA-256 / HKDF only — no Poseidon) is in [V.2-passkey](#v2-passkey--passkey-prf--seed-fixture-pinned).

**Who holds what** (this table is the cryptographic basis of the trust model, [§6.6](#66-threat-model-and-trust-configurations)):

| Key | Held by | Can do | Cannot do |
|---|---|---|---|
| `skᵢ` (SPEND branch) | wallet only | authorise spends | — |
| `nk` | wallet, and the wallet's **own** node (operational bundle) | compute nullifiers — required in the proving witness ([§2.1 clause 4](#21-the-compliance-predicate)) | spend; it **can link the account's own spends**, which is why it is entrusted only to the account's own node, never a foreign one |
| `ivk` | wallet, and any node the wallet delegates to | detect & decrypt **incoming** coins | spend |
| `ovk` | same | recover **outgoing** coin plaintext via the per-coin `out_ciphertext` (§1.3) | spend |
| `op` | the node | act as the standard Nostr identity, send/read NIP-17 messages, sign profiles, relay lists, view grants & acknowledgements | spend, decrypt others' coins |
| `K_tx` (per-coin note key, §1.3) | derived per coin; shareable | decrypt **exactly one** coin | spend, see any other coin |

The **operational bundle** `{ivk, ovk, op, nk, op_secret}` is what a wallet entrusts to its **own** node so the node can receive, prove, and serve on its behalf 24/7 ([§6.2](#62-wallet--node)). None of it can spend; `nk` additionally lets its holder link the account's own spends, which is why the bundle goes only to the account's own node. A *foreign* node never receives the bundle; the wallet instead issues that node a scoped, `op`-signed **view grant** ([§5.2](#52-view-grant)).

**Spend-key model (account-level).** The keys `skᵢ` are rotating **per-transition** signing keys — there is **no** per-coin signing key. Transition `i` (where `i = send_counter` at entry) is authorised by `skᵢ`, whose public key `Pkᵢ` is the account's `current_pubkey` and is carried in that transition's `SpendRecord` (§1.4); every **state-advancing** transition — send, receive, or mint — publishes `Pkᵢ` as its on-chain nullifier key ([§3.1](#31-the-on-chain-object)), while the account's own recursive proof verifies the transition in-circuit ([§2.2](#22-proof-types)). The transition rotates `current_pubkey` to `Pk_{i+1}`. `Pk₀` and `nk_commit` together fix the address (`address = H(Pk₀ ‖ nk_commit)`, §1.4). `nk` is account-level and is **bound to the account identity itself**: its commitment `nk_commit = Hc("NkCommit", nk)` is both a committed `AccountState` field ([§1.5](#15-core-data-structures), [§2.1 clause 4](#21-the-compliance-predicate)) **and** part of the address preimage, so a coin sent to an address has exactly one valid nullifier and a holder cannot equivocate two accounts (two `nk`) under one address (the soundness role, not a custody change — `nk` stays the secret witness). Coin ownership is by the account (a coin's `recipient = address`); a receiver therefore never needs a per-coin key.

**Accounts and addresses are one-to-one.** An account `A` has **exactly one** address, `address = H(Pk₀ ‖ nk_commit)` (§1.4); the address commits to both the initial spend key **and** the account's nullifier-key commitment, so the correspondence `address ↔ (Pk₀, nk_commit) ↔ account` is genuinely one-to-one — a holder cannot register two accounts (two `nk`) under one address. The protocol defines **no** diversified addresses, sub-addresses, or change addresses: there is no way to derive a second, separately-disclosable or separately-unlinkable receiving address under the same account. The **account is therefore the sole unit** of every isolation boundary in the system — privacy domain, selective disclosure ([Access & Explorer](#5--access--explorer)), recovery ([Transport & Recovery](#4--transport--recovery)), and node portability ([Requirement 10](/requirements)). A wallet derives further accounts at `m/1798'/account'`; it **MUST NOT** present multiple receiving addresses within one account. Consequences a wallet **MUST** surface to the user:

- To keep two activities unlinkable toward the counterparties they are shared with, or to disclose one independently of the other ([Access & Explorer §5.8](#58-address-view-full-history)), each **MUST** live in its **own account**, chosen deliberately — never as an implicit sub-address of a shared account.
- Each additional account is an independent scan and recovery scope (its own `ivk` / `detect_tag` lineage) and adds backup and scanning cost. This cost is the deliberate, accepted price of compartmentalisation; it is the reason the default is **one account reused**, not many accounts.
- Reusing one address toward many counterparties reveals nothing on-chain — [Requirement 2](/requirements) is unaffected — but lets those counterparties correlate one another **off-chain** through the shared address string. Per-relationship unlinkability therefore requires per-relationship accounts, never extra addresses on one account.

**Dense, monotone account assignment (normative — terminating discovery).** Hardened account indices at `m/1798'/account'` are assigned **densely and monotonically**: the wallet **MUST NOT** first-use account index `n+1` until account index `n` has at least one **`completed`** genesis transition (its `InitialProof` under `Pk₀(n)` has reached first-occurrence + ≥6 confirmations, [§3.10](#310-transaction-states)). Seed recovery therefore enumerates accounts by a **dense scan** that is the **sole normative truth** of which accounts exist under the seed ([§4.5](#45-recovery)): for `account' = 0, 1, 2, …` re-derive `Pk₀(account)` and stop at the first index whose `Pk₀` has **never** been published on Bitcoin; a moderate gap limit of **20** consecutive indices whose `Pk₀` is on-chain only as `pending` (not yet `completed`) **MAY** be bridged so a recovering wallet does not abort mid-window of in-flight genesises, but a never-published `Pk₀` is always a hard stop. Neither the account index nor any "previous account" reference **MUST** appear on-wire or on-chain — the correspondence is seed-local only. An optional encrypted account-hint in a [§4.3](#43-addressing-for-delivery) recovery-manifest **MAY** accelerate discovery but is **never** the sole source of truth and **MUST NOT** replace the dense scan.

### 1.3 Per-coin keys (note encryption & detection)

Each output coin carries an ephemeral key and is individually encrypted, so that a single per-coin capability discloses one coin and nothing else.

```
Per output coin:
  esk           = random scalar                          (sender, fresh per coin)
  epk           = esk·G                                   (published with the coin)
  IVPK          = ivk·G                                   (recipient incoming-view pubkey)
  ss            = ECDH(esk, IVPK)  = ECDH(ivk, epk)       (shared secret; both sides derive it)
  K_tx          = HKDF("zkCoins/v1/NoteKey",  ss ‖ epk)   (per-coin symmetric note key)
  detect_tag    = Hc("zkCoins/v1/DetectTag",  ss ‖ epk)   (per-coin detection tag; same ss as K_tx, distinct tag)
  K_out         = HKDF("zkCoins/v1/OutKey",   ovk ‖ epk)  (sender-side, from the SENDER's own ovk)
  out_ciphertext = NIP44Binary(K_out, "K_tx", K_tx)       (outgoing-recovery envelope; §4.2 self-delivery)
```

**`NIP44Binary` — binary payloads over NIP-44 v2 (normative).** NIP-44 v2's interoperable plaintext interface is **UTF-8 text** and its on-the-wire / library return value is a **Base64 payload string**. Binary protocol values therefore **MUST NOT** be passed raw into `NIP44_v2`. The labelled canonical helper is:

```
NIP44Binary(key, label, b) := NIP44_v2(key, UTF8("zkcoins-bin-v1:" ‖ label ‖ ":" ‖ base64url_no_pad(b)))
```

where `label` is a fixed ASCII token with no `:` character, `base64url_no_pad` is the URL-safe Base64 alphabet of RFC 4648 §5 **without** `=` padding, and `key` is the NIP-44 conversation key. The helper's output — and therefore every stored/transmitted `ciphertext` / `out_ciphertext` field — is the **UTF-8 encoding of the Base64 payload string that NIP-44 v2 returns**, **not** the decoded AEAD ciphertext raw bytes and **not** the binary plaintext `b`.

**Decrypt / open (normative, fail-closed).** Opening a `NIP44Binary` field under the expected `key`, `label`, and binary length `L` **MUST**:

1. Treat the field as UTF-8 of a NIP-44 Base64 payload and run NIP-44 v2 decryption under `key`; failure **MUST** reject.
2. Require the recovered plaintext UTF-8 string to equal exactly `"zkcoins-bin-v1:" ‖ label ‖ ":" ‖ enc` for the **expected** `label` (exact byte match of the fixed prefix and label, single `:` separators); any other prefix, label, or extra/missing separator **MUST** reject.
3. Require `enc` to be **canonical** `base64url_no_pad` of some byte string `b` (alphabet `[A-Za-z0-9\-_]`, no `=`, no whitespace, and re-encoding `base64url_no_pad(b)` **MUST** equal `enc` bit-for-bit — non-canonical encodings reject).
4. Require `|b| = L` for a call site with a **fixed** expected length; a length mismatch **MUST** reject. For a **variable-length** call site (currently only `"blob-locators"`), require instead that `b` is a **canonical** parse of the labelled structure under that call site's bounds (no trailing bytes); a parse failure **MUST** reject.

The normative call sites and their `(label, L)` pairs are:

| Field | Conversation key | `label` | Binary `b` | Expected `L` |
|---|---|---|---|---|
| `CoinProof.ciphertext` | `K_tx` | `"coin"` | `serialize(Coin)` ([§1.5](#15-core-data-structures)) | **112** (fixed) |
| `out_ciphertext` (per `output_ref`) | `K_out` | `"K_tx"` | `K_tx` (32-byte note key) | **32** (fixed) |
| `fee_blob_locators` ([§7.6](#76-publisher-interface-normative)); encrypted holder sets under a note key | `K_tx` (re-derived from the hand-off `epk` / publisher `ivk`) | `"blob-locators"` | `serialize(BlobLocatorSet)` ([§7.1](#71-serialization-conventions-normative)) | **variable** — after decrypt, `b` **MUST** parse as a well-formed `serialize(BlobLocatorSet)` under the §7.1 bounds; any parse failure, out-of-bounds count/length, or trailing byte **MUST** reject (step 4 uses parse-acceptance in place of a single fixed `L`) |

- `K_tx` and `K_out` instantiate the [§1.1](#11-cryptographic-primitives) `HKDF(tag, material)` parameter mapping (`IKM = material` — here `ss ‖ epk` or `ovk ‖ epk` — `salt` = 32 zero bytes, `info = tag`, `L` = 32).
- The coin plaintext — `serialize(Coin)` ([§1.5](#15-core-data-structures), the coin's `{identifier, recipient, amount, asset_id}`) — is encrypted under `K_tx` as `ciphertext = NIP44Binary(K_tx, "coin", serialize(Coin))`; this is the `CoinProof.ciphertext` field ([§1.5](#15-core-data-structures)). It is **distinct** from the bundle-level ZBE output the whole serialised `CoinProof` is wrapped in for transport and content-addressing ([§4.2](#42-bundle-delivery) steps 1–2, [§4.2.1](#421-bundle-blob-encryption-zbe-normative)) — the two are different byte strings under different schemes that happen to share the informal name "ciphertext"; only the bundle-level one is ever hashed for `blob_id`. Only a holder of `ivk` (the recipient, or its node) can re-derive `K_tx` and decrypt either.
- `detect_tag` lets a recipient/node find its own coins **without trial-decrypting every event**. The **sender** computes it from the shared secret `ss = ECDH(esk, IVPK)`; the **recipient**, holding `ivk`, recomputes `ss = ECDH(ivk, epk)` for each candidate's published `epk`, then `Hc("zkCoins/v1/DetectTag", ss ‖ epk)`, and matches against the published `detect_tag` — one ECDH plus one Poseidon hash per scanned event, replacing the full AEAD trial-decryption **and** the (≈100 KB) blob fetch for every non-matching event. Because every coin uses a fresh `epk`, each recipient's events carry **all-distinct** tags: a tag does **not** link two of one recipient's coins, and a relay that holds neither `ivk` nor the sender's `esk` can **neither** pre-filter for the recipient **nor** correlate the recipient's events. Detection does not reduce the *count* of candidates the recipient pulls. `ivk` is **seed-derivable**, so detection doubles as the recovery scan key ([Requirement 6](/requirements)).
- **Why the shared secret, not a recipient-only key (normative rationale).** The tag **MUST** derive from `ss` — not from a value bound to the recipient's secret `ivk` alone — because the **sender** sets the tag at send time and holds only the recipient's public `IVPK`. It can compute `ss = ECDH(esk, IVPK)`, but **cannot** compute any function of the recipient's secret key. A recipient-only detection key (e.g. `HKDF(ivk)`) would shrink the recipient's per-event check to a single hash, but is **unsatisfiable for an open, no-prior-interaction address**: a per-coin tag that is simultaneously (i) sender-computable from a static public key and (ii) unlinkable to outsiders must carry its per-coin entropy through a Diffie–Hellman with the fresh `epk`, so the recipient's check is inherently one ECDH per candidate, never a bare hash. The bandwidth lever would be the future-version (not in v1) Fuzzy message detection below, not a cheaper tag derivation.
- **Key-reuse safety (normative).** The same shared secret `ss` feeds both the **secret** note key `K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk)` and the **public** `detect_tag = Hc("zkCoins/v1/DetectTag", ss ‖ epk)`. The two are domain-separated outputs of `ss ‖ epk` under distinct context strings **and** distinct primitives (HKDF-SHA-256 vs Poseidon); modelling each primitive as an independent random oracle, neither value reveals the other. In particular the on-the-wire `detect_tag` does **not** leak `ss` (Poseidon preimage resistance, [§1.7.1](#171-poseidon-instance-and-digest-encoding)), so publishing the tag does **not** weaken `K_tx` or the coin's confidentiality.
- **Fuzzy message detection (NOT part of v1).** A relay-side probabilistic pre-filter (tunable false-positive rate) reduces the candidate count the recipient downloads, at no linkability cost. It would change only the tag computation and is a possible **future-version** scan-efficiency upgrade — v1 nodes and wallets **MUST** use exactly the detect-tag computation of this section, and no FMD algorithm is specified or permitted in v1 — not a fix for a linkability the deterministic scheme does not have.
- **Outgoing recovery (`out_ciphertext`, normative).** For every outgoing coin the sender **MUST** derive `K_out = HKDF("zkCoins/v1/OutKey", ovk ‖ epk)` from its **own** `ovk` and produce `out_ciphertext = NIP44Binary(K_out, "K_tx", K_tx)` — the labelled binary envelope of the 32-byte note key under `K_out` as the conversation key. Each outgoing coin appears in the sender's `SelfDeliveryRecordV1` as an `output_ref { coin_id, blob_id, epk, out_ciphertext, blob_locators }` ([§4.2](#42-bundle-delivery), [§7.1](#71-serialization-conventions-normative)). A holder of the sender's `ovk` re-derives `K_out` from the stored `epk`, opens `out_ciphertext` under the decrypt rules above (`label = "K_tx"`, `L = 32`) to recover `K_tx`, fetches the blob via the framed `blob_locators` when it is not held locally, and opens the outgoing coin's `ciphertext` under (`label = "coin"`, `L = 112`) — this is the concrete mechanism behind every "recover outgoing-coin plaintext" capability (§1.2, [§5.8](#58-address-view-full-history)). `ivk` alone therefore yields the incoming-only view; `ivk ‖ ovk` yields the full view.
- The **per-coin view capability** placed in an explorer link ([§5.3](#53-per-coin-view-capability), [§5.6](#56-shareable-confirmation-links)) is `K_tx` for that one coin. It decrypts that coin only.

### 1.4 Identifiers and hashes

Exact derivations. Every value here is reproducible from its inputs.

| Identifier | Definition | Size / type |
|---|---|---|
| **Address** | `address = H(Pk₀ ‖ nk_commit)` — SHA-256 of the **initial** spend public key concatenated with the account's nullifier-key commitment `nk_commit = Hc("NkCommit", nk)` (§1.5, §2.1 clause 4); fixed at account creation; the protocol's only value-bearing cryptographic payment identifier. NIP-05 is the account's public human/Nostr identity. Binding `nk_commit` **into the address** makes the account's nullifier key part of its payment identity, so a coin sent to an address has **exactly one** valid nullifier and a holder cannot equivocate two accounts (two `nk`) under one address (§2.1 clause 4, §2.2) | 32 bytes (Bech32m, HRP `zk`) |
| **nk_commit** | `nk_commit = Hc("NkCommit", nk)` — Poseidon commitment to the account nullifier key `nk` (§1.2); a committed field of `AccountState` (§1.5, §1.7.4) and part of the `address` preimage above; `nk` stays the secret witness | 256-bit digest (32-byte canonical) |
| **AssetId** | `asset_id = Hc("AssetId", genesis_tag ‖ creator_pubkey ‖ name_hash ‖ decimals ‖ issuance_version)` at asset creation, where `creator_pubkey ≜ Pk₀` of the issuing account (its initial spend public key — the key that, together with `nk_commit`, fixes the account `address`; note `asset_id` binds **`Pk₀` alone**, not the full address, so one `Pk₀` may issue under several accounts — see [Architecture §6.5](#65-issuance--token-standards)), `name_hash = H(name)`, `genesis_tag` is the fixed constant ASCII string `zkCoins/v1/genesis`, and `issuance_version` is the **token standard (issuance-schema version)** the asset is created under (a `u8`; `1` or `2`, see [Architecture §6.5](#65-issuance--token-standards)). A **token-standard-2** asset instead derives `asset_id = Hc("AssetIdV2", genesis_tag ‖ creator_pubkey ‖ name_hash ‖ decimals ‖ issuance_version ‖ cap_total ‖ terms_salt)`, additionally binding the supply cap `cap_total` (`u128`) and its secret blind `terms_salt` (32 bytes), with `terms_hash = Hc("IssuanceTermsV2", asset_id ‖ issuance_version ‖ cap_total ‖ terms_salt)` ([Architecture §6.5](#token-standard-2--auditable-capped-supply)). The human-readable `name` is **never** on-chain. Every input is derived from stated values, so `asset_id` is fully reproducible | 256-bit digest (32-byte canonical) |
| **Coin identifier** | `coin.identifier = Hc("Coin", prev_account_state_hash ‖ recipient ‖ asset_id ‖ amount ‖ coin_index)`. The `prev_account_state_hash` is the `ash` of the **prior** account state — the state *before* the transition that creates the coin — so the identifier is a well-defined function of inputs known at creation time and is **not** recursively dependent on the transition's own `new_account_state_hash` (which itself folds in `coin_history_root`, §1.7.4–§1.7.6). `recipient` and `amount` are the coin's `CoinTemplate` fields (§1.5), also fixed at creation, so folding them into the preimage keeps the identifier deterministic while **binding the coin's value and owner into the commitment**: the identifier is the leaf committed to `output_coins_root` (§2.1 clause 6), and it is **recomputed in-circuit from the full tuple** wherever the coin is spent (§2.1 clause 2(c)) or received (§2.1 clause 10(b)), so a receiver cannot credit — nor a spender debit — an `amount` or `recipient` other than the one the creating account committed. This is what makes per-asset conservation hold **across** account boundaries, not only within one transition (§2.4). `recipient` and `amount` stay in the witness — only the identifier and the roots over it are public (§2.1 clause 9) — so this binding adds no disclosure. A coin's identifier is fixed at creation and recomputed with that same `prev_ash` (and the same `recipient`/`asset_id`/`amount`/`coin_index`) when later spent. | 256-bit digest (32-byte canonical) |
| **account_state_hash** (`ash`) | `ash = Hc("AccountState", serialize(AccountState))` | 32-byte canonical |
| **output_coins_root** (`ocr`) | Poseidon Merkle root over the transaction's output `coin.identifier`s, tag `CoinsRoot` | 32-byte canonical |
| **input_nullifiers_root** (`inr`) | Poseidon Merkle root over the transition's spent `nf`s, tag `NullifiersRoot` | 32-byte canonical |
| **Transition message** (`m_state`) | The **per-network fixed** protocol-constant string that every account transition on that network signs (§3.2, §2.1 clause 2), chosen by the node's network: `m_state = "zkCoins/v1/StateUpdate/mainnet"` \| `"zkCoins/v1/StateUpdate/testnet"` \| `"zkCoins/v1/StateUpdate/regtest"`. It remains a **fixed constant per network** — a scanner operating on a given network knows which constant applies and recomputes every challenge from on-chain data alone (using the per-network fixed constant `m_state` for the network the scanner operates on, §3.6). The transition's specifics — `inr`, `ocr`, and the rotated spend authority (via `new_account_state_hash`) — are **not** in the message; they are folded into `ProofData` and bound into the signature's nonce by **sign-to-contract** (`H(ProofData)`, below), which is what keeps the on-chain nullifier at ~64 bytes. **This per-network `m_state` is what closes on-chain cross-network replay** of a raw `(Pk, R, s)` (a testnet signature fails BIP-340 under mainnet's `m_state`); the public-input `network_id` below binds only the proof, not the signature | fixed ASCII string (per network) |
| **network_id** | `network_id = Hc("Network", network_tag_bytes)`, where `network_tag_bytes` is the ASCII encoding of the network tag `zkCoins/v1/mainnet` \| `zkCoins/v1/testnet` \| `zkCoins/v1/regtest` ([§2.2](#22-proof-types)). A **public input** of the compliance circuit `C` **and** of the balance-attestation circuit `C_balance` — **4 Goldilocks field elements** (a Poseidon `HashOut`) — constrained in-circuit against the compile-time network constant of the build. **Placement differs by circuit:** in `C`, `network_id` is the public input **after** `consumed_pubkey` ([§2.1 clause 9](#21-the-compliance-predicate), [§2.5](#25-circuit-dimensioning-normative)); in `C_balance` there is **no** `consumed_pubkey` and `network_id` is simply the **last** public input ([§2.5](#25-circuit-dimensioning-normative), [§5.7](#57-balance-attestation-history-private)). It is **not** part of `serialize(ProofData)` and does **not** enter `H(ProofData)` (exactly like `consumed_pubkey` on `C`). **`network_id` binds only the proof to its network** (proof-level binding); it does **not** bind the BIP-340 signature and does **not** close on-chain cross-network replay of a raw `(Pk, R, s)` — that is closed exclusively by the per-network `m_state` above | 4 field elements (Poseidon HashOut) |
| **On-chain nullifier** | `(Pkᵢ, Rᵢ)` — the transition's account-state nullifier written to Bitcoin ([§3.1](#31-the-on-chain-object)): `Pkᵢ` (x-only) is the state's `current_pubkey`, and `Rᵢ` (x-only) is the sign-to-contract nonce of `txn_sig` that commits `H(ProofData)`. A publisher half-aggregates many transitions' `(Pkᵢ, Rᵢ)` signatures — plus the single shared scalar `s_agg` — into one inscription, the **`AggregateStateNullifierV3`** object ([§3.1](#31-the-on-chain-object), [§3.3](#33-half-aggregation)) whose per-member unit is this pair `(Pkᵢ, Rᵢ)`; the global accumulator (§1.6, §3.7) folds each `Pkᵢ` by **first-occurrence**, **appending** the position-bound leaf `Hc("NfLog/Leaf", p ‖ Pkᵢ ‖ Rᵢ)` to the append-only log (§1.7.6). Rotating and per-transition, so unlinkable to the account | 64 bytes per transition on-chain (before aggregation) |
| **SpendRecord** | `{ public_key: Pkᵢ (32B x-only), signature: BIP-340(skᵢ, m_state) with sign-to-contract binding H(ProofData) (64B) }` — the account's **transition authorization**: one per transition, produced by **every** state-advancing transition alike — a send, a receive, and a mint. Its `(Pkᵢ, Rᵢ)` pair is what a publisher half-aggregates and inscribes on Bitcoin as the on-chain nullifier (above); the wallet's own node MAY self-publish it. Because every state-advancing transition consumes its state's one-time key `Pkᵢ`, **every** SpendRecord — a receive's and a mint's included — publishes its `(Pkᵢ, Rᵢ)` and is arbitrated by first-occurrence exactly like a spend (§2.1 clause 1, §3.10) | 96 bytes |
| **Nullifier** (`nf`, in-circuit) | `nf = Hc("Nullifier", nk ‖ coin.identifier)` — the **per-coin** nullifier, derived in-circuit by the spender and folded into `input_nullifiers_root` and the coin-history SMT (§2.1 clause 4, clause 8). It is the account's **private, in-circuit** bookkeeping and **never** appears on Bitcoin — the on-chain object is the per-transition account-state nullifier `(Pkᵢ, Rᵢ)` above, whose `Rᵢ` commits `H(ProofData)` (hence `inr` over all `nf`). Unlinkable to the coin without `nk` | 256-bit digest (32-byte canonical) |
| **nav / nav_commitment** (conditional NAV) | `nav` is the transition's **conditional nullifier-accumulator value** — the chain-derived accumulator value (§3.7), always `size_final` (the shared ≥6-confirmation-final prefix, §2.3.2 step 5), that contains every nullifier the transition **depends on** (its previous account state's nullifier and each input/received coin's creating-transition nullifier), the dependency-anchoring construct that ties each dependency to its on-chain nullifier (§3.7); reorg handling is bounded by the [§3.9](#39-finality-and-reorg-handling) finality directive. It is exposed only through the **hiding commitment** `nav_commitment = Hc("NavCommit", nav_root ‖ nav_rand)`, the fifth `ProofData` field: carried forward **monotonically** (§2.1 clause 1) and required to be a **canonical** accumulator value on a verifier's own scan (§2.3.3 step 2), so — with the per-hop predecessor-nullifier check (§2.1 clause 1) and clause 10(d) requiring each state-advancing transition's own nullifier to be a canonical member — one check attests the whole lineage's anchoring; a reorg that orphans a dependency makes `nav` non-canonical; within the ≤5-block tolerated window this cannot happen to a final dependency, and a ≥6-block reorg is outside v1's guarantee (§3.9). `nav_rand = HKDF("zkCoins/v1/NavRand", op_secret ‖ u64-be(send_counter))` is derived deterministically (so any prover holding the operational bundle reproduces it, and a fresh node rebuilds any prior opening — [Requirement 10](/requirements)) and **MUST NOT** be derived from `nav`. The opening `{nav, nav_rand}` travels only to a coin's recipient (via the `CoinProof` bundle) or a disclosure verifier | 32-byte digest (rand: 32-byte secret) |
| **ProofData** (public inputs) | `{ new_account_state_hash, output_coins_root, input_nullifiers_root, coin_history_root, nav_commitment, npk_commit }` — the per-account proof's public inputs. Global double-spend is enforced **not** here but by the on-chain nullifier accumulator's first-occurrence rule (§3.6, §3.7). The fifth field, **`nav_commitment`**, is the hiding conditional-NAV commitment defined above. **Canonical serialization** `serialize(ProofData) := new_account_state_hash ‖ output_coins_root ‖ input_nullifiers_root ‖ coin_history_root ‖ nav_commitment ‖ npk_commit` (the six 32-byte digests in that exact order — **192 bytes**), and **`H(ProofData) := SHA-256(serialize(ProofData))`** is the single normative definition the transition's sign-to-contract tweak commits everywhere ([§2.1 clause 2, clause 9](#21-the-compliance-predicate), [§3.2](#32-transition-signing-bip-340--sign-to-contract), [§5.7](#57-balance-attestation-history-private), V.4). **`ProofData` is the v1 realization of the `TransitionEssenceV3`** — the transition essence the signature commits: it binds the new account-state hash (`new_account_state_hash`; the *prior* state is bound through the recursive `prev_proof` check, §2.1 clause 1), the output-coins root (`output_coins_root`), the input-nullifiers root (`input_nullifiers_root`), the coin-history root (`coin_history_root`), and the conditional NAV (`nav_commitment`), and the rotated-key commitment (`npk_commit`, §2.1 clause 2). It realizes the *next-key-hiding commitment* as the sixth field `npk_commit = H("zkCoins/v1/NpkCommit" ‖ next_pubkey ‖ npk_rand)` (SHA-256, §2.1 clause 2), a **hiding** commitment (fresh secret `npk_rand`) to the rotated `current_pubkey = Pkᵢ₊₁`. It is a separate field — rather than being folded only into `new_account_state_hash` — precisely so the **thin wallet can recompute it** (SHA-256, no Poseidon) and confirm the node folded the wallet's own `next_pubkey`, closing the hosted-prover rotation-capture (§2.1 clause 2, [Requirement 5](/requirements)). **Consumed-key output.** Alongside `ProofData` (not within it), `C` exposes **one further public output**, the transition's **consumed key** `Pkᵢ` (= `txn_pubkey`, the `current_pubkey` this transition spends and publishes as its on-chain nullifier key, §3.1), so a verifier can bind each on-chain nullifier to the *specific* key its creating transition consumed ([§2.1 clause 1, clause 9, clause 10(d)](#21-the-compliance-predicate)); it is **not** part of `serialize(ProofData)` and does **not** enter `H(ProofData)`, so the **192-byte** `serialize(ProofData)` (six fields, including `npk_commit`) and every V.4–V.6 vector already account for it. `Pkᵢ` is already public on-chain, so exposing it discloses nothing new (clause 9, [Requirement 2](/requirements)). **Network-id output.** `C` additionally exposes **`network_id = Hc("Network", network_tag_bytes)`** as the **4** public-input field elements **after** `consumed_pubkey` ([§2.5](#25-circuit-dimensioning-normative)); `C_balance` exposes the same `network_id` as its **last** public input (it has no `consumed_pubkey`, [§2.5](#25-circuit-dimensioning-normative)). In both circuits `network_id` is **not** part of `serialize(ProofData)`. `network_id` is **proof-level binding only** — it does **not** enter the BIP-340 message and does **not** close on-chain cross-network replay (that is the per-network `m_state`, above) | hashes/roots + `Pkᵢ` + `network_id` |

The account's BIP-340 transition signature over the per-network fixed `m_state` additionally uses **sign-to-contract**: it embeds the digest of the transition's validity proof (`H(ProofData)`) in the nonce `R`, so the on-chain nullifier `(Pkᵢ, R)` commits **exactly this** transition ([§2.1 clause 2](#21-the-compliance-predicate), [On-chain §3.2](#32-transition-signing-bip-340--sign-to-contract)). This is the only Schnorr object placed **on-chain** and half-aggregated; there is no separate publisher proof or publisher signature over shared state. Off-chain BIP-340 signatures exist elsewhere — `addr_sig`, `name_sig`, `op_sig`, the ownership-proof responses, and ordinary Nostr event signatures.

### 1.5 Core data structures

```
AccountState = {
  owner             : address,                 // fixed identity
  nk_commit         : digest,                  // = Hc("NkCommit", nk); binds the account's nullifier
                                               //   key so forks cannot equivocate nullifiers (§2.1
                                               //   clause 4); fixed at genesis, carried forward
                                               //   unchanged like owner
  balances          : map<asset_id, amount>,   // private bookkeeping, multi-asset (≤ MAX_ACCOUNT_ASSETS
                                               //   distinct non-zero entries, §2.5)
  current_pubkey    : Pkᵢ,                      // rotates each state-advancing transition
  send_counter      : i,                        // monotonic
  coin_history_root : root                      // Poseidon SMT root over the account's coin history (§1.6)
}

Coin         = { identifier, recipient: address, amount, asset_id }
CoinTemplate = { recipient: address, amount, asset_id }

CoinProof    = {                            // the value-bearing off-chain bundle (bearer)
  coin,                                      // plaintext coin
  proof,                                     // recursive validity proof
  inclusion_proof,                           // membership of coin in output_coins_root
  creating_prev_ash,                         // PRIOR account_state_hash of the transition that
                                             // created this coin; needed to recompute coin.identifier
                                             // in-circuit — by the spender (clause 2c) and by the
                                             // receiver (clause 10b) (§1.4, §2.1)
  creating_nullifier = { Pk_create,          // the creating transition's on-chain nullifier (§3.1);
                         R_create,            // Pk_create is bound to creating_proof.consumed_pubkey
                         R_prime_create },    // (§2.1 clause 10(d) / clause 9) and R_create S2C-opens to
                                             // H(creating proof's ProofData) via R_prime_create, so a
                                             // receiver or disclosure verifier confirms the creating
                                             // transition's first-occurrence entry — KEY and leaf — in
                                             // the accumulator (§2.3.3 step 4, §5.6). Present for a MINT too:
                                             // a mint publishes (Pk₀, R), so a receiver of a directly-minted
                                             // coin runs the identical first-occurrence key+leaf check
                                             // (§2.3.1, §2.3.3 step 4, clause 10(d))
  nav_opening = { nav,                        // the creating proof's conditional NAV and its commitment
                  nav_rand },                 // randomness (§1.4); lets the recipient open
                                             // creating_proof.nav_commitment and check prefix(nav, own nav)
                                             // in clause 10c
  asset_terms? = { creator_pubkey, name,     // OPTIONAL plaintext IssuanceTerms of coin.asset_id
                   decimals,                 // (§6.5, §2.3.2). token standard 1 ends after issuance_version; a
                   issuance_version,         // token-standard-2 asset additionally carries cap_total and
                   cap_total?, terms_salt? }, // terms_salt (§6.5). The version-dispatched fields
                                             // determine exactly the non-constant asset_id preimage
                                             // inputs of §1.4 (name enters as name_hash = H(name));
                                             // self-authenticating: the receiver recomputes asset_id
                                             // and rejects the bundle on mismatch (§2.3.3 step 6);
                                             // absent ⇒ coin valid, asset carried as opaque asset_id only
  epk, ciphertext, detect_tag                // encryption envelope (§1.3)
}

Invoice      = { amount, recipient: address, asset_id, memo? }     // shareable, off-chain
```

**`serialize(Coin)` (normative).** Wherever `Coin` is carried in a byte layout that is hashed, content-addressed, or read as a wire value — the `coin` field of `CoinProof` above, and the [§1.3](#13-per-coin-keys-note-encryption--detection) `ciphertext = NIP44Binary(K_tx, "coin", serialize(Coin))` envelope — it is the fixed **112-byte** concatenation of its four fields, each at its [§1.7.3](#173-fixed-widths) width: `identifier` (32 bytes) ‖ `recipient` (32 bytes, the `address`) ‖ `amount` (16 bytes big-endian, u128) ‖ `asset_id` (32 bytes). There is no length prefix or optional field: every `Coin` serializes to exactly these 112 bytes.

**`asset_terms` — the `IssuanceTerms` transport field (normative).** The optional `asset_terms` field is the in-bundle carrier of an asset's plaintext issuance terms to a holder — `asset_id` alone is a hash and reveals none of them ([Foundations §1.4](#14-identifiers-and-hashes)); the same terms are additionally resolvable openly by `asset_id` from any holder that has retained them via the Class-B lookup ([§4.6](#46-data-availability), [§7.5](#75-node-rest-api-normative)). Its payload is version-dependent: `issuance_version == 1` carries `{creator_pubkey, name, decimals, issuance_version}`; `issuance_version == 2` additionally carries `{cap_total, terms_salt}` (the supply cap and its secret blind, [Architecture §6.5](#token-standard-2--auditable-capped-supply)). No other field carries the terms inside a bundle. As part of the `CoinProof` bundle plaintext it travels encrypted inside the ZBE bundle blob under the per-coin `K_tx` ([§4.2.1](#421-bundle-blob-encryption-zbe-normative)); it appears in **no** delivery event and on **no** on-chain byte (its only unencrypted-transport trace is the blob-size side channel of [§4.2.1](#421-bundle-blob-encryption-zbe-normative)). The same terms are additionally resolvable, once a holder has the `asset_id`, through the open Class-B `asset_id → terms` lookup any holder that has retained the terms may serve ([§4.6](#46-data-availability), [§7.5](#75-node-rest-api-normative)) — a deliberate open path, not an on-chain or delivery-event exposure. It is **self-authenticating**: the fields required by its `issuance_version` determine exactly the non-constant inputs of that version's `asset_id` derivation — `name` enters the preimage as `name_hash = H(name)` ([Foundations §1.4](#14-identifiers-and-hashes)) — so the receiver dispatches on `issuance_version`, recomputes `asset_id`, and compares it against `coin.asset_id` ([§2.3.3 step 6](#233-receive)) — no trust anchor, no registry, no reliance on the sender's honesty. An asset `name` is a raw byte string and **MUST NOT** exceed **255 bytes**; this length bound is normative for every carrier of the plaintext `name` (the [§7.1](#71-serialization-conventions-normative) wire layout relies on it), and an `asset_terms` whose `name` exceeds it is malformed and **MUST** be rejected. `name_hash = H(name)` hashes these raw bytes, so the [§2.3.3 step 6](#233-receive) recompute is defined over bytes, not text. UTF-8 validity of `name` is a **display-only** concern, checked by the receiving wallet, never by the wire format or the recompute: a `name` that fails UTF-8 decoding **MUST** be treated as if it were absent for display purposes — the wallet carries the asset opaquely, without showing a name — while the bundle and the coin it carries remain valid. Sender rules: [§2.3.2](#232-send); receiver rules: [§2.3.3 step 6](#233-receive); transport model and non-goals: [Architecture §6.5](#issuanceterms-transport).

### 1.6 Trees: one global structure, one per-account structure

| Structure | Scope | Contents | Built from |
|---|---|---|---|
| **Coin-history SMT** | per account | coins the account has received/spent (for in-circuit non-inclusion) | the account's own coins; root folded into `ash` lineage (Private) |
| **Nullifier accumulator** | global | an **append-only Merkle log** (RFC 6962, [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)) over the first-occurrence sequence; leaf `Hc("NfLog/Leaf", p ‖ Pkᵢ ‖ Rᵢ)` binds the position, supporting inclusion + log-consistency proofs | the `(Pkᵢ, Rᵢ)` nullifiers published on Bitcoin, folded by **first-occurrence** in canonical chain order ([§3.6](#36-chain-scanning), [§3.7](#37-the-nullifier-accumulator)) — a pure function of confirmed Bitcoin data |

There is **exactly one** consensus-bearing global structure — the nullifier accumulator — and Bitcoin is the only ordering surface the protocol relies on. zkCoins defines **no** global, account-keyed commitment tree: an account's latest state is carried by its own constant-size recursive proof ([Proofs §2.2](#22-proof-types)), never by a global per-account on-chain index. This is deliberate. A global structure keyed by a stable account identifier would have to be **either** rebuildable from publicly verifiable data **or** privacy-preserving — never both. The protocol keeps privacy ([Requirement 2](/requirements)) and rebuildability ([Requirement 10](/requirements)) at once by removing that structure entirely and anchoring double-spend protection in the **nullifier accumulator** alone.

The accumulator is a **pure function of the on-chain nullifiers** (given the pinned network parameters, §3.6): every node scans Bitcoin in canonical order, verifies each published nullifier's signature (§3.2), and folds each fresh `Pkᵢ` by first-occurrence ([§3.7](#37-the-nullifier-accumulator)). Because the nullifiers are on Bitcoin — not in any off-chain object — two honest nodes at the same tip compute the **identical** accumulator with **no** trust in any peer and **no** data-availability assumption. The receive path's whole-lineage anchoring and the conditional NAV (§2.1 clause 1, clause 10, [§3.9](#39-finality-and-reorg-handling)) are derived from this same accumulator; no separate on-chain or off-chain anchoring structure exists. The per-account coin-history SMT is Private (its leaves are the account's own coins) and never leaves the account's own proving context; only its root appears, hashed, inside `ash`.

### 1.7 Encoding, serialization, and the reference instantiation

Every value defined in §1.4 is reproducible bit-for-bit when the rules below are followed. They pin one concrete, implementable convention for every otherwise-ambiguous detail (sponge layout, byte→field packing, `serialize`, Merkle and SMT constructions). They are **normative for protocol version v1** — a conforming implementation **MUST** match them bit-for-bit. By explicit project decision this reference instantiation is **final for v1**: v1 ships on the conjectured security of the pinned parameters ([§1.7.9](#179-proof-system-parameters-normative)) with no separate pre-mainnet measurement gate, and any parameter refinement is a **version bump** ([§1.7.8](#178-reference-instantiation-status-final-for-v1)), never an in-place v1 change.

#### 1.7.1 Poseidon instance and digest encoding

The reference Poseidon instance is **Plonky2's `PoseidonGoldilocksConfig`** (state width 12, rate `r = 8`, capacity `c = 4`; 8 full + 22 partial rounds; round constants and MDS as in `plonky2/src/hash/poseidon.rs`). All in-circuit Poseidon operations and every use of `Hc` MUST use exactly this instance. `Hc(tag, x₁, …, xₙ)` is computed as

```
Hc(tag, x₁, …, xₙ) := PoseidonSponge( E(tag) ‖ E(x₁) ‖ … ‖ E(xₙ) )
```

where `E(·)` is the field-encoding of §1.7.2, the concatenated sequence of field elements is absorbed by the Plonky2 rate-8/capacity-4 sponge in its standard `hash_n_to_hash` layout, and the result is the first 4 squeezed rate elements.

A **Poseidon digest** is those 4 field elements, canonically encoded as **32 bytes**: each element is reduced mod `p` and emitted as **8 bytes big-endian**, in order. Each digest element is `< p ≤ 2^64`, so 8 bytes always suffice. SHA-256 outputs are 32 bytes as-is.

A single 64-bit Goldilocks element **MUST NOT** be used as a nullifier, identifier, or root: 64-bit collision resistance is insufficient.

#### 1.7.2 Field-encoding `E(·)` of `Hc` inputs

Each input has a categorical type and is encoded as a fixed sequence of field elements; concatenation of those sequences is what the sponge absorbs.

- **Tag.** The literal byte string `"zkCoins/v1/<context>"` (UTF-8, ASCII-only by construction) is encoded by the byte-string rule below. Distinct tags therefore prefix the absorption with distinct element sequences and provide the required domain separation.
- **Byte-string input** (raw bytes, SHA-256 hash, secp256k1 x-only pubkey, secp256k1 scalar, an asset's `name`, a `serialize(...)` output, NIP-44 ciphertext, etc.): encode as
  - **one length element** holding the byte length `L` as an unsigned integer (`L < 2^56`); then
  - the bytes packed into **7-byte big-endian chunks**, each interpreted as a 56-bit unsigned integer and emitted as one field element; the final chunk is right-padded with zero bytes to 7 bytes.

  Total elements: `1 + ⌈L / 7⌉`. Every chunk is `< 2^56 < p`, so every emitted element is a valid reduced Goldilocks element.
- **Digest input** (any 256-bit value already produced by `Hc`): encode as its **4 field elements**, in order, with **no** length prefix — its width is fixed by type.
- **Small numeric input** (a declared-width unsigned integer of `≤ 56` bits): encode as **one field element** equal to the unsigned value. Because the value is `< 2^56 < p`, the element is canonical with no `mod p` ambiguity.
- **Wide numeric input** (`u64`, `u128`): encode as the value's fixed-width **big-endian byte representation** (8 bytes for `u64`, 16 bytes for `u128`) absorbed via the **byte-string** rule above. This avoids the mod-`p` collision that a 64-bit numeric element would have (`p ≈ 2^64 − 2^32`, so distinct `u64` values can reduce to the same field element).

The same `x` always produces the same `E(x)`, regardless of which call uses it. Combined with the **per-tag fixed input schema** (the §1.7.3 widths together with the input list written at every `Hc` call site), no two distinct `Hc` invocations produce the same element sequence: per-input length prefixes on byte strings, fixed widths on digests and small numerics, and the prefix-tag domain together fix an unambiguous absorption per tag.

**`‖` inside `Hc` call sites (normative).** Wherever this document writes `Hc(tag, x₁ ‖ x₂ ‖ … ‖ xₙ)`, the `‖` separates the **input list** of the §1.7.1 signature: each `‖`-separated argument is **one** input, individually encoded by the rules above and the widths of [§1.7.3](#173-fixed-widths) — the arguments **MUST NOT** be byte-concatenated into a single byte-string input first. `Hc(tag, a ‖ b)` and `Hc(tag, a, b)` denote the same invocation. For example, `Hc("Nullifier", nk ‖ coin.identifier)` absorbs `nk` as a byte-string input (length prefix + 5 chunks) followed by `coin.identifier` as a 4-limb digest input. Byte concatenation applies only outside `Hc` input lists — e.g. in `serialize(…)` layouts, `H(…)` and HKDF preimages (`ss ‖ epk`; the sign-to-contract tweak preimage `bytes(R') ‖ H(ProofData)` of [§3.2](#32-transition-signing-bip-340--sign-to-contract); and the `nav_rand = HKDF("zkCoins/v1/NavRand", op_secret ‖ u64-be(send_counter))` derivation of [§1.4](#14-identifiers-and-hashes), whose 32-byte secret and 8-byte big-endian counter are absorbed as raw bytes) and Bech32m payloads (`ivk ‖ ovk`). The canonical `serialize(ProofData) = new_account_state_hash ‖ output_coins_root ‖ input_nullifiers_root ‖ coin_history_root ‖ nav_commitment ‖ npk_commit` ([§1.4](#14-identifiers-and-hashes)) is likewise a byte concatenation of six 32-byte digests, hashed by `H(ProofData) = SHA-256(serialize(ProofData))` — **not** an `Hc` input list.

#### 1.7.3 Fixed widths

| Field | Width (bits) | Notes |
|---|---|---|
| `amount` | 128 (u128) | Encoded as **16-byte big-endian** byte-string input per §1.7.2 (1 length element + 3 limbs of 7 bytes = 4 absorbed elements); same 16 bytes big-endian in `serialize`. Range-checked in-circuit to `[0, 2^128 − 1]` |
| `decimals` | 8 (u8) | One small-numeric element (value `< 2^8`, trivially `< p`) |
| `issuance_version` | 8 (u8) | One small-numeric element; bound into `asset_id` (§1.4) and `IssuanceTerms.terms_hash` ([Architecture §6.5](#65-issuance--token-standards)). The `u8` space suffices: versions start at `1`, so 255 schema versions are available, and each new version costs an in-circuit dispatch branch of the single circuit `C` ([Architecture §6.5](#adding-new-token-standards)) — the space is practically inexhaustible |
| `coin_index` | 32 (u32) | One small-numeric element |
| `send_counter` | 64 (u64) | Encoded as **8-byte big-endian** byte-string input per §1.7.2 (1 length element + 2 limbs of 7 bytes = 3 absorbed elements); same 8 bytes big-endian in `serialize` |
| `unix_seconds` (`not_before`, `not_after`, `expiry`, [§5.1](#51-capability-gated-pull), [§5.2](#52-view-grant)) | 64 (u64) | Encoded as **8-byte big-endian**, identical treatment to `send_counter` above; this is the width used wherever these fields are concatenated in a raw `H(…)` preimage (e.g. `grant_message`, §5.2), not only inside an `Hc` input list |
| `block_anchor.height` | 32 (u32) | One small-numeric element; 4 bytes big-endian on-chain (§3.5) |
| `name_hash`, `address`, `nk`, `epk`, `Pkᵢ` | 256 | Byte-string input, encoded per §1.7.2 (length prefix + 5 chunks) |
| `Hc` digest (`asset_id`, `coin.identifier`, `nf`, `ash`, `nk_commit`, `ocr`, `inr`, any root) | 256 (4 limbs) | Digest input, encoded per §1.7.2 |

`amount` MUST be range-checked in-circuit to `[0, 2^128 − 1]`; an out-of-range amount invalidates the proof. Range-checking a single `amount` bounds each term but does **not** bound a **sum** of amounts: the per-asset conservation of [§2.1 clause 3](#21-the-compliance-predicate) adds up to `MAX_TX_INPUTS`/`MAX_TX_OUTPUTS` such terms (§2.5), so those sums and their comparison are carried in-circuit as **wide multi-limb integers** wide enough that no partial sum can wrap ([§2.1 clause 3](#21-the-compliance-predicate), [§2.6](#26-in-circuit-non-native-cryptography-normative)) — never as a single Goldilocks field element, which cannot hold even one `u128` (`p ≈ 2^64`, §1.1).

**`coin.identifier` preimage (normative order).** The [§1.4](#14-identifiers-and-hashes) `Hc("Coin", …)` call absorbs its five inputs in this exact order, each encoded per [§1.7.2](#172-field-encoding-e-of-hc-inputs) by its type: `prev_account_state_hash` (digest, 4 limbs) ‖ `recipient` (256-bit `address`, byte-string input) ‖ `asset_id` (digest, 4 limbs) ‖ `amount` (u128, 16-byte big-endian byte-string input) ‖ `coin_index` (u32 small-numeric element). The same order is recomputed at every derivation and check site — output construction ([§2.1 clause 5](#21-the-compliance-predicate)), input recompute (clause 2(c)), and received-coin recompute (clause 10(b)); reordering changes the digest and is invalid ([§1.7.7](#177-bech32m-and-bitcoin-conventions)).

#### 1.7.4 `serialize(AccountState)`

`AccountState` (§1.5) is canonically serialized as a fixed-format byte string before being absorbed into `ash = Hc("AccountState", serialize(AccountState))`:

```
serialize(AccountState) :=
   owner                       (32 bytes — the address)
‖ nk_commit                    (32 bytes — Poseidon digest = Hc("NkCommit", nk), §1.2/§2.1 clause 4)
‖ current_pubkey               (32 bytes — Pkᵢ, x-only)
‖ send_counter                 ( 8 bytes — u64 big-endian)
‖ coin_history_root            (32 bytes — Poseidon digest, §1.6)
‖ balances_count               ( 4 bytes — u32 big-endian, the number of non-zero entries)
‖ for each (asset_id, amount) in balances, sorted ASCENDING by asset_id (byte order):
     asset_id                  (32 bytes)
     amount                    (16 bytes — u128 big-endian)
```

Entries with `amount == 0` MUST be omitted; duplicate `asset_id`s MUST NOT appear; the ascending sort is total over the 32-byte canonical encoding; `balances_count` MUST NOT exceed `MAX_ACCOUNT_ASSETS` ([§2.5](#25-circuit-dimensioning-normative)). This fixes a canonical preimage for `ash`. (`nk_commit`, `balances`, and `coin_history_root` are the §1.5 fields; the byte string is then absorbed by `Hc` as one byte-string input per §1.7.2.)

**In-circuit absorption of `balances` (normative).** The out-of-circuit serialization above is **variable-length**: exactly the `balances_count` active `(asset_id, amount)` entries appear, so the absorbed byte-string input has length `L = 140 + 48·balances_count` and its length element ([§1.7.2](#172-field-encoding-e-of-hc-inputs)) reflects that count. A fixed-shape circuit computing `ash` in-circuit ([§2.1 clause 7](#21-the-compliance-predicate)) carries a fixed array of `MAX_ACCOUNT_ASSETS` balance slots, of which only the `balances_count` active slots (ascending `asset_id`, left-aligned) contribute bytes — the remaining slots are **inactive** and contribute **nothing** to the serialized byte string, to `L`, or to the sponge. The circuit therefore reconstructs the **identical** variable-length byte string of `140 + 48·balances_count` bytes and absorbs it as the identical single byte-string input, so the in-circuit `ash` is bit-for-bit equal to the out-of-circuit `Hc("AccountState", serialize(AccountState))`. `MAX_ACCOUNT_ASSETS` is only the circuit's fixed-shape upper bound on the slot count ([§2.5](#25-circuit-dimensioning-normative)); it never appears in the serialized bytes and never changes `ash`.

#### 1.7.5 Poseidon Merkle tree (used for `ocr` and `inr`)

A Poseidon Merkle root with tag `T ∈ { "CoinsRoot", "NullifiersRoot" }` over a list `L = (v₁, …, vₘ)` of 256-bit digest values is computed as:

1. **Leaf hash.** `Lᵢ = Hc("<T>/Leaf", vᵢ)` for each `i` (each `vᵢ` is a digest input, so its 4 elements are absorbed directly).
2. **Pad.** Extend `L` with the **empty-leaf hash** `L_⊥ = Hc("<T>/Leaf", 0₂₅₆)` (the digest of the all-zero 256-bit value) until the list length is a power of two (at least 1). An empty list (`m = 0`) has root `L_⊥`.
3. **Combine.** For each adjacent pair `(L₂ⱼ₋₁, L₂ⱼ)`, compute `Pⱼ = Hc("<T>/Node", L₂ⱼ₋₁, L₂ⱼ)`. Repeat the pairwise combination on the resulting list until one element remains: that is the **root**.

A membership proof (`inclusion_proof`, [§1.5](#15-core-data-structures)) is the sibling path against this construction. Its **canonical byte layout** (the form serialised inside a `CoinProof`, [§7.1](#71-serialization-conventions-normative)) is:

```
inclusion_proof :=
   leaf_index   ( 4 bytes — u32 big-endian; the 0-based position of the proven leaf vᵢ
                            among the m output-coin identifiers, before padding)
‖ depth        ( 1 byte  — u8; the number of sibling levels = log₂(padded leaf count),
                            0 for a single-leaf tree)
‖ for level = 0 (leaf level) up to depth−1, bottom-to-top:
     sibling   (32 bytes — the Poseidon digest of the sibling node at that level)
```

The verifier re-derives the root by hashing `Lᵢ = Hc("<T>/Leaf", vᵢ)` and folding in each `sibling` from the bottom up, choosing left/right order at level `k` from bit `k` of `leaf_index` (bit `0` = least-significant = leaf level; bit `=0` ⇒ the proven node is the left child, sibling on the right; bit `=1` ⇒ proven node is the right child, sibling on the left), then rejects on any mismatch with the committed root. `depth` follows the same `2^⌈log₂ max(m,1)⌉` canonical shape as the tree itself (each `sibling` is supplied explicitly as 32 bytes, whether it is a real node or a padding subtree — a padding sibling at the leaf level is `L_⊥`, at level `k>0` it is the `Hc("<T>/Node", …)` root of an all-padding subtree), so two implementations produce byte-identical `inclusion_proof`s. The distinct `<T>/Leaf` and `<T>/Node` domain tags prevent second-preimage collisions across levels.

#### 1.7.6 Nullifier accumulator (append-only Merkle log)

The global nullifier accumulator (§1.6, [On-chain §3.7](#37-the-nullifier-accumulator)) is an **append-only Merkle log** — a Certificate-Transparency Merkle tree (**RFC 6962 §2.1** / **RFC 9162 §2.1**, instantiated over the [§1.7.1](#171-poseidon-instance-and-digest-encoding) Poseidon hash `Hc` in place of SHA-256) — over the **canonical first-occurrence sequence** of on-chain account-state nullifiers. Every node derives it from Bitcoin alone ([§3.6](#36-chain-scanning)): scanning in the canonical total order `(height, tx_index, vin_index, payload_member_index)` (block height ▸ reveal-transaction index ▸ reveal-input index ▸ in-payload member index, [§3.6](#36-chain-scanning) step 4), it **appends** each surviving `(Pkₚ, Rₚ)` whose `Pkₚ` is **unseen** as the next entry `eₚ` at position `p` (the first-occurrence **winner**), and **skips** any later occurrence of an already-present `Pkₚ` (a double-spend / fork loser — never appended). Positions are `0`-based; `size` is the number of entries.

- **Leaf hash** (the RFC 6962 `0x00` leaf domain, here the tag `NfLog/Leaf`; **binds the position**): the hash of entry `p = (Pk, R)` is `MTH([eₚ]) = Hc("NfLog/Leaf", p ‖ Pk ‖ R)`, with `p` absorbed as an **8-byte big-endian byte-string** input (a `u64` wide-numeric input per [§1.7.2](#172-field-encoding-e-of-hc-inputs) / [§1.7.3](#173-fixed-widths) — not a single numeric field element, which would collide mod `p`) and `Pk, R` the two 32-byte inputs.
- **Interior node** (the RFC 6962 `0x01` node domain, tag `NfLog/Node`): for a run of `n > 1` leaves `D[0:n]`, let `k` be **the largest power of two strictly less than `n`** (`k = 1 ≪ (bit_length(n − 1) − 1)`); then `MTH(D[0:n]) = Hc("NfLog/Node", MTH(D[0:k]) ‖ MTH(D[k:n]))`. For `n = 1`, `MTH(D[0:1])` is the leaf hash above.
- **Empty log:** `MTH({}) = Hc("NfLog/Empty", 0)`, a protocol constant — the `0` is a **small-numeric** `Hc` input ([§1.7.2](#172-field-encoding-e-of-hc-inputs)), not the all-zero digest `0₂₅₆`; the coin-history empty-leaf `Hc("CoinHist/Leaf", 0)` uses the same small-numeric `0`.
- **Accumulator value.** The accumulator at `size = n` is the pair `(n, mth)`, `mth = MTH(D[0:n])`; its committed 32-byte form is `nav_root = Hc("NfLog/Root", size ‖ mth)`, with `size` absorbed as an **8-byte big-endian byte-string** input (same `u64` wide-numeric rule as `p` above). Binding `size` inside the preimage forecloses length-extension. This is the value opened by `nav_commitment = Hc("NavCommit", nav_root ‖ nav_rand)` ([§1.4](#14-identifiers-and-hashes)).

A node keeps, alongside the log, a **local index** `Pk → (position, R)` — not part of the authenticated tree — that answers first-occurrence / non-membership queries in O(1) for the [§3.6](#36-chain-scanning) scan and the [§3.7](#37-the-nullifier-accumulator) Path-A / Path-B services. The log and index are a **pure function of the on-chain `(Pk, R)` stream** — byte-identical across honest nodes at the same tip — so **no root is ever inscribed**. A reorg is handled by **canonical-view replay** ([§3.9](#39-finality-and-reorg-handling)): **exclude orphaned entries from the canonical view; retained, never deleted** — advance the canonical head (and the active index pointer, or rematerialised view) to the last entry whose inclusion block survives, and re-append winners over the new canonical order. Already-stored log entries from orphaned blocks remain in the store indefinitely (Data Permanence, [§4.8](#48-durability--the-store-everything-invariant)); they are only dropped from the **active canonical** projection, never deleted from storage. The accumulator remains fully reconstructible from Bitcoin alone.

Inclusion proofs and the consistency (`prefix`) relation over this log are defined in [On-chain §3.7](#37-the-nullifier-accumulator); their in-circuit uses are [Proofs §2.1 clause 1 and clause 10](#21-the-compliance-predicate).

**Coin-history SMT (per account).** The per-account coin-history (§1.5, §1.6) is a structurally identical **256-bit-depth sparse Merkle tree** with its own distinct domain tags. It is Private — its leaves are the account's own coins — and is used in-circuit by the compliance predicate ([Proofs §2.1](#21-the-compliance-predicate) clause 2(b) and clause 8); only its 32-byte `coin_history_root` ever leaves the proving context, hashed inside `ash`.

- **Key:** the coin's `coin.identifier` (a 256-bit Poseidon digest, §1.4), used as the bit-string `id₂₅₅ id₂₅₄ … id₀` to walk root → leaf.
**Byte-to-bit rule (normative):** the 32-byte key is read **big-endian** — bit 255 is the most-significant bit of byte 0 and bit 0 the least-significant bit of byte 31; the level-`i` step uses bit `i` (0 = left/low, 1 = right/high), matching the [§1.7.5](#175-poseidon-merkle-tree-used-for-ocr-and-inr) leaf-index convention.
- **Leaf state** `s ∈ {0, 1, 2}`: `0` = the account has never received this coin (key is absent); `1` = received-and-unspent (the coin is in the account's holdings); `2` = spent (the coin was received and has since been nullified by this account). Encoded as one numeric element.
- **Leaf:** `H'_leaf(s) = Hc("CoinHist/Leaf", s)`.
- **Internal node at level `i`** (level 0 = leaf, level 256 = root): `H'_node(i, l, r) = Hc("CoinHist/Node", i, l, r)`, level index as one numeric element and `l, r` as digest inputs.
- **Empty subtree at level `i`** has the precomputed hash `E'ᵢ` defined recursively by `E'₀ = H'_leaf(0)` and `E'ᵢ = H'_node(i, E'_{i-1}, E'_{i-1})`. The 257 values `E'₀, …, E'₂₅₆` are constants of the protocol; `E'₂₅₆` is the **empty coin-history root** (the `coin_history_root` of the canonical empty account, §2.2).

**Operations.** A transition that spends `input_coins[j]` proves in-circuit that `coin.identifier = input_coins[j].identifier` has leaf state `1` against the prior `coin_history_root` (clause 2(b)); the same transition flips that leaf from `1` to `2` (spent) and admits each newly received output template by flipping its key from `0` to `1` (received-unspent). `coin_history_root` after the transition is the recomputed root over these updates and is the value bound into the new `AccountState` (clause 8, §1.7.4). The distinct `CoinHist/Leaf` and `CoinHist/Node` tags — and the per-level domain separation in `H'_node` — make these constants distinct from every other tagged tree. (The global nullifier accumulator is an append-only Merkle log with **no** per-level empty-subtree `E_i` ladder, §1.7.6 — only this per-account coin-history is a 256-bit SMT.)

**`balances` is the state-`1` partition (normative).** `AccountState.balances` ([§1.5](#15-core-data-structures)) is not an independently free field: by the [§2.1 clause 7](#21-the-compliance-predicate) closed relation, `balances(a)` equals, for every `asset_id` `a`, the sum of `amount` over this coin-history SMT's own state-`1` (held, unspent) leaves whose coin carries `asset_id = a` — by induction from the canonical empty account, where both `balances` and the coin-history tree are empty ([§2.2](#22-proof-types)). Every transition debits/credits exactly the same leaves on both sides (spend `1 → 2` debits `In(a)`; admit `0 → 1` credits the matching `output_templates`/`received_coins[]` amount, clause 7, clause 8), so the two structures never diverge (a **token-standard-2** mint's self-addressed output is deferred on **both** sides per §6.5 clause (g) — credited to neither `balances` nor the coin-history until a later clause-10 receive — so the invariant still holds).

#### 1.7.7 Bech32m and Bitcoin conventions

- Addresses, view grants, and bearer view capabilities use Bech32m with distinct HRPs so they are never confused: `zk` (address, 32-byte payload), `zkgrant` (view grant, full `ViewGrant` byte serialization), `zkview` (per-coin view capability, 32-byte payload), `zkavk` (bearer account view key, 64-byte `ivk ‖ ovk` payload, or 32-byte `ivk`-only payload — the incoming-only variant; see [Access & Explorer §5.8](#58-address-view-full-history)), `zkbid` (confirmation-link blob locator, 32-byte `blob_id = H(ciphertext)`; see [Access & Explorer §5.6](#56-shareable-confirmation-links)), `zkatt` (balance-attestation content handle, 32-byte `SHA-256(BalanceAttestationV1)`; see [Access & Explorer §5.7](#57-balance-attestation-history-private)). A node/explorer **MUST** reject a value presented under the wrong HRP.
- **Length.** The 90-character maximum of BIP-173/BIP-350 does **not** apply to these HRPs: a `zkavk` payload (64 bytes) and a `zkgrant` payload (a full `ViewGrant` serialization) exceed it by construction. Encoders and decoders for the HRPs above **MUST NOT** enforce the 90-character limit and **MUST** accept Bech32m strings longer than 90 characters (the same relaxation NIP-19 applies to its bech32 entities). Beyond 90 characters the Bech32m checksum's error-detection guarantee is weaker than the BIP-173 bound; the checksum remains a transcription check, never a security boundary.
- Bitcoin txids are stored internal-order and **displayed** byte-reversed (canonical Bitcoin convention).
- All multi-input hashes fix input order exactly as written in §1.4 and in this section; reordering changes the digest and is invalid.

#### 1.7.8 Reference-instantiation status (final for v1)

This section pins one concrete, implementable convention for everything otherwise underspecified at the cryptographic-engineering level. It is normative for protocol version v1 — a conforming implementation MUST match it bit-for-bit. **By explicit project decision the instantiation is final for v1:** there is no pre-mainnet external review or audit gate, and v1 accepts the conjectured security margins as stated ([§1.7.9](#179-proof-system-parameters-normative)). Any refinement of the Poseidon parameter choice, the byte→field encoding, the sponge variant, the `serialize(AccountState)` field ordering, or the in-circuit/out-of-circuit boundary is a **version bump** (the tag prefix `"zkCoins/v1/…"` reserves the namespace) — never a change to v1.

**v1 freeze (normative).** The v1 protocol surface is **frozen** in two classes with distinct effectiveness points on the [Path to mainnet runbook](/implementation-mandate). **From runbook step 3 (vectors pin):** the circuit shape of `C` and `C_balance` (public-input layout, the [§2.5](#25-circuit-dimensioning-normative) bounds, the [§2.6](#26-in-circuit-non-native-cryptography-normative) relations), the §1.7 encodings and serializations, and every Poseidon-dependent pinned value — the class that **carries digests and lineages**. `IssuanceTerms_v2` ([§6.5](#65-issuance--token-standards), [§2.1 clause 3](#21-the-compliance-predicate)) is part of the **initial** v1 circuit build, not a later addition. Once the reference implementation generates and pins `circuit_digest(C)` and `circuit_digest(C_balance)` ([§1.7.9](#179-proof-system-parameters-normative), [V.4](#v4-poseidon-derived-values)), any change to any element of this class defines a **new protocol version** with new digests and new lineages; v1 artefacts are never edited in place. **From runbook step 7 (public testnet):** additionally the [§7](#7--wire-formats--node-interfaces) wire formats. From that point nodes that are not jointly updated run for the first time; a wire change thereafter produces identical version names under different rules and is therefore a real version conflict — any change to a §7 wire format after step 7 defines a **new protocol version**. **Between step 3 and step 7** an addition to the §7 wire formats that touches **neither** a circuit element **nor** a pinned vector **nor** a digest is **not** a new protocol version; it **MUST** be introduced by a specification PR that states why the addition is required. The open, additive `GET /v1/token/<asset_id>/provenance` read ([§7.5](#75-node-rest-api-normative), [§4.6](#46-data-availability) Class B) is exactly such an addition — read-only, unauthenticated, and changing no existing format. Between those steps no foreign node and no lineage carries value (the project is green field — [Implementation Mandate §0](/implementation-mandate); rollback before runbook step 10 is free — [Path to mainnet](/implementation-mandate)), so a wire freeze protects nothing while forcing a full rebuild of the vector series (the tag prefixes `"zkCoins/v1/…"` enter every Poseidon digest). The digest- and lineage-carrying class is **not** relaxed by this separation: it remains absolute from step 3.

**Residual review target (normative note).** v1 ships without an external audit ([Assurance Roadmap](/assurance)). Of the v1 construction, the one element for which independent cryptographic review is explicitly recommended (but is **not** a v1 release gate — v1 discharges it via the mandatory differential-test below, not a human review; no external-audit step, project decision 2026-07-22) is the **in-circuit arithmetization of the RFC-6962 log-consistency verifier** ([§3.7](#37-the-nullifier-accumulator)): its data-dependent recursion (split points driven by the bits of the two log sizes) is unrolled to `≤ 2·H_MAX` slots with select gates, and a subtly wrong split-point or peak-bagging would let it accept a **non-prefix**, collapsing the transitive-anchoring soundness ([§2.1 clause 1](#21-the-compliance-predicate)). The reference implementation **MUST** differential-test the gadget against an independent RFC-6962 reference at **every** `2ᵏ−1`, `2ᵏ`, `2ᵏ+1` size boundary for **`k = 0…63`** — the **generated log-boundary suite** of [V.11](#v11-nullifier-accumulator-log-vectors). That suite tests the **split-/peak-bagging LOGIC** of the consistency and inclusion gadgets with **given/symbolic subtree-root fixtures** (the O(log n) boundary subtree roots per case — Poseidon-dependent, hence `<REGEN>`), **not** by materialising Θ(n) leaves for large `n`. Small hand-listed sizes (`n ≤ 9`) **MAY** fully materialise; high-`k` cases **MUST NOT** require Θ(n) leaf evaluation. The suite is part of the **v1 freeze differential-test** (this section) and **feeds the D-05 release gate** (in-circuit differential-test of the RFC-6962 log-consistency + inclusion arithmetization — [Paper-Deviation Analysis D-05](/paper-conformance-analysis)). The inclusion **PATH** gadget ([§3.7](#37-the-nullifier-accumulator)) shares the same data-dependent split-point arithmetization (driven by the position bits, `≤ H_MAX` audit-path hashes) and is covered by the **same** differential-test discipline and the V.11 vectors (hand-listed smoke set **and** the symbolic-subtree-root suite for all `k`). The abstract relation is peer-reviewed (RFC 6962 / RFC 9162 log consistency); only its Poseidon-over-Goldilocks in-circuit realisation is v1-new.

#### 1.7.9 Proof-system parameters (normative)

§1.1 names the proof system abstractly (a FRI-based PCD scheme over Goldilocks with Poseidon). This section fixes the **one concrete, conforming parameter set** for protocol version v1. Any two conforming implementations that follow it — including the pinned digests, hence the reference circuit shape ([§2.6](#26-in-circuit-non-native-cryptography-normative)) — produce proofs that verify against each other's verifier data (the project itself deliberately maintains a single protocol implementation — the node; conformance is proven by the node↔SDK primitive parity suite and the executable conformance harness — the [test vectors](#test-vectors-conformance-harness) and the A-to-Z suite of the [Implementation Mandate](/implementation-mandate)). Like the rest of §1.7 it is normative-for-v1 and final for v1 ([§1.7.8](#178-reference-instantiation-status-final-for-v1)).

**Transparent setup — no trusted setup ([Requirement 3](/requirements)).** The proof system is **transparent**: FRI commits with a collision-resistant hash (the §1.7.1 Poseidon instance) and needs **no** trusted setup — no ceremony, no structured reference string (SRS/CRS), and no *"toxic waste"* whose leakage would let a party forge proofs. The *"any setup procedure"* party [Requirement 3](/requirements) enumerates therefore does not exist in zkCoins: there is no setup secret to trust, lose, or subvert, and no per-deployment ceremony to coordinate.

**Library and field.** The reference proving system is **Plonky2** at the crates.io release **`plonky2 = "1.1.0"`** (registry source, the published `1.1.0` artefact). The proof field is **Goldilocks** `𝔽`, `p = 2^64 − 2^32 + 1`; the extension degree used for FRI is **`D = 2`** (the quadratic extension). The hash/config is **`PoseidonGoldilocksConfig`** (the §1.7.1 Poseidon instance). A conforming implementation in another library MUST reproduce the same field, the same Poseidon instance, the same FRI parameters below, and the same recursion shape; it MAY use different code.

**Circuit configuration (normative).** The production circuit `C` (§2) is built with Plonky2's **`CircuitConfig::standard_recursion_zk_config()`** — the standard recursion config **with zero-knowledge enabled**. The zero-knowledge variant is mandatory, not optional: a per-account proof travels to the receiver inside the `CoinProof` bundle (§2.3.3), so the proof object itself is held by a party who must not learn its witness. A non-zero-knowledge FRI proof leaks *bounded* information about the witness through its query openings — and the witness here includes amounts, recipients, and the nullifier key `nk` (§2.1) — so any residual leakage is unacceptable. ZK blinding closes this; it is therefore required by [Requirement 2](/requirements). The resulting `FriConfig` is fixed at:

| Parameter | Value |
|---|---|
| `rate_bits` | `3` |
| `cap_height` | `4` |
| `proof_of_work_bits` | `16` |
| `num_query_rounds` | `28` |
| `reduction_strategy` | `ConstantArityBits(arity_bits = 4, final_poly_bits = 5)` |
| `security_bits` | `100` |
| `num_challenges` | `2` |
| `zero_knowledge` | `true` |

These are the Plonky2 `standard_recursion_zk_config()` values and **MUST NOT** be overridden per circuit. The conjectured security level is **100 bits** (FRI), independent of the Poseidon algebraic-attack margin (≈95 bits at the time of writing; both margins are accepted for v1 as conjectured — [§1.7.8](#178-reference-instantiation-status-final-for-v1), final for v1 — and a revised margin is a version bump).

**Recursion shape (normative).** Recursion is **cyclic**: one fixed circuit verifies proofs of itself (§2.2). Each circuit adds its own verifier data to its public inputs and, in-circuit, checks the cyclic relationship (Plonky2's `conditionally_verify_cyclic_proof_or_dummy` against the circuit's own `VerifierCircuitData`). The fixed-point `CommonCircuitData` for a circuit is the deterministic result of building that circuit; it is **not** serialized into any artefact (§1.7.9 "serialization" below), it is rebuilt identically by every implementation at boot. `C` has constant verifier data, parameterised by the network tag of [§2.2](#22-proof-types).

**Circuit digest (normative, pinned constant).** Each circuit's identity is its **circuit digest** — the `verifier_only.circuit_digest` Poseidon `HashOut` produced when the circuit is built — encoded to 32 bytes per [§1.7.1](#171-poseidon-instance-and-digest-encoding). The digest `circuit_digest(C)`, one per network tag, is a **protocol constant**: every node MUST pin it and MUST reject a proof whose embedded verifier-data digest does not match the pinned value for the network it operates on. Because `circuit_digest(C)` is a function of the circuit's full shape — including its **public-input layout** — it reflects the `consumed_pubkey` public output **and** the `network_id` public input ([§2.1 clause 9](#21-the-compliance-predicate), [§2.5](#25-circuit-dimensioning-normative)); when the v1 circuit is built with that layout, the digest changes accordingly, and a proof from a circuit lacking either verifies against a different digest and is rejected. The concrete byte values are produced by the reference implementation (they are Poseidon-dependent, so they are pinned in the [test vectors](#test-vectors-conformance-harness) only as values generated by that implementation — never hand-authored — exactly like every other §1.7 Poseidon value).

**Canonical proof serialization (normative).** The on-chain nullifier binds a transition's proof **not** by its proof bytes but by `H(ProofData) = SHA-256(serialize(ProofData))` — the digest of the proof's **public inputs** over the deterministic 192-byte `serialize(ProofData)` ([§1.4](#14-identifiers-and-hashes)), committed in the sign-to-contract nonce `R` ([§3.2](#32-transition-signing-bip-340--sign-to-contract)). `serialize(ProofData)` is fixed regardless of proof randomness, so every verifier recomputes the same `H(ProofData)`. The **proof bytes** themselves are never hashed on-chain: they travel to the recipient inside the `CoinProof` bundle, which is content-addressed by its ZBE blob `blob_id = H(ciphertext)` ([§4.2.1](#421-bundle-blob-encryption-zbe-normative), [§7.4](#74-blossom-blob-store-normative)). Where an implementation does serialise a Plonky2 proof (for at-rest storage or bundle transport), the canonical form is its **native `ProofWithPublicInputs::to_bytes()`** encoding (the Plonky2 1.1.0 canonical byte layout: public inputs as 8-byte-LE field elements followed by the proof body); it is **not** a serde/`bincode` encoding. Because production proofs are zero-knowledge (randomised), `to_bytes()` differs run-to-run; this never matters on-chain, where only the deterministic `H(ProofData)` is committed.

#### 1.7.10 Half-aggregation with commitments (NISSHAC, normative)

The on-chain nullifier objects of [§3.1](#31-the-on-chain-object) are half-aggregated by the **Non-Interactive Signature Half-Aggregation with Commitments (NISSHAC)** scheme of *Shielded CSV*, instantiated here over BIP-340/secp256k1. This subsection is the single normative source for the half-aggregate relation and the commitment-opening relation that [§2.6](#26-in-circuit-non-native-cryptography-normative), [§3.2](#32-transition-signing-bip-340--sign-to-contract), and [§3.3](#33-half-aggregation) refer to; like the rest of §1.7 it is normative-for-v1 and final for v1 ([§1.7.8](#178-reference-instantiation-status-final-for-v1)). All arithmetic is over secp256k1 with group order `n` and generator `G`; `H` is SHA-256 (§1.1) and `H_BIP340` is the BIP-340 tagged challenge hash (§1.1).

**Algorithms.**

- **`KeyGen() → (sk, pk)`** — `sk ← [1, n)` uniformly; `pk = sk·G`, encoded x-only (BIP-340, 32 bytes). In zkCoins `sk = skᵢ`, `pk = Pkᵢ = current_pubkey` (§1.2), fresh per transition.
- **`Sign(sk, m, m_SC) → (σ, r_SC)`** — a BIP-340 signature on the **per-network fixed** message `m = m_state`, where `m_state` is the network's constant `"zkCoins/v1/StateUpdate/mainnet"` \| `"zkCoins/v1/StateUpdate/testnet"` \| `"zkCoins/v1/StateUpdate/regtest"` ([§1.4](#14-identifiers-and-hashes)), that additionally commits the message `m_SC = H(ProofData)` by **sign-to-contract** (§3.2): draw `R' = k'·G` (`k'` a fresh BIP-340 nonce; if `y(R')` is odd, set `k' ← n − k'`), set `t = H(bytes(R') ‖ m_SC)`, `R = R' + t·G` (if `int(t) ≥ n`, `R = ∞`, or `y(R)` is odd, redraw `k'` — [§3.2](#32-transition-signing-bip-340--sign-to-contract) steps 1b/3b), `e = H_BIP340(bytes(R) ‖ bytes(pk) ‖ m)`, and `s = (k' + t + e·sk) mod n`; output `σ = (R, s)` and the opening randomness `r_SC = R'`. The pair `(pk, R)` is the transition's on-chain nullifier `(Pkᵢ, Rᵢ)` (§3.1).
- **`Verify(m, pk, σ) → bool`** — the ordinary BIP-340 check `s·G == R + e·pk` with `e = H_BIP340(bytes(R) ‖ bytes(pk) ‖ m)`. It attests the signature but **not** the commitment `m_SC`.
- **`AggregateSig((m, pkⱼ, σⱼ)_{j=1..k}) → σ_agg`** — publisher-side, no secret keys: with `σⱼ = (Rⱼ, sⱼ)`, derive `z = H("zkCoins/v1/HalfAgg" ‖ bytes(R₁) ‖ Pk₁ ‖ … ‖ bytes(R_k) ‖ Pk_k)` and per-index coefficients `aⱼ = H(z ‖ u32-be(j)) mod n`, then `s_agg = Σⱼ aⱼ·sⱼ mod n`. The output `σ_agg = ((R₁,…,R_k), s_agg)` retains every `Rⱼ` (each `(Pkⱼ, Rⱼ)` pair is kept; only the `sⱼ` collapse into `s_agg`). This is exactly the derivation of [§3.3](#33-half-aggregation), and the object it produces is the **`AggregateStateNullifierV3`** ([§3.1](#31-the-on-chain-object)).
- **`AggregateVerify(σ_agg, (m, pkⱼ)_{j=1..k}) → bool`** — recompute each `eⱼ = H_BIP340(bytes(Rⱼ) ‖ bytes(Pkⱼ) ‖ m)` and each `aⱼ` as above, then check the single multi-scalar relation `s_agg·G == Σⱼ aⱼ·(Rⱼ + eⱼ·Pkⱼ)`. Because `m` is the **per-network fixed constant** `m_state` for the network the scanner operates on, a scanner recomputes every `eⱼ` from pure on-chain data alone (§3.6).
- **`CommRetrieve(σ_agg, j) → Rⱼ`** — return the `j`-th retained commitment point `Rⱼ` from the aggregate (the sign-to-contract nonce of transition `j`).
- **`CommVerify(Rⱼ, m_SC, r_SC) → bool`** — the opening a recipient runs: with `r_SC = R'ⱼ`, check `Rⱼ == R'ⱼ + H(bytes(R'ⱼ) ‖ m_SC)·G`. This proves the on-chain commitment `Rⱼ` binds **exactly** `m_SC = H(ProofData)` of transition `j` ([§2.3.3 step 4](#233-receive), [§3.2](#32-transition-signing-bip-340--sign-to-contract)).

**Integer interpretation and reduction (normative).** Throughout this subsection, [§3.2](#32-transition-signing-bip-340--sign-to-contract) and [§3.3](#33-half-aggregation): `bytes(P)` of a curve point is its 32-byte x-only BIP-340 encoding; every 32-byte hash output used as a scalar is interpreted as a **big-endian** unsigned integer. The sign-to-contract tweak `t = H(bytes(R') ‖ m_SC)` is used **unreduced**: if `int(t) ≥ n` (probability ≈ 2⁻¹²⁸), the value is invalid — a signer **MUST** draw a fresh `k'` and recompute, and a verifier (`CommVerify`, the in-circuit clause-2 opening, and the publisher's §7.6 check) **MUST** treat the opening as failed. The half-aggregation coefficients are explicitly reduced: `aⱼ = int(H(z ‖ u32-be(j))) mod n`. The BIP-340 challenge `e` follows BIP-340's own `int(·) mod n` rule unchanged.

**Completeness.** If every `σⱼ` was produced by `Sign` under `pkⱼ` on the shared `m`, then `AggregateVerify(AggregateSig(…), (m, pkⱼ)ⱼ)` holds: substituting `sⱼ = k'ⱼ + tⱼ + eⱼ·skⱼ` and `Rⱼ = R'ⱼ + tⱼ·G = k'ⱼ·G + tⱼ·G` gives `sⱼ·G = Rⱼ + eⱼ·Pkⱼ` for each `j`, hence `s_agg·G = Σⱼ aⱼ·sⱼ·G = Σⱼ aⱼ·(Rⱼ + eⱼ·Pkⱼ)`. The commitment openings are independent of aggregation: `CommVerify(CommRetrieve(σ_agg, j), H(ProofData_j), R'ⱼ)` holds for every honest member `j`.

**Ordinary BIP-340 batch verification is NOT a substitute (normative).** The half-aggregate relation and the commitment-opening relation `CommVerify` are **protocol-critical** and distinct from a plain BIP-340 batch check: a batch check that merely confirms `k` signatures are individually valid does **not** verify that each retained `Rⱼ` opens to its transition's `H(ProofData)` (the binding the receive path depends on, [§2.3.3 step 4](#233-receive)), and does not reproduce the coefficient-bound non-malleability of `s_agg` (§3.3). A conforming verifier **MUST** run `AggregateVerify` (the coefficient-derived multi-scalar relation) for on-chain admission and **MUST** run `CommVerify` when opening a commitment — never a generic batch verifier in their place. **Canonical secp256k1 encodings MUST be enforced** on every point and scalar: x-only public keys and nonces as canonical 32-byte BIP-340 encodings, scalars reduced into `[0, n)`, and any point at infinity, off-curve point, or non-canonical encoding **MUST** cause rejection (`AggregateVerify`/`Verify`/`CommVerify` return false), so no member is admitted through a malformed encoding.

**Sizes (normative note).** The **~64 bytes per transition** figure (§3.5) is **asymptotic**: each aggregated member costs one 32-byte public key `Pkⱼ` plus one 32-byte commitment `Rⱼ`, while the single `s_agg` (32 bytes), the payload framing/header (§3.5), and the Bitcoin fee/tx overhead are **amortised** across the whole aggregate and per-member only vanish as `k` grows — at small `k` the per-transition cost is higher. The reference implementation **MUST** publish **measured** on-chain sizes (payload bytes and witness vBytes per transition) at `k = 1, 10, 100, and the standardness-bounded maximum`, recorded in the reference implementation's build report ([Implementation Mandate §4](/implementation-mandate)).


## 2 · Proofs & State Transitions

> *In one sentence: what the zero-knowledge proof actually proves about each transition (mint, send, receive), and how the sender, the recipient, and the recursive proof plug together.*

This page defines the **proof system** and the **three state transitions** (mint, send, receive) of zkCoins. It builds strictly on [Foundations](#1--foundations-normative): every key, identifier, hash, tree, and structure is used exactly as defined there and never redefined here. Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) follow RFC 2119.

The proof system is a **proof-carrying-data (PCD)** scheme realised by **cyclic recursion** (see [Foundations §1.1](#11-cryptographic-primitives)): one circuit verifies a proof of itself. Each transition consumes the account's previous proof and emits a new one, so a coin that changed hands `N` times carries a **single constant-size proof**, verified in **constant time**, regardless of `N`.

### 2.1 The compliance predicate

Every transition is a single execution of one circuit, `C`. The circuit takes a **private witness** `w` and a set of **public inputs** equal to `ProofData` together with `consumed_pubkey` and `network_id` (see [Foundations §1.4](#14-identifiers-and-hashes), [§2.1 clause 9](#21-the-compliance-predicate), [§2.5](#25-circuit-dimensioning-normative)). A proof `π` is accepted only if `C(ProofData, consumed_pubkey, network_id, w) = 1`, i.e. **all** of the following clauses hold. The clauses are normative: a conforming prover **MUST** enforce every one, and a conforming verifier **MUST** reject any proof for which the public inputs are not bound exactly as below.

Witness (private to the prover; never revealed):

```
w = {
  prev_proof,                 // the account's previous recursive proof (absent for InitialProof)
  prev_account_state,         // AccountState before this transition (Foundations §1.5)
  input_coins[],              // coins being spent (Foundations §1.5); empty for a pure mint
  input_auth[]   = {          // per input coin, membership evidence (NO per-coin key/signature)
    history_path,                                    // inclusion in prior coin-history SMT
    creating_prev_ash,                               // the PRIOR account_state_hash of the transition that
                                                     // created this coin (delivered inside its CoinProof bundle);
                                                     // breaks the would-be coin.identifier ↔ new_ash recursion
    coin_index                                       // the coin's output ordinal in its creating transition
                                                     // (= inclusion_proof.leaf_index of its original CoinProof, §1.5);
                                                     // needed to recompute coin.identifier in clause 2(c)
  },
  txn_sig        = BIP-340(skᵢ, m_state),            // the account's single transition signature over the per-network
                                                     // FIXED message m_state = "zkCoins/v1/StateUpdate/{mainnet|testnet|regtest}",
                                                     // sign-to-contract binding H(ProofData) in its nonce (§1.4, §3.2)
  s2c_nonce      = R' (pre-tweak nonce point),       // the sign-to-contract pre-image R' of txn_sig's nonce R;
                                                     // clause 2 checks R = R' + H(bytes(R') ‖ H(ProofData))·G in-circuit
  txn_pubkey     = Pkᵢ (x-only),                     // current_pubkey, authorises this whole transition
  output_templates[],         // CoinTemplate list (Foundations §1.5)
  received_coins[],           // coins received from other accounts, admitted by this transition (clause 10); empty when none
  received_auth[] = {         // per received coin, provenance evidence (clause 10)
    creating_proof,                                  // the creating transition's recursive proof π (verified in-circuit)
    inclusion_proof,                                 // membership of coin.identifier in creating_proof's output_coins_root
    creating_prev_ash,                               // PRIOR account_state_hash of the creating transition; lets clause 10(b)
                                                     // recompute coin.identifier over the full (recipient, asset_id, amount)
                                                     // tuple (delivered inside the coin's CoinProof bundle, §1.5)
    creating_nullifier = { Pk_create,                // the creating transition's on-chain nullifier and its S2C pre-nonce
                           R_create, R_prime_create }, // (from the coin's CoinProof, §1.5); clause 10(d) binds
                                                     // Pk_create == creating_proof.consumed_pubkey and R_create S2C-opens
                                                     // H(creating ProofData), so the first-occurrence key+leaf check runs
                                                     // for every creating coin — a directly-minted (Pk₀, R) coin included
    creating_nav_inclusion,                          // RFC-6962 audit path of (Pk_create, R_create) at position
                                                     //   pos_create in w.nav — the clause-10(d) inclusion check (§3.7)
    pos_create,                                      // u64 position of the creating nullifier in the accumulator log
    creating_nav_opening,                            // {nav, nav_rand} opening the creating proof's nav_commitment (§1.4 conditional NAV)
    creating_nav_consistency,                        // RFC-6962 consistency SUBPROOF prefix(r_nav ⊑ w.nav) — the creating
                                                     // account's log is a prefix of this receiver's (clause 10c, §3.7);
                                                     // **implementation-internal circuit witness, not a v1 wire object**
    size_r                                           // u64 size of the creating account's committed r_nav
  },
  history_update_paths[],     // one coin-history-SMT sibling path per clause-8 update (spend flips and
                              //   admissions), in clause 8's sequential update order
  nav = (size, mth),          // this transition's CONDITIONAL NAV — the §1.7.6 accumulator-log value (log size + Merkle tree head)
                              // containing all dependencies' nullifiers (§1.4, §3.9); its committed form
                              // nav_root = Hc("NfLog/Root", size ‖ mth) is the value opened behind ProofData.nav_commitment
  nav_rand,                   // deterministic 256-bit commitment randomness (§1.4, keyed by op_secret ‖ send_counter)
  prev_nav_opening,           // {prev nav, prev nav_rand} opening prev_proof.nav_commitment (absent for InitialProof)
  nav_consistency,            // RFC-6962 consistency SUBPROOF prefix(prev.nav ⊑ w.nav) (§3.7; trivial empty-log proof for
                              //   InitialProof) — **implementation-internal circuit witness, not a v1 wire object**
  size_prev,                  // u64 size of prev.nav (0 for an InitialProof)
  prev_state_nullifier = {    // the PREVIOUS transition's on-chain account-state nullifier (absent for InitialProof):
    Pk_prev,                  //   its account-state nullifier public key — bound to prev_proof.consumed_pubkey
                              //   (clause 1 key-binding (iii)) AND to its leaf below, so it is NOT a free witness
    R_prev,                   //   the sign-to-contract nonce in the predecessor's log leaf Hc("NfLog/Leaf", pos_prev ‖ Pk_prev ‖ R_prev) (§3.7)
    R_prime_prev,             //   the pre-tweak nonce opening R_prev to H(prev_proof.ProofData) (§3.2)
    nav_inclusion,            //   RFC-6962 audit path of (Pk_prev, R_prev) at position pos_prev in w.nav (§3.7)
    pos_prev                  //   u64 position of the predecessor nullifier in the accumulator log (clause-1(i) check)
  },                          // clause 1's predecessor-anchoring check: (Pk_prev, R_prev) included in w.nav (canonical) at position pos_prev via RFC-6962 inclusion,
                              //   AND Pk_prev == prev_proof.consumed_pubkey (the predecessor's exposed consumed key)
  nk,                         // nullifier key (Foundations §1.2; held by the wallet and its own node — operational bundle)
  next_pubkey   = Pkᵢ₊₁,      // rotated spend pubkey for the new state (folded into new_account_state by clause 7,
                              // hence into new_account_state_hash and — via sign-to-contract — into txn_sig; §1.2)
  npk_rand,                   // **32 unmodified bytes** from OS-CSPRNG / WebCrypto getRandomValues per proving attempt
                              // (§2.1 clause 2) — **not** HKDF-derived like `nav_rand`, **no** scalar reduction, **never reused**
                              // (hygiene); equality/linkage leak of npk_commit applies only on same-key retries;
                              // fail-closed if CSPRNG unavailable; blinds npk_commit (§2.1 clause 2, §7.5)
  asset_issuance?             // present only for issuance: {asset_id, creator_pubkey = Pk₀, issuance_version, name_hash, amount, decimals, terms_hash,
                              //   cap_total?, terms_salt?} — cap_total and terms_salt are present **iff** issuance_version == 2
                              //   (consumed by the token-standard-2 clauses of §6.5 via clause 3; absent for issuance_version == 1)
}
```

**Predicate `C` — enumerated clauses.**

1. **Recursive verification (PCD) and conditional-NAV carry-forward.** First, the fifth public input binds the witnessed conditional NAV and its randomness: `ProofData.nav_commitment` **MUST** equal `Hc("NavCommit", nav_root ‖ w.nav_rand)`, where `nav_root = Hc("NfLog/Root", size ‖ mth)` is the committed form of the accumulator-log value `w.nav = (size, mth)` ([§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)) ([§1.4](#14-identifiers-and-hashes), [§3.9](#39-finality-and-reorg-handling)). Then either this is an `InitialProof` and `w.prev_proof` is absent and `w.prev_account_state` is the canonical empty account for the account's `owner` ([§2.2](#22-proof-types)), where the InitialProof **MUST** check `owner == H(txn_pubkey ‖ prev_account_state.nk_commit)` (i.e. `owner = H(Pk₀ ‖ nk_commit)`, §1.4) **and** `prev_account_state.nk_commit == Hc("NkCommit", nk)` (clause 4) — so the genesis address commits to **both** the initial spend key `Pk₀` (= `txn_pubkey` at the first transition) and the nullifier key `nk`; two distinct `nk` yield two distinct addresses, so a coin sent to an address has exactly **one** valid nullifier and genesis equivocation is impossible — and `w.nav` satisfies `prefix(nav_empty, w.nav)` via `w.nav_consistency` — the trivial RFC-6962 consistency to the empty log ([§3.7](#37-the-nullifier-accumulator)), `size_prev = 0`; **or** `w.prev_proof` verifies under the circuit's own verifier data (cyclic recursion), its public output `new_account_state_hash` equals the `ash` of `w.prev_account_state`, its `coin_history_root` equals the coin-history root over which clause 2 proves inclusion, its `nav_commitment` equals `Hc("NavCommit", Hc("NfLog/Root", size_prev ‖ mth_prev) ‖ w.prev_nav_opening.nav_rand)`, where `w.prev_nav_opening.nav = (size_prev, mth_prev)` (opening the previous commitment), **and** `w.nav` satisfies `prefix(prev.nav, w.nav)` via `w.nav_consistency` — the **RFC-6962 log-consistency** relation of [§3.7](#37-the-nullifier-accumulator) (`prev.nav`'s Merkle head is exactly the first `size_prev` leaves of `w.nav`, `size_prev ≤ size`, so every leaf is invariant up the chain to the canonical top `w.nav`) — the account's conditional-NAV view is carried forward **monotonically** and can never be replaced or rewound, so it commits to a nullifier-accumulator value that contains every dependency of every transition in the account's own lineage (checked canonical by the [§2.3.3 step 2](#233-receive) receiver scan). Additionally, on **every** `AccountUpdateProof` (this branch), the circuit **MUST** enforce **predecessor-nullifier anchoring**: it witnesses the previous transition's on-chain account-state nullifier `w.prev_state_nullifier = (Pk_prev, R_prev, R'_prev)` and checks **both** (i) **membership** — `(Pk_prev, R_prev)` is a member of `w.nav` by an **RFC-6962 inclusion proof at position `pos_prev < size`** (`w.nav_inclusion`, [§3.7](#37-the-nullifier-accumulator)), the same inclusion gadget clause 10(d) uses, so that because `w.nav` is required **canonical** on the receiver's own chain-derived accumulator ([§2.3.3 step 2](#233-receive)) the predecessor transition is proven **actually anchored on Bitcoin**; and (ii) the **leaf** binding — `R_prev` sign-to-contract-opens `H(w.prev_proof.ProofData)` via `R'_prev` (`R_prev == R'_prev + H(bytes(R'_prev) ‖ H(prev_proof.ProofData))·G`, [§3.2](#32-transition-signing-bip-340--sign-to-contract)), i.e. the accumulator **leaf** at key `Pk_prev` **MUST** be exactly `R_prev`, **not merely** that `Pk_prev` is present; and (iii) the **key** binding — `Pk_prev == w.prev_proof.consumed_pubkey`, the predecessor's own **consumed key** exposed as a public output of `C` (clause 9) and read here in-recursion, so membership is evaluated at the key the predecessor *actually* consumed and published, never an attacker-chosen key. This is the own-lineage counterpart of clause 10(d)'s cross-account edge, and it makes the "account-state nullifier of `prev_account_state`" that `w.nav` is described as carrying (bullet below) an **enforced** requirement rather than a described one. The three checks together close both fork paths: (ii) the **leaf** pins the specific `R_prev` against a **same-key** fork loser (whose stored leaf is the *winner's* `R`, §3.6 step 5), and (iii) the **key** pins `Pk_prev` against a **fresh-key** substitution (a naked nullifier a malicious prover could otherwise mint under a key it controls whose leaf S2C-opens `H(prev_proof.ProofData)`) — so a fork loser can neither reuse the winner's leaf nor escape to a fresh key, and its successor's proof is unsatisfiable. The verifier data **MUST** be fixed and identical in prover and verifier; a proof verified against any other verifier data is invalid.
   - **Conditional NAV — dependencies and reorg safety.** The witnessed `w.nav` is the nullifier-accumulator value (a chain-derived root, [§3.7](#37-the-nullifier-accumulator)) that **contains every nullifier this transition depends on** — the account-state nullifier of `prev_account_state` (the predecessor transition's own `(Pk_prev, R_prev)`, **enforced** in `w.nav` by the predecessor-nullifier check above on every `AccountUpdateProof`; present except for an `InitialProof`, which has no predecessor), the creating-transition nullifier of every `received_coins[j]` (checked directly by clause 10(d)), and — inductively — the creating-transition nullifier of every `input_coins[j]` (each input entered the coin-history by an earlier hop of this same account — a clause-10 receive, whose 10(d) check anchored its creating nullifier, or clause 8 for a self-produced output, whose creating transition is one of the account's own predecessors and is anchored by the clause-1 predecessor chain; the RFC-6962 consistency carry-forward `prefix(prev.nav ⊑ w.nav)` keeps every such nullifier contained ever since). Carrying it forward monotonically (above) means an account's `nav` at any point contains the whole lineage's dependency nullifiers. A verifier accepts the transition's outputs **only if `w.nav` is a canonical accumulator value** on the verifier's own chain-derived history ([§2.3.3 step 2](#233-receive)), and a receiver credits a coin only once its creating nullifier is **final** (6 confirmations — [§3.10](#310-transaction-states), [§3.9](#39-finality-and-reorg-handling)). A reorg of ≤5 blocks touches only non-final nullifiers and resolves by canonical replay; a reorg of ≥6 blocks that displaces a final nullifier is **outside v1's guarantee** and MAY break the account ([§3.9](#39-finality-and-reorg-handling)). There is no in-circuit no-op recovery branch. Because the predecessor's nullifier is one of these dependencies, the same finality applies to it: a successor is **final** only once the predecessor's own nullifier is final, and only a ≥6-block reorg could reverse a final predecessor — the same accepted boundary ([§3.9](#39-finality-and-reorg-handling)).
   - **No global lineage anchor beyond the nullifier accumulator.** An account's latest state is attested **entirely** by its own constant-size recursive proof plus the on-chain nullifier accumulator; the protocol defines no global, account-keyed commitment tree to bind to ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure)). Anchoring to Bitcoin comes via the **on-chain nullifier**: **every** state-advancing transition — send, receive, or mint/issuance, including this genesis `InitialProof` under `Pk₀` — takes effect only once its `(Pkᵢ, Rᵢ)` is published and folded by first-occurrence ([§3.6](#36-chain-scanning), [§3.10](#310-transaction-states)). Equivocation between two forks of one account is caught by that **first-occurrence** rule: both forks advance from the same state and so share the identical `current_pubkey = Pkᵢ` (at genesis, `Pk₀`), publish the **same** nullifier key `Pkᵢ`, and the accumulator admits it **only once** — the later fork is the loser (§3.10 `failed`). At **genesis** this on-chain `Pk₀` first-occurrence is what closes genesis-fork equivocation: the `nk_commit` binding above (and clause 4) forces two genesis forks to the identical `nk`/`nf` but does **not** by itself separate two genesis transitions under one `Pk₀` — only Bitcoin first-occurrence on `Pk₀` does. Because the genesis proof exposes `consumed_pubkey = Pk₀` (bound to the address via `owner = H(Pk₀ ‖ nk_commit)`, clause 9), the **first successor's** predecessor-check binds `Pk_prev == Pk₀` (clause 1 key-binding (iii)), so a genesis fork cannot escape that first-occurrence with a fresh-key nullifier either. For a spend it is reinforced by the shared `nf` (clause 4: the `nk` deriving `nf` is committed by `prev_account_state.nk_commit`, so forks cannot equivocate the coin nullifier either).
   - **How the anchoring invariant tiles (soundness).** With the predecessor-nullifier check above, **every** state-advancing transition in a coin's lineage is anchored, by three complementary edges: (a) the coin's **immediate** creating transition is anchored by clause 10(d) at the receiver — the **cross-account** edge; (b) **every earlier hop** in the creating account's own lineage is anchored by its **successor's** predecessor-nullifier check — the **own-lineage** edge, so a pure receive, a self-held mint, or a genesis-receive that only rotates the key can no longer advance state without a verifier-enforced anchor of its **own** `(Pkᵢ, Rᵢ)`; and (c) **genesis** — which has no predecessor to check — is anchored by the **first** `AccountUpdateProof` successor (whose predecessor-check targets the genesis nullifier under the address-bound `Pk₀`) together with the on-chain `Pk₀` first-occurrence just described. Inducting from a delivered coin backwards: the last transition is anchored via 10(d), each earlier hop via its successor's predecessor-check, and the genesis root via the first successor plus `Pk₀` first-occurrence — so a knowledge extractor walking the recursion recovers a lineage anchored **end-to-end**, each hop's `(Pkᵢ, Rᵢ)` bound to the *specific* key it consumed (via the consumed-key output, next bullet), with no unanchored state-advancing hop. The predecessor-check (own-lineage edge) and clause 10(d) (immediate/cross-account edge) are **complementary, not redundant**: neither covers the other's edge.
   - **How the consumed-key binding closes the fork end-to-end.** Each transition exposes its **consumed key** `Pkᵢ` (= `txn_pubkey`, the `current_pubkey` it spends and publishes as its on-chain nullifier key) as a public output of `C` (clause 9). The predecessor-check binds `Pk_prev == prev_proof.consumed_pubkey` (in-recursion) and clause 10(d) binds `Pk_create == creating_proof.consumed_pubkey` — so **every** on-chain-nullifier membership check is evaluated at the key its transition *actually* consumed, not a witness the prover may choose. This is the faithful port of the *Shielded CSV* per-transition union-membership check `ToSAccVVerifyUnionMembership`, which binds **both** the incoming account state's nullifier **public key** and its transaction commitment into the accumulator (the paper authors' feedback); the single circuit `C` cannot commit its **own** `R` before `H(ProofData)`, so it binds the **predecessor's**/creating transition's already-on-chain `(Pkᵢ, Rᵢ)` — key **and** leaf. A fork is now caught two ways at once: a **same-key** fork (both branches reuse `Pkᵢ`) loses on the **leaf** (ii) — first-occurrence stored only the winner's `R`, so the loser's successor cannot open the stored leaf; a **fresh-key** substitution loses on the **key** (iii) — the successor requires `Pk_prev` to equal the predecessor's *exposed consumed key*, which a naked attacker-minted nullifier under a different key does not match. Neither branch can be both a valid successor and a canonical anchored predecessor, so the cross-account double-spend (pure-receive, self-held-mint, and genesis-receive forks alike) is closed. `Pkᵢ` is already public on-chain as the nullifier key, so exposing it discloses nothing new and does not link an account's consecutive transitions (each `Pkᵢ` is a fresh rotating key; the rotation edge `Pkᵢ → Pkᵢ₊₁` stays hidden inside `new_account_state_hash`) — [Requirement 2](/requirements) is preserved (clause 9). Proving cost: the binding is an in-circuit **equality** on an exposed key, not a new membership gadget ([§2.6](#26-in-circuit-non-native-cryptography-normative)).

2. **Input authenticity (transition signature + sign-to-contract binding).** The whole transition is authorised by the account's **single transition signature** — there is no per-coin key and no per-coin signature ([Foundations §1.2](#12-key-hierarchy)). The circuit **MUST** check that `txn_sig` is a valid **BIP-340** signature (see [Foundations §1.1](#11-cryptographic-primitives)) over the **per-network fixed** protocol-constant message `m_state` — `"zkCoins/v1/StateUpdate/mainnet"` \| `"zkCoins/v1/StateUpdate/testnet"` \| `"zkCoins/v1/StateUpdate/regtest"`, the constant of the network this circuit was built for ([Foundations §1.4](#14-identifiers-and-hashes), [§3.2](#32-transition-signing-bip-340--sign-to-contract)) — by `txn_pubkey = Pkᵢ`, and that `Pkᵢ` is `prev_account_state.current_pubkey`. Signing a per-network fixed message keeps the on-chain nullifier at ~64 bytes (§3.5), lets a scanner verify the signature with no off-chain data using the per-network fixed constant `m_state` for the network the scanner operates on (§3.6), and **closes on-chain cross-network replay** of a raw `(Pk, R, s)` (a signature under one network's `m_state` fails BIP-340 under another's). The circuit **MUST** additionally constrain the public input `network_id = Hc("Network", network_tag_bytes)` against the same compile-time network constant (clause 9, [§2.5](#25-circuit-dimensioning-normative)); **`network_id` is proof-level binding only** — it binds the proof to its network, it does **not** bind the BIP-340 signature and does **not** itself close on-chain cross-network replay (that is exclusively the per-network `m_state`). The circuit **MUST** additionally check the **sign-to-contract opening**: let `R` be the nonce point of `txn_sig`; then `R == w.s2c_nonce + H(bytes(w.s2c_nonce) ‖ H(ProofData))·G`, i.e. `R = R' + t·G` with `t = H(bytes(R') ‖ H(ProofData))` ([§3.2](#32-transition-signing-bip-340--sign-to-contract)), where `H(ProofData)` is this proof's own public-input digest ([Foundations §1.4](#14-identifiers-and-hashes)). This binds the fixed-message signature to **exactly this** `ProofData` — a signature is unforgeable without `skᵢ` and non-replayable across transitions (each commits a distinct `H(ProofData)`). Because `ProofData.new_account_state_hash` (= `ash` of the new state) is folded into `H(ProofData)`, and `new_account_state.current_pubkey = w.next_pubkey = Pkᵢ₊₁` by clause 7, the custody signature **authorises the key rotation** `Pkᵢ → Pkᵢ₊₁` on **every** transition — send, **receive**, and mint alike, each of which runs this same in-circuit check and publishes its own on-chain nullifier ([§2.3.3](#233-receive), [§3.10](#310-transaction-states)). The circuit **MUST** also bind the rotation into a **wallet-recomputable** sixth `ProofData` field: `ProofData.npk_commit == H("zkCoins/v1/NpkCommit" ‖ w.next_pubkey ‖ w.npk_rand)` (SHA-256, [§1.4](#14-identifiers-and-hashes)), where `w.next_pubkey` is the rotated key folded into `new_account_state_hash` by clause 7 and `w.npk_rand` is **exactly 32 unmodified bytes** drawn from an OS-CSPRNG (or, in a browser wallet, Web Crypto `crypto.getRandomValues` over a 32-byte buffer) **per proving attempt**. Those 32 bytes enter the `npk_commit` preimage **as-is** — **no** secp256k1 scalar reduction, **no** modular clamping, **no** hashing-down. `npk_rand` **MUST NOT** be derived deterministically (in particular **not** via HKDF from `op_secret`/`send_counter` like `nav_rand`, and **not** from any weak or non-crypto PRNG). `npk_rand` **MUST** be drawn fresh **per proving attempt** and **MUST NOT** be reused (hygiene). The concrete equality / linkage consequence is narrower: reusing the same `npk_rand` across two attempts that also share the same `next_pubkey` (**same-key retry**) yields **equal** `npk_commit` values and can link those two `ProofData` openings; reusing `npk_rand` with a **different** `next_pubkey` does **not** make `npk_commit` equal (different preimage) and does not create that equality-linkage. The hygiene rule ("never reuse") is kept regardless; the equality-/linkage-leak claim is restricted to same-key retries. If the platform CSPRNG / `getRandomValues` is unavailable or fails, the wallet **MUST** refuse to produce `npk_rand` and **MUST** refuse to sign (fail-closed) — there is no fallback entropy source. Because `H(ProofData)` (which the sign-to-contract nonce commits) now covers `npk_commit`, and because the wallet **computes `npk_commit` itself** from **its own** chosen `next_pubkey` and `npk_rand` and refuses to sign unless the surfaced value matches ([§7.5](#75-node-rest-api-normative) fail-closed), a node holding the operational bundle `{ivk, ovk, op, nk, op_secret}` but **not** the spend key **cannot** rotate `current_pubkey` to a key it controls: folding a different `next_pubkey'` yields an `npk_commit'` the wallet's own recomputation rejects, and forging the custody signature over any `ProofData` requires `skᵢ`. The rotated key `Pkᵢ₊₁` never appears on-chain — it lives only inside the off-chain, hashed `new_account_state_hash` — so the rotation edge `Pkᵢ → Pkᵢ₊₁` stays hidden from every chain observer (the privacy substance of the earlier `next_pubkey_commit` hiding commitment, now carried structurally by `ash` being an off-chain hash rather than by a separate published commitment). Then, for every `input_coins[j]`:
   a. `input_coins[j].recipient` equals `prev_account_state.owner`, i.e. the coin is owned by the spending account (`owner = address = H(Pk₀ ‖ nk_commit)`, [Foundations §1.4](#14-identifiers-and-hashes)) — ownership is by the account, so a receiver never needs a per-coin key index;
   b. `input_coins[j]` is included in the prior **coin-history SMT** (per-account, [Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure)) via `input_auth[j].history_path` against the root referenced in clause 1, and the circuit **MUST** check the authenticated leaf is exactly `H'_leaf(1)` (received-and-unspent, [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)) — membership of the key with any other leaf state does not satisfy this clause;
   c. `input_coins[j].identifier` is recomputed in-circuit as `Hc("Coin", input_auth[j].creating_prev_ash ‖ input_coins[j].recipient ‖ input_coins[j].asset_id ‖ input_coins[j].amount ‖ input_auth[j].coin_index)` — using the witnessed `creating_prev_ash` (the **prior** `account_state_hash` of the transition that produced this coin, i.e. the `ash` of the creating account *before* its creating transition, delivered to the spender inside the coin's `CoinProof` bundle) — and **MUST** match the supplied identifier. The per-input witness `input_auth[]` **MUST** therefore include each input coin's `creating_prev_ash` and its `coin_index` (the coin's output ordinal in the creating transition, i.e. the `inclusion_proof.leaf_index` of its original `CoinProof`, [§1.5](#15-core-data-structures) — symmetric to clause 10(b)). Because the identifier commits `amount` and `recipient`, this recompute **binds the very `amount` fed to clause 3's conservation sum** to the value the creating account assigned — and `recipient` to `prev_account_state.owner`, cross-checked in clause 2(a) — so a spender cannot overstate the value of a coin it already holds. This matches [Foundations §1.4](#14-identifiers-and-hashes): a coin's identifier binds the creating account's **prior** state, breaking the would-be recursion between `coin.identifier` and `new_account_state_hash`.

3. **Per-asset balance conservation.** Let `In(a) = Σ { input_coins[j].amount : input_coins[j].asset_id = a }` and `Out(a) = Σ { output_templates[k].amount : output_templates[k].asset_id = a }`, plus `Mint(a)` from any `asset_issuance` for asset `a` (zero otherwise). For **every** `asset_id` `a` appearing in inputs or outputs: `In(a) + Mint(a) ≥ Out(a)`. Each `amount` is range-checked to `[0, 2^128 − 1]` (§1.7.3); an amount outside range invalidates the proof. Because each per-asset sum ranges over at most `MAX_TX_INPUTS` inputs or `MAX_TX_OUTPUTS` outputs plus an optional `Mint` (§2.5), `In(a)`, `Out(a)`, and `Mint(a)` are accumulated in-circuit as **exact non-negative integers** in a fixed width of at least `128 + ⌈log₂ max(MAX_TX_INPUTS + 1, MAX_TX_OUTPUTS)⌉` bits (132 bits at the v1 bounds) — wide enough that no term or partial sum can overflow — and `In(a) + Mint(a) ≥ Out(a)` is an **exact wide-integer comparison**, never a modular one over the Goldilocks field (`p ≈ 2^64`, §1.1). Range-checking each `amount` alone bounds each term but **not** their sum: a field- or `u128`-wrapping sum would let outputs whose integer total exceeds the inputs pass conservation whenever their wrapped total does not, minting spendable value from nothing. This wide-integer accumulation and comparison are non-native to Goldilocks and are realised by the multi-limb balance gadgets of [§2.6](#26-in-circuit-non-native-cryptography-normative). Only **no-inflation** is enforced by this clause: `In(a) + Mint(a) ≥ Out(a)` guarantees value is never created except by an explicit, predicate-checked `Mint(a)`. The difference `In(a) + Mint(a) − Out(a)` **SHOULD** be returned to the account as a change coin (whose `amount` is itself range-checked to `[0, 2^128 − 1]` like every amount, §1.7.3), but this return is part of the `output_templates[]` witness the (in v1 trusted) node builds, not a separate in-circuit check — a dishonest self-selected prover can redirect the difference to a recipient of its choosing, or drop it entirely (burn), an accepted v1 boundary registered as **D-17** ([§6.7](#67-security-properties-summary); [Paper-Deviation Analysis](/paper-conformance-analysis)). When `asset_issuance` is present, `asset_issuance.issuance_version` **MUST** equal `1` or `2`; any other value **MUST** make the proof fail (the circuit accepts no undefined issuance version, so `Mint(a)` can never flow into conservation under an unconstrained version). The mint clauses of [Architecture §6.5](#65-issuance--token-standards) for that `issuance_version` **MUST** all hold — they are the normative content of the mint circuit and hook §6.5 into the predicate enumerated here. For `issuance_version == 1`:

   - (a) `asset_issuance.issuance_version == 1` (this branch accepts only token-standard-1 mints);
   - (b) `H(asset_issuance.creator_pubkey ‖ prev_account_state.nk_commit) == prev_account_state.owner` (binds the issuance to the asset's creator account, using the account's own committed `nk_commit`, since `owner = H(Pk₀ ‖ nk_commit)`, §1.4; the witness carries `creator_pubkey = Pk₀` because the SPEND key rotates per transition and `Pk₀` is otherwise irrecoverable in-circuit from the address);
   - (c) `asset_issuance.asset_id == Hc("AssetId", genesis_tag ‖ asset_issuance.creator_pubkey ‖ asset_issuance.name_hash ‖ asset_issuance.decimals ‖ asset_issuance.issuance_version)` (the token-standard-1 `IssuanceTerms.asset_id` derivation of [Foundations §1.4](#14-identifiers-and-hashes));
   - (d) `terms_hash == Hc("IssuanceTerms", asset_issuance.asset_id ‖ asset_issuance.issuance_version)` (the token-standard-1 `IssuanceTerms.terms_hash` recomputation).

   When `asset_issuance.issuance_version == 2` the **token-standard-2** mint clauses (a)–(g) of [Architecture §6.5](#token-standard-2--auditable-capped-supply) **MUST** hold **instead**: the same creator binding as (b); the `AssetIdV2` and `IssuanceTermsV2` derivations (which additionally bind `cap_total`/`terms_salt`); the cap check `asset_issuance.amount ≤ asset_issuance.cap_total` as an exact wide-integer comparison over `[0, 2^128 − 1]` (§2.6); the **genesis binding** `prev_account_state.send_counter == 0` **and** `prev_account_state.current_pubkey == asset_issuance.creator_pubkey` (`= Pk₀`), which forces the mint to consume `Pk₀` so that `Pk₀` first-occurrence (§3.6) admits the asset's single mint at most once **globally** across every account sharing `Pk₀`; and explicit-output emission with no self-credit in the creating transition. Together these make a token-standard-2 asset's total supply provably `≤ cap_total` (§6.5).

   Together with `Mint(asset_issuance.asset_id) = asset_issuance.amount` flowing into the `In(a) + Mint(a) ≥ Out(a)` check above, these complete the issuance discipline for the asset's version.

4. **Nullifier derivation.** The circuit **MUST** first bind the witnessed `nk` to the account: `Hc("NkCommit", nk)` **MUST** equal `prev_account_state.nk_commit` ([§1.5](#15-core-data-structures), [§1.2](#12-key-hierarchy)); a witness whose `nk` does not open the committed `nk_commit` invalidates the proof. Only then, for every `input_coins[j]`, compute `nf_j = Hc("Nullifier", nk ‖ input_coins[j].identifier)` ([Foundations §1.4](#14-identifiers-and-hashes)) in-circuit from that bound `nk`. This binding closes fork double-spend at the coin level: because `nk_commit` is carried forward unchanged from genesis (clause 1, clause 7), two forks of the same `prev_account_state` share the identical `nk_commit`, are forced to the identical `nk`, and therefore derive the **identical** `nf` for any shared input coin. All `nf_j` within one transition **MUST** be pairwise distinct, and they form the leaves whose root is `ProofData.input_nullifiers_root` (`inr`). The `nf_j` are **in-circuit only** — they are the account's private per-coin bookkeeping, folded into `inr` and used to advance the coin-history SMT (clause 8); **no `nf` ever appears on Bitcoin**. What reaches the chain is the transition's **account-state nullifier** `(Pkᵢ, Rᵢ)` (§3.1): `Rᵢ` sign-to-contract-commits `H(ProofData)`, which includes `inr` (clause 9), so the on-chain nullifier binds the exact set of coins this transition spent without revealing them. **Global double-spend protection** is enforced by the on-chain nullifier accumulator's first-occurrence rule ([§3.6](#36-chain-scanning), [§3.7](#37-the-nullifier-accumulator)): the account state's `Pkᵢ` can be folded only once, so two forks of one account — forced to the same `Pkᵢ` (fixed `current_pubkey`) and the same `nf` (fixed `nk`) — collide on a single accumulator key, and the later occurrence is the rejected double-spend (§3.10 `failed`). The per-account proof makes **no** in-circuit claim of global non-membership; a receiver confirms the creating transition's `Pkᵢ` is the first occurrence in the accumulator it rebuilt from Bitcoin ([§2.3.3 step 4](#233-receive)) via its own Path-A accumulator ([§3.7](#37-the-nullifier-accumulator); Path-B answers are display-only and never back a credit, [§2.3.3 step 4](#233-receive)). Within the account, clause 2(b) together with the coin-history update (clause 8) prevent the account from spending the same coin twice along its own lineage.

5. **Output coin construction.** For each `output_templates[k]`, the new `coin.identifier` is computed as `Hc("Coin", prev_account_state_hash ‖ output_templates[k].recipient ‖ output_templates[k].asset_id ‖ output_templates[k].amount ‖ coin_index_k)` ([Foundations §1.4](#14-identifiers-and-hashes)), with `coin_index_k` assigned monotonically within the transition — so each output coin's `recipient` and `amount` are committed into `output_coins_root` (clause 6) and cannot be restated by a later holder. **Canonical output order (normative):** `coin_index` is assigned `0, 1, 2, …` over the outputs in this exact order — (i) the recipient coins in the caller's `output_templates[]` order, then (ii) the per-asset change coins in **ascending `asset_id`** order ([§2.3.2](#232-send) step 4), then (iii) the publisher-fee coin last, if present — which in v1 it never is, publishing being sponsored ([§3.8](#38-fees-and-economics)); the slot is defined here so the deferred mechanism of [§3.8.1](#381-fee-coin-mechanism-deferred) needs no re-ordering. This fixes a single `ocr` for a given logical transaction so test vectors are reproducible and a wallet's own `ocr` is deterministic. Using the **prior** state's `ash` here keeps the identifier non-circular with respect to `new_account_state_hash` (which itself folds in the post-transition `coin_history_root` covering these very output coins). The resulting `Coin` objects (`{identifier, recipient, amount, asset_id}`) are the transition's outputs.

6. **Output coins root.** `ProofData.output_coins_root` (`ocr`) **MUST** equal the Poseidon Merkle root over the output `coin.identifier`s under tag `CoinsRoot` ([Foundations §1.4](#14-identifiers-and-hashes), §1.6).

7. **New account state.** `new_account_state` is `prev_account_state` with: `balances` updated by the **exact per-asset equation**, evaluated with the §2.6 wide-integer gadgets: for every `asset_id` `a`, `new_balances(a) = prev_balances(a) − In(a) + Self(a) + Recv(a)`, where `In(a)` is clause 3's spent-input sum, `Self(a) = Σ { output_templates[k].amount : output_templates[k].recipient = prev_account_state.owner ∧ output_templates[k].asset_id = a }` (the change coin(s) and any self-retained issuance output — **except** a token-standard-2 mint's self-addressed output, which §6.5 clause (g) defers to a later clause-10 receive), and `Recv(a) = Σ { received_coins[j].amount : received_coins[j].asset_id = a }` (clause 10). Every term and every resulting map entry is an exact non-negative integer in `[0, 2^128 − 1]`; the subtraction cannot underflow for a valid witness (clause 2(b) admits only state-`1` inputs, which the §1.7.6 invariant counts in `prev_balances(a)`), and a witness for which it would underflow is **invalid**. An entry reaching `0` is removed (the inactive-slot discipline of §1.7.4), `current_pubkey = next_pubkey = Pkᵢ₊₁` (the same `w.next_pubkey` whose folding into `new_account_state_hash` clause 2 binds to the custody signature via sign-to-contract), `send_counter` incremented by one, and `coin_history_root` set to the value produced by clause 8 (the recomputed per-account coin-history SMT root, [Foundations §1.7.6](#176-nullifier-accumulator-append-only-merkle-log)). The updated `balances` **MUST** hold at most `MAX_ACCOUNT_ASSETS` distinct non-zero entries ([§2.5](#25-circuit-dimensioning-normative)); the circuit builds `serialize(new_account_state)` over its fixed `MAX_ACCOUNT_ASSETS` balance slots with the inactive-slot discipline of [§1.7.4](#174-serializeaccountstate), so the in-circuit `ash` equals the out-of-circuit variable-length `Hc("AccountState", serialize(new_account_state))` bit-for-bit. `ProofData.new_account_state_hash` **MUST** equal `ash = Hc("AccountState", serialize(new_account_state))` ([Foundations §1.4, §1.7.4](#14-identifiers-and-hashes)). `new_account_state.owner` **and** `new_account_state.nk_commit` **MUST** be unchanged.

8. **Coin-history update.** The per-account coin-history SMT is updated to mark spent inputs (`1 → 2`), admit every output coin this transition returns to the account itself — `output_templates[k].recipient = prev_account_state.owner`, i.e. `Self(a)` of clause 7's `balances` update (the change coin(s) and any self-retained `asset_issuance` output alike — except a **token-standard-2** mint's self-addressed output, which §6.5 clause (g) credits only through clause 10 in a later transition, not here) — (`0 → 1`), and admit every `received_coins[]` entry accepted by clause 10 (`0 → 1`). Each update is a **constrained two-root transition**, proven in-circuit over a witnessed sibling path (`w.history_update_paths[]`, one per update, applied **sequentially** — spends in `input_coins[]` order, then self-output admissions in clause 5's canonical output order, then `received_coins[]` admissions in their clause-10 order — each against the intermediate root left by the previous update, starting from the clause-1 prior root): for a **spend**, the old leaf at key `coin.identifier` **MUST** be `H'_leaf(1)` and the new root is recomputed with `H'_leaf(2)` over the same siblings; for an **admission**, the old leaf **MUST** be `H'_leaf(0)` (the key absent) and the new root is recomputed with `H'_leaf(1)` over the same siblings — so re-admitting a coin already in state `1` or `2` is **unsatisfiable** (the [§2.3.3 step 5](#233-receive) replay guard, enforced in-circuit). `ProofData.coin_history_root` **MUST** equal the final root.

9. **Public-input binding.** All six `ProofData` fields — `new_account_state_hash`, `output_coins_root`, `input_nullifiers_root`, `coin_history_root`, `nav_commitment`, `npk_commit` — **MUST** be the in-circuit-computed values above and are the proof's public inputs (`npk_commit` per clause 2); **and** the circuit **MUST** additionally expose the transition's **consumed key** `consumed_pubkey = Pkᵢ` (the `txn_pubkey` of clause 2, checked `== prev_account_state.current_pubkey`), so a successor (clause 1 key-binding (iii)) and a receiver (clause 10(d)) bind each on-chain nullifier's key to the *specific* key its transition consumed; **and** the circuit **MUST** expose **`network_id = Hc("Network", network_tag_bytes)`** as the next public input after `consumed_pubkey` ([§1.4](#14-identifiers-and-hashes), [§2.5](#25-circuit-dimensioning-normative)) and constrain it equal to the compile-time network constant of this build. `network_id` is **not** part of `serialize(ProofData)` (exactly like `consumed_pubkey`); it binds **only the proof** to its network and does **not** bind the BIP-340 signature — on-chain cross-network replay is closed by the per-network `m_state` of clause 2, not by `network_id`. `Pkᵢ` is **already** the public on-chain nullifier key (§3.1), so exposing it leaks nothing not already on Bitcoin; and it does **not** link an account's consecutive transitions — each `Pkᵢ` is a **fresh rotating** key and the rotation edge `Pkᵢ → Pkᵢ₊₁` stays hidden inside `new_account_state_hash` (clause 2/7), so a **chain observer** sees only unlinkable one-time keys; a counterparty holding this transition's `CoinProof` additionally sees `creating_prev_ash` and the public `new_account_state_hash`, whose cross-transition linkage potential is the bounded, accepted boundary D-19 ([§6.7](#67-security-properties-summary)) ([Requirement 2](/requirements) preserved). Nothing **else** is public: amounts, asset ids, recipients, the other keys (`nk`; the rotated `next_pubkey` hidden inside `new_account_state_hash`, clause 2/7), counts, and the underlying conditional NAV `nav` (hidden inside `nav_commitment`, clause 1) remain in the witness (zero-knowledge).

10. **Received-coin admission (receive path).** For every `received_coins[j]` (empty for a transition that receives nothing), the circuit **MUST** check, using `received_auth[j]`:
    a. **Provenance proof.** `creating_proof` verifies under the circuit's **own** verifier data (cyclic recursion, exactly as clause 1's `prev_proof` check) — this transitively attests the creating account's entire lineage;
    b. **Coin binding (value- and owner-committing).** The coin's identifier is **recomputed in-circuit** as `Hc("Coin", received_auth[j].creating_prev_ash ‖ received_coins[j].recipient ‖ received_coins[j].asset_id ‖ received_coins[j].amount ‖ coin_index)` — where `coin_index` is the `inclusion_proof.leaf_index` ([§1.7.5](#175-poseidon-merkle-tree-used-for-ocr-and-inr): the leaf's 0-based position in `output_coins_root`, which clause 5's canonical order fixes equal to the creating `coin_index_k`) — and **MUST** equal `received_coins[j].identifier`; that identifier is then proven a member of `creating_proof.ProofData.output_coins_root` via `inclusion_proof`; and `received_coins[j].recipient == prev_account_state.owner`. Because the recomputed identifier commits `amount` and `recipient`, membership can hold **only** for the exact `(recipient, asset_id, amount)` the creating account assigned — so the `amount` clause 7 credits and the `recipient` this account claims are both bound to the creating transition: a receiver can neither inflate the credited value nor redirect a coin addressed to someone else. The per-received witness `received_auth[]` **MUST** therefore include each received coin's `creating_prev_ash` (delivered in the coin's `CoinProof` bundle, [§1.5](#15-core-data-structures));
    c. **Cross-account conditional-NAV binding (transitivity — always).** The witnessed `creating_nav_opening = {r_nav, r_rand}` opens the creating proof's commitment: `creating_proof.ProofData.nav_commitment == Hc("NavCommit", Hc("NfLog/Root", size_r ‖ mth_r) ‖ r_rand)`, where `r_nav = (size_r, mth_r)`; **and** `prefix(r_nav, w.nav)` holds via `creating_nav_consistency` (the **RFC-6962 log-consistency** relation of [§3.7](#37-the-nullifier-accumulator), so the creating account's log is exactly a prefix of the receiver's canonical `w.nav`, `size_r ≤ size` — the sender selects `size = size_final` per [§2.3.2 step 5](#232-send)) — the creating account's conditional-NAV view **MUST** be contained in this receiver's own. This is the binding that makes anchoring **transitive**: the receiver's own `w.nav` is checked canonical against a real scan just once ([§2.3.3 step 2](#233-receive)), and because the creating account's `r_nav` must be a prefix of it, every dependency in the creating account's entire lineage is transitively contained in `w.nav`. Without this clause a colluding intermediary could hide an unanchored ancestor by exposing its own clean NAV; with it, any lineage whose dependency nullifier is not on Bitcoin makes `w.nav` non-canonical, and the first honest downstream verifier rejects it.
    d. **Admission binding — the creating transition's on-chain nullifier (every state-advancing transition).** The transition that created this coin advanced an account state and therefore published an on-chain account-state nullifier — **whether it was a spend or a mint/issuance** ([§2.3.1](#231-mint--issuance), [§3.10](#310-transaction-states)): there is no non-anchored creating transition. That nullifier is a **dependency of this receive** and **MUST** be contained in `w.nav`: the circuit binds, via `received_auth[j]`, that the creating transition's on-chain nullifier `(Pk_create, R_create)` — where `R_create` sign-to-contract-opens to `H(creating_proof.ProofData)` (§3.2), so it commits **exactly this** creating transition against any competing transition on the same account state, **and** `Pk_create == creating_proof.consumed_pubkey`, the creating proof's exposed consumed key (clause 9), so the anchored **key** is the one that transition *actually* consumed rather than a fresh key a malicious sender minted a naked nullifier under — is a member of `w.nav` by an **RFC-6962 inclusion proof at position `pos_create < size`** (`creating_nav_inclusion`, [§3.7](#37-the-nullifier-accumulator)). Because `w.nav` is checked **canonical** against the receiver's own chain-derived accumulator ([§2.3.3 step 2 & step 4](#233-receive)), and the accumulator folds `Pk_create` **only** on first occurrence ([§3.6](#36-chain-scanning)), this proves the creating transition was actually anchored on Bitcoin — and was the *first* (valid) transition on that state, not a fork loser: the `R_create` **leaf** pins a **same-key** competitor (its stored leaf is the winner's `R`) and the `consumed_pubkey` **key** binding pins against a **fresh-key** substitution, the same two-way closure as clause 1's predecessor-check. In the paper model **every** state-advancing transition publishes its nullifier, so there is no off-chain-only "self-spend hop" and no non-anchored mint: an unanchored creating transition has no on-chain `Pk_create == creating_proof.consumed_pubkey` to be a member of any canonical `w.nav`, closing the cross-account double-spend — and the mint-fork — that a hidden or fresh-key transition would otherwise allow. (Clause (c) carries the creating account's whole-lineage *dependency* view via `prefix(r_nav, w.nav)`; (d) anchors the creating transition itself, key and leaf.)
    A coin admitted here becomes spendable in a **later** transition (clause 2(b) requires membership in the *prior* coin-history root); received coins never feed clause 3's conservation sums of the same transition. The out-of-circuit receive gates — the creating nullifier's `completed` state, the `w.nav`-canonical check, decryption — remain the receiver's node-side checks of [§2.3.3](#233-receive); clause 10 is what folds a verified receipt into the account's own recursive lineage, so that a single current proof transitively attests every coin the account holds ([§2.2](#22-proof-types)).

The transition's **on-chain nullifier** `(Pkᵢ, Rᵢ)` ([Foundations §1.4](#14-identifiers-and-hashes), [§3.1](#31-the-on-chain-object)) is the account-state nullifier this transition publishes: `Pkᵢ = current_pubkey` and `Rᵢ` sign-to-contract-commits `H(ProofData)`, which folds in `input_nullifiers_root` (the spent coins), `output_coins_root` (the produced coins), and `new_account_state_hash` (hence the rotated spend authority). A publisher half-aggregates many transitions' nullifiers and inscribes them on Bitcoin ([On-chain §3.3](#33-half-aggregation)); the wallet's own node MAY instead self-publish its nullifier. Construction and publishing are specified in [On-chain Layer](#3--on-chain-layer).

### 2.2 Proof types

There is **one** PCD circuit: the **per-account compliance circuit** `C`, which produces both `InitialProof` and `AccountUpdateProof`. There is **no** publisher-side aggregation circuit — in the paper model a publisher only half-aggregates BIP-340 signatures ([On-chain §3.3](#33-half-aggregation), no recursive proof, no secret keys) and inscribes the resulting nullifiers; the double-spend accumulator is rebuilt by every node from those on-chain nullifiers by first-occurrence ([On-chain §3.6](#36-chain-scanning)), so nothing recursive needs to be proved about a batch.

| Type | Circuit | When | Clause 1 behaviour |
|---|---|---|---|
| `InitialProof` | `C` | first transition of an account (creation; optionally an issuance) | `prev_proof` absent; `prev_account_state` is the canonical empty account for `owner = H(Pk₀ ‖ nk_commit)` (defined below) |
| `AccountUpdateProof` | `C` | every subsequent transition | `prev_proof` present and verified recursively against the circuit's own verifier data |

**Canonical empty account (normative).** For any `address`, the **canonical empty `AccountState`** has these exact field values and **MUST** be reproducible bit-for-bit:

- `owner = address = H(Pk₀ ‖ nk_commit)` ([§1.4](#14-identifiers-and-hashes))
- `nk_commit = Hc("NkCommit", nk)` — the Poseidon commitment to the account's nullifier key `nk` ([§1.2](#12-key-hierarchy)), fixed at account creation from the `nk` the wallet chose; every later transition carries it forward **unchanged** ([§2.1 clause 1, clause 7](#21-the-compliance-predicate)), exactly like `owner`. Because `nk_commit` is part of the `owner` (address) preimage, the empty account is canonical **per address** — the address already binds `nk_commit`, so two distinct `nk` are two distinct addresses (two distinct accounts), which forbids both genesis and fork equivocation on nullifiers (clause 4, clause 1 InitialProof check)
- `balances = {}` (the empty map; `balances_count = 0` in `serialize`, [§1.7.4](#174-serializeaccountstate))
- `current_pubkey = Pk₀` (the x-only initial spend pubkey; with `nk_commit` it fixes `owner = H(Pk₀ ‖ nk_commit)`)
- `send_counter = 0`
- `coin_history_root = E'₂₅₆` (the empty coin-history SMT root, [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log))

The InitialProof's `prev_account_state` is exactly this state; its `ash` (call it `ash_empty(address)`) is `Hc("AccountState", serialize(canonical_empty_account))`.

Because recursion is **cyclic** — one fixed circuit that verifies proofs of itself — the verifier data of `C` is constant, so **per-account proof size and verification time are constant** and independent of an account's or a coin's history length. A conforming verifier **MUST NOT** require, fetch, or re-execute any prior transition: verifying the latest proof transitively attests every predecessor.

**On-chain anchoring (normative).** The per-account proof `C` is the **only** recursive proof in the system. A transition's public `ProofData` — `{ new_account_state_hash, output_coins_root, input_nullifiers_root, coin_history_root, nav_commitment, npk_commit }` (six 32-byte fields, 192-byte `serialize`, [§1.4](#14-identifiers-and-hashes)) — is bound to Bitcoin **not** by a second circuit but by the transition's own **sign-to-contract nullifier**:

- The transition signs the per-network fixed message `m_state` with sign-to-contract committing `H(ProofData)` in its nonce `R` ([§2.1 clause 2](#21-the-compliance-predicate), [On-chain §3.2](#32-transition-signing-bip-340--sign-to-contract)). The on-chain nullifier is the pair `(Pkᵢ, Rᵢ)` ([§3.1](#31-the-on-chain-object)); `Rᵢ` therefore commits **exactly this** `ProofData`, and the account key `Pkᵢ` proves the poster owns the account state being nullified. The same `Pkᵢ` is exposed as the proof's `consumed_pubkey` public output ([§2.1 clause 9](#21-the-compliance-predicate)), so a successor (clause 1) and a receiver (clause 10(d)) bind the on-chain nullifier's **key** to the *specific* key the transition consumed — not a witness the prover may pick.
- Every node folds `Pkᵢ` into the global accumulator by **first-occurrence** ([§3.6](#36-chain-scanning)); the accumulator is a **pure function of the on-chain nullifiers**, identical on every honest node, so admission is objective and availability-independent — no off-chain object, no publisher-asserted root, and no recursive batch proof gate it.
- **Conditional NAV.** The fifth public input `nav_commitment` hides the transition's conditional nullifier-accumulator value `nav` ([§2.1 clause 1](#21-the-compliance-predicate)) — the chain-derived accumulator value that contains all the transition's dependency nullifiers. A receiver opens it from the `CoinProof` bundle and checks `nav` is a **canonical** value on its own chain-derived accumulator ([§2.3.3 step 2](#233-receive)); the in-circuit prefix chain (clause 1, clause 10c) carries every **dependency** nullifier into `nav`, while the per-hop **predecessor-nullifier check** (clause 1) and clause 10(d) require each state-advancing transition's **own** `(Pkᵢ, Rᵢ)` to be a canonical member too — bound, key and leaf, to the *specific* key the transition consumed (clause 1 (iii), clause 10(d)) — so that single check attests the **whole lineage's** anchoring. A reorg of ≤5 blocks touches only non-final nullifiers and resolves by canonical replay; a reorg of ≥6 blocks that displaces a final dependency is outside v1's guarantee and MAY break the account ([§3.9](#39-finality-and-reorg-handling)), which v1 accepts in place of the paper's no-op recovery.

**Network/chain separation (normative).** The verifier data of `C` is parameterised by a fixed network tag (`zkCoins/v1/mainnet`, `zkCoins/v1/testnet`, `zkCoins/v1/regtest`), so a proof valid against one network's verifier data is unsatisfiable against another's. The public input `network_id = Hc("Network", network_tag_bytes)` ([§1.4](#14-identifiers-and-hashes), [§2.1 clause 9](#21-the-compliance-predicate), [§2.5](#25-circuit-dimensioning-normative)) is constrained in-circuit against that same compile-time network constant — **proof-level** binding: a verifier of `C` reads `network_id` from the four field elements after `consumed_pubkey` and checks it against its own network; a verifier of `C_balance` reads `network_id` as the **last** public input (no `consumed_pubkey` on that circuit) and checks it the same way. **`network_id` does not bind the BIP-340 signature and does not close on-chain cross-network replay**; that is closed exclusively by the per-network fixed `m_state` (`"zkCoins/v1/StateUpdate/mainnet"` \| `"…/testnet"` \| `"…/regtest"`, [§1.4](#14-identifiers-and-hashes), [§3.2](#32-transition-signing-bip-340--sign-to-contract)), which every scanner and the in-circuit BIP-340 check use. Each network additionally fixes a consensus-critical **`activation_height`** — the first Bitcoin block height at which nullifiers are recognised ([§3.6](#36-chain-scanning)) — pinned as part of the same per-network parameter set (mainnet at deployment; fixed for testnet/regtest). This is the **closed** set of network tags; `/v1/info.network` and `kernel.v1 Info.network` advertise the short names `mainnet` | `testnet` | `regtest`, which map 1:1 to these tags. A conforming verifier MUST refuse a proof whose verifier data does not match the network it is operating on ([§1.7.9](#179-proof-system-parameters-normative)).

**`C_balance` (normative, cross-reference).** The [§5.7](#57-balance-attestation-history-private) `BalanceAttestation` is produced by a second, **non-cyclic** circuit `C_balance` — unlike the compliance circuit `C` it never verifies a proof of itself, so it carries no cyclic-recursion machinery. It verifies exactly one `C`-proof `π` under `C`'s pinned verifier data (a non-cyclic foreign-verifier-data check), plus the balance-disclosure checks the §5.7 statement lists. Because a `BalanceAttestation` proof is handed to a disclosure verifier and its witness is the subject's **full** `AccountState` (every asset's balance, not only the one attested), `C_balance` **MUST** likewise be built with zero-knowledge enabled ([§1.7 circuit configuration](#179-proof-system-parameters-normative), [Requirement 2](/requirements)); its circuit configuration and pinned circuit digest are fixed by [§1.7.9](#179-proof-system-parameters-normative), exactly as for `C`.

### 2.3 State transitions

The three operations are the only ways state changes. Each is one execution of `C`. **Every** state-advancing transition — a **send**, a **receive**, and a **mint** — consumes its state's one-time key `Pkᵢ` and hands its on-chain nullifier `(Pkᵢ, Rᵢ)` — extracted from that transition's `SpendRecord` authorization ([Foundations §1.4](#14-identifiers-and-hashes)) — to a publisher, or has the wallet's own node self-publish it ([§3.3](#33-half-aggregation)–[§3.4](#34-the-publisher)); a mint and a pure receive anchor on Bitcoin by first-occurrence exactly like a spend ([§2.1 clause 1](#21-the-compliance-predicate), [§3.10](#310-transaction-states)). For value delivered to a counterparty the transition additionally produces one or more `CoinProof` bundles (off-chain, [Foundations §1.5](#15-core-data-structures)). The **wallet** holds the SPEND branch and signs; the **node/prover** holds the operational bundle `{ivk, ovk, op, nk, op_secret}`, builds the witness, and runs the prover ([Foundations §1.2](#12-key-hierarchy)). The spend key **MUST NOT** leave the wallet.

#### 2.3.1 Mint / issuance

Creates an account and/or issues coins of a newly-created asset. Issuance is **creator-bound and governed by a mandatory token standard**: each asset is created under exactly one token standard (its `issuance_version`, [System Architecture §6.5](#65-issuance--token-standards)), and the asset's identity binds to its creator's `Pk₀` *and* its `issuance_version` by construction ([Foundations §1.4](#14-identifiers-and-hashes)). *"Permissionless"* means anyone can create their own asset, not that anyone can mint someone else's: only the holder of `sk₀` of the issuing account can sign mint transitions for it. **Token standard 1 imposes no protocol-level supply cap, per-mint quantum, or time window** — within their own asset, the creator MAY mint any amount at any time; supply discipline is a creator's commitment, not a protocol guarantee. A **token-standard-2** asset instead carries a protocol-enforced maximum supply `cap_total`, minted once in the issuing account's genesis transition (see [Architecture §6.5](#token-standard-2--auditable-capped-supply)).

```
Inputs (wallet → node):
  owner          = H(Pk₀ ‖ nk_commit)   // account identity, from the initial spend key and
                                        //   the nullifier-key commitment nk_commit = Hc("NkCommit", nk) (§1.4)
  name, decimals                        // human-readable; name is NEVER on-chain
  amount                                 // initial supply to emit to self

Wallet:
  1. derive Pk₀ = sk₀·G and the rotated next_pubkey Pk₁ (both SPEND branch); derive
     name_hash = H(name); asset_id = Hc("AssetId", genesis_tag ‖ Pk₀ ‖ name_hash ‖ decimals ‖ issuance_version=1)   (Foundations §1.4);
     provide next_pubkey Pk₁ (SPEND branch) so the node folds it into the new state
     (the node already holds nk — operational bundle, Foundations §1.2); post the transition
     intent (`TransitionRequest` — §7.5)
     (a mint is a STATE-ADVANCING transition: it consumes the genesis one-time key Pk₀ and MUST
      publish (Pk₀, R) on Bitcoin, arbitrated by first-occurrence exactly like a spend — this is
      what closes the mint-fork, §3.10; current_pubkey rotates to Pk₁, folded into
      new_account_state_hash — hence into H(ProofData) — so the sign-to-contract nonce authorises
      the rotation, §2.1 clause 2)

Node / prover:
  2. build the witness with empty inputs, asset_issuance = {asset_id, creator_pubkey = Pk₀,
     issuance_version = 1, name_hash, amount, decimals, terms_hash}, and one output coin
     {recipient = owner, amount, asset_id}; derive nav_rand (§1.4) and set nav to `size_final` (§2.3.2 step 5) — the shared ≥6-confirmation-final prefix, which is `nav_empty = (0, nflog_empty)` on a fresh network where `size_final = 0` and the current final prefix on an active network — for **every** mint (a fresh network's first mint, a new account's first mint on an active network, and a follow-up mint alike); nav_commitment =
     Hc("NavCommit", nav_root ‖ nav_rand) (§1.4); determine the six ProofData fields and surface them
     plus `proof_data_hash` (`awaiting_signature`)

Wallet:
  3. recompute H(ProofData) itself (fail-closed, §7.5) and sign the single
     transition signature BIP-340(sk₀, m_state) over the per-network FIXED message
     m_state = "zkCoins/v1/StateUpdate/{mainnet|testnet|regtest}" (the node's network), applying the sign-to-contract tweak that binds this
     transition's H(ProofData) in the nonce R = R' + H(bytes(R') ‖ H(ProofData))·G (§1.4, §3.2);
     POST `{ signature, s2c_nonce }`

Node / prover:
  4. verify the signature and finalise the recursive proof: run C as an InitialProof (clause 1, InitialProof path) when this is the account's first
     transition, or as an AccountUpdateProof with asset_issuance present when the creator
     mints on an account that already has a prior transition (clause 3 admits asset_issuance in any transition;
     step 1 then uses the current skᵢ/Pkᵢ, rotating to Pkᵢ₊₁, instead of sk₀/Pk₀ → Pk₁, and step 3 signs with skᵢ;
     the asset_id derivation in step 1 is unchanged — it always binds Pk₀, and
     asset_issuance.creator_pubkey remains Pk₀). Either way the token-standard-1 issuance circuit
     checks the four §6.5 mint clauses — issuance_version == 1, H(creator_pubkey ‖ nk_commit) == owner,
     asset_id derivation, and terms_hash recomputation; Mint(asset_id) = amount,
     In(asset_id) = 0, so balance clause 3 admits exactly `amount` of the new asset
  5. obtain π, new ash, ocr, and ProofData; assemble SpendRecord/CoinProofs, deliver, and hand the
     nullifier to the publisher / self-publish

Produces the transition authorization (canonical §1.4 SpendRecord layout) and its on-chain nullifier:
  { public_key: Pk₀ (x-only), signature: BIP-340(sk₀, m_state) with S2C over H(ProofData) }
  (for a mint on an account with a prior transition, the current Pkᵢ/skᵢ take the place of Pk₀/sk₀)
  The mint's on-chain nullifier (Pk₀, R) is handed to a publisher — or self-published (§3.3–§3.4) —
  and MUST reach state `completed` (§3.10) before any recipient credits a coin whose lineage
  includes this mint. There is no non-anchored mint shortcut: a mint is anchored on Bitcoin by
  first-occurrence exactly like a spend, so two mints against the same state collide on Pk₀ and only
  the first is admitted (§6.5). The receiver of any subsequent CoinProof still re-verifies the mint's
  recursive proof transitively (cyclic recursion, §2.2) AND checks this on-chain nullifier's
  first-occurrence (§2.3.3 step 4).

CoinProof produced:  for self-held supply, none is delivered; the node retains the coin,
  proof, and inclusion proof locally as spend credential, together with the asset's plaintext
  terms {creator_pubkey, name, decimals, issuance_version} — the asset_terms of §1.5, which no
  chain data can reproduce. When the issuer later delivers the asset's coins, the first hop
  to each new recipient MUST carry asset_terms (§2.3.2, §2.3.3 step 6).
```

`asset_id` is globally unique because it commits to the creator pubkey, `name_hash = H(name)`, `decimals`, and the `issuance_version`; two creators cannot collide, the same creator distinguishes assets by `name_hash`/`decimals`, and two assets created under different `IssuanceTerms` versions are also distinct. The human-readable `name` travels inside bundles and, once a holder has the `asset_id`, is additionally resolvable via the open Class-B lookup from any holder that has retained the terms ([§4.6](#46-data-availability), [§7.5](#75-node-rest-api-normative)); it is never on-chain ([Foundations §1.4](#14-identifiers-and-hashes)) — concretely, in the optional `asset_terms` field of the `CoinProof` bundle ([Foundations §1.5](#15-core-data-structures)).

#### 2.3.2 Send

Spends owned input coins and produces output coins (recipient coins plus a change coin), the corresponding nullifiers, a new account state, and a proof.

```
Inputs (wallet → node):
  input_coins[]                          // coins the account owns and will spend
  output_templates[] = CoinTemplate[]    // {recipient, amount, asset_id} per payee

Wallet:
  1. supply the rotated next_pubkey Pkᵢ₊₁ (SPEND branch, Foundations §1.2) so the node folds it
     into new_account_state_hash — hence into H(ProofData), so the sign-to-contract nonce
     authorises the rotation Pkᵢ → Pkᵢ₊₁ (§2.1 clause 2); the node already holds nk (operational
     bundle) and derives the nullifiers; post the transition intent (`TransitionRequest` — §7.5)

Node / prover:
  2. for each input coin, derive nf = Hc("Nullifier", nk ‖ coin.identifier)
  3. assemble the witness; per asset, add a change CoinTemplate {recipient = owner,
     amount = In(a) + Mint(a) − Out(a), asset_id = a} so clause 3 holds with equality
  4. for each output coin (Foundations §1.3): draw esk, compute epk = esk·G,
     ss = ECDH(esk, IVPK_recipient), K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk),
     detect_tag = Hc("zkCoins/v1/DetectTag", ss ‖ epk);
     ciphertext = NIP44Binary(K_tx, "coin", serialize(Coin));
     derive K_out = HKDF("zkCoins/v1/OutKey", ovk ‖ epk) and
     out_ciphertext = NIP44Binary(K_out, "K_tx", K_tx) for the sender's own outgoing record (§1.3)
  5. set nav to **`size_final`** — the ≥6-confirmation-final prefix (§3.9), the **shared** canonical
     accumulator value at the current tip (committed form `nav_root = Hc("NfLog/Root", size_final ‖
     mth_final)`). Every dependency (the previous account-state nullifier and each input/received
     coin's creating-transition nullifier) is final, hence at a position `< size_final`, so `nav`
     anchors them all. Because `size_final` is **identical for every prover at a given tip**, the
     fee-coin `nav_opening` (deferred, §3.8.1) would reveal only that shared ordinal, not the account's activity —
     this is the **MUST** default. If any dependency is still **pending** (position `≥ size_final`)
     the **wallet** waits for it to finalize before building the transition (§2.3.3, §3.9). v1 has **no** proving-pipelining: every
     transition's `nav` is exactly `size_final`, so a not-yet-final dependency is simply not yet
     spendable. This keeps `nav` a **shared**, node-enforced value (§3.9) — the wallet does not independently verify it, an accepted thin-client boundary (D-17) and forecloses the
     account-brick a published-but-non-final `nav` would cause under a tolerated reorg — and
     derive nav_rand; compute nav_commitment = Hc("NavCommit", nav_root ‖ nav_rand) (§1.4); determine
     the six ProofData fields
     and surface them plus `proof_data_hash` (`awaiting_signature`)

Wallet:
  6. recompute H(ProofData) itself (fail-closed, §7.5) and sign the single transition signature
     BIP-340(skᵢ, m_state) over the per-network FIXED message m_state = "zkCoins/v1/StateUpdate/{mainnet|testnet|regtest}"
     (the node's network) with the
     current per-transition signing key skᵢ (whose Pkᵢ is current_pubkey; no per-coin key),
     applying the sign-to-contract tweak that binds this transition's H(ProofData) in the nonce
     R = R' + H(bytes(R') ‖ H(ProofData))·G (§1.4, §3.2); POST `{ signature, s2c_nonce }`

Node / prover:
  7. verify the signature and finalise the recursive proof: run C as an AccountUpdateProof:
     recursive verify of prev_proof + conditional-NAV carry-forward
     (clause 1), input authenticity (2), per-asset conservation (3), nullifier derivation (4),
     output construction (5–6), new state/ash (7), coin-history update (8), binding (9),
     received-coin admission (10, empty here unless receipts are folded into the same transition)
  8. obtain π, ash, ocr, ProofData; assemble SpendRecord/CoinProofs, deliver, and hand the
     nullifier to the publisher / self-publish

Produces the SpendRecord (off-chain; the account's transition authorization, canonical §1.4 layout):
  { public_key: Pkᵢ (x-only), signature: BIP-340(skᵢ, m_state) with S2C over H(ProofData) }
  Its on-chain nullifier (Pkᵢ, Rᵢ) — where Rᵢ is the sign-to-contract nonce that commits
  H(ProofData) — is handed to a publisher together with the wallet's pre-tweak nonce R' and the
  scalar sᵢ (§7.6), or self-published (§3.4). The publisher half-aggregates it with others' and
  inscribes one nullifier set on Bitcoin (On-chain §3.3, §3.5); every node then folds Pkᵢ into the
  global accumulator by first-occurrence (§3.6).

CoinProof produced (per recipient coin, delivered off-chain):
  { coin, proof = π, inclusion_proof (membership in ocr), creating_prev_ash (= the ash of
    this transition's prev_account_state, §1.4),
    creating_nullifier = {Pk_create, R_create, R_prime_create} (this transition's own on-chain
    nullifier and its S2C pre-nonce, so the recipient confirms first-occurrence and that R_create
    opens H(ProofData); §1.5, §2.3.3 step 4),
    nav_opening = {nav, nav_rand} (lets the recipient open this proof's nav_commitment and check
    prefix(nav, own nav) in clause 10(c), §1.4),
    asset_terms? = {creator_pubkey, name, decimals, issuance_version} (§1.5, §6.5),
    epk, ciphertext, detect_tag }
  (Foundations §1.5). The sender SHOULD attach asset_terms, and MUST attach it when it holds
  terms passing the §2.3.3 step-6 recompute for this asset_id and has not previously delivered
  asset_terms passing that recompute for this asset_id to this recipient (the terms' first hop
  to that recipient): without the terms the recipient cannot run the §2.3.3 step-6 terms
  check, and its wallet can carry the asset only as an opaque asset_id. A holder that itself
  received the asset without verified terms (§2.3.3 step 6 permits exactly that state) MAY
  nevertheless spend it onward; the recipient then carries the asset as an opaque asset_id as
  well. The change coin's bundle is retained locally, not delivered; the sender's
  SelfDeliveryRecordV1 carries output_refs[{coin_id, blob_id, epk, out_ciphertext,
  blob_locators}] per outgoing coin plus self_blob_locators for the SDR blob (§1.3, §4.2, §7.1).
```

When the transition's nullifier `(Pkᵢ, Rᵢ)` is inscribed and every node folds `Pkᵢ` into the global accumulator by **first-occurrence** ([On-chain §3.6](#36-chain-scanning)), the spent account state can never be spent again ([§3.7](#37-the-nullifier-accumulator)). The rotated spend key `next_pubkey = Pkᵢ₊₁` **never appears on Bitcoin** — it lives only inside the off-chain, hashed `new_account_state_hash` ([§1.4](#14-identifiers-and-hashes), [§2.1 clause 2](#21-the-compliance-predicate)) — so the rotation edge `Pkᵢ → Pkᵢ₊₁` that would otherwise chain an account's consecutive transitions stays hidden from every chain observer; the on-chain nullifier reveals only a fresh rotating `Pkᵢ`, unlinkable to the account or to the account's other nullifiers. The proof's fifth public input is a **hiding** `nav_commitment` with fresh randomness per transition ([§1.4](#14-identifiers-and-hashes)) rather than a decodable accumulator value. Under the deferred fee mechanism the publisher would receive the fee coin's `nav_opening` (it must, to later spend the fee coin, [§3.8.1](#381-fee-coin-mechanism-deferred)); in v1 there is no fee coin and it receives none — but because the spender sets `nav` to the shared `size_final` prefix (step 5, [§2.3.3](#233-receive), [§3.9](#39-finality-and-reorg-handling)) — identical for every prover at that tip — that opening reveals only that shared global ordinal, not the account's activity, and distinct transitions carry distinct commitments, so **this opening** gives the publisher no link between the transition and the account's prior ones, and a chain-only observer learns nothing about the spender. (A *repeatedly reused* publisher retains a bounded linkage channel — in v1 through the pre-anchor `Pkᵢ` each hand-off discloses, and under the deferred fee mechanism additionally through the fee coin's own `CoinProof` fields — an accepted v1 boundary, registered as D-19 and catalogued in [Risks](/risks); publisher rotation or self-publish removes it at no protocol cost.) Delivery of the per-recipient `CoinProof` over Nostr is specified in [Transport & Recovery](#4--transport--recovery); hand-off of the spender's nullifier `(Pkᵢ, Rᵢ, sᵢ, R')` to a publisher is specified in [§7.6](#76-publisher-interface-normative); the fee `CoinProof` accompanies it only under the deferred mechanism of [§3.8.1](#381-fee-coin-mechanism-deferred).

#### 2.3.3 Receive

The receiver (or its node, on its behalf) credits a coin **only after independent verification** — the trustless-receive norm ([Requirement 4](/requirements)). A conforming receiver **MUST NOT** credit a coin on the sender's or any third party's assertion.

```
Inputs:
  CoinProof bundle (off-chain, delivered to the recipient)   (Foundations §1.5)
  the receiver's own view of Bitcoin and the global roots

Receiver / node:
  1. discovery & decrypt: re-derive ss = ECDH(ivk, epk), match detect_tag against
     Hc("zkCoins/v1/DetectTag", ss ‖ epk); then K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk); decrypt the coin
     (only a holder of ivk can; Foundations §1.3)
  2. RE-VERIFY THE FULL RECURSIVE PROOF: C.verify(proof) under the canonical verifier data.
     This transitively attests the entire provenance in constant time (§2.2). MUST pass.
     ADDITIONALLY: open proof.ProofData.nav_commitment with the nav_opening the sender placed in
     the CoinProof bundle (§1.5) — check it commits (Hc("NavCommit", nav_root ‖ nav_rand),
     short tag, nav_root = Hc("NfLog/Root", size ‖ mth); §1.7.6) —
     and verify that nav is a CANONICAL nullifier-accumulator value on the receiver's OWN scan
     (§3.7, §3.9) (§3.7 Canonical value: mth = MTH(D[0:size]) on the receiver's own scan, and —
     for crediting — size ≤ size_final). This one check is what makes the provenance's whole lineage trustworthy: the
     in-circuit prefix chain (clause 1, clause 10(c)) forces every DEPENDENCY nullifier — and the
     per-hop predecessor-nullifier check (clause 1) together with clause 10(d) force every
     state-advancing transition's OWN account-state nullifier — of every transition in the coin's
     past to be contained in this top-level nav, so a single canonical check validates all of them
     at once — each hop's own nullifier bound key-and-leaf to the specific key its transition
     consumed (clause 1 key-binding (iii), clause 10(d)). A reorg that orphaned any dependency
     makes nav non-canonical, so the receiver MUST re-evaluate rather than credit; within
     the ≤5-block window this resolves by canonical replay, and a ≥6-block reorg that leaves
     it non-canonical is the accepted break boundary (§3.9), not a no-op. The receiver **MUST**
     additionally require `w.nav.size ≤ size_final` (§3.9) — every position `w.nav` authenticates
     lies in the ≥6-confirmation-final prefix of the log, so no authenticated leaf can be
     reshuffled by a ≤5-block reorg after a coin is credited.
  3. inclusion: verify inclusion_proof places coin.identifier in the committed output_coins_root.
  4. anchoring: verify the creating transition's on-chain nullifier (Pk_create, R_create) from the
     bundle's creating_nullifier (§1.5) is the FIRST OCCURRENCE of Pk_create in the accumulator the
     receiver rebuilt from Bitcoin (Onchain §3.6, §3.7), with R_create opening — via R_prime_create —
     to H(creating proof's ProofData) (§3.2). In-circuit, clause 10(d) additionally binds
     Pk_create == creating_proof.consumed_pubkey (§2.1 clause 9), so the KEY checked here is the one
     the creating transition ACTUALLY consumed — a malicious sender cannot substitute a fresh-key
     naked nullifier it minted under a key it controls. This proves the creating transition was
     actually anchored on Bitcoin, and was the first (valid) transition on that account state, not a
     double-spend loser. Any other classification of Pk_create (present with a different R, or a
     later occurrence) MUST be treated as not anchored (§3.10). Because EVERY state-advancing
     transition publishes its nullifier, there is no off-chain-only "self-spend hop": an unanchored
     creating transition has no on-chain Pk_create to be a first occurrence. Crediting is **Path-A-only**: the `completed` classification behind a credit ([§3.10](#310-transaction-states)) **MUST** come from the receiver's own node's Path-A accumulator (its own §3.6 scan of Bitcoin — [Requirement 4](/requirements)). A Path-B answer (a delegated RFC-6962 log-inclusion proof from a foreign node, §3.7) **MUST NOT** be the basis for crediting — neither a single answer nor any combination of answers; it MAY back non-crediting display, marked unverified. (A mint coin is NOT a special case: the
     creating transition is the mint itself, which is state-advancing and anchors its own
     (Pk_create, R_create) on Bitcoin — §2.3.1, §3.10 — so this same first-occurrence check applies
     to it unchanged.)
  5. replay guard: the receiver MUST NOT re-credit a coin it already holds or has already spent.
     This is its OWN per-account coin-history SMT (§1.6, §1.7.6): a coin already present in the
     account's coin-history (leaf state 1 received-unspent, or 2 spent) is not admitted again by
     clause 8. No global-accumulator lookup by the receiver's own nf is possible — the account's
     private per-coin nf never appears on Bitcoin (the global accumulator is keyed by account-state
     Pkᵢ, not by nf, §3.7) — so this replay case is a purely per-account check. Sender-side
     equivocation is caught by step 4's first-occurrence check, not here.
  6. amount/asset sanity & issuance terms: confirm coin.recipient = receiver's address and
     asset_id is well-formed. If the bundle carries asset_terms (§1.5), the receiver MUST
     dispatch on issuance_version and recompute the matching asset_id from the supplied
     terms: for token standard 1, asset_id == Hc("AssetId", genesis_tag ‖ creator_pubkey ‖ H(name)
     ‖ decimals ‖ issuance_version); for token standard 2, asset_id == Hc("AssetIdV2", genesis_tag
     ‖ creator_pubkey ‖ H(name) ‖ decimals ‖ issuance_version ‖ cap_total ‖ terms_salt)
     (§1.4, §6.5) — then compare against coin.asset_id; a mismatch MUST reject the whole
     bundle — never credit the coin while silently discarding the terms. An `asset_terms` whose `issuance_version` is neither `1` nor `2` is **malformed**: the receiver **MUST** reject the whole bundle (fail-closed — no dispatch branch exists for it, §7.1). For a token-standard-2 asset the
     verified terms carry cap_total, so the recompute is also what assures the holder of the
     asset's provable supply cap (§6.5). If asset_terms is absent the coin remains valid and creditable,
     but the wallet MUST carry the asset as an opaque asset_id — no name, no decimals-scaled
     display — until terms passing this recompute arrive (§6.5); a name that has not passed
     it MUST NOT be shown to the user.
     (This is an out-of-circuit early reject; the binding that actually secures the credited amount
     and recipient is IN-CIRCUIT — clause 10(b) recomputes coin.identifier over
     creating_prev_ash ‖ recipient ‖ asset_id ‖ amount ‖ coin_index and requires it to be the
     output_coins_root member — so a malicious receiver running its own prover cannot evade it, §2.1.)

On all of 2–6 passing:
  7. RUN THE RECEIVE TRANSITION: execute C — as an InitialProof if this is the account's first
     transition (clause 1 InitialProof path: prev_proof absent, prev_account_state = the canonical
     empty account, nav satisfying prefix(nav_empty, nav)), otherwise as an AccountUpdateProof —
     whose received_coins[] contains the verified coin (clause 10). The node takes each creating
     transition's on-chain nullifier and the creating proof's nav_opening from the CoinProof bundle
     (§1.5), and sets its own nav to `size_final` (the shared ≥6-confirmation-final prefix, [§2.3.2 step 5](#232-send), [§3.9](#39-finality-and-reorg-handling)) — a canonical value that is a
     superset of every received coin's creating nav (clause 1 + clause 10(c)) and contains each
     creating transition's nullifier (clause 10(d)); it credits balances (clause 7) and admits the
     coin to the coin-history SMT (clause 8). Several verified receipts MAY be folded into one
     transition (bounded by MAX_RX_COINS, §2.5), and a receive MAY be combined with a send in a
     single transition. The wallet signs the transition signature exactly as for a send (§7.5
     proving handshake); a receive is itself a state-advancing transition, so it too consumes its
     state's one-time key Pkᵢ, and its on-chain nullifier (Pkᵢ, Rᵢ) MUST be handed to a publisher or
     self-published (§3.3–§3.4) and reach state `completed` (§3.10) — the account's newly-folded
     coins become creditable and spendable by others only after that. Receiving therefore now costs
     a ~64-byte on-chain nullifier, the accepted trade-off: an UNanchored receive would let a coin be
     double-spent across an account fork (the two branches' later spends rotate to different keys, so
     only anchoring the fork-point receive's Pkᵢ by first-occurrence catches it).

The resulting proof — not the raw incoming bundle alone — is the receiver's spend credential
for a future Send (clause 2(b) requires the coin in the PRIOR coin-history root). The receiver
MUST retain the incoming CoinProof bundle per §4.8 and, after this verification and durable
persist (§4.8), MUST return the encrypted acknowledgement of §4.2 so the sender knows the
recipient durably stored it; the sender still retains its own copy (§4.8) (Transport & Recovery).
```

Steps 2 (recursive re-verification of the spender's per-account proof plus the canonical-`nav` check), 4 (chain anchoring: the creating transition's on-chain nullifier is the first occurrence in the accumulator the receiver rebuilt from Bitcoin) and 5 (the receiver's own coin-history replay guard) are the checks that make receipt fully trustless: the receiver depends on **Bitcoin and the spender's recursive proof, never on the courier or any node's bare claim**. A failed or malicious transport can **withhold** a bundle but can never make an invalid one verify; a dishonest node can refuse to serve a Path-B RFC-6962 proof but cannot forge one, because the accumulator is a pure function of the on-chain nullifiers (given the pinned network parameters, §3.6) the receiver can rebuild itself.

### 2.4 Soundness summary

Each predicate property delivers a specific [Requirement](/requirements):

| Property (clause) | Guarantees | Requirement |
|---|---|---|
| Recursive verification + input authenticity (1, 2) | **No forgery** — a coin exists only as the signed, proven output of a valid prior transition; no party can fabricate a coin it was not entitled to | 3 · Trustless |
| Per-asset balance conservation (3) + coin-value binding (§1.4; clauses 2(c)/5/10(b)) | **No inflation of others' assets** — for every `asset_id`, outputs never exceed inputs plus an explicit, creator-bound `Mint`; conservation holds **across** account boundaries, not only within one transition, because a coin's `amount` is folded into its `coin.identifier` (committed to `output_coins_root`) and **recomputed in-circuit** wherever the coin is spent (clause 2(c)) or received (clause 10(b)) — so a receiver cannot credit, nor a spender debit, an `amount` other than the one the creating account assigned (token standard 1 sets no protocol-level issuance cap, and over-issuance by the creator itself is not publicly detectable, [§6.5](#65-issuance--token-standards)) | 3, 8 |
| Nullifier derivation (4) + on-chain first-occurrence + receive check 4 | **No double-spend** — a transition's account-state nullifier `Pkᵢ` is published on Bitcoin and folded into the global accumulator by **first-occurrence** ([§3.6](#36-chain-scanning)), so it enters the set only once; a later transition re-using the same account state must re-use the same `Pkᵢ` and is the rejected double-spend loser (§3.10 `failed`). Because every state-advancing transition publishes its nullifier on-chain, admission is a pure function of Bitcoin (given the pinned network parameters, §3.6) — two honest nodes never diverge. The **fork** case is closed twice over: two forks of one account share the identical `current_pubkey = Pkᵢ` (fixed) and the identical `nf` for any shared coin (the `nk` deriving `nf` is committed by `nk_commit`, clause 4), so they collide on one accumulator key. Clause 1's **predecessor-nullifier check** closes the collision even for a pure-**receive** fork — which spends no shared coin, hence has no `nf` to collide — by forcing each fork's successor to prove the fork's own `Pkᵢ` was anchored, bound **both** to the winner's leaf `R` (a **same-key** loser cannot open the stored leaf, §3.6 step 5) **and** to the predecessor's **exposed consumed key** (a **fresh-key** substitution fails the `Pk_prev == prev_proof.consumed_pubkey` binding, [§2.1 clause 1](#21-the-compliance-predicate) (iii) / clause 9), so neither fork branch can evade. Receive check 4 (§2.3.3) confirms the creating transition's `Pkᵢ` is the first occurrence bound to its `H(ProofData)`; the coin-history SMT (clause 8) prevents an account re-spending a coin along its own lineage | 3 |
| Received-coin admission (10) + conditional-NAV carry-forward (1) | **No fabricated receipts, transitively** — a coin enters an account's provable holdings only with its creating proof verified in-circuit, its `(recipient, asset_id, amount)` bound by recomputing `coin.identifier` against the creating `output_coins_root` (clause 10(b) — so a coin can be credited **only** by its committed `recipient` and **only** for its committed `amount`, closing both cross-account duplication and receive-time inflation), and (for every state-advancing creating transition, mints included) its creating transition's on-chain nullifier required to be a member of the receiver's conditional NAV (clause 10(d)); clause 10(c) forces the creating account's `nav` to be a **prefix** of the receiver's own, clause 1's **predecessor-nullifier check** requires **each** state-advancing hop in the lineage to anchor its **own** `(Pkᵢ, Rᵢ)` (so a pure receive, self-held mint, or genesis-receive cannot advance state off-chain), and clause 1 forbids any rewind, so a colluding chain of holders cannot hide an unanchored ancestor — any lineage with an off-chain-only state advance makes the top-level `nav` non-canonical, which the single §2.3.3 step 2 scan check exposes. Because **every** state-advancing transition's nullifier is on Bitcoin — each bound key-and-leaf to the *specific* key it consumed (clause 1 (iii), clause 10(d)) — the unbatched off-chain hop that a hidden spend or receive would need, and the fresh-key substitution a malicious prover might otherwise mint, both cannot exist | 3 |
| Full re-verification on receipt (§2.3.3) | **Client-side validation** — correctness never depends on the sender, a foreign node, or any third party (the receiver's own node re-verifies on its behalf, [Requirement 4](/requirements)) | 4 |
| Public-input binding + ZK witness (9) | **Privacy** — against the public-chain observer ([Requirement 2](/requirements)'s adversary) nothing but the nullifier pair `(Pkᵢ, Rᵢ)` reaches Bitcoin, and off-chain only the proof's public inputs (roots/hashes) leave the circuit: amounts, assets, parties, and the transaction graph stay hidden. The bounded counterparty-scope residuals (co-output holders of one transition, a repeatedly reused publisher, a self-selected hosted prover) are outside this row's claim — accepted v1 boundaries D-17–D-19, catalogued in [Risks](/risks) and stated precisely in [§6.7](#67-security-properties-summary) | 2 |
| Constant-size cyclic recursion (§2.2) | **Scalable trustlessness** — history of any length verifies in constant time, so re-verification is always feasible | 4 |

### 2.5 Circuit dimensioning (normative)

A ZK circuit has a **fixed shape**: the number of inputs, outputs, and inner-proof verifications it can carry is wired in at build time and cannot vary per execution. This section fixes those bounds for v1. They are normative protocol constants — a proof built against different bounds verifies against different verifier data and is rejected ([§2.2 network/chain separation](#22-proof-types), [§1.7.9](#179-proof-system-parameters-normative)).

**Per-account circuit `C`** — the only circuit ([§2.2](#22-proof-types)).

| Constant | Value | Meaning |
|---|---|---|
| `MAX_TX_INPUTS` | **8** | maximum `input_coins[]` spent in one transition |
| `MAX_TX_OUTPUTS` | **8** | maximum output coins produced in one transition, **counting** every recipient coin and the per-asset change coin — and, under the deferred fee mechanism only, the publisher-fee coin ([§3.8.1](#381-fee-coin-mechanism-deferred)); v1 publishing is sponsored and produces no fee output |
| `MAX_RX_COINS` | **4** | maximum `received_coins[]` admitted in one transition ([§2.1 clause 10](#21-the-compliance-predicate)); each active slot costs one cyclic proof verification, so this bound dominates the receive path's proving cost — a node with more verified receipts folds them into sequential transitions |
| `MAX_ACCOUNT_ASSETS` | **32** | maximum distinct non-zero `(asset_id, amount)` entries an account's `balances` may hold — the fixed slot count the in-circuit `serialize(AccountState)` absorption pads to ([§1.7.4](#174-serializeaccountstate), [§2.1 clause 7](#21-the-compliance-predicate)); inactive slots contribute nothing to `ash`. An account that would need more than `MAX_ACCOUNT_ASSETS` distinct assets with non-zero balance cannot be formed (practically never relevant at 32) |
| `MAX_NAV_DEPTH` (`H_MAX`) | **64** | the maximum height of the [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log) accumulator Merkle log = `⌈log₂(max entry count)⌉`. Each in-circuit inclusion proof is `≤ H_MAX` node hashes and each consistency proof `≤ 2·H_MAX` ([§2.1 clause 1, clause 10](#21-the-compliance-predicate), [§3.7](#37-the-nullifier-accumulator)). `H_MAX = 64` supports up to `2⁶⁴ − 1` first-occurrence entries (a `u64` position), far beyond any realistic lifetime (≈ 5.8 billion years at the [§3.8](#38-fees-and-economics) throughput bound). In a position-indexed log the depth is `log₂(count)` — there is no separate key length to reconcile |
| `MAX_HISTORY_UPDATES` | **20** | `MAX_TX_INPUTS + MAX_TX_OUTPUTS + MAX_RX_COINS` — fixed number of clause-8 two-root coin-history-SMT update gadgets ([§2.1 clause 8](#21-the-compliance-predicate)) |
| coin-history SMT depth | **256** | [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log) |
| nullifier-accumulator log height `H_MAX` | **64** | [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log), [§2.5 `MAX_NAV_DEPTH`](#25-circuit-dimensioning-normative) |

- `MAX_HISTORY_UPDATES = MAX_TX_INPUTS + MAX_TX_OUTPUTS + MAX_RX_COINS` (= `20` at the v1 bounds) — the fixed number of clause-8 two-root coin-history-SMT update gadgets in `C` ([§2.1 clause 8](#21-the-compliance-predicate)). Unused slots are **no-ops**: an inactive slot MUST leave the intermediate root unchanged (the circuit enforces old-root == new-root for it), so the fixed shape covers every transition ≤ the bounds.

Unused input/output slots are filled with a canonical **inactive** sentinel (an `active` BoolTarget per slot, gated so an inactive slot contributes `0` to every balance sum, no nullifier, and no output-coin leaf). The `MAX_ACCOUNT_ASSETS` balance slots of `serialize(AccountState)` follow the **same** inactive-sentinel discipline ([§1.7.4](#174-serializeaccountstate)): only the active `balances_count` slots (ascending `asset_id`, left-aligned) contribute bytes to the absorbed byte string, and inactive slots contribute nothing to `ash` — so the in-circuit, `MAX`-padded absorption yields the identical `Hc` value as the out-of-circuit variable-length serialization. The recipient coins, **one change coin per distinct asset** moved (§2.3.2 step 3), all draw from the same `MAX_TX_OUTPUTS` slots; under the deferred fee mechanism one publisher-fee coin would draw from them too ([§3.8.1](#381-fee-coin-mechanism-deferred)), but v1 publishing is sponsored and reserves no such slot. A wallet that needs more output slots than are available (or more than `MAX_TX_INPUTS` input coins) **MUST** split the payment across several sequential transitions; each is an ordinary `AccountUpdateProof` extending the previous one. (For the common single-asset, externally-published case this leaves `MAX_TX_OUTPUTS − 1 = 7` recipient slots in v1, one reserved for change; the deferred fee mechanism would reserve a second, leaving 6.) These bounds are an implementation parameter of the reference instantiation (§1.7.8) and MAY be revised by a version bump; they are **not** a privacy or correctness boundary (the anonymity set is global regardless of slot count).

`C`'s public inputs are the six `ProofData` fields (§2.1 clause 9) — five Poseidon digests (**20 field elements**) plus the SHA-256 `npk_commit` (**8 × u32 limbs**) — **plus the transition's consumed key `consumed_pubkey = Pkᵢ`** (§2.1 clause 1 / clause 9: the x-only `current_pubkey` it spends, exposed so a verifier binds each on-chain nullifier to the key its creating transition consumed), encoded as the reference `plonky2-ecdsa` secp256k1 base-field element — **8 Goldilocks field elements**, one 32-bit limb each (the same `NonNativeTarget` / `[U32Target; 8]` layout the in-circuit BIP-340 check already uses for `txn_pubkey`, [§2.6](#26-in-circuit-non-native-cryptography-normative)) — **plus `network_id = Hc("Network", network_tag_bytes)`** ([§1.4](#14-identifiers-and-hashes), clause 9) as a Poseidon `HashOut` — **4 Goldilocks field elements** — constrained in-circuit against the compile-time network constant of the build — so `C` exposes **20 + 8 + 8 + 4 = 40** application public-input elements — plus the cyclic verifier-data public inputs Plonky2 appends (`add_verifier_data_public_inputs`: the circuit digest, 4 elements, and the `constants_sigmas_cap`, `num_cap_elements()` digests at `cap_height = 4`). A conforming verifier reads `ProofData` from the first **28** public-input elements (20 Poseidon + 8 for `npk_commit`), `consumed_pubkey` from the next **8**, and `network_id` from the final **4** — total **40** — checks `network_id` against its own network, and checks the appended verifier-data elements against the pinned `circuit_digest(C)` (§1.7.9). `network_id` is **not** part of `serialize(ProofData)` (192 bytes unchanged) — it is separate, like `consumed_pubkey`. Unused `received_coins[]` slots follow the same inactive-sentinel discipline as the input/output slots above (an inactive receive slot verifies a canonical dummy proof via Plonky2's `conditionally_verify_cyclic_proof_or_dummy` and contributes nothing to balances or the coin-history update).

**Public-input limb encoding (normative).** Poseidon digests among the public inputs are native `HashOut`s — 4 Goldilocks field elements each ([§1.7.1](#171-poseidon-instance-and-digest-encoding)), including `network_id`. Every non-Poseidon 32-byte value (`consumed_pubkey`, `npk_commit`, and in `C_balance`: `subject`, `txid`, `block_hash`, `Pk_anchor`, `R_anchor`) is interpreted as a **big-endian integer** and carried as **8 × u32 limbs in little-endian limb order** (limb 0 = bits 0–31); `u128` amounts are 4 × u32 limbs, `u64` heights 2 × u32 limbs, same order. This layout is part of the circuit shape frozen by the digest pin ([§1.7.8](#178-reference-instantiation-status-final-for-v1)).

**No publisher-side circuit.** The retired batched design carried a second, publisher-side aggregation circuit that proved a batched accumulator transition over many members. The paper model removes it entirely: a publisher performs only **non-interactive Schnorr half-aggregation** of the members' BIP-340 signatures ([On-chain §3.3](#33-half-aggregation)) — arithmetic over collected signatures, no circuit, no secret keys, no recursive proof — and every node rebuilds the accumulator by first-occurrence from the on-chain nullifiers ([On-chain §3.6](#36-chain-scanning), [§3.7](#37-the-nullifier-accumulator)). There is therefore **no** batch-member dimensioning at all: a publisher may half-aggregate an arbitrary number of nullifiers into one inscription (bounded only by Bitcoin standardness, [§3.5](#35-inscription-format)), and the number of nullifiers per inscription is not a circuit parameter.

**`C_balance` shape (normative).** The balance-attestation circuit `C_balance` ([§2.2](#22-proof-types), [§5.7](#57-balance-attestation-history-private)) is dimensioned and pinned by the same discipline as `C`: its public inputs are exactly the §5.7 public values in declaration order — `subject` (32B), `asset_id` (32B), `balance` (`u128`, §2.6 limb encoding), `nav_ceiling` (32B), `size_ceiling` (`u64`, 2 × u32 limbs), `anchor.txid` (32B, internal order), `anchor.block_hash` (32B, internal order), `anchor.height` (`u64`), `anchor.Pk_anchor` (32B), `anchor.R_anchor` (32B), **`network_id` (Poseidon `HashOut`, 4 field elements — last field)** — encoded per the public-input limb rules above; the statement **MUST** include `network_id == Hc("Network", network_tag_bytes)` constrained against the compile-time network constant of the build (same proof-level binding as `C`; does **not** bind any signature); one verifying key per network tag; `circuit_digest(C_balance)` is a function of this layout and is pinned in [V.4](#v4-poseidon-derived-values). Any change to this layout is a version bump ([§1.7.8](#178-reference-instantiation-status-final-for-v1)).

### 2.6 In-circuit non-native cryptography (normative)

Several operations the predicate mandates are **not** native to the proof field (Goldilocks, §1.1). Two of them — secp256k1/BIP-340 Schnorr verification and in-circuit SHA-256 — are the **dominant proving cost** of the whole system; a third, wide-integer balance arithmetic, is non-native but comparatively cheap. This section fixes how they are realised so two implementations agree on feasibility and semantics; like §1.7, it is normative-for-v1 and final for v1 ([§1.7.8](#178-reference-instantiation-status-final-for-v1)).

**secp256k1 / BIP-340 Schnorr, in-circuit (foreign-field).** The compliance predicate verifies the account's BIP-340 transition signature in-circuit ([§2.1 clause 2](#21-the-compliance-predicate)) — one signature over the per-network fixed message `m_state`, plus the sign-to-contract opening `R = R' + H(bytes(R') ‖ H(ProofData))·G` that binds it to this proof. secp256k1's base and scalar fields are **not** Goldilocks, so this requires **non-native (foreign-field) arithmetic**: ~256-bit modular arithmetic and secp256k1 point operations emulated over Goldilocks. The reference instantiation uses the Plonky2 secp256k1/ECDSA gadget stack (the `plonky2-ecdsa`-style `nonnative` field + `curve` gadgets from the Plonky2 ecosystem, adapted to BIP-340 x-only keys and the §1.1 tagged-SHA-256 challenge). The *relation* is fixed normatively; the *gadget realising it* is a design-time freedom of the **reference implementation only** — because `circuit_digest(C)` is a function of the concrete gadget selection ([§1.7.9](#179-proof-system-parameters-normative)), once the reference build pins the digests ([V.4](#v4-poseidon-derived-values), [§1.7.8 v1 freeze](#178-reference-instantiation-status-final-for-v1)) network conformance requires reproducing the reference circuit **exactly**; a different gadget yields a different digest and is a different network. **Half-aggregation** — the **NISSHAC** scheme defined normatively in [§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative) ([§3.3](#33-half-aggregation)) — is a separate, **out-of-circuit** operation: a publisher folds the `m` on-chain nullifier signatures into one multi-scalar relation `s_agg·G == Σⱼ aⱼ·(Rⱼ + eⱼ·Pkⱼ)` (the `AggregateVerify` relation of [§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative)) that every **scanner** checks against the chain (§3.6) — it is not part of the ZK circuit at all, so it imposes no in-circuit cost and remains an on-chain-space optimisation. The commitment-opening relation `CommVerify` (§1.7.10) is likewise host-side, run by a receiver ([§2.3.3 step 4](#233-receive)).

**SHA-256, in-circuit.** SHA-256 (`H`, §1.1) appears in-circuit in these places: (a) **inside the BIP-340 verification itself** — BIP-340 uses tagged SHA-256 for its challenge `e = H_BIP340(R ‖ Pk ‖ m_state)` (§1.1), so the in-circuit transition-signature check computes a tagged-SHA-256 once per transition; (b) the **sign-to-contract opening** `t = H(bytes(R') ‖ H(ProofData))` ([§2.1 clause 2](#21-the-compliance-predicate), [§3.2](#32-transition-signing-bip-340--sign-to-contract)) — one `H(ProofData)` over the 192-byte `serialize(ProofData)` ([§1.4](#14-identifiers-and-hashes)) plus the tweak hash, once per transition; (b2) the **foreign-nullifier S2C openings** — clause 1(ii)'s predecessor leaf binding `R_prev == R'_prev + H(bytes(R'_prev) ‖ H(prev_proof.ProofData))·G` (one instance per `AccountUpdateProof`) and clause 10(d)'s creating-nullifier binding (one instance per active `received_coins[]` slot, ≤ `MAX_RX_COINS`) — each instance is one SHA-256 tweak hash plus one secp256k1 point multiplication/addition in the foreign-field gadget ([§2.1](#21-the-compliance-predicate)); (c) the mint-path binding `H(creator_pubkey ‖ nk_commit) == owner` ([§2.1 clause 3(b)](#21-the-compliance-predicate), [§6.5](#65-issuance--token-standards)) — one SHA-256 per mint; and (d) the genesis owner-binding `H(txn_pubkey ‖ nk_commit) == owner` ([§2.1 clause 1](#21-the-compliance-predicate), InitialProof branch) — one SHA-256 per account at genesis; and (e) the **rotated-key commitment** `npk_commit = H("zkCoins/v1/NpkCommit" ‖ next_pubkey ‖ npk_rand)` ([§2.1 clause 2](#21-the-compliance-predicate)) — one SHA-256 over a 64-byte-plus-tag preimage per transition, the wallet-verifiable rotation binding. This binding forces two genesis forks to the identical `nf`/`nk`, but genesis-fork equivocation **itself** is closed by the on-chain `Pk₀` **first-occurrence** ([§2.1 clause 1](#21-the-compliance-predicate), [§3.10](#310-transaction-states)), not by the hash binding alone (§1.4) — the first successor's predecessor-check binds `Pk_prev == Pk₀` (the genesis proof's exposed `consumed_pubkey`, [§2.1 clause 1](#21-the-compliance-predicate) (iii) / clause 9), so a fresh-key genesis nullifier cannot escape it. For a **mint** InitialProof this coincides with (c) (`txn_pubkey = creator_pubkey = Pk₀`); for a **non-mint** InitialProof (an account that receives before it ever mints — the common case) it is a **standalone** check, so an implementer **MUST NOT** optimise it away with (c). The reference instantiation uses a standard Plonky2 SHA-256 gadget; (a), (b), and (e) run once per transition, the second-largest cost after the foreign-field EC arithmetic. **Every other hash in the protocol is Poseidon** (`Hc`), which is field-native and cheap; SHA-256-in-circuit is confined to these signature/identity checks where Bitcoin-key compatibility (§1.1) requires it. (ECDH, NIP-44, and `K_tx`/`detect_tag` derivation are **host-side** in the node, never in-circuit — [§1.3](#13-per-coin-keys-note-encryption--detection), §4 — so they impose no circuit cost.)

**Wide-integer balance arithmetic (multi-limb).** `amount` is a `u128` (§1.7.3), which the Goldilocks base field (`p ≈ 2^64`, §1.1) cannot hold in a single element, so amounts are carried in-circuit as fixed multi-limb integers. The per-asset conservation of [§2.1 clause 3](#21-the-compliance-predicate) accumulates `In(a)`, `Out(a)`, and `Mint(a)` over up to `MAX_TX_INPUTS`/`MAX_TX_OUTPUTS` terms (§2.5), so those sums and the `In(a) + Mint(a) ≥ Out(a)` comparison are computed by **wide multi-limb integer gadgets** over a fixed width of at least `128 + ⌈log₂ max(MAX_TX_INPUTS + 1, MAX_TX_OUTPUTS)⌉` bits (132 bits at the v1 bounds), with each limb range-checked and carries propagated so no term or partial sum wraps. The *relation* (exact non-negative-integer accumulation and an exact `≥` comparison) is fixed normatively; the *gadget* is the reference implementation's design-time choice, frozen with the digest pin — the same discipline as the two operations above. This arithmetic is cheap next to the foreign-field Schnorr and SHA-256 (a handful of range-checked limb additions per transition), but it is normative: a field-native or `u128`-modular sum would let conservation be satisfied by a **wrapped** total, creating spendable value from nothing, and is non-conforming ([§2.1 clause 3](#21-the-compliance-predicate)).

**Cost, feasibility, and build-report measurements (normative note).** The foreign-field Schnorr verification and the in-circuit SHA-256 dominate `C` proving time; the recursion overhead (§1.7.9), the Poseidon SMT updates, the conditional-NAV prefix/membership gadgets ([§2.1 clause 1, clause 10](#21-the-compliance-predicate)), and the multi-limb balance arithmetic are comparatively cheap. Each active `received_coins[]` slot ([§2.1 clause 10](#21-the-compliance-predicate)) adds one cyclic proof verification (recursion-overhead class) plus cheap Poseidon paths (conditional-NAV prefix + membership); `MAX_RX_COINS` (§2.5) bounds that cost. The clause 1 **predecessor-nullifier check** ([§2.1 clause 1](#21-the-compliance-predicate)) adds, per `AccountUpdateProof`, **one** conditional-NAV membership gadget (the leaf/S2C check (ii); an **RFC-6962 inclusion path of `≤ H_MAX = 64` Poseidon hashes** over the [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log) log, plus the per-hop **consistency proof of `≤ 2·H_MAX`** hashes, [§2.5](#25-circuit-dimensioning-normative), [§3.7](#37-the-nullifier-accumulator)) — a cheap Poseidon path in the same class as clause 10(d)'s — **plus** the consumed-key binding (iii), which is a single in-circuit **equality** comparing the witnessed `Pk_prev` to `prev_proof.consumed_pubkey` (an exposed public output), **not** a new gadget; clause 10(d) adds the symmetric equality per received coin, and exposing `consumed_pubkey` adds only a handful of public-input elements ([§2.5](#25-circuit-dimensioning-normative)), not proving work. The clause-1(ii)/10(d) S2C openings add up to `1 + MAX_RX_COINS` foreign-field tweak verifications per proof (item (b2) above) — they are part of the pinned circuit shape. The membership gadget's exact contribution at the §2.5 bounds is **not yet quantified**; the reference implementation measures it and records it in the build report ([Implementation Mandate §4](/implementation-mandate)), and it does **not** move the in-circuit/out-of-circuit boundary. Concrete gate counts and proving times at the §2.5 bounds (`MAX_TX_INPUTS/OUTPUTS = 8`, `MAX_RX_COINS = 4`) **MUST** be measured by the reference implementation and recorded in its build report ([Implementation Mandate §4](/implementation-mandate)); the in-circuit/out-of-circuit boundary fixed here is final for v1 ([§1.7.8](#178-reference-instantiation-status-final-for-v1)). Should foreign-field Schnorr prove impractical at these bounds, the resolution is a **version bump** (e.g. a Goldilocks-native signature scheme) — never a silent change; v1 fixes secp256k1/BIP-340 because address and key compatibility with Bitcoin ([Requirement 1](/requirements), §1.1) is a hard protocol requirement.

### Reading guide

- On-chain nullifier construction, transition signing, half-aggregation, chain scanning, and the global nullifier accumulator: [On-chain Layer](#3--on-chain-layer).
- `CoinProof` delivery, paired-relay transport, note discovery, and recovery/data-availability: [Transport & Recovery](#4--transport--recovery).
- Viewing keys, view grants, and the public/authorised explorer: [Access & Explorer](#5--access--explorer).
- Node/wallet/explorer components, portability, and the open-mint issuance terms: [System Architecture](#6--system-architecture).



## 3 · On-chain Layer

> *In one sentence: the per-transition object zkCoins writes to Bitcoin (a half-aggregated nullifier), how a publisher aggregates many of them into one inscription, and how every node rebuilds the global nullifier accumulator by first-occurrence from the chain alone.*

This page specifies the Bitcoin-facing layer of zkCoins: how a transition's on-chain **nullifier** ([Foundations §1.4](#14-identifiers-and-hashes)) is signed and embedded, how many nullifiers are half-aggregated and inscribed together, how any node rebuilds the global **nullifier accumulator** from the chain by first-occurrence ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure)), and how that accumulator provides trustless double-spend protection. It introduces **no** change to Bitcoin consensus and **no** native token ([Requirement 1](/requirements)).

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) are used per RFC 2119. All primitives, identifiers, and domain-separation tags are those defined in [Foundations](#1--foundations-normative) and are used unchanged.

### 3.1 The on-chain object

The **only** object zkCoins writes to Bitcoin is the transition **nullifier** — the account-state nullifier of one state-advancing transition (send, receive, or mint), published on-chain so every node can rebuild the global double-spend set from Bitcoin alone. A nullifier is the pair:

```
Nullifier = {
  public_key : Pkᵢ                    // 32 bytes, BIP-340 x-only — the transition's account-state
                                       //   nullifier public key (= current_pubkey, rotated per transition, §1.2)
  R          : nonce point            // 32 bytes, x-only — the sign-to-contract commitment to the
                                       //   transition's validity proof H(ProofData) (§3.2)
}                                      // 64 bytes per transition on-chain (before aggregation)
```

Each state-advancing transition nullifies the account state it consumes: `Pkᵢ` is that state's `current_pubkey` (a fresh rotating key, §1.2), and the sign-to-contract nonce `R` **commits** the transition's off-chain validity-proof digest `H(ProofData)` (§3.2). The transition's spent-nullifier root `inr`, its output-coins root `ocr`, and its rotated spend authority are all folded into `ProofData` (§1.4, §2.1 clause 9), so `R` binds the whole transition **without** any of those values appearing on Bitcoin. A nullifier reveals no amount, asset, sender, or receiver, and its rotating `Pkᵢ` ties it to no account ([Requirement 2](/requirements)). Only the pair `(Pkᵢ, R)` is inscribed; the **message** the signature covers is the **per-network fixed** protocol constant `m_state` (`"zkCoins/v1/StateUpdate/mainnet"` \| `"…/testnet"` \| `"…/regtest"`, [§1.4](#14-identifiers-and-hashes), [§3.2](#32-transition-signing-bip-340--sign-to-contract)), so a scanner needs nothing off-chain to verify the signature and fold the nullifier — it uses the per-network fixed constant `m_state` for the network the scanner operates on.

**Per-transition, keyed by `Pkᵢ`.** Following the account model of *Shielded CSV*, a transition nullifies its **account state** once, regardless of how many coins it spends — there is **exactly one** `(Pkᵢ, R)` per state-advancing transition, not one per input coin. This is what makes the on-chain footprint per transition constant (~64 bytes half-aggregated, [§3.5](#35-inscription-format)) and independent of the input count. The per-coin `nf = Hc("Nullifier", nk ‖ coin.identifier)` and the `input_nullifiers_root` remain the **in-circuit** per-account bookkeeping ([§2.1 clause 4](#21-the-compliance-predicate)); they never appear on Bitcoin.

The proof that a nullifier corresponds to a valid state transition is **off-chain** ([Proofs & State Transitions](#2--proofs--state-transitions)) and travels to the recipient in the `CoinProof` bundle ([Foundations §1.5](#15-core-data-structures)); Bitcoin attests only that the nullifier was **published** and **ordered**. The published `(Pkᵢ, R)` pairs — half-aggregated with their shared scalar `s_agg` into one inscription, the **`AggregateStateNullifierV3`** object ([§3.3](#33-half-aggregation), [§3.5](#35-inscription-format)) whose per-member unit is the pair `(Pkᵢ, Rᵢ)` — are exactly what every node folds into the global nullifier accumulator by first-occurrence (§3.6) — so the one global structure zkCoins relies on is rebuilt from the chain alone (given the pinned network parameters, §3.6), with no off-chain data and no trust in any publisher.

### 3.2 Transition signing (BIP-340 + sign-to-contract)

Every state-advancing transition is authorised by **one** BIP-340 Schnorr signature by the account's current spend key `skᵢ` ([Foundations §1.2](#12-key-hierarchy)). To keep the on-chain footprint at ~64 bytes, the signature covers the **per-network fixed** protocol-constant message `m_state` (`"zkCoins/v1/StateUpdate/mainnet"` \| `"zkCoins/v1/StateUpdate/testnet"` \| `"zkCoins/v1/StateUpdate/regtest"`, [§1.4](#14-identifiers-and-hashes)) and carries the transition's binding **in its nonce** via **sign-to-contract**, so no per-transition message ever reaches Bitcoin. The per-network constant is what closes on-chain cross-network replay of a raw `(Pk, R, s)`; the public-input `network_id` binds only the off-chain proof ([§2.1 clause 9](#21-the-compliance-predicate)).

Let `H(ProofData) = SHA-256(serialize(ProofData))` be the 32-byte digest of the transition's **off-chain** validity-proof public inputs (`H` = SHA-256, [Foundations §1.1, §1.4](#14-identifiers-and-hashes)). Because `ProofData` is **not** on-chain, committing it in the nonce is a real, non-redundant binding. The signer MUST construct the nonce as:

```
1. R'  = k'·G                          // k' a fresh BIP-340 nonce scalar
1b. if y(R') is odd: k' ← n − k'       // normalise R' to even-y, so bytes(R') (x-only) lifts back
                                       //   to the exact point the verifier reconstructs
2. t   = H( bytes(R') ‖ H(ProofData) ) // sign-to-contract tweak, SHA-256, 32 bytes, big-endian int
3. R   = R' + t·G                      // committed nonce point
3b. if int(t) ≥ n, or R = ∞, or y(R) is odd:
                                       //   discard k' and redraw a fresh nonce (restart at step 1)
4. e   = H_BIP340( bytes(R) ‖ bytes(Pkᵢ) ‖ m_state )   // BIP-340 challenge over the per-network FIXED message
5. s   = (k' + t + e·skᵢ) mod n        // n = secp256k1 group order; skᵢ BIP-340-normalised (even-y key)
6. signature = bytes(R) ‖ bytes(s)     // 64 bytes; the on-chain nullifier keeps only (Pkᵢ, R), §3.3
```

**Why steps 1b/3b are required (normative).** BIP-340 verification and the `CommVerify` opening ([§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative)) reconstruct points from **x-only** encodings by lifting to the **even-y** candidate. Without step 1b, a signer whose `R'` has odd y would produce an `s` that no verifier can open (`lift_x(bytes(R'))` is a different point); without the step-3b redraw, roughly half of all signing attempts would yield an odd-y `R` whose signature fails plain BIP-340 verification. The redraw terminates in an expected ~2 attempts. Nonce choice is signer-private and never consensus-relevant, so any fresh-nonce redraw strategy conforms; the [V.8](#v8-signing--half-aggregation-fixture-synthetic-fully-pinned) fixture pins one deterministic counter-based strategy solely so the vector is reproducible.

The signature is an ordinary, standalone BIP-340 signature: any scanner checks `s·G == R + e·Pkᵢ` from the on-chain `(Pkᵢ, R)`, the shared aggregate scalar (§3.3), and the **per-network fixed constant** `m_state` for the network the scanner operates on — with no knowledge of `t` and no off-chain data. A **receiver** who holds the `CoinProof` bundle — hence `ProofData` (so it can compute `H(ProofData)`) and the pre-tweak nonce `R'` — additionally recomputes `t = H(bytes(R') ‖ H(ProofData))` and confirms `R = R' + t·G`, proving the on-chain nullifier commits to **exactly that** off-chain transition ([§2.3.3 step 4](#233-receive)). The signer MUST follow BIP-340 nonce hygiene (deterministic-plus-auxiliary-randomness derivation of `k'`) and MUST NOT reuse a nonce across two distinct commitments. `Pkᵢ` MUST be the x-only `current_pubkey` under which the spend is authorised; reusing `Pk₀` for a non-initial spend is forbidden (keys rotate per transition, [Foundations §1.2](#12-key-hierarchy)).

**Why the on-chain object carries this signature (normative).** A bare nullifier public key would let anyone who obtains it post a nullifier on someone else's behalf. The BIP-340 signature under `Pkᵢ` proves the poster knows `skᵢ`, so **only the account owner can occupy its own nullifier-key slot** in the accumulator — a scanner folds `(Pkᵢ, R)` **only** if the signature verifies (§3.6). This is the account-model equivalent of *Shielded CSV*'s nullifier signature; a hash-only nullifier is forgeable and is insufficient. The same signature check runs **in-circuit** for every transition ([§2.1 clause 2](#21-the-compliance-predicate)) — including a pure receive, which likewise publishes its own on-chain state nullifier ([§2.3.3](#233-receive), [§3.10](#310-transaction-states)) — so the rotated spend key is bound by custody on every state-advancing transition.

### 3.3 Half-aggregation

Many independent transition signatures are compressed into one **half-aggregate** before inscription. This is the **NISSHAC** scheme (Non-Interactive Signature Half-Aggregation with Commitments) of *Shielded CSV*; its algorithms (`AggregateSig`/`AggregateVerify`/`CommRetrieve`/`CommVerify`) and both the half-aggregate and the commitment-opening relations are defined normatively in [§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative), and the on-chain object it produces is the **`AggregateStateNullifierV3`** (§3.1). The derivation below is that scheme's concrete instantiation. Half-aggregation is **non-interactive**: it requires no coordination among signers and no secret keys — a publisher (§3.4) performs it on signatures it has merely collected. Each nullifier public key `Pkⱼ` and its sign-to-contract nonce `Rⱼ` are retained; only the per-signature scalar `sⱼ` is aggregated.

Given transitions `1 … m` with signatures `(Rⱼ, sⱼ)`, keys `Pkⱼ`, over the shared **per-network fixed** message `m_state` (the constant for the network this batch is published on):

```
1. For each j:  eⱼ = H_BIP340( bytes(Rⱼ) ‖ bytes(Pkⱼ) ‖ m_state )
2. Derive aggregation coefficients:
      z  = H( "zkCoins/v1/HalfAgg" ‖ bytes(R₁) ‖ Pk₁ ‖ … ‖ bytes(R_m) ‖ Pk_m )
      aⱼ = H( z ‖ u32-be(j) )  mod n         // distinct per index, binds the whole batch
3. s_agg = Σⱼ ( aⱼ · sⱼ )  mod n             // single 32-byte aggregate scalar
4. AggregateNullifier = ( (Pk₁,R₁) … (Pk_m,R_m) , s_agg )    // m pairs (64B each) + one s_agg (32B)
```

The aggregate verifies with a single multi-scalar check:

```
s_agg·G  ==  Σⱼ aⱼ·( Rⱼ + eⱼ·Pkⱼ )
```

This replaces `m` independent `s` values (32 bytes each) with one, while each `(Pkⱼ, Rⱼ)` is retained — and each `Rⱼ` remains the sign-to-contract commitment to its transition's off-chain proof (§3.2). Because the signed message is the **per-network fixed constant** `m_state` for the network the scanner operates on, a scanner recomputes every `eⱼ` from pure on-chain data alone and needs no per-transition message. The coefficients `aⱼ` MUST be derived as above so the batch is non-malleable: a verifier MUST reject an aggregate whose multi-scalar check fails, and MUST treat every constituent nullifier of a failing aggregate as **unpublished** (§3.6). The blockchain space to nullify `m` transitions is therefore `m` public keys, `m` nonces, and one shared scalar plus a constant header — approaching **64 bytes per transition** for a 256-bit curve, independent of each transition's input count (*Shielded CSV*, Table 1).

A publisher (§3.4) MAY also inscribe a single nullifier **without** aggregation (`m = 1`, the raw pair `(Pkᵢ, Rᵢ)` plus its own `sᵢ`) — the wallet's own node self-publishing one of its transitions ([§3.4](#34-the-publisher)) does exactly this at trivial cost. The half-aggregate and the raw single-member forms fold to the identical accumulator entry.

### 3.4 The publisher

A **publisher** is the permissionless agent that moves nullifiers from off-chain to Bitcoin. Its mapping is **many-to-one**: it collects transition nullifiers from many distinct zkCoins transitions — typically from many users — half-aggregates their signatures (§3.3), and inscribes them **together in a single Bitcoin transaction**.

- Running a publisher MUST be permissionless; any participant MAY run one, and a wallet's own node MAY act as its publisher.
- A publisher MUST NOT be trusted for **correctness**: it cannot forge, alter, reorder-to-steal, or drop-without-detection any nullifier, because (a) each signature is verified by every scanning node (§3.6), and (b) the value-bearing proof and coin plaintext travel off-chain ([Transport & Recovery](#4--transport--recovery)), never through the publisher.
- A publisher MUST NOT be trusted for **custody**: it never holds a spend key and never holds any customer coin or proof — in v1 it receives no coin or proof at all, only the nullifier hand-off; under the deferred fee mechanism the one object it would receive is its **own fee coin's** `CoinProof` ([§3.8.1](#381-fee-coin-mechanism-deferred), [§7.6](#76-publisher-interface-normative)); the worst a faulty or malicious publisher can do is **censor** (refuse to inscribe) or **delay** — both mitigated because anyone else can publish the same nullifier, and the censored spender can submit to a different publisher.
- **Contention-free self-publish (normative).** A nullifier references **no shared global state** — no accumulator root, no other transition — so **any** node can inscribe its own transitions independently, at any time, with no ordering slot to win and no risk of going stale ([Requirement: every node publishes its own transactions without competitive pressure](/requirements)). There is no single sequential writer: two publishers inscribing in the same block never conflict, because each nullifier is folded into the accumulator by first-occurrence on its own key `Pkⱼ` (§3.6). Redundant publication is idempotent — a scanner folds each unique `Pkⱼ` once, and a second inscription of an already-folded `Pkⱼ` is a no-op (§3.6).
- A publisher SHOULD batch over a bounded interval (e.g. once per Bitcoin block) and SHOULD half-aggregate (§3.3) to minimise per-transition cost. Larger aggregates amortise the constant per-inscription header more aggressively (§3.8), but the marginal per-transition footprint is already ~64 bytes and never depends on shared state.

A publisher is only marginally heavier than a plain broadcaster: it half-aggregates collected signatures (§3.3, no secret keys, cheap) and broadcasts one inscription. It holds **no** recursive proof, **no** off-chain bundle, and **no** consensus-critical data — every value-bearing artefact travels sender→receiver off-chain, never through the publisher. A publisher's "right to publish" rests entirely on its ability to reach the bitcoind-broadcast surface; it need not prove anything.

### 3.5 Inscription format

Nullifiers are carried in a Taproot **commit/reveal** inscription. The commit transaction pays to a Taproot output whose internal key is tweaked by a script-path leaf; the reveal transaction spends it via **script path**, exposing the executed Tapscript leaf. The payload of one inscription is the **`AggregateStateNullifierV3`** object ([§3.1](#31-the-on-chain-object), [§3.3](#33-half-aggregation)): the half-aggregated set of per-transition pairs `(Pkⱼ, Rⱼ)` plus the single shared scalar `s_agg`, framed by the header below. Scanners **MUST** extract zkCoins payload bytes **exclusively** from the **actually executed** Tapscript leaf of each script-path input, under the envelope grammar below — never from an unexecuted leaf, a key-path spend, or annex bytes.

**Taproot envelope grammar (normative).** For each reveal input that carries a zkCoins inscription, the **executed** Tapscript leaf **MUST** contain exactly one envelope construct of the form:

```
OP_FALSE OP_IF
  <push chunk_0> <push chunk_1> … <push chunk_{n-1}>
OP_ENDIF
```

so the data is dropped by Bitcoin script evaluation and costs only witness weight. The **payload byte string** is the **bytewise concatenation** of the pushed data chunks `chunk_0 ‖ chunk_1 ‖ … ‖ chunk_{n-1}` in script order. That concatenated string **MUST** begin with the fixed 2-byte **marker prefix** `0x42 0x42` (`"BB"`) — the payload marker that identifies the envelope as a zkCoins inscription and lets scanners skip all other inscriptions cheaply. Concatenation starts at the first push of the envelope; there is no length prefix or delimiter between chunks.

**Push encoding (normative).** Every data push inside the envelope **MUST** use a **minimal push opcode** (BIP-62 / Bitcoin consensus minimal-push discipline): the shortest legal encoding for that length. Each individual push **MUST** be at most **520 bytes** (Bitcoin's script data-push limit). A non-minimal push, a push larger than 520 bytes, or any other non-data opcode **inside** the `OP_FALSE OP_IF … OP_ENDIF` body makes the envelope **malformed** for that input.

**Witness stack (normative, script-path).** A conforming reveal input's witness stack for the script-path spend is, in BIP-341 stack order (last element is stack top before script execution):

```
  <optional script-required stack elements>
  <tapscript>                 // the executed leaf script containing the envelope
  <control block>             // BIP-341 control block
  <optional annex>            // if present: first byte MUST be 0x50 (BIP-341)
```

**Annex treatment (normative).** If a Taproot annex is present (BIP-341, leading byte `0x50`), scanners **MUST** ignore it for payload extraction: annex bytes are **never** part of the envelope, never concatenated into the payload, and never searched for the `0x42 0x42` marker. An annex that is present but does not begin with `0x50` is invalid under BIP-341 and the input is not a valid Taproot script-path spend.

**One envelope per script-path input (normative).** Each script-path input of a reveal transaction **MUST** carry **strictly at most one** zkCoins envelope (exactly one `OP_FALSE OP_IF … OP_ENDIF` body whose concatenated pushes begin with `0x42 0x42`). A second (or further) marker envelope — a second envelope whose concatenated push bytes also begin with `0x42 0x42` — in the **same** executed leaf, or any second distinct `0x42 0x42`-prefixed envelope construct in that input's executed leaf, makes **that whole input** **nullifier-empty / malformed**: the scanner **MUST** treat the input as carrying **zero** valid nullifiers. Other inputs of the **same** reveal transaction remain independent and are evaluated under this rule on their own. An input with no marker envelope contributes no nullifier. A payload larger than what one input's envelope can carry **MUST** be split across multiple reveal inputs and/or transactions, each with its own single marker envelope and full header (§3.5 body layout).

Every zkCoins payload MUST begin with the fixed 2-byte **marker prefix** `0x42 0x42` (`"BB"`). The payload layout is:

```
offset  size  field
------  ----  -----------------------------------------------------------
  0       2   marker                    = 0x42 0x42                   (zkCoins prefix)
  2       1   version                   = 0x03                        (half-aggregated nullifier payload;
                                                                       0x01/0x02 are retired earlier-draft
                                                                       payloads and MUST be rejected)
  3       1   format                    0x00 = raw single nullifier
                                        0x01 = half-aggregated (§3.3)
  4       2   count m                   big-endian u16, number of nullifiers
  6      32   block_anchor.block_hash   Bitcoin block hash of the tip this batch is anchored to (§3.9)
 38       4   block_anchor.height       big-endian u32, height of that block (§3.9); cross-checked on acceptance
 42       …   body                      m nullifiers, depends on `format` (below)

format 0x00 — raw, one nullifier:
   32      Pkᵢ          (x-only)
   32      Rᵢ           (x-only sign-to-contract nonce, §3.2)
   32      sᵢ           (BIP-340 scalar)

format 0x01 — half-aggregated, m nullifiers then one shared scalar:
   per nullifier j:
      32      Pkⱼ       (x-only)
      32      Rⱼ        (x-only sign-to-contract nonce, §3.2)
   32      s_agg     (single shared aggregate scalar, §3.3 — appended once, after all m pairs)
```

The inscription carries **no** transition message, **no** per-coin nullifier list, and **no** global accumulator root — only the `(Pkⱼ, Rⱼ)` pairs and the aggregate scalar. The double-spend state is therefore not *asserted* by a root the publisher chose — it is *rebuilt* by every node directly from the published nullifiers by first-occurrence (§3.6), so no off-chain data and no trust in the publisher is involved. The signed message is the **per-network fixed constant** `m_state` (§3.2) for the network the scanner operates on, so a scanner verifies every signature from on-chain data alone.

The `block_anchor` is the pair `{ block_hash, height }` identifying the tip the batch's proofs were built against — the freshness anchor for the whole batch. Members are built independently and MAY each have been proved against a slightly different recent tip; the publisher chooses one `block_anchor` that **MUST be an ancestor of, or equal to, the oldest member's own build tip** and MUST satisfy the bound below against the inclusion block. An issuance validity-window height check ([System Architecture §6.5](#65-issuance--token-standards)) would be evaluated **in-circuit against the issuing member's own proof-time height** carried in that member's per-account proof — not against the batch `block_anchor`; v1 imposes no issuance window ([§6.5](#65-issuance--token-standards)), so `block_anchor` serves only the freshness/gap bound. A scanner cross-checks on acceptance that `block_anchor.block_hash` is at `block_anchor.height` in its own Bitcoin chain view.

**`block_anchor` bound (normative).** Let `inclusion_height` be the height of the Bitcoin block that includes this batch's reveal transaction. A scanner MUST reject the batch unless **both**: (1) `block_anchor.height` is strictly less than `inclusion_height` and `block_anchor.block_hash` is a strict ancestor of the inclusion block (the anchor MUST NOT be the inclusion block itself, a forward block, or off the inclusion block's chain), and (2) the gap is bounded by `N = 100` blocks: `inclusion_height − block_anchor.height ≤ 100`. The first condition rejects forward anchoring; the second rejects stale anchoring. A batch whose `block_anchor` is not a strict ancestor of its inclusion block, or whose gap exceeds `N = 100`, MUST be treated as carrying **zero** valid nullifiers.

> Note on sizes. The fixed payload header is `2+1+1+2+32+4 = 42` bytes (marker, version, format, count, `block_anchor.block_hash`, `block_anchor.height`), amortised across the whole batch. A raw nullifier (`format 0x00`) adds `96` bytes of body (`Pkᵢ ‖ Rᵢ ‖ sᵢ`); the half-aggregated form (`format 0x01`) drops the per-nullifier `s` and shares one 32-byte `s_agg`, so the marginal cost of an additional nullifier falls to **64 bytes** (`Pkⱼ ‖ Rⱼ`). By Bitcoin's 1/4 witness-weighting that is **~16 vBytes per transition** (~$0.16 at 10 sat/vB and BTC at $100 000), plus the amortised commit + reveal overhead; a payload larger than the standardness limit MUST be split across multiple reveal inputs/transactions, each carrying **exactly one** marker envelope and its own header (one-envelope-per-input rule above). For reference, a realistic Bitcoin SegWit payment (1-in / 2-out P2WPKH) is ~140 vBytes, so the per-transition footprint is roughly an order of magnitude smaller — and, unlike the paper's per-transaction on-chain nullifier, it stays ~64 bytes regardless of how many coins the transition spends (one account-state nullifier per transition, §3.1). The per-block ceiling is therefore on the order of **~100 transitions per second** at Bitcoin's block-space budget — the *Shielded CSV* throughput envelope, block-space-bound rather than gated by any single writer.

Because nullifiers are fixed-length, a scanner MUST parse the body sequentially: read exactly `m` records by consuming `Pkⱼ`, then `Rⱼ`, then (`format 0x00`) `sⱼ`; for `format 0x01` a single 32-byte `s_agg` follows the last pair. The parse MUST consume the body **exactly**: a payload that ends mid-record, declares a `count` that overruns the body, or leaves trailing bytes (other than the `s_agg` of `format 0x01`) is malformed. The §3.6 structural check (step 2) verifies that exactly `count == m` nullifiers parse with no bytes left over; a scanner MUST reject a malformed or truncated payload as carrying **zero** valid nullifiers. The same applies to the header itself: a payload whose `version` byte is not `0x03` or whose `format` byte is not `0x00`/`0x01` is **malformed** and carries **zero** valid nullifiers — there is no dispatch branch for unknown values (fail-closed). For `format 0x00` the header's `count` MUST equal `1`; any other value is malformed (zero valid nullifiers).

**Metadata (normative note).** A zkCoins inscription reveals the number of transition nullifiers in the batch (its `count m`), the publisher's Bitcoin identity (the reveal transaction's own key — a publisher who values privacy MAY use a fresh key per batch), and the anchoring Bitcoin tip — nothing more. Because a transition nullifies its **account state once**, the on-chain `count` is the per-block *transaction* count, **not** an input count: how many coins each transition spent, and every amount, asset, party, and the transaction graph, remain hidden, so [Requirement 2](/requirements) holds for all of them. That the per-block transaction count becomes public is the deliberate, bounded price of a chain-rebuildable nullifier set (§3.6–§3.7) — the same disclosure *Shielded CSV* accepts; a wallet that wants to blunt it MAY spread its transitions across blocks, at no protocol-level requirement. The rotating `Pkⱼ` is fresh per transition, so two of an account's on-chain nullifiers are unlinkable, and the rotation edge `Pkᵢ → Pkᵢ₊₁` never appears on Bitcoin (the successor key lives only inside the account's off-chain, hashed `AccountState`, §1.4/§2.1).

### 3.6 Chain scanning

Any node rebuilds the global **nullifier accumulator** from Bitcoin alone, trusting no peer ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure), [Requirement 3](/requirements)). For each new Bitcoin block, in canonical order, a node MUST:

1. **Discover.** Beginning at the network's pinned **`activation_height`** (the consensus-critical first Bitcoin block height at which zkCoins nullifiers are recognised — see *Scan origin* below), identify reveal transactions and, within each, each script-path input whose **executed** Tapscript leaf contains a zkCoins envelope under the §3.5 grammar (concatenated pushes beginning with the marker `0x42 0x42`). Scanners evaluate **only** that executed leaf per the envelope grammar — never unexecuted leaves, key-path spends, or annex bytes (§3.5). Any inscription in a block **below `activation_height`**, every non-marker inscription, and every input that is nullifier-empty/malformed under the one-envelope rule (§3.5) is ignored and contributes no nullifier.
2. **Parse and bound-check.** From each surviving input's single envelope, decode header and body sequentially (§3.5). Reject any payload failing the structural checks of §3.5, and reject any inscription violating the §3.5 `block_anchor` bound (strict ancestor of the inclusion block; gap ≤ `N = 100`).
3. **Verify signatures.** For `format 0x00`, verify the BIP-340 signature `(Rᵢ, sᵢ)` against `(Pkᵢ, m_state)` (§3.2), where `m_state` is the **per-network fixed constant** for the network the scanner operates on. For `format 0x01`, verify the single multi-scalar aggregate check of §3.3 against the `m` pairs and that same per-network fixed message `m_state`. A nullifier whose signature does not verify (or whose aggregate check fails, discarding the whole aggregate) MUST be treated as unpublished.
4. **Order.** Establish the consensus **total order** over surviving nullifiers, **exactly** the 4-tuple `(height, tx_index, vin_index, payload_member_index)`:
   - `height` — Bitcoin block height of the reveal transaction's inclusion block;
   - `tx_index` — index of the reveal transaction within that block;
   - `vin_index` — index of the reveal input within that transaction (the script-path input whose executed leaf carried this envelope);
   - `payload_member_index` — the nullifier's 0-based position `j` within that input's payload body (`j ∈ [0, m)`).
   The `vin_index` component is the tertiary key that orders multiple reveal inputs of one transaction before any in-payload member order; two envelopes in different inputs of the same transaction are therefore totally ordered by input index. This order is a deterministic function of the public chain, so every node processes nullifiers in the same sequence.
5. **Fold by first occurrence (first-spend-wins).** In that order, for each nullifier, **append** the entry `(Pkⱼ, Rⱼ)` to the global nullifier-accumulator log ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure)) as the next position-bound leaf `Hc("NfLog/Leaf", p ‖ Pkⱼ ‖ Rⱼ)` (`Rⱼ` its sign-to-contract commitment) **if `Pkⱼ` is not already present**. If `Pkⱼ` **is** already present, this nullifier is a **fork or double-spend attempt** — a second state-advancing transition on the same account state — and the scanner MUST treat it as **invalid**: its `Rⱼ` is not stored, and any transition or output that opens against it is treated as never anchored. The **first** on-chain occurrence of `Pkⱼ`, in this canonical order, is the one and only valid transition on that account state.

Because steps 1–5 are a pure function of confirmed Bitcoin data **from the pinned `activation_height` onward** (§3.6 Scan origin), two honest nodes scanning the same chain MUST arrive at the **identical** nullifier accumulator — no node-supplied root, and no off-chain data, is ever consulted. A wallet or explorer therefore computes the accumulator itself, or checks any served (non-)membership answer against its own copy, never by trusting the server ([Requirement 4](/requirements), [Requirement 10](/requirements)). This is the property the retired batched design could not offer: with the nullifiers on Bitcoin, admission is objective and availability-independent, so two honest nodes at the same tip can never diverge on the accumulator.

**Scan origin (normative, consensus-critical).** Because the log is **position-bound** (`Hc("NfLog/Leaf", p ‖ Pk ‖ R)`, [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)), the height at which the scan begins is a **consensus parameter**: two nodes that start at different heights fold different first-occurrence sequences and assign **different positions** to the same nullifier, so every inclusion proof, every `prefix` chain, and every `nav` diverges between them. zkCoins therefore pins one **`activation_height` per network** as part of the frozen network parameter set (alongside the network tag and `circuit_digest`, [§1.7.9](#179-proof-system-parameters-normative)): position `0` is the first surviving nullifier in a block at height `≥ activation_height`, and any inscription below it is **not** part of the accumulator. For **mainnet** the `activation_height` is pinned at deployment (the genesis/deployment runbook step) and is identical across all nodes; for **testnet** and **regtest** it is a fixed constant of the network definition. A node **MUST** reject a configured `activation_height` that does not match the pinned network value. **Values (normative).** `regtest` fixes `activation_height = 0` (scan from the regtest genesis; regtest chains are ephemeral). `testnet` (on **Bitcoin Signet**) fixes `activation_height` to **exactly the Signet block height of the testnet's genesis inscription**, observed when the public testnet is stood up (runbook step 7) and published in its network parameter set — the same observed-genesis rule as mainnet. For **mainnet** the operator first broadcasts the network's genesis inscription (runbook step 9); once it confirms, `activation_height` is set to **exactly the Bitcoin block height of the block that carries it** — a unique value the operator **observes** (it is not chosen ahead of time), then publishes in the network parameter set, thereafter **immutable**. The genesis inscription is therefore the **only** zkCoins inscription at `activation_height` with no earlier one possible, so no node can diverge on position 0. Every node **MUST** load the published per-network value and a node whose configured value differs **MUST** refuse to become ready (`/health/ready` stays `503`). This forecloses a pre-deployment-inscription split: an adversary who writes valid `0x42 0x42` payloads before `activation_height` cannot shift any node's positions, because those blocks are below the pinned origin. The **network parameter set** is the pinned tuple `{ network_tag, circuit_digest(C), circuit_digest(C_balance), activation_height, finality_confirmations = 6, bootstrap_pubkey }`, published as a content-addressed `network-params.json` in the deployment and echoed by `GET /v1/info` (§7.5); it is byte-identical across all nodes of a network. **`bootstrap_pubkey`** is the BIP-340 x-only public key (32 bytes) that alone may sign that network's `BootstrapManifestV1` ([§4.3](#43-addressing-for-delivery)); its concrete value is deployment-pinned per network (testnet/regtest fixtures pin their own keys; mainnet pins at genesis). Its **canonical encoding** (what "content-addressed" is over) is the byte string `network_tag_len (u8) ‖ network_tag (UTF-8) ‖ circuit_digest(C) (32B) ‖ circuit_digest(C_balance) (32B) ‖ activation_height (8B big-endian) ‖ finality_confirmations (1B = 0x06) ‖ bootstrap_pubkey (32B x-only)`; the artefact's identifier is `SHA-256` of that byte string, and `GET /v1/info` echoes the same fields. Two nodes agree iff this byte string is identical. **Relation to the "pure function of on-chain data" claim (normative).** `activation_height` is a **pinned, immutable network constant** — a member of the frozen network parameter set alongside the network tag and `circuit_digest` — **not** mutable off-chain state and **not** a peer's claim. The accumulator therefore remains a pure function of the on-chain nullifiers **relative to this pinned parameter set**: a verifier that already holds the network's constants (as it must to verify any proof) reconstructs the identical log from Bitcoin alone. Wherever this document says the accumulator is "rebuilt from Bitcoin alone", read it as "from Bitcoin alone, **given the pinned network parameters**". **Honest caveat (normative):** unlike the network tag and `circuit_digest`, which are **cryptographically bound** into the verifier data — a proof against the wrong network simply fails to verify (§1.7.9) — `activation_height` is **not** a circuit public input; it is enforced only by the node-config equality check and the readiness gate above. Two nodes with identical verifier data but a **different** accepted `activation_height` would verify the same proofs yet fold **different** log positions and `nav`s **whenever the interval between their two `activation_height` values contains at least one admitted first-occurrence nullifier** (with none, the log `(size, mth)` is identical regardless of the origin). The log's canonicity therefore carries a **distinct, weaker parameter-agreement assumption** — that every node loads the same pinned `network-params.json` — which the paper's per-user model does not have. It is registered as a residual of **D-05** and gated by the `network-params.json` byte-exactness plus this readiness check ([Paper-Conformance Remediation](/paper-conformance-remediation)).

The operative double-spend check is **per-transition** (§3.7): a verifier confirms a coin's **creating** transition is anchored by checking that transition's `(Pkᵢ, Rᵢ)` is the first occurrence of `Pkᵢ` in the accumulator it rebuilt from the chain, with `Rᵢ` opening to the creating transition's `H(ProofData)` (§3.2, [§2.3.3 step 4](#233-receive)). There is no global root to fetch and no per-coin membership path needs to travel inside a `CoinProof` bundle, because the verifier holds the whole published nullifier set itself.

### 3.7 The nullifier accumulator

Double-spend protection is enforced **on-chain and trustlessly** by the global **nullifier accumulator** ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure)): an append-only Merkle log ([§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)) over the first-occurrence sequence of `(Pkᵢ, Rᵢ)` — every account-state nullifier public key `Pkᵢ` ([Foundations §1.4](#14-identifiers-and-hashes)) ever **published in an on-chain nullifier**, paired with the transition's sign-to-contract commitment `Rᵢ` ([§3.2](#32-transition-signing-bip-340--sign-to-contract)). It supports both **inclusion** and **log-consistency** proofs as authenticated RFC-6962 objects; a Path-B node may additionally return an **unauthenticated local-index absence answer** (`present: false`) when its `Pk → (pos, R)` index has no entry — that answer is **not** an RFC-6962 non-inclusion proof.

**Insertion.** When a transition advances an account state, its `(Pkᵢ, Rᵢ)` is published on-chain as that transition's nullifier (§3.1, §3.5). Every node folds the published keys into the accumulator in the §3.6 canonical order (step 5, first-occurrence). There is **no** inscribed accumulator root and **no** off-chain attestation of one: the accumulator is a deterministic function of the published nullifiers, so every honest node computes the same one directly from the chain. The **set** of first-occurrence winners is order-independent (idempotent), but the **log** is **order-sensitive**: the canonical chain order (§3.6) fixes each winner's **position**, so a different interleaving of distinct winners yields different leaf preimages `Hc("NfLog/Leaf", p ‖ Pkᵢ ‖ Rᵢ)`, a different `mth`, and a different `nav_root`. The canonical order therefore both decides, between two nullifiers publishing the **same** `Pkᵢ`, which is the valid transition (the earlier) and which the rejected fork or double-spend (the later), **and** assigns every winner its immutable position. Because that order is a deterministic function of confirmed Bitcoin data (from the pinned `activation_height`, §3.6), every honest node at the same tip computes the identical log.

**Anchored value.** A membership answer is meaningful only **relative to a Bitcoin chain tip**: the canonical value is `NAV(tip) = (accumulator, tip_block_hash, tip_height)`. The `block_anchor = { block_hash, height }` field of every inscription (§3.5) records the tip the proof was built against. A verifier MUST evaluate any membership claim **relative to a stated tip**; an answer quoted without its anchoring tip MUST be rejected as ambiguous. (Path-B `present: false` is an unauthenticated index answer, not a tip-anchored non-inclusion proof — see Path B below.) A transition that commits to a **conditional NAV** ([§2.1 clause 1](#21-the-compliance-predicate)) is valid only against a tip whose accumulator still contains all the nullifiers that NAV depends on (reorg safety, §3.9).

**Canonical value (normative).** An accumulator value `(size, mth)` is **canonical** on a verifier's scan **iff** `mth = MTH(D[0:size])` over that verifier's own log rebuilt from Bitcoin (§3.6) — i.e. `(size, mth)` is a true prefix of `NAV(tip)`. Every `nav` (§2.3.2) and every `nav_ceiling` (§5.7) MUST be canonical in this sense. A **creditable** result additionally requires `size ≤ size_final` (§3.9) — the whole covered prefix is ≥6-confirmation-final. Since v1 has no pipelining (§2.3.2 step 5), `nav` is exactly `size_final`, so every authenticated position is `< size_final` and immediately creditable.

**Inclusion and consistency over the accumulator log (normative).** Membership and the `prefix` relation the conditional NAV uses ([§2.1 clause 1, clause 10c](#21-the-compliance-predicate), [§5.7](#57-balance-attestation-history-private)) are the standard **RFC 6962 / RFC 9162** Merkle-log proofs over the [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log) log, instantiated with Poseidon. Notation: `MTH`, the split point `k` (the largest power of two strictly less than the run length), the leaf/node hashes, and the empty root are exactly as [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log).

**Inclusion** (RFC 6962 §2.1.1). `(Pk, R)` is a member at position `p` of an accumulator value `(size, mth)` **iff** `p < size` **and** the audit path `PATH(p, D[0:size])` recomputes `mth` from the leaf `Hc("NfLog/Leaf", p ‖ Pk ‖ R)`, with `p` absorbed as an **8-byte big-endian byte-string** input ([§1.7.2](#172-field-encoding-e-of-hc-inputs) / [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)). `PATH(m, D[0:n])` is: for `n = 1`, the empty list `{}`; for `n > 1`, split at `k`: if `m < k`, `PATH(m, D[0:k]) ‖ MTH(D[k:n])`; else `PATH(m − k, D[k:n]) ‖ MTH(D[0:k])`. Binding `p` into the leaf makes an audit path valid at **exactly one** position — a leaf cannot be replayed at another position.

**Consistency** — the relation `prefix(a, b)` for `a = (m, mth_a)`, `b = (n, mth_b)`, `m ≤ n`, holds **iff** the RFC 6962 §2.1.2 consistency proof `PROOF(m, D[0:n])` recomputes **both** `mth_a` (over the first `m` entries) **and** `mth_b` (over all `n`). `PROOF(m, D[0:n]) = SUBPROOF(m, D[0:n], true)`, where `SUBPROOF(m, D[0:n], b)` is: if `m = n`, the empty list `{}` when `b` is **true**, else the single node `MTH(D[0:n])`; otherwise split at `k` — if `m ≤ k`, `SUBPROOF(m, D[0:k], b) ‖ MTH(D[k:n])`; else `SUBPROOF(m − k, D[k:n], false) ‖ MTH(D[0:k])`. Edge cases: `m = 0` (consistency to the empty log `Hc("NfLog/Empty", 0)`) is the **trivial** witness — the empty log is a prefix of every log (the genesis `prefix(nav_empty, w.nav)` of [§2.1 clause 1](#21-the-compliance-predicate), satisfiable, and **not** a no-op recovery branch, cf. [§3.9](#39-finality-and-reorg-handling)); `m = n` is identity. The proof is at most `2·H_MAX` node hashes ([§2.5](#25-circuit-dimensioning-normative)) and is **independent of `n − m`** — this is what makes the in-circuit prefix **constant-size** ([§2.6](#26-in-circuit-non-native-cryptography-normative)); the retired 256-bit-SMT submap relation was linear in the intervening foreign insertions.

**`SUBPROOF` / consistency witness — not a v1 wire object (normative).** The RFC-6962 consistency / inclusion `SUBPROOF` node-list (and the circuit witnesses that carry it — `nav_consistency`, `creating_nav_consistency`, [§2.1](#21-the-compliance-predicate)) is an **implementation-internal circuit witness**: it is constructed and consumed inside the prover / verifier of `C` and **is not** a v1 public REST, Blossom, Nostr, or kernel-RPC wire object. v1 clients (thin-wallet trusts node, [§6.2](#62-wallet--node)) **do not** verify log-consistency themselves against a remote peer; Path-B surfaces only inclusion (and the unauthenticated absence answer) on `GET /v1/chain/nullifier/<pubkey>` ([§7.5](#75-node-rest-api-normative)). Transporting a consistency `SUBPROOF` across component boundaries as a first-class object would be a separate **v2** wire fix, not part of this specification.

**Why this closes fork-burial (soundness).** A consistency proof forces `mth_a` to commit **exactly** the first `m` leaves of `mth_b`, so any leaf authenticated at a position `p < m` under `a` is the **identical** leaf at `p` under `b`; this composes **transitively** along the recursion's prefix chain up to the top `w.nav`, which the receiver checks **canonical** against its own `NAV(tip)` scan ([§2.3.3 step 2](#233-receive)). Because the first-occurrence fold appends each `Pkᵢ` **at most once**, carrying the **winner** `Rᵢ` ([§3.6](#36-chain-scanning)), a fork loser `(Pkᵢ, R_loser ≠ R_winner)` sits at **no** canonical position; a proof that buries it at a deep internal hop and lifts it to a canonical top is **unsatisfiable** without a Poseidon collision (canonical position `p` would have to equal both the genuine winner leaf and the forged loser leaf). Leaf-preservation is therefore a **theorem** here, not a per-leaf relation to enforce. The consistency recursion's exact behaviour is pinned above and reference-tested at the `2ᵏ−1, 2ᵏ, 2ᵏ+1` size boundaries for **every** `k = 0…63` by the **generated log-boundary suite** of [V.11](#v11-nullifier-accumulator-log-vectors) — exercising split/peak-bagging against **symbolic O(log n) subtree-root fixtures**, not Θ(n) leaf materialisation (the freeze differential-test of [§1.7.8](#178-reference-instantiation-status-final-for-v1); feeds the D-05 release gate); its in-circuit arithmetization is the one element flagged for cryptographic review at [§1.7.8](#178-reference-instantiation-status-final-for-v1).

**Double-spend check (per-transition, `Pkᵢ`-keyed).** To confirm a coin's creating transition is a valid, non-double-spent state update as of `tip`, a verifier checks that transition's `Pkᵢ` against the accumulator it **rebuilt itself** from the chain at `NAV(tip)` (§3.6) — never against a root supplied by a node:

- `Pkᵢ` **present with the matching `Rᵢ`** (opening to the creating transition's `H(ProofData)`, §3.2) ⇒ the transition is the **first, valid** spend of that account state — anchored;
- `Pkᵢ` **present with a different `Rᵢ`** ⇒ a competing transition on the same account state was anchored first; **this** one is the rejected double-spend and its outputs MUST NOT be credited;
- `Pkᵢ` **absent** ⇒ the transition is not yet anchored (still `pending`, §3.10).

Because `Pkᵢ` is a fresh rotating key unlinkable to the account without the account's secrets ([Foundations §1.2](#12-key-hierarchy)), the published nullifiers reveal that *some* account transacted without revealing which account, coin, or amount ([Requirement 2](/requirements)). The whole-lineage anchoring predicate — clause 10(d) for a coin's **immediate** creating transition, plus clause 1's per-hop **predecessor-nullifier check** for **every earlier** state-advancing transition in the account's own lineage ([§2.1 clause 1, clause 10](#21-the-compliance-predicate), [§2.3.3](#233-receive)) — requires **every** state-advancing transition in a coin's lineage to be anchored this way; because every such transition (spend, receive, or mint) publishes its nullifier on Bitcoin, an unanchored self-spend, receive, or mint hop is impossible; and because each nullifier is bound **key and leaf** to the *specific* key its transition consumed (the `consumed_pubkey` public output, [§2.1 clause 1](#21-the-compliance-predicate) (iii) / clause 10(d)), a malicious prover cannot substitute a fresh-key nullifier either — the successor (clause 1 (iii)), the receiver (clause 10(d)), **and every out-of-circuit disclosure verifier** ([§5.6](#56-shareable-confirmation-links)–[§5.8](#58-address-view-full-history)) pin `Pkᵢ` to the proof's own consumed key, not a witness the prover may choose.

**Light clients (cost of trustless absence checks).** Absence of a `Pkᵢ` from the accumulator is checked against the accumulator itself, so a verifier that does not hold it has **no free shortcut** — this is the standing cost of nullifier-based double-spend protection, shared with the *Shielded CSV* paper and with Zcash, not specific to zkCoins. Two honest options remain:

- **Path A — maintain the accumulator itself**, by scanning only the marker inscriptions (§3.5) — far cheaper than full Bitcoin validation (on the order of ~64 bytes per transition) but its state grows with the total number of spends ever made. The verifier then answers any query by direct local lookup, and reveals nothing.
- **Path B — delegate the lookup.** Hold nothing but ask any Path-A node for a Path-B answer for `Pkᵢ`. When the node's local `Pk → (pos, R)` index has an entry, the answer is a self-verifying **RFC-6962 inclusion** proof of `(Pkᵢ, Rᵢ)` at its position `p` (`≤ H_MAX = 64` audit-path hashes, [§3.7](#37-the-nullifier-accumulator)). When the index has no entry, the node returns `present: false` — an **unauthenticated local-index absence answer**, **not** an RFC-6962 non-inclusion proof (the log authenticates only inclusion and consistency; v1 defines no authenticated non-membership proof over the log). Delegation has a sharp edge a membership check lacks: a dishonest node can falsely answer *absent* for an already-spent state and so trick a receiver into accepting a double-spend. Because there is no on-chain root to check the path against (nullifiers are the on-chain data, not a root), Path B therefore serves **display and delegation only**: for any **crediting** decision ([§2.3.3 step 4](#233-receive), [§3.10](#310-transaction-states) `completed`) the verifier **MUST** use its own Path-A accumulator — a Path-B answer (inclusion **or** unauthenticated absence), from however many nodes, **MUST NOT** be the basis for a credit (one mechanism, no quorum variant; project decision 2026-07-22). A wallet whose own node is temporarily without a synced accumulator simply waits for its scan to catch up before crediting. A node MAY serve a **checkpoint accumulator root** to help a Path-A client cross-check its own scan; because that root is a deterministic function of the on-chain nullifiers, anyone who reconstructs the set recomputes and rejects a wrong one, so it carries no authority and the protocol inscribes none.

**Reorg handling.** Because the accumulator is a **pure function of the on-chain nullifiers** (given the pinned network parameters, §3.6), a reorg within the tolerated window is handled by deterministic **canonical replay** — **exclude orphaned entries from the canonical view; retained, never deleted**: every `Pkᵢ` published only in orphaned blocks is permanently kept/archived in the store and only excluded from the active canonical head/index (or materialised view), then re-fold first-occurrence over the new canonical order (§3.6), yielding a fresh `NAV(tip')`. Nothing already stored is deleted from the store. The accumulator remains fully reconstructible from Bitcoin alone; the permanence rule only forbids physical deletion of stored entries. Finality is bounded: at 6 confirmations a nullifier's position is final and a reorg of ≥6 blocks that displaces it MAY break zkCoins (the [§3.9](#39-finality-and-reorg-handling) finality directive). Because `NAV` is explicitly tied to a tip, a stale one is self-identifying: a verifier MUST recompute or re-fetch `NAV` for the current canonical tip before acting on a result, and SHOULD wait for the [§3.9](#39-finality-and-reorg-handling) 6-confirmation threshold so that the anchoring tip is final.

**Storage.** The accumulator log grows by **append**. A Path-A node stores the log (or its Merkle peaks) plus the local `Pk → (pos, R)` index; there is no 256-bit sparse key space and no default-subtree pruning (those belonged to the retired SMT). The accumulator **cannot** prune by age: every position must remain to answer inclusion and log-consistency proofs against the current tip, so "old" entries are never discardable.

### 3.8 Fees and economics

Publishing costs ordinary Bitcoin transaction fees, paid in BTC by the publisher; zkCoins has no native token ([Requirement 1](/requirements)).

- **Per-transition on-chain cost is ~64 bytes.** A half-aggregated nullifier adds `Pkⱼ ‖ Rⱼ` = 64 bytes of witness data per transition (~16 vBytes by Bitcoin's 1/4 witness-weighting), plus an amortised share of the fixed 42-byte header and the commit + reveal transaction overhead (§3.5). At 10 sat/vB and BTC at $100 000 the marginal per-transition cost is on the order of **$0.16–0.19**, independent of how many coins the transition spends. For reference, a realistic Bitcoin SegWit payment (1-in / 2-out P2WPKH) is ~140 vBytes (~$1.40), so a zkCoins transition lands roughly an **order of magnitude cheaper per spend** while adding full privacy — the *Shielded CSV* Table 1 figure (asymptotic to 64 bytes / ~16–19 vB per transaction).
- **Throughput.** Because the marginal on-chain footprint is ~16 vB per transition and there is no single sequential writer, the block-space ceiling is on the order of **~100 transitions per second** at Bitcoin's block-space budget — the *Shielded CSV* envelope, bounded by block space rather than by any publisher's ordering slot.
- **Publishing is sponsored in v1 (normative).** The **publisher** pays the Bitcoin fee for the inscription it broadcasts (§3.4) and is **not** reimbursed. v1 defines **no** protocol fee, no fee coin, and no fee-bearing hand-off: every external hand-off is the **fee-less** case (c) of the [§7.5](#75-node-rest-api-normative) presence matrix, which a publisher accepts or declines by its own policy. The spender never signs or exposes a Bitcoin UTXO, and its on-chain footprint stays limited to the opaque nullifier.
- **A publisher therefore needs an `op` key, a relay presence, and an HTTP endpoint — and nothing else.** With no fee address to bind, it needs no zkCoins account, no payment address, no SPEND key, and no wallet: only the `op` key that signs its kind-30421 profile and its kind-30422 endpoint event, the relays those list, and the [§7.6](#76-publisher-interface-normative) hand-off URL that endpoint names ([§7.3](#73-nostr-event-kinds-normative) *Publisher profile*, [Requirement 7](/requirements)). No domain, no DNS, and no CA are involved — an IP-literal or onion endpoint serves.
- **Liveness does not depend on a sponsor.** Self-publish is permissionless and contention-free (§3.4), so a spender that finds no willing publisher directs its own node to inscribe. The absence of sponsors raises that spender's own Bitcoin cost; it never denies access, and no publisher can extract rent.
- **The assumption this makes explicit.** v1 assumes some operator is willing to carry the inscription cost for others. That is an economic property of a deployment, not one the protocol enforces — the protocol guarantees only that nobody *has* to rely on it.

#### 3.8.1 Fee-coin mechanism (deferred — not part of v1) {#381-fee-coin-mechanism-deferred}

Nothing in this subsection is normative for v1. It is retained in full because it is designed, coherent, and the natural way to add paid publishing later; an implementation targeting v1 **MUST NOT** implement it, and a v1 publisher profile carries none of its fields.

A spender compensates a publisher by adding one ordinary output coin to the very transition the publisher will anchor — no new on-chain field, no protocol-level fee output, no UTXO exposure. The mechanism's safety rests on one structural fact: a transition has **exactly one** on-chain nullifier binding (via sign-to-contract, §3.2) **exactly one** `output_coins_root` (`ocr`, §1.4), and the fee coin is one of the outputs under that `ocr`. The fee coin and the recipient payment are therefore **atomically bound** — anchoring the transition's nullifier commits *all* of its outputs at once, or none. The mechanism reuses the coin model exactly:

1. **Publisher discovery.** A publisher advertises a signed **publisher profile** (a Nostr addressable event, [§7.3](#73-nostr-event-kinds-normative)) carrying `{ fee_address, fee_asset_id, fee, relays, pk0, nk_commit, ivpk, addr_sig }`, where `fee_address` is a normal zkCoins `address` the publisher controls and `fee` is the flat price **per transition** quoted in `fee_asset_id` (any asset the publisher chooses to accept — there is no native token, [Requirement 1](/requirements)). The profile is `op`-signed by the publisher's node identity; the signature covers the whole content, so a wallet that authenticates `op_pubkey` binds the advertised `fee_address` to the same operator. That `op_pubkey` **is** the `publisher_pubkey` a spender names in its transition-submit request ([§7.5](#75-node-rest-api-normative)), and it is the profile's `d` tag ([§7.3](#73-nostr-event-kinds-normative)) — so `publisher_pubkey` resolves to this event by an ordinary addressable-event lookup, and a `publisher_pubkey` with no such authenticated profile is the §7.5 `unknown_publisher` error. A publisher **MAY** also accept **fee-less** hand-offs by policy ([§7.5](#75-node-rest-api-normative) presence matrix case (c), [§7.6](#76-publisher-interface-normative)); fee policy is not consensus. Before encrypting a fee-bearing hand-off to this publisher (step 3 below), the spender **MUST** verify this event under the three checks and field-shape rules of [§7.3](#73-nostr-event-kinds-normative) *Publisher profile* — `H(pk0 ‖ nk_commit) == fee_address`, `addr_sig` under `pk0`, and the event signature under the author `op_pubkey` — and only then encrypts the fee `CoinProof` to the verified `ivpk`. The check runs on this event alone: no kind-0 event, no name, and no DNS is involved, so being a publisher stays permissionless. A publisher profile that is missing or fails any check **MUST** be treated as unusable for a fee-bearing hand-off; the spender's remedy is step 5 below — pick another publisher, or self-publish.
2. **Spender includes a fee coin (when paying).** When the hand-off is case (b) of the [§7.5](#75-node-rest-api-normative) presence matrix, the spender, building the transition (§2.3.2), adds one extra output `CoinTemplate { recipient = fee_address, amount ≥ fee, asset_id = fee_asset_id }`. This fee coin occupies one of the `MAX_TX_OUTPUTS` slots ([§2.5](#25-circuit-dimensioning-normative)) and is conserved by the balance predicate ([§2.1 clause 3](#21-the-compliance-predicate)) like any other output — it is indistinguishable on-chain from a payment, and it shares the transition's single `ocr`. Case (a) self-publish and case (c) fee-less hand-off add **no** fee output.
3. **Hand-off.** The spender hands the publisher its transition's `{Pkᵢ, Rᵢ, sᵢ, R'ᵢ}` (nullifier plus the pre-tweak sign-to-contract nonce, §7.6). When a fee coin is present (case (b)), the spender additionally delivers the fee coin's `CoinProof` as an **ordinary ZBE blob encrypted to `fee_address`'s `IVPK`** — the same §4.2 / §4.2.1 delivery path used for every other recipient coin, so the publisher is just another recipient for that one coin. The wire hand-off on `/v1/publish/spendrecord` carries **only** `fee_blob_id`, an encrypted locator/delivery reference, and a fresh `epk` — **never** the fee `CoinProof` plaintext ([§7.6](#76-publisher-interface-normative)). The publisher **decrypts** the ZBE blob with the account's `ivk` (re-deriving `K_tx` from `epk` as in [§1.3](#13-per-coin-keys-note-encryption--detection) / [§4.2.1](#421-bundle-blob-encryption-zbe-normative)), **then** verifies, before inscribing, that the fee coin (a) is addressed to its `fee_address`, (b) is of `fee_asset_id`, (c) meets its quoted `fee`, and (d) is an output under the **same `ocr`** the nullifier's `Rᵢ` commits (opened via `R'ᵢ`, §3.2); only then does it inscribe the nullifier. Plaintext fee-`CoinProof` over TLS is **forbidden**: a TLS terminator, reverse proxy, or CDN would otherwise observe the coin, `ProofData`, and `creating_prev_ash` (a D-19 linkage regression).
4. **Settlement is atomic with anchoring.** Because the fee coin and the recipient payment are outputs under the one `ocr` bound by the one nullifier, the publisher cannot anchor the fee while omitting the payment, and the fee coin only becomes a spendable (`completed`) coin once *this* transition's nullifier reaches `completed` ([§3.10](#310-transaction-states)) — the same event that finalises the spender's payment. A publisher thus **cannot** collect a fee without delivering the anchoring it was paid for.
5. **Censorship / non-anchoring.** If the chosen publisher never anchors the transition within a reasonable window, the spender re-builds the transition against a different publisher (a fresh fee coin to the new `fee_address`) — or directs its own node to **self-publish** (§3.4). This is safe: the account-state nullifier is idempotent (§3.7 first-occurrence), so at most one of the competing transitions can ever be anchored, and the **fee coin of an un-anchored transition never reaches `completed`**, so a censoring publisher collects **nothing** — the spender pays exactly one fee, to whichever publisher actually anchors. The risk is duplicate proving effort, never a lost or double-paid fee. The wallet **MUST** treat the first transition as abandoned only after confirming its `Pkᵢ` is not yet present at `NAV(tip)` (a late-anchoring first publisher simply wins the race, which is equally acceptable — the payment still goes through exactly once).

A publisher **MUST NOT** be trusted for correctness of this exchange: it cannot collect the fee without anchoring the spender's payment (they share one `ocr`, bound by one nullifier), and cannot forge the transition's proof (which travels off-chain to the recipient, §4.2). **v1 adopts** sponsored publishing and permissionless, contention-free self-publish (§3.4) — a wallet that finds no publisher uses its own node as the escape hatch. **v1 defers** the spender-picks-publisher fee coin above, and with it the paper's *first-to-publish-wins* fee design (a fee bound to "whichever publisher first inscribes this nullifier", removing the spender's need to pick a publisher up front); it is a forward-compatible privacy upgrade that would let a gossip network of publishers compete for each nullifier, but it needs a two-step payment structure this spec does not yet fix.

### 3.9 Finality and reorg handling

A transition nullifier is **published** the instant its reveal transaction enters a Bitcoin block, and **final** under the same assumptions as any Bitcoin payment of comparable value. zkCoins fixes the receive-side threshold at **6 confirmations**: a nullifier at fewer than 6 confirmations is in state `pending` (§3.10), and a receiver **MUST NOT** treat the coins whose anchoring depends on it as spendable-final.

- zkCoins adds no separate consensus, validator set, or checkpoint beyond Bitcoin ([Requirement 1](/requirements), [Requirement 3](/requirements)); the confirmation **floor** for receiving is fixed at 6 (§3.10 — a receiver **MUST NOT** credit earlier); a receiver **MAY** require more than 6 for extreme value, never fewer. It does, however, cap **recoverable reorg depth**: unlike a native Bitcoin payment (which a deep reorg cleanly reverses), a reorg of **≥6 blocks** MAY break a zkCoins account with no recovery path, because v1 does not adopt the paper's arbitrary-depth conditional-NAV recovery (the finality directive below).
- A membership result (§3.7) is only as final as the tip it is anchored to; a verifier **MUST** re-evaluate any **not-yet-final** result whose tip a reorg displaces below the required confirmation depth. A result already final at 6 confirmations is treated as fixed; a ≥6-block reorg that displaces it is the accepted break (below), not a re-evaluation this recovers.
- Threat-model implications: see [Architecture §6.6](#66-threat-model-and-trust-configurations).

**Finality bound (hard project directive).** zkCoins v1 fixes finality at **6 confirmations**: once a nullifier's inclusion block has 6 confirmations, its position in the accumulator is treated as **final** and is never revisited. **`size_final` (normative).** `size_final` is the accumulator size at the highest block height `≤ tip_height − 5` — equivalently, the log prefix every entry of which has ≥6 confirmations; `size_final = 0` when `tip_height < 5`. `nav = size_final` is the **creditable default** ([§2.3.2 step 5](#232-send)). Define `size_final` as the number of first-occurrence log entries ([§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)) whose inclusion block has **at least 6 confirmations** — i.e. the log prefix through block height `tip_height − 5` (from the [§5.6](#56-shareable-confirmation-links) confirmation count `tip_height − height + 1`, so 6 confirmations ⇔ height `≤ tip_height − 5`). A conditional NAV a transition commits ([§2.1 clause 1](#21-the-compliance-predicate)) and every balance attestation ([§5.7](#57-balance-attestation-history-private)) **MUST** authenticate only positions `< size_final` (there is no exception — v1 has no pipelining, §2.3.2 step 5). Because the accumulator is an **ordered** Merkle log (order-sensitive, unlike the retired order-independent SMT, [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)), this confines every authenticated position to the never-reshuffled final region: a ≤5-block reorg touches only positions `≥ size_final`, and a ≥6-block reorg displacing a final position is the accepted break above. The order-sensitivity is a **liveness** cost only (the non-final suffix of `NAV(tip)` beyond `size_final` may reshuffle, but a committed `nav` — always `size_final` — never does after a reshuffle), never a double-spend lever. This is a deliberate, load-bearing project directive, not merely a UX default:

1. **Reorgs of up to 5 blocks are tolerated.** They only ever touch **non-final** nullifiers (fewer than 6 confirmations). Every node handles them by **canonical replay** — **exclude orphaned entries from the canonical view; retained, never deleted**: every nullifier `Pkᵢ` published only in orphaned blocks stays permanently in the store (archived) and is only excluded from the active canonical head/index (or materialised view); then re-fold first-occurrence over the new canonical order (§3.6). The accumulator at the new tip is the deterministic replay of publications in the new canonical order — no re-batching, no publisher coordination, no stranded shared root, and no physical deletion of already-stored log entries (Data Permanence, [§4.8](#48-durability--the-store-everything-invariant)).
2. **Nothing final is reversed by a tolerated reorg.** A receiver **MUST NOT** credit a coin until its creating nullifier is final (§3.10 `completed`). Because a ≤5-block reorg touches only **non-final** nullifiers, it cannot reverse a credited (final) coin or a final account state; a wallet simply re-publishes any orphaned not-yet-final transition after canonical replay. No final value is lost within the tolerated window. (Because `nav` is always `size_final` (§2.3.2 step 5), a transition is never built against a not-yet-final dependency — the wallet waits until the dependency finalizes; this is what forecloses the account-brick a non-final `nav` would otherwise cause under a tolerated reorg.)
3. **A reorg of 6 or more blocks MAY break zkCoins.** Displacing a final nullifier is **outside v1's guarantee**: such a reorg can orphan a dependency a completed transition relied on, or reverse a credited coin, and v1 provides **no** recovery path for it. This is an **explicit, accepted limitation** of v1 — the stated boundary of the protocol's safety, so that integrators size their confirmation policy accordingly. Deployments handling extreme value **MAY** adopt additional out-of-band confirmation policies on top of the 6-confirmation floor. A node that detects such a displacement of a final nullifier **MUST** surface the condition — its `/health/ready` **MUST** stop reporting ready — and **MUST NOT** continue crediting against the broken state.


This is a deliberate deviation from *Shielded CSV*, which uses a tuple-of-sets accumulator with an `IsPrefix`/`DistinctElement` **exactly-one-of** relation to make reorgs of arbitrary depth defined and survivable (a conditional-NAV no-op branch). zkCoins v1 uses an **append-only Merkle-log accumulator with RFC-6962 log-consistency** with no `DistinctElement` no-op branch ([§3.7](#37-the-nullifier-accumulator)), and therefore does **not** inherit the paper's arbitrary-depth recovery; it replaces it with this hard 6-confirmation finality bound. The deviation and its rationale are registered in the [paper-deviation analysis](/paper-conformance-analysis); the Bitcoin-industry 6-confirmation default makes it the established, Bitcoin-consistent choice.

### 3.10 Transaction states

Every transition nullifier a verifier observes is classified into **exactly one** of three states. The state is a function of the verifier's own §3.5+§3.6 scan and the inclusion block's confirmation depth — **never** of any assertion by a node, publisher, courier, or sender. Two honest verifiers at the same canonical Bitcoin tip **MUST** classify every nullifier identically.

| State | Defined as | Receiver MAY credit |
|---|---|---|
| **`completed`** | the nullifier is **anchored** under §3.5+§3.6 by the verifier's own scan — its signature verifies (§3.2) and its `Pkᵢ` is the **first occurrence** of that key in the accumulator (§3.6 step 5) — **AND** its inclusion block has **at least 6 confirmations** (§3.9) | **yes** |
| **`failed`** | the nullifier is **rejected** by the verifier's scan — a structural/`block_anchor` violation (§3.5), a signature failure (§3.2), or a **later** occurrence of a `Pkᵢ` already folded (a double-spend loser, §3.6 step 5) | **no** (never) |
| **`pending`** | the nullifier is in neither state — its bytes are inscribed but its inclusion block has fewer than 6 confirmations | **no** |

There is no `pending`-due-to-data-availability sub-state anymore: the nullifier is entirely on Bitcoin, so a verifier that can read the chain can always classify it. The batched design's dependence on fetching an off-chain `BatchBundle` before admission — and the resulting "inscribed but unverifiable" limbo — is gone.

**Relationship to the nullifier accumulator.** The accumulator (§3.7) folds a nullifier the moment its signature verifies and its inclusion block is on the canonical chain — i.e. from state `pending` onward, before the 6-confirmation threshold. Double-spend protection therefore takes effect **at publication**: a coin whose creating transition's `Pkᵢ` has been folded is immediately anchored against any competing spend of the same state, even while still `pending` on confirmation depth. What the 6-confirmation threshold gates is only *receive-side finality*, not the first-occurrence ordering.

**`completed` and reorg finality.** Because the accumulator is a pure function of the on-chain nullifiers (§3.7), a reorg within the tolerated window is handled by canonical replay (§3.6). Finality is bounded at 6 confirmations (the [§3.9](#39-finality-and-reorg-handling) hard project directive): a nullifier classified `completed` at 6 confirmations is treated as final, and a reorg of ≥6 blocks that displaces its inclusion block **MAY** break zkCoins — an accepted v1 limitation, not a recovery case. A verifier **MUST** re-evaluate any not-yet-final result whose anchoring tip a reorg displaces.

**`failed` is forward-sticky within a chain.** A rejection cannot become an anchoring by waiting. A reorg **MAY** change *which* of two nullifiers racing to publish the same `Pkᵢ` is the first occurrence (if canonical order shifts under §3.6), but on a fixed canonical chain the property of being the later occurrence cannot be undone by passage of time alone.

**Every state-advancing transition anchors — there is no non-anchored path.** Every transition that advances an account state — a send, a **receive**, and a **mint** (issuance), including the genesis `InitialProof` — consumes the state's one-time key `Pkᵢ` and **MUST** publish its nullifier `(Pkᵢ, Rᵢ)` on Bitcoin, arbitrated by first-occurrence exactly like any spend ([§2.3.1](#231-mint--issuance), [§2.3.3](#233-receive), [§3.1](#31-the-on-chain-object)). There is **no** non-anchored-mint whitelist and **no** off-chain-only acceptance: a coin is creditable only once **every** state-advancing transition in its lineage is in state `completed` ([Proofs §2.3.3 step 4](#233-receive), [§2.1 clause 10](#21-the-compliance-predicate)). The anchor / receive checks in [Proofs §2.3.3](#233-receive), [Transport & Recovery §4.5](#45-recovery), and [Access & Explorer §5.6 / §5.7 / §5.8](#56-shareable-confirmation-links) all require the relevant nullifier to be in state `completed`; a nullifier in any other state **MUST NOT** be treated as anchored. The user-facing **status** rendered by an explorer (e.g. Access & Explorer §5.6 step 3) **MUST** be the §3.10 state (one of `completed`, `failed`, `pending`), not a node-asserted classification.

**Why a mint must anchor (normative).** A mint is a state update whose consumed one-time key `Pkᵢ` must win first-occurrence just like a spend; anchoring it is what makes the mint-fork exclusion hold ([§6.5](#65-issuance--token-standards)). A genesis mint publishes `Pk₀` itself as the first-occurrence nullifier of the genesis (the `nk_commit` binding of [§2.1 clause 1](#21-the-compliance-predicate) alone does **not** close genesis-fork equivocation — two genesis transitions under the same `Pk₀` are only separated by Bitcoin first-occurrence). Anchoring every mint makes issuance **frequency and timing chain-visible** — an accepted privacy/on-chain-bytes trade-off, consistent with the paper's on-chain state-nullifier model; amounts, assets, parties, and the graph remain hidden ([Requirement 2](/requirements)).



## 4 · Transport & Recovery

> *In one sentence: how the encrypted coin bundle gets from sender to recipient over Nostr, how the recipient finds its own coins on a relay, and how a wallet that lost everything rebuilds its state from seed + Bitcoin + the network.*

This page specifies the **off-chain layer**: how the value-bearing `CoinProof` bundle ([Foundations §1.5](#15-core-data-structures)) travels from sender to recipient, how the spender's on-chain nullifier `(Pkᵢ, Rᵢ)` reaches a publisher, how a recipient discovers its own incoming coins, how a node recovers its entire state from the **seed** plus Bitcoin (including fully replayable `SelfDeliveryRecordV1` state records, [§4.2](#42-bundle-delivery)), and the data-availability guarantees that make recovery possible. The on-chain layer carries only the opaque per-transition nullifier ([Foundations §1.4](#14-identifiers-and-hashes)); the value-bearing off-chain objects — per-coin `CoinProof` bundles and per-transition `SelfDeliveryRecordV1` records — live here and **MUST** be retained indefinitely under Data Permanence ([§4.8](#48-durability--the-store-everything-invariant)); availability follows from that permanence ([§4.6](#46-data-availability)).

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) are used per RFC 2119. All primitives, keys, and identifiers are defined in [Foundations](#1--foundations-normative) and used unchanged.

### 4.1 Roles and transport

Every zkCoins **node is paired with a full Nostr relay** for transport. In the reference deployment that relay runs as its **own container** (`nostr-relay`), reached over the relay protocol; it **MAY** be the operator's own (the default) or an external relay ([§6.1](#61-components-and-responsibilities)). The node performs Bitcoin validation, proof verification, state storage, standard Nostr messaging, and the capability-gated pull endpoint ([Access & Explorer](#5--access--explorer)); the paired relay carries encrypted zkCoins bundle traffic and may also be one of the account's published kind-10050 DM relays. Outgoing NIP-17 messages go to each contact's own kind-10050 relays. There is no separate, mandatory third-party courier for zkCoins bundles — by default that transport is part of the operator's own stack.

The transport key is `op`, the operational / Nostr identity key ([Foundations §1.2](#12-key-hierarchy)). It is the account's **ordinary Nostr account key**, not a zkCoins-specific messaging key: its public key authors the standard kind-0 profile and kind-10050 DM relay list, and `op` signs NIP-59 seals for NIP-17 messages. The node holding the operational bundle drives transport and messaging on the wallet's behalf; `op` **MUST NOT** be able to spend (it is a hardened sibling of the SPEND branch). A sovereign user's own node therefore controls and can read that user's messages; a hosted provider holding the bundle can do the same for its hosted account ([§6.6](#66-threat-model-and-trust-configurations)). Interoperability means ordinary NIP-17 peers exchange standard events directly with this Nostr identity — no external peer needs the `op` secret or any zkCoins-specific adapter.

Human messages and zkCoins coin delivery are separate protocols on the same Nostr identity. Human messages **MUST** use NIP-17 kinds `14`, `13`, `1059`, and `10050`; zkCoins delivery and acknowledgement rumors remain kinds `1420` and `1421` and **MUST NOT** carry chat content ([§7.3](#73-nostr-event-kinds-normative)).

The transport is trusted only for **availability** and for **metadata minimisation** — never for correctness. A relay can **withhold** a bundle but can neither **forge** nor **alter** one, because the recipient verifies every bundle cryptographically (§4.5). This is the same trust spectrum as the node model: a compromised relay is a privacy/availability problem, never theft.

### 4.2 Bundle delivery

A bundle is delivered as a small Nostr control event that **references** the encrypted bundle, plus the bundle blob itself in content-addressed storage.

**Why split.** A recursive proof is large (on the order of 100 KB or more) — too big for an ordinary relay event. Therefore:

1. The sender encrypts the serialised `CoinProof` bundle under the per-coin note key `K_tx` ([Foundations §1.3](#13-per-coin-keys-note-encryption--detection)) using the **zkCoins Bundle Encryption (ZBE)** scheme of [§4.2.1](#421-bundle-blob-encryption-zbe-normative), producing `ciphertext`. (`K_tx` is re-derivable by the recipient from `ivk` and the coin's `epk`; no relay can derive it.) NIP-44 v2 supports extended-length plaintext up to `2^32-1` bytes, but proof blobs belong in content-addressed Blossom/blob transport rather than large Nostr control events. ZBE provides chunkwise authenticated processing, bounded memory, and blob-oriented framing and retry (§4.2.1); the small control event in step 3 *is* a plain NIP-44 v2 message.
2. The sender stores `ciphertext` in a content-addressed blob store (a Blossom store, [§7.4](#74-blossom-blob-store-normative), co-located with each node's relay) and **MUST** additionally store it in at least one of the network's `blob_stores` ([§4.3](#43-addressing-for-delivery) recovery-discoverable overlap), so the value-bearing bytes — not only the delivery event's locator on a `seed_relay` — are recoverable from the seed-discoverable set after total loss. The store key is the content hash `blob_id = H(ciphertext)` (Blossom serves blobs by their SHA-256, matching [§5.6](#56-shareable-confirmation-links)).
3. The sender constructs a **delivery event**, an application-specific Nostr event whose plaintext payload is:

   ```
   DeliveryEvent.payload = {
     blob_id,                    // content hash of the encrypted bundle / SelfDeliveryRecordV1
     blob_locators,              // base64url-no-pad of serialize(BlobLocatorSet) = holders only
                                 //   (§7.1); blob_id is context (above), not in the set;
                                 //   lives ONLY in this encrypted interior (§4.3)
     ack_nonce                   // 32 random bytes, sender-chosen; binds the ACK to this
                                 //   delivery attempt (§4.2 ACK rule). Fresh per retry.
   }
   ```

   The payload carries **no** amount, asset, recipient address, or sender — those live only inside `ciphertext`. Note that `K_tx` itself is **never** placed in the delivery event; the recipient re-derives it from `ivk` and `epk`. The `ack_nonce` is generated fresh per delivery attempt and is what the recipient signs in the ACK (below); the sender therefore knows that a returned ACK corresponds to **this** delivery, not a captured-and-replayed ACK from an earlier round. `blob_locators` **MUST NOT** appear as cleartext outer tags or public gossip ([§4.3](#43-addressing-for-delivery) privacy boundary).

4. The sender encrypts the delivery event to the recipient's **incoming-view public key** `IVPK = ivk·G` ([Foundations §1.3](#13-per-coin-keys-note-encryption--detection)) with **NIP-44 v2**, then **NIP-59** gift-wraps the result under a fresh ephemeral key. The **outer** kind-1059 event carries exactly two **cleartext tags** — `["zkdt", detect_tag]` and `["zkepk", epk]` ([Foundations §1.3](#13-per-coin-keys-note-encryption--detection), [§7.3](#73-nostr-event-kinds-normative)) — so a recipient runs the [§4.4](#44-note-discovery) scan without unwrapping anything; both values are fresh and random-looking per coin, so they identify no party and link no two events. Beyond those two tags the outer event is addressed to the fresh ephemeral key, so a relay sees neither sender nor recipient — only an opaque blob stored at some time.
5. The sender publishes the gift-wrapped event to the recipient's advertised relay set (§4.3), **MUST** additionally publish it to at least one of the network's `seed_relays` ([§4.3](#43-addressing-for-delivery) recovery-discoverable overlap), and **MAY** place further optional redundant copies at other holders ([§4.6](#46-data-availability)).

**Store-and-forward.** The recipient **MAY** be offline. Relays **MUST** retain a delivery event and blob stores **MUST** retain its blob **indefinitely** — no deletion and no retention-policy expiry ([Data Permanence, §4.8](#48-durability--the-store-everything-invariant)); Data Permanence applies to paired relays and blob stores alike. Receiving therefore requires that **one** relay holding the event **and one** blob store holding the blob are reachable when the recipient comes online — hence the two-plane recovery-discoverable overlap of §4.3.

**ACK + retry (normative).** Delivery is reliable, not best-effort:

- The sender **MUST** retain its own copy of the bundle (and `K_tx`) **indefinitely** ([§4.8](#48-durability--the-store-everything-invariant)). A valid acknowledgement ends the retry loop; it is a durability confirmation, never a drop licence.
- On successful receipt and verification (§4.5), the recipient's node **MUST** return an **acknowledgement**: a NIP-44-encrypted, NIP-59 gift-wrapped kind-1421 rumor ([§7.3](#73-nostr-event-kinds-normative)) addressed back to the sender whose JSON `content` is exactly `{detect_tag, blob_id, ack_nonce, op_sig}` — four closed fields, all binary values lowercase hex, `op_sig` the 64-byte BIP-340 signature by the recipient's `op` over the fixed preimage `ack_message = H("zkCoins/v1/Ack" ‖ detect_tag ‖ blob_id ‖ ack_nonce)` (raw 32-byte fields, not hex). The `ack_nonce` echoes the delivery event's plaintext payload. The sender verifies (i) `op_sig` under the recipient's published `op` pubkey over that exact `ack_message` **and** (ii) that the echoed `ack_nonce` matches the nonce the sender chose for this delivery attempt. The nonce binding ensures a captured ACK cannot be replayed against a later retry (a fresh attempt uses a fresh `ack_nonce`, so a stale ACK fails verification (ii)).
- Until a valid ACK arrives, the sender **MUST** re-publish the delivery event on an exponential-backoff schedule (RECOMMENDED: initial 30 s, doubling, capped at 1 h) to every relay in the recipient's set.
- After a valid ACK the sender **still retains** its copy indefinitely ([§4.8](#48-durability--the-store-everything-invariant)). The ACK confirms that the recipient durably stored the bundle; it does **not** authorise the sender (or any other holder) to drop any copy.

**Self-delivery of change and account state — `SelfDeliveryRecordV1` (normative).** Every transition — a spend with its change coin, a mint, or a receive transition ([§2.3.3 step 7](#233-receive)) — advances the account to a new state whose recursive proof is the credential the **next** transition must extend. A pure receive produces **no** output `CoinProof`s, so self-delivery **MUST NOT** be defined as "the change-coin `CoinProof` plus outgoing keys" alone: the account **MUST** publish a fully replayable **state/transition record**. The normative object is **`SelfDeliveryRecordV1`** — a **tagged, fully length-prefixed** envelope (wire layout [§7.1](#71-serialization-conventions-normative)):

```
SelfDeliveryRecordV1 =
  magic ‖ version ‖ record_kind ‖ send_counter ‖ prev_state_head
  ‖ serialize(AccountState)          // the NEW post-transition state, canonical (§1.7.4)
  ‖ recursive_proof ‖ serialize(ProofData)
  ‖ own_nullifier                    // (Pk, R, R') of THIS transition
  ‖ proof_block_anchor ‖ inclusion_block ‖ occurred_at
  ‖ spent_or_folded_coin_ids[]
  ‖ output_refs[]                    // each { coin_id, blob_id, epk, out_ciphertext, blob_locators }
  ‖ self_blob_locators               // BlobLocatorSet for THIS SDR blob
```

- **`magic`** = ASCII `"SDR1"` (4 bytes); **`version`** = `0x01` (u8).
- **`record_kind`** (u8) discriminates the transition class: `0x01` = mint, `0x02` = send, `0x03` = receive (any other value is malformed).
- **`send_counter`** is the post-transition `AccountState.send_counter` (u64 big-endian); **`prev_state_head`** is the prior `ash` (or the empty-account `ash` for a genesis `InitialProof`).
- **`serialize(AccountState)`** is the full new state — balances, `current_pubkey`, `send_counter`, `coin_history_root`, `nk_commit` — so a pure receive is fully reconstructible without any output `CoinProof`.
- **`recursive_proof`** is the length-prefixed Plonky2 proof bytes of this transition ([§1.7.9](#179-proof-system-parameters-normative)); **`serialize(ProofData)`** is the fixed 192-byte public-input layout ([§1.4](#14-identifiers-and-hashes)).
- **`own_nullifier`** = `Pk (32B x-only) ‖ R (32B x-only) ‖ R' (32B x-only)` — the transition's on-chain nullifier pair plus the pre-tweak S2C opening.
- **`proof_block_anchor`** = `{ block_hash (32B), height (u32) }` — the **proof-context anchor**: the Bitcoin tip this transition's proofs were built against (a **strict ancestor** of the inclusion block, gap ≤ `N = 100` per [§3.5](#35-inscription-format); **MUST NOT** be the inclusion block itself). This is the Phase-A build tip carried into the SDR as a proof/batch context field — **not** the on-chain `AggregateStateNullifierV3` header `block_anchor` chosen by the publisher ([§3.5](#35-inscription-format)), which **MAY** differ from a member's own build tip and is **not** re-checked against the inscription header when accepting an SDR.
- **`inclusion_block`** = `{ block_hash (32B), height (u32) }` — the Bitcoin block in which this transition's own `(Pk, R)` was **first included** (verified first-occurrence in the nullifier-accumulator log, [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log), [§3.6](#36-chain-scanning)). Distinct from `proof_block_anchor`: **proof context** vs **actual first-occurrence inclusion**.
- **`occurred_at`** is a `u64` Unix-seconds timestamp that is **NOT sender-asserted**: a conforming node **MUST** set it to **`MTP(inclusion_block)`** — the **Median-Time-Past (MTP, BIP-113)** of that first-occurrence inclusion block — **exactly** that block's MTP, no other chain-derived clock — and **MUST** reject a recovered record whose claimed `occurred_at` is inconsistent with that first-occurrence inclusion's MTP. Replay derives `occurred_at` **exclusively** from `inclusion_block` (never from `proof_block_anchor` or any publisher-chosen header).
- **`spent_or_folded_coin_ids[]`** is the ordered list of `coin.identifier`s this transition spent (send inputs) or folded in (receive `fold_coin_ids`); empty for a pure mint that spends none.
- **`output_refs[]`** lists every outgoing coin of the transition (recipient outputs, change, and — under the deferred fee mechanism only — a fee coin) as `{ coin_id, blob_id, epk, out_ciphertext, blob_locators }` so an `ovk` holder recovers outgoing plaintext **and** knows which holders hold the coin blob ([§1.3](#13-per-coin-keys-note-encryption--detection), [§7.1](#71-serialization-conventions-normative) `serialize(BlobLocatorSet)`); `M = 0` for a pure receive.
- **`self_blob_locators`** is a `BlobLocatorSet` for the **SelfDeliveryRecordV1** ZBE blob itself (holders that serve this record's `blob_id`), framed per [§7.1](#71-serialization-conventions-normative).

**Two-phase finalisation (normative).** Because `occurred_at` is the MTP of the first-occurrence inclusion block, that timestamp is known only **after** the transition's nullifier is observed on Bitcoin. A conforming node **MUST** therefore build and self-deliver the SDR in **two phases** — never by writing a provisional `occurred_at` and later rewriting the ciphertext:

1. **Phase A — build + publish nullifier.** Prove the transition against a `proof_block_anchor` (the member's own proof-context tip — a strict ancestor under the [§3.5](#35-inscription-format) gap bound; **not** necessarily equal to the publisher's eventual on-chain `AggregateStateNullifierV3` header `block_anchor`), assemble the nullifier hand-off (`(Pk, R, s, R')`; no fee coin in v1), and publish / self-publish the nullifier ([§3.4](#34-the-publisher), [§7.6](#76-publisher-interface-normative)). Outgoing coin blobs **MAY** already be stored at holders; the SDR is **not** yet final-serialised.
2. **Phase B — observe first-occurrence, then finalise SDR.** After the node's own scan confirms the first-occurrence inclusion of `(Pk, R)` ([§3.6](#36-chain-scanning)), set `inclusion_block` to that inclusion block's `{block_hash, height}`, set `occurred_at` to **`MTP(inclusion_block)`** (BIP-113), leave `proof_block_anchor` as the proof-context tip from Phase A (a **strict ancestor** of `inclusion_block` per [§3.5](#35-inscription-format) — **not** the inclusion block, and **not** re-derived from the publisher's inscription header), complete every `output_ref` / `self_blob_locators` holder set, **then** compute `serialize(SelfDeliveryRecordV1)`, ZBE-encrypt, content-address, and self-deliver under [§4.2](#42-bundle-delivery), retaining every copy indefinitely ([§4.8](#48-durability--the-store-everything-invariant)).

Replacing a finalised SDR after self-delivery (rewriting `occurred_at` or any other field) would change `ciphertext` / `blob_id` and **MUST NOT** be done; a node that has not yet observed first-occurrence **MUST NOT** emit a final SDR.

**Transport privacy (MUST).** The **complete** record — `record_kind`, coin ids, `output_refs` (including each per-coin `BlobLocatorSet`), `self_blob_locators`, `AccountState`, proof, nullifier, `proof_block_anchor`, `inclusion_block`, and `occurred_at` — lives **exclusively** inside the ZBE-encrypted blob (or, for the small control path, the NIP-44-encrypted delivery interior). The **outer** gift-wrap (kind `1059`) of a self-delivery event carries **exactly** the same two cleartext scan tags as any other delivery — `["zkdt", detect_tag]` and `["zkepk", epk]` ([§4.2 step 4](#42-bundle-delivery)) — and **MUST NOT** expose any field of `SelfDeliveryRecordV1` in cleartext tags, delivery outer fields, or gossip.

The account's node **MUST** deliver this self-addressed record to its **own** advertised relay set under the identical delivery rules above — encrypted to the account's own `IVPK`, carrying its own `detect_tag`, ACK-tracked where applicable, and retained indefinitely under Data Permanence ([§4.8](#48-durability--the-store-everything-invariant)); optional redundant copies at other holders only add durability ([§4.6](#46-data-availability)). The account **MUST** additionally self-deliver each `SelfDeliveryRecordV1` to at least one of the network's `seed_relays` ([§4.3](#43-addressing-for-delivery) recovery-discoverable overlap), so it stays recoverable even if the account's own paired relay is later lost together with its database. Self-delivery is not optional bookkeeping; it is what makes two situations work, and **without it neither does**:

- **Multiple devices / nodes on one seed.** The Bitcoin chain reveals only the opaque per-transition nullifiers `(Pkᵢ, Rᵢ)` — a fresh rotating key and an S2C nonce — never anything per-account. A second device learns of a transition made elsewhere **only** by discovering this self-addressed record on a shared relay (§4.4) and replaying it. Devices that must stay in sync **MUST** share at least one advertised relay, or one node **MUST** be reachable through the other's pull endpoint ([Access & Explorer §5.1](#51-capability-gated-pull)); otherwise a second device can detect that an accumulator transition occurred but **cannot reconstruct the spendable state**, and must fall back to emergency reconstruction (§4.5).
- **Emergency recovery.** Steps 5–6 of §4.5 rebuild the spendable head by verifying and replaying recovered `SelfDeliveryRecordV1` objects in `send_counter` order; they are retrievable only because they were self-delivered and retained indefinitely here ([§4.8](#48-durability--the-store-everything-invariant)).

**Replay (normative).** A recovering or multi-device node **MUST** sort accepted `SelfDeliveryRecordV1` objects **strictly by `send_counter` ascending** and apply them in that order only. For each record it **MUST** verify: (i) `prev_state_head` equals the `ash` of the state produced by the previous applied record (or the canonical empty-account `ash` for the genesis record); (ii) `ash(AccountState) == ProofData.new_account_state_hash`; (iii) the recursive proof verifies against `ProofData` and the network's pinned circuit digest; (iv) `own_nullifier.(Pk, R)` is the **first occurrence** of `Pk` in the node's **own** rebuilt nullifier-accumulator log ([§3.6](#36-chain-scanning)) with `R` opening `H(ProofData)` via `R'` **and `own_nullifier.Pk == recursive_proof.consumed_pubkey`** — the key the proof exposes as `consumed_pubkey` **MUST** be the on-chain nullifier key, not a freely chosen one; without this binding an SDR could advertise a freshly chosen `Pk` as its nullifier whose leaf S2C-opens `H(ProofData)` without being the key the recursive proof actually consumed (the **Fresh-Key-Substitution** already closed on the in-circuit edges by [§2.1 clause 1(iii) / clause 10(d)](#21-the-compliance-predicate) and the [§1.4](#14-identifiers-and-hashes) consumed-key output) — first-occurrence is checked against that local reconstruction, **not** against a publisher-chosen inscription header; (v) `inclusion_block` equals that verified first-occurrence inclusion block (`block_hash`, `height`) and `occurred_at` equals **`MTP(inclusion_block)`** (BIP-113) — `occurred_at` is derived **exclusively** from `inclusion_block` (never from `proof_block_anchor`); (vi) `proof_block_anchor` is a **strict ancestor** of `inclusion_block` within the [§3.5](#35-inscription-format) gap bound (and is **not** the inclusion block) — it is proof-context only and **MUST NOT** be required to equal the on-chain `AggregateStateNullifierV3` header `block_anchor`. A record failing any check **MUST** be discarded. Among successfully verified records the node **MUST** select the **uniquely highest** `send_counter` head as the spendable lineage tip; if two verified records claim the same `send_counter` with divergent `ash`, both **MUST** be rejected for that counter (equivocation — first-occurrence on-chain admits only one fork).

The chain guarantees the **integrity** of the head; self-delivery is what guarantees the **availability** of the content behind it. As with all transport, a relay can withhold this record but can never forge or alter it (§4.1) — so self-delivery is a liveness precondition, never a trust assumption.

#### 4.2.1 Bundle blob encryption (ZBE, normative)

The control event (step 3) and the acknowledgement are small and use **NIP-44 v2** directly. NIP-44 v2 extended-length framing accepts plaintext through `2^32-1` bytes, but a **blob plaintext** — a `CoinProof` bundle or a `SelfDeliveryRecordV1` (typically ~100 KB) — belongs in the content-addressed Blossom/blob plane rather than in a large Nostr control event. It is therefore encrypted with **zkCoins Bundle Encryption (ZBE)**, whose chunked **ChaCha20-Poly1305** AEAD permits chunkwise authenticated processing, bounded memory, and blob-oriented framing and retry. NIP-44 v2 and ZBE do **not** use identical primitives: NIP-44 v2 uses ChaCha20 plus HMAC-SHA-256, while ZBE uses ChaCha20-Poly1305. ZBE is its own on-wire format, **not** a sequence of NIP-44 v2 messages. ZBE applies to the value-bearing, recipient-encrypted off-chain blobs (`CoinProof` and `SelfDeliveryRecordV1`). (The nullifier accumulator is rebuilt from the on-chain nullifiers alone, [§3.6](#36-chain-scanning), so there is no public, consensus-bearing off-chain blob that would have to be stored in plaintext for every scanner to read.)

The key derivation `kb` below is the fully spelled-out, single-argument instance of the general `HKDF(tag, material)` parameter mapping fixed in [§1.1](#11-cryptographic-primitives) (`material = K_tx`).

```
Inputs:  K_tx  (32-byte per-coin note key, §1.3)
         P     (plaintext blob = serialize(CoinProof bundle))

1. kb   = HKDF-SHA256(IKM = K_tx, salt = 32 zero bytes,     // 32-byte AEAD key
                      info = "zkCoins/v1/BlobKey", L = 32)   //   (RFC 5869; empty salt = 32 zero bytes)
2. split P into chunks P_0 .. P_{N-1} of CHUNK = 65536 bytes each
   (the final chunk P_{N-1} MAY be shorter; N = ceil(len(P)/CHUNK), N >= 1;
    an empty blob has N = 1 with a zero-length final chunk)
3. for each i in 0 .. N−1:
     nonce_i = 0x00000000 ‖ u64_be(i)                         // 12 bytes (4 zero ‖ 8-byte BE counter)
     aad_i   = "zkCoins/v1/Blob" ‖ u32_be(N) ‖ u32_be(i)      // binds total count and index
     C_i     = ChaCha20Poly1305_Seal(key = kb, nonce = nonce_i, aad = aad_i, plaintext = P_i)
              // C_i is P_i length + 16-byte Poly1305 tag
4. ciphertext = ZBE_MAGIC ‖ u32_be(N) ‖ (u32_be(len C_0) ‖ C_0) ‖ … ‖ (u32_be(len C_{N-1}) ‖ C_{N-1})
   where ZBE_MAGIC = ASCII "ZBE1" (4 bytes)
5. blob_id = H(ciphertext)                                    // SHA-256, the Blossom content address
```

Decryption reverses this: re-derive `kb`, parse `N` and the length-prefixed chunks, and `Open` each with the matching `nonce_i`/`aad_i`; **any** authentication-tag failure, a chunk count mismatch, or a missing magic **MUST** abort decryption (the blob is rejected, not partially accepted). The per-chunk AAD binds both the chunk's position and the total count, so a truncated or reordered ciphertext fails to authenticate. Because the same `kb` is used across a blob's chunks with a strictly increasing counter nonce, no `(key, nonce)` pair repeats within a blob; `K_tx` (hence `kb`) is unique per coin (fresh `epk`, §1.3), so it never repeats across blobs either. `kb` **MUST** encrypt at most one plaintext: a per-coin `K_tx` **MUST NOT** be reused to ZBE-encrypt a second, different `CoinProof` bundle plaintext, since that repeats `(kb, nonce_i)` against different data. ZBE is deterministic given `(K_tx, P)`, so two honest senders of the identical bundle under the identical key produce the identical `blob_id` (content-addressing is stable).

**Blob-size side channel (normative note).** ZBE adds framing and per-chunk tags but **no padding**: `len(ciphertext)` is a fixed function of `len(P)`. Every blob holder — the Blossom stores and any optional redundant holders ([§4.6](#46-data-availability)) — therefore learns the exact plaintext bundle length, and under the [§7.1](#71-serialization-conventions-normative) layout that length reflects the presence of the optional fields and the byte length of a carried `asset_terms.name`. Blob size can thus weakly distinguish bundles carrying issuance terms (typically an asset's first hop to a recipient, [§2.3.2](#232-send)) and, for an observer who knows candidate assets' name lengths, narrow down the asset — while still revealing no party, amount, `asset_id`, or plaintext byte. This is an accepted **residual leak** of the same class as the [§4.4](#44-note-discovery) privacy-tradeoff note: v1 mandates no bundle padding.

### 4.3 Addressing for delivery

The value-bearing destination is the zkCoins payment address `address = H(Pk₀ ‖ nk_commit)` ([Foundations §1.4](#14-identifiers-and-hashes)), fixed by seed-derived keys alone. A sender must additionally obtain the recipient's `IVPK` and a relay set to post to, and this section fixes how.

**Names (normative).** The API and app layers **MUST** provide every account they serve with exactly one active email-style **name** `<user>@<domain>`, resolve it as NIP-05, and publish the [§7.3](#73-nostr-event-kinds-normative) kind-0 `zkcoins` object under it. The kernel works from `op_pubkey`, `nprofile`, and `addr_sig`-carrying objects ([§6.1](#61-components-and-responsibilities) *Kernel and API — two boundaries*).

**Name consent (normative).** The account holder attests the name with the wallet-only key `sk₀`, so that a consumer can establish that the **seed holder** — and not merely whoever holds `op` — put this name on this identity:

```
name_message = H( "zkCoins/v1/NameConsent" ‖ network ‖ u32-be name_len ‖ UTF-8(name) ‖ op_pubkey )
name_sig     = BIP-340(sk₀, name_message)
```

`name` is the normalized lowercase identifier of *Identifier syntax* below; `network` is the same closed string as `zkcoins.network`; `op_pubkey` is the kind-0 author. `name_sig` travels in the `zkcoins` object and **MUST** be produced by the wallet — `op` is node-held ([§1.2](#12-key-hierarchy)), so an `op` signature over a name attests only that the node asserted it. The wallet produces it without user interaction when the name is set or changed. A name stays outside the seed derivation, outside `invoice_message`, and outside every value-bearing structure. It enters exactly two preimages: `name_message`, the only one in which the **seed holder** attests it, and the ordinary kind-0 event serialization that `op` signs. Neither carries payment authority.

A name **MUST** be replaceable; replacing it affects no key, no balance, and no established contact. It **MAY** come from the API layer that serves the account under its `wallet` feature ([§6.1](#61-components-and-responsibilities)), a self-hosted domain, or any third-party NIP-05 provider.

An amount-specific **`Invoice`** ([Foundations §1.5](#15-core-data-structures)) remains a valid direct payment object. It carries the recipient-published, `op`-signed transport fields:

```
Invoice = {
  amount, recipient: address, asset_id, memo?,   // Foundations §1.5
  pk0           : Pk₀,                             // recipient initial spend pubkey (x-only, 32B)
  nk_commit     : digest,                          // recipient nullifier-key commitment (32B); with pk0
                                                   //   forms the `recipient` preimage: H(pk0 ‖ nk_commit) == recipient (§1.4)
  ivpk          : IVPK,                            // recipient incoming-view pubkey = ivk·G
  op_pubkey     : op·G,                            // recipient operational/Nostr identity
  relays        : [relay_url, …],                  // recipient's advertised relay set (≥ 1)
  addr_sig      : BIP-340(sk₀, invoice_message),   // 64B; chains the address-holder to every field below
  sig           : BIP-340(op,  invoice_message)    // 64B; carries the per-issuance op authorisation
}

invoice_message = H( "zkCoins/v1/Invoice" ‖ amount ‖ recipient ‖ pk0 ‖ nk_commit ‖ asset_id ‖ memo
                   ‖ ivpk ‖ op_pubkey ‖ relays )
```

**Preimage framing (normative):** `amount` is 16-byte big-endian `u128`; `memo` is `u32-be length ‖ UTF-8 bytes` (length 0 when absent); `relays` is `u16-be count ‖` for each relay `u32-be length ‖ UTF-8 bytes`, in the listed order; all fixed-width fields use their §1.7.3 widths; the concatenation order is exactly as written above. Two invoices differing in any field yield different digests; no unframed variable-length field exists.

The two signatures' preimage is a **fixed concatenation** in exactly the order written in the `invoice_message` formula above — note that `pk0 ‖ nk_commit` precede `asset_id` there, deliberately diverging from the struct's field order; the formula, not the struct layout, is normative (the same fixed-concatenation discipline as `grant_message`, [Access & Explorer §5.2](#52-view-grant)); `H` and the input ordering are per [Foundations §1.4, §1.7](#14-identifiers-and-hashes). The optional `memo` contributes the empty byte string when absent, and `relays` is concatenated in its listed order. Reordering any field changes the digest and **MUST** be rejected. `serialize(fields)` is **not** used; only this explicit order is signed and verified.

The sender **MUST** verify, in order: (i) `H(pk0 ‖ nk_commit) == recipient` (so the named `pk0` and `nk_commit` are the actual address preimage, §1.4); (ii) `addr_sig` valid under `pk0` over `invoice_message` (proves the address-holder authorised these exact contents — `ivpk`, `op_pubkey`, `relays`, amount, asset, memo); (iii) `sig` valid under `op_pubkey` over `invoice_message` (carries the per-issuance authorisation by the recipient's online `op`). Any of these checks failing **MUST** reject the `Invoice`. Check (ii) is the **address ↔ rest binding**: without it, a party that observes the recipient's public `pk0` and `nk_commit` (both are published in the clear in any legitimate `Invoice` or profile) could publish a malicious `Invoice` claiming the legitimate `recipient`/`pk0` but with **their own** `ivpk`/`op_pubkey`, and the sender would encrypt the bundle to the attacker. `addr_sig` makes that forgery infeasible under BIP-340 EUF-CMA. The operational consequence is that **issuing an `Invoice` requires the wallet** (`sk₀` is SPEND-branch, wallet-only) — the same custody boundary that already governs sending. The per-issuance `sig` remains because the recipient's `op` is the online actor that signs the wire-format event the relay sees; it is not redundant with `addr_sig` operationally (one offline, one online).

An account served by the app or API layers publishes its delivery data as an additive `zkcoins` object inside the standard replaceable Nostr **kind-0 user-metadata event** authored by its `op` key ([§7.3](#73-nostr-event-kinds-normative)). A payer resolves it from the account's name without first obtaining an `Invoice`:

```json
{
  "name": "Alice",
  "nip05": "alice@example.com",
  "lud16": "alice@example.com",
  "zkcoins": {
    "version": 1,
    "network": "mainnet",
    "address": "zk1...",
    "pk0": "<32-byte lowercase hex>",
    "nk_commit": "<32-byte lowercase hex>",
    "ivpk": "<32-byte lowercase hex>",
    "relays": ["wss://relay.example.com"],
    "addr_sig": "<64-byte lowercase hex>",
    "name_sig": "<64-byte lowercase hex>"
  }
}
```

`op_pubkey` is the kind-0 event author and **MUST NOT** be duplicated inside `zkcoins`. The `lud16` field is present only when the same name supports the optional Lightning bridge; when it is present it **MUST** equal the normalized `nip05` value of the same profile, so one profile can never resolve to two different Lightning endpoints ([Lightning bridge](/lightning-bridge)). A profile whose `zkcoins` object is absent or invalid is not payable through that profile — the account remains payable by an `Invoice` it issues directly — and this **MUST NOT** disable NIP-17 messaging. An ordinary Nostr account that is not a zkCoins wallet simply has no such object.

For a profile, `addr_sig` uses the existing `invoice_message` with the profile-fixed values `amount = 0`, `asset_id` = the all-zero 32-byte value, and `memo` = empty; `recipient` is `zkcoins.address`, `op_pubkey` is the kind-0 author, and `pk0`, `nk_commit`, `ivpk`, and `relays` come from the `zkcoins` object. A sender **MUST** verify, in order: (i) `H(pk0 ‖ nk_commit) == address`; (ii) `addr_sig` under `pk0` over that profile-fixed `invoice_message`; (iii) the kind-0 event signature under its author `op_pubkey`; and, whenever the profile was reached by resolving a name, (iv) `name_sig` under `pk0` over `name_message` for that name (*Name consent* above). It **MUST** additionally require `version = 1`, the expected `network`, lowercase-hex fields of the stated widths, and at least one valid relay URL. Failing any profile check disables payment through that profile. Resolution by a raw `address` alone, with neither a valid `Invoice` nor a verified kind-0 `zkcoins` object, is not supported. The wire carrier that places a verified `Invoice` or a verified kind-0 event at the node for every non-self output is `OutputTemplate.delivery` ([§7.5](#75-node-rest-api-normative), [§7.8](#78-kernel-rpc--the-internal-interface-normative)); without it the node has no path from a bare address to `{ivpk, op_pubkey, relays}` and **MUST NOT** invent one. Delivery proceeds only through that credential, which the kernel alone verifies.

**Payment readiness and messaging readiness are separate (normative).** Payment resolution through a profile requires exactly the checks above plus the payment-identity pin check below — and **nothing else**. It **MUST NOT** be gated on a valid kind-10050 event, on NIP-17 readiness, or on any name resolving. Messaging readiness is the separate condition of [§7.3](#73-nostr-event-kinds-normative): a valid kind-10050 event with at least one retained endpoint. A recipient with a verified `zkcoins` object and no kind 10050 is payable and not yet messageable; a recipient with a valid kind 10050 and no `zkcoins` object is messageable and not payable through its profile.

Each published delivery event carries the per-coin `detect_tag` and `epk` as cleartext tags on the **outer** gift-wrap event (§4.2 step 4, [Foundations §1.3](#13-per-coin-keys-note-encryption--detection)) so the recipient can locate it by scan rather than by trial-decrypting every event.

**Recovery-discoverable overlap (both planes, normative).** Seed-only recovery ([§4.5](#45-recovery)) scans the network's signed `seed_relays` and fetches blobs from the network's `blob_stores` (the *Bootstrap manifest* below), all **global infrastructure independent of any single account's node**. A delivery has two planes — the small **control event** (the gift-wrapped kind-1059 carrying the blob **locator**, [§4.2 steps 3–5](#42-bundle-delivery)) and the value-bearing **blob** (the ZBE `ciphertext`, [§4.2 steps 1–2](#42-bundle-delivery)) — and recovery needs **both**. To make the seed-only scan complete, the **publishing node MUST place each artefact on the seed-discoverable set on both planes**, in addition to the recipient's advertised relays and its own store: it publishes each gift-wrapped delivery event (and each self-delivered `SelfDeliveryRecordV1`) to **≥1 of the network's `seed_relays`**, and it stores the artefact's blob in **≥1 of the network's `blob_stores`** (which accept recovery-overlap uploads from any node, [§7.4](#74-blossom-blob-store-normative)). A `seed_relay` retains only the event (the locator), never the blob bytes, which is why the blob duty is separate and equally mandatory. Both are a **fail-closed publisher duty**, enforced by the sending/self-delivering node from the network's signed Bootstrap Manifest it already holds — neither depends on which relays or stores the recipient advertised, so a minimal, missing, or self-only advertised set cannot defeat recovery. A recipient **MAY** additionally advertise relays/stores of its own for low-latency delivery; those are a performance choice, while the seed-discoverable copies are what the recovery guarantee rests on. The seed-discoverable copies add no cleartext: the gift-wrapped kind-1059 still carries only the two per-coin scan tags ([§4.2 step 4](#42-bundle-delivery)) and the blob stays ZBE-encrypted and content-addressed, so a seed relay or blob store learns nothing more about parties than any other holder ([§4.7](#47-metadata-and-privacy-tradeoffs); [§4.2.1](#421-bundle-blob-encryption-zbe-normative) blob-size side channel aside). **Boundary (honest).** The guarantee assumes the network's `seed_relays`/`blob_stores` are operated independently of the recovering account, as is the norm. A fully-sovereign operator whose *only* seed-discoverable copy sits on infrastructure it runs itself, and which it loses together with its database, falls back to the other redundancy layers ([§4.6](#46-data-availability)) and ultimately to the Tier-1 total-loss boundary ([§4.10](#410-responsibility-boundaries-and-the-availability-model-normative)). Recovery further assumes the recovering wallet can reach one node to fetch and verify the current signed manifest — its relay/store URLs come from a node's `GET /v1/info`, not from the seed; only the verifying `bootstrap_pubkey` is a pinned network parameter (*Bootstrap manifest* below) — and that **manifest rotation preserves recovery-discoverability**: a network **MUST NOT** delist a `seed_relay`/`blob_store` that still holds recoverable artefacts unless that retained corpus is first carried to a still-listed holder, so no artefact is ever orphaned on a delisted-but-live holder.

**Bootstrap manifest and peer discovery (normative).** A client that knows only a single node base URL still needs seed relays, blob stores, and alternative operators. Every network publishes a **per-network, signed, content-addressed Bootstrap Manifest** whose payload is **global and account-independent** infrastructure only:

```
BootstrapManifestV1 = {
  network,                          // "mainnet" | "testnet" | "regtest"
  protocol_version: "v1",
  seed_relays:     [relay_url, …],  // ≥ 1 seed Nostr relays
  blob_stores:     [base_url, …],   // ≥ 1 Blossom base URLs
  operator_ids:    [op_pubkey, …],  // configured operator trust-list entries
  issued_at, expires_at,            // unix seconds
  manifest_sig                      // BIP-340 over bootstrap_message by the pinned bootstrap pubkey
}

bootstrap_message = H("zkCoins/v1/BootstrapManifest" ‖ network ‖ protocol_version
                    ‖ seed_relays ‖ blob_stores ‖ operator_ids ‖ issued_at ‖ expires_at)
```

**Trust anchor — bootstrap public key (normative).** Each network pins a single **`bootstrap_pubkey`** (BIP-340 x-only, 32 bytes) in the frozen **network parameter set** ([§3.6](#36-chain-scanning) *Scan origin* / network parameters). That key is the **only** authority permitted to sign `BootstrapManifestV1` for that network. A conforming verifier **MUST**, in this order: (1) select the `bootstrap_pubkey` pinned for the network it operates on; (2) recompute `bootstrap_message` under the preimage framing below; (3) verify `manifest_sig` as BIP-340 under that pinned `bootstrap_pubkey` over `bootstrap_message`; (4) reject the manifest if the signature fails, if `network` / `protocol_version` disagree with the verifier's network, or if `expires_at < now` (when a clock is available). A self-signed or operator-signed manifest that does not verify under the **pinned** key **MUST** be rejected — there is no other trust root for bootstrap.

**`serialize(BootstrapManifestV1)` (normative) — preimage + content-address framing.**

```
serialize(BootstrapManifestV1) :=
  magic (4B ASCII "BMF1") ‖ version (1B = 0x01)
  ‖ u8 network_len ‖ UTF-8(network)                 // "mainnet" | "testnet" | "regtest"
  ‖ u8 protocol_version_len ‖ UTF-8(protocol_version) // "v1"
  ‖ u16-be seed_relay_count
  ‖ seed_relay_count × (u32-be url_len ‖ UTF-8(relay_url))
  ‖ u16-be blob_store_count
  ‖ blob_store_count × (u32-be url_len ‖ UTF-8(base_url))
  ‖ u16-be operator_id_count
  ‖ operator_id_count × op_pubkey (32B x-only each)
  ‖ issued_at (8B u64-be) ‖ expires_at (8B u64-be)
  ‖ manifest_sig (64B BIP-340)
```

Bounds: `seed_relay_count ≥ 1`, `blob_store_count ≥ 1`, `operator_id_count ≥ 1`; each URL length is at least 1 and at most **2048** bytes; `network` is exactly one of the three closed strings above; `protocol_version` is exactly `"v1"`. The **signature preimage** `bootstrap_message` uses the **same field framing and order as `serialize` from `network` through `expires_at`**, domain-separated as `H("zkCoins/v1/BootstrapManifest" ‖ <those framed bytes>)` — i.e. the framed body **without** `magic`/`version`/`manifest_sig`. `manifest_id = SHA-256(serialize(BootstrapManifestV1))` (the full serialisation **including** `manifest_sig`). A decoder **MUST** reject unrecognised `magic`/`version`, out-of-bounds counts/lengths, wrong-width `op_pubkey`/`manifest_sig`, or trailing bytes. The manifest is **mirrored** from every conforming node's `GET /v1/info` ([§7.5](#75-node-rest-api-normative)) so a wallet that dials one node learns the network's seed infrastructure (and still re-verifies under the pinned `bootstrap_pubkey`). Nodes **MAY** gossip signed **operator/endpoint records** (`OperatorEndpointV1 = { operator_id, base_url, relay_url, blossom_url, issued_at, expires_at, op_sig }` with `op_sig` over `H("zkCoins/v1/OperatorEndpoint" ‖ …)` under the operator's `op` key) so peers learn alternative endpoints without re-fetching the whole manifest; gossip is of **global operator infrastructure**, never of account- or blob-specific holders.

**Privacy (MUST — bootstrap / locator boundary).** **Only** the global, account-independent bootstrap seeds (and the operator/endpoint gossip above) are public. The protocol defines **no** deterministic public recovery identifier and **no** account- or blob-specific public holder gossip (either would be a stable recipient tag or a `blob_id ↔ operator` correlation). The account-specific **`BlobLocatorSet`** — **`holders` only** (ordered base URLs); the companion **`blob_id` always lives beside the set in context**, never inside it ([§7.1](#71-serialization-conventions-normative) `serialize(BlobLocatorSet)`) — lives **exclusively** in the **encrypted** interior of a `DeliveryEvent.payload` or a `SelfDeliveryRecordV1` blob ([§4.2](#42-bundle-delivery)) — never as a cleartext tag, public Nostr event field, or gossipable holder record. An optional **recovery manifest** (an encrypted hint listing account-local blob locators for seed recovery) **MAY** be published only as a **p-tag-less**, freshly gift-wrapped kind-1059 event with **no** stable public identifier and **no** deterministic `d` tag; recovery of that material runs through the [§4.5](#45-recovery) privacy-preserving full scan (K-B11), never through a public lookup key. Disclosure-link holder locators appear **only** in the opt-in URL **fragment** of [§5.6](#56-shareable-confirmation-links) (`;h=<locator>`), never as a public directory entry.

#### Names — NIP-05 `user@domain`

A name `<user>@<domain>`, such as `alice@example.com`, identifies the account's existing Nostr `op_pubkey` and resolves as a standard NIP-05 identity. It stands on its own: an SMTP mailbox or a Lightning bridge under the same string exists only when the operator runs that bridge ([§6.4](#64-external-interfaces-abstract)).

**One active name (normative).** An account has exactly one name in force at a time: the value in its kind-0 `nip05`, attested by the `name_sig` in the same profile. A client accepts that name and rejects a name the profile does not attest. Replacing a name means publishing a new kind-0 with the new `nip05` and a `name_sig` over it; keys, `address`, and pinned contacts stay as they are.

**Name loss (normative).** An account whose name stops resolving keeps its keys, `address`, ability to spend, retained conversations, and every pin a counterparty holds on it, and is unreachable under that name until it resolves again or another name is published.

**Identifier syntax.** Inputs are lowercased before validation and comparison, so `Alice@Example.com` normalises to `alice@example.com`. The canonical form — stored, displayed, and resolved — is lowercase. The local name uses only `a-z0-9-_.`, is non-empty, does not begin or end with `.`, and contains no consecutive dots; the domain is a DNS hostname. This is valid NIP-05 syntax and remains compatible with LUD-16.

**First discovery through NIP-05.** When the identifier is not known locally, the client performs the standard NIP-05 request (redirects **MUST NOT** be followed):

```text
GET https://<domain>/.well-known/nostr.json?name=<user>
```

The response maps `<user>` to a lowercase-hex Nostr public key. The standard `relays` attribute is recommended by NIP-05 but optional. A zkCoins-operated NIP-05 identity **MUST** publish at least one relay hint for its public key:

```json
{
  "names": {
    "alice": "<32-byte lowercase op_pubkey hex>"
  },
  "relays": {
    "<32-byte lowercase op_pubkey hex>": ["wss://relay.example.com"]
  }
}
```

The client forms one discovery set as the **union** of (a) every non-empty `relays[op_pubkey]` hint and (b) its already configured Nostr profile/discovery relays, including the Bootstrap Manifest's seed relays. It searches that whole set for the latest kind-0 and kind-10050 events by using ordinary NIP-01 filters for that author and kind; the two valid events may come from different relays. It introduces no custom endpoint, kind, tag, NIP-65 requirement, or zkCoins capability metadata. The client verifies the kind-0 signature under `op_pubkey` and checks whether its `nip05` field equals the normalized name (the reverse NIP-05 check). It verifies kind 10050 under the same author and requires at least one valid `relay` tag.

The two outcomes are scoped differently; per [NIP-05](https://nips.nostr.com/5) the public key, not the name, is the primary reference:

- **Reverse check fails, name not yet associated with a known key.** The client **MUST NOT** adopt the name or contact the key; the resolution fails closed, with no SMTP or NIP-04 fallback.
- **Reverse check completes and disagrees, name already associated with a pinned `op_pubkey`.** This covers a resolution that answers — a 404, or a `nip05` that no longer matches — and **not** a lookup that fails to complete, which is inconclusive and changes nothing (`M-16b`). The client **MUST** keep the contact, its conversation, and its pinned payment identity, **MUST** stop presenting that name, and **MUST NOT** delete, merge, or re-point the contact, nor treat messaging or payment as unavailable while retained transport serves. A name now mapping to a different key is a different contact and **MUST NOT** replace the pinned one.
- **No valid kind-10050 event.** NIP-17 fails closed, with no SMTP or NIP-04 fallback; payment resolution is unaffected (*Payment readiness and messaging readiness are separate*, above).

While DNS is available for first discovery, the client **MUST** actually connect to the relevant profile/discovery relays and every kind-10050 relay it intends to retain; storing URL strings without a successful Nostr WebSocket connection is insufficient. It constructs a standard NIP-19 `nprofile` containing only `op_pubkey` and at least one relay URL that actually returned a valid relevant kind-0 or kind-10050 event from the union above. A NIP-05 hint that returned no valid relevant event **MUST NOT** become an `nprofile` relay hint merely because it appeared in the HTTP response. The client then retains the contact and local transport state below.

**Known-contact storage and DNS-resistant resolution.** The retained contact record is **keyed by `op_pubkey`** — the seed-derived, permanent value — and never by a name. The record's **current** name is a single attribute — the one name in force (*One active name* above) — implemented as a **current/active pointer** over retained name history. A record **MUST** retain every superseded name indefinitely as inactive audit data (Data Permanence, [Requirement 12](/requirements#12-data-permanence), [§4.8](#48-durability--the-store-everything-invariant)); superseded names **MUST NOT** be presented or resolved as current. Nothing received is deleted or overwritten — only the active pointer moves. The record therefore splits along the kernel/API seam ([§6.1](#61-components-and-responsibilities)): the **kernel** holds everything addressed by key — the key itself, the `nprofile`, the DM relays (each list retained indefinitely, with a separate current/active pointer), the retained transport endpoints, and the payment-identity pin — while the **name attributes** and their reverse-check state belong to the layer that resolved them, the API layer or the app. After a successful first discovery the client **MUST** retain, across those two layers, at minimum:

- `op_pubkey` — the record key;
- the contact's current normalized name and the outcome of its last reverse check and `name_sig` verification;
- the NIP-19 `nprofile`, including its relay hints;
- the last known valid kind-10050 DM relays;
- for every retained profile/discovery, kind-10050 DM, and `zkcoins.relays` URL that has been reached, the last successfully used resolved network endpoint (IP address and effective port), keyed by the original relay URL;
- the last valid, three-check-verified kind-0 `zkcoins` object, when present — retained, not merely cached, with its payment-identity fields `{address, pk0, nk_commit, ivpk}` pinned (*Payment-identity pinning* below); `relays` remains silently updatable.

The endpoint mapping is local transport state, not part of `nprofile`, a Nostr event, or any public protocol field. A client **MUST** add or update an endpoint only after both (a) a successful TLS connection authenticated for the relay URL's original hostname and (b) a successful WebSocket relay upgrade on that original URL's path. When dialing the retained IP directly, it **MUST** preserve the original scheme, hostname, effective port, and path, including the hostname for TLS SNI, certificate verification, and the WebSocket `Host` value. It **MUST NOT** disable TLS verification, accept a certificate for the IP address in place of the original hostname, weaken WebSocket origin/host checks, or retain an endpoint after TLS alone when the relay upgrade/path failed.

Resolution is therefore exactly:

```text
if op_pubkey is known directly (contact record, nprofile, Invoice):
    use the record's relay hints, DM relays, and TLS-and-WebSocket-validated
    IP endpoints directly; do not call DNS or NIP-05
else if a name was supplied and it already maps to a known record:
    use that record as above; do not call DNS or NIP-05
else:                                    # a name not yet associated with a key
    resolve the name through NIP-05
    search the union of NIP-05 hints and configured discovery/bootstrap relays
    fetch and verify kind 0 and kind 10050; complete the TLS-authenticated
    WebSocket relay upgrade on the relevant original URLs and paths
    create or extend the record keyed by op_pubkey; attach the name,
    the nprofile, relay hints, DM relays, successful endpoints,
    and any valid zkcoins object
    continue through Nostr
```

The kernel messages and pays a counterparty by key. An application resolves a name before presenting a contact ([Implementation Mandate](/implementation-mandate#app-layer-identity-and-contacts-normative)). A name verified later **MUST** be attached to the existing record.

For a known recipient, normal messaging, profile refresh, and the cold-start fallback **MUST NOT** make a DNS or NIP-05 request. One narrow exception exists, and only for display: when a verified profile under the pinned `op_pubkey` announces a **different** `nip05`, the client **MAY** make a single forward NIP-05 request to revalidate that new name (*Name changes* below). Nothing depends on its outcome — messaging, payment, and transport continue by the pinned key whether it succeeds, fails, or never completes — so this exception introduces no DNS dependency for anything but a label. The client connects through retained IP endpoints while authenticating the original URL host as above. It may fetch newer kind-0 and kind-10050 events through those connections and accepts updates only when their signatures verify under the already-pinned `op_pubkey`; which fields such a verified kind-0 event may silently update, versus which require confirmation, is stated once in *Payment-identity pinning* below. Updated kind-10050 tags advance the **current/active** pointer for the DM relay list only after the client successfully connects and retains at least one endpoint for every newly adopted relay URL it needs for delivery — every previously stored list **MUST** remain retained indefinitely and is merely no longer presented as current (Data Permanence, [§4.8](#48-durability--the-store-everything-invariant)); updated, valid `zkcoins.relays` follow the same rule (append the new value, move the active pointer; never overwrite or discard the prior stored set). A signed rotation solely to previously unknown hostnames cannot be used without DNS and **MUST NOT** discard the last usable retained set. A DNS answer, if obtained during an explicit user-requested revalidation, **MUST NOT** silently replace a pinned public key; changing the key requires a warning and explicit user confirmation.

**Payment-identity pinning.** On first successful verification of a contact's kind-0 `zkcoins` object (the three checks above), the client **MUST** pin, alongside `op_pubkey`, the zkCoins payment identity `{address, pk0, nk_commit, ivpk}` (trust-on-first-use, the same discipline as the pinned public key above). A later kind-0 event that verifies under the pinned `op_pubkey` **MAY** silently update only `zkcoins.relays`, exactly as above; it **MUST NOT** silently change `address`, `pk0`, `nk_commit`, or `ivpk`. A valid signature under the pinned `op_pubkey` is **not** sufficient to change these fields — the holder of `op` is not necessarily the holder of the payment address ([§6.1](#61-components-and-responsibilities), [§6.6](#66-threat-model-and-trust-configurations)), and a hosted provider or compromised node holding `op` could otherwise publish its own `zkcoins` object under the same `op_pubkey` and silently redirect every future payment. A kind-0 event whose `zkcoins` object differs from the pinned `address`, `pk0`, `nk_commit`, or `ivpk` **MUST** raise a warning and **MUST NOT** be adopted silently; adopting it requires explicit user confirmation, exactly as for a changed public key. The pin binds the contact's payment identity, not a particular carrier object: an `Invoice` (above) whose `sig` verifies under a **pinned** `op_pubkey` **MUST** additionally be checked against that contact's pinned `{address, pk0, nk_commit, ivpk}`, matching `recipient` against the pinned `address`; a mismatch **MUST** raise the same warning and **MUST NOT** be paid silently — proceeding requires explicit user confirmation, exactly as for a changed profile. The reason: `addr_sig` proves only that *some* address-holder authorised the `Invoice`'s contents, never that it is the same address-holder the sender pinned. An `Invoice` from a party the sender has **not** pinned (no pinned `op_pubkey` matching its `sig`) is unaffected by this check and remains a valid direct payment object under the checks (i)–(iii) above alone — first contact is not an error. A **publisher profile** (kind 30421) is **not** pinned and **MUST NOT** be compared against a contact's pinned payment identity, even when its author equals a pinned `op_pubkey`. In v1 it carries no payment identity at all ([§7.3](#73-nostr-event-kinds-normative)), and one identity may legitimately act both as a correspondent and as a publisher; a client that pinned it would warn on every ordinary publisher update. The pin is part of the retained known-contact state ([§6.1](#61-components-and-responsibilities)) and is **not** derivable from the seed; a node switch ([§6.3](#63-node-portability-and-multi-node-operation)) or a recovery that rebuilds state from the seed alone starts a contact's pin over at first use. A client that has lost its pin set (node switch, reinstall, or emergency recovery per [§4.5](#45-recovery)) **MUST** treat a contact for which it holds no pin as first use, and **MUST NOT** present that contact as previously verified. When the client has any surviving evidence that it had transacted with that identifier before (a retained contact entry or a completed payment in its own history) and no pin to compare against, it **MUST** warn before the first payment that the payment identity could not be checked against an earlier one. The node operator's own durable backup ([§4.5](#45-recovery) primary recovery path) **SHOULD** include the pin set, so that the ordinary (primary) recovery path preserves the pins and only the emergency fallback path loses them. This pin-loss residual is named in [§6.3](#63-node-portability-and-multi-node-operation).

**Name changes (normative).** Pinning covers `op_pubkey` and the payment identity above. A verified kind-0 event under the pinned `op_pubkey` whose `nip05` differs from the stored name **MAY** be adopted once its `name_sig` verifies under the pinned `pk0` **and** a forward NIP-05 resolution of the new name returns that same pinned `op_pubkey`; the client then advances the **current/active** name pointer to the new name while **MUST**-retaining every superseded name indefinitely as inactive audit data (Data Permanence, [§4.8](#48-durability--the-store-everything-invariant)) — nothing is deleted or overwritten; only which name is presented as current changes. The pinned keys, the payment identity, the conversation, and retained transport remain as they are. Until that resolution succeeds the client **MUST NOT** present the new name **and MUST NOT** keep presenting the old one: a verified profile under the pinned `op_pubkey` announcing a different `nip05` retires the previous name from **current** presentation immediately (the value stays stored), and the contact is shown in an explicit **unresolved** state until a forward lookup confirms one. Presenting the superseded label would be worse than showing none — an attacker who makes the lookup impossible, rather than making it fail, would otherwise hold the contact on a name its holder may no longer control. Messaging and payment continue by the pinned key throughout, so this costs a label and never reachability. A profile whose `name_sig` fails keeps the current name pointer where it is.

**What `name_sig` proves, and what it does not (normative).** It proves that the seed holder consented to this name for this `op_pubkey`. That consent is **permanent and cannot be withdrawn** ([§5](#5--access--explorer) *Consent is one-way*), so a valid `name_sig` is **not** evidence that its name is the account's current one: an old attestation stays verifiable forever, and a node holding `op` may republish it. Currency comes from resolution, not from signatures — which is why adopting a changed name requires the forward check above, and why this specification defines no name-consent revocation, sequence number, or expiry. A consumer whose lookup **cannot complete** keeps the last name it confirmed, since no answer was received; a lookup that completes and disagrees stops presentation under the reverse-check outcomes above. Either way, once a newer profile has superseded the name, the unresolved state described above applies. A host that withholds newer profiles is an availability limit no signature scheme closes, and it is not treated as one here. A name that now maps to a **different** public key belongs to a different contact, per the reverse-check outcome above.

Changing the name means republishing kind-0 with a new `nip05` and `name_sig`; the object's payment fields and their `addr_sig` stay as they are, since `addr_sig` covers no name.

A directly supplied valid `nprofile` can be used and retained without DNS. Until a matching NIP-05 identity has separately been established, it identifies the contact by public key rather than proving an email-style identifier.

**DNS outage behavior.** During a DNS outage, a known contact remains reachable after a cold start only if at least one previously successful retained endpoint for the required relay set still serves under the original hostname's valid TLS certificate and completes the Nostr WebSocket upgrade on the original URL path. The node loads only its persistent contact/transport state, dials the retained IP, preserves the original scheme/host/port/path, and makes no DNS or NIP-05 request. A relay outage, expiry of every applicable certificate, failure of every retained WebSocket relay path, or a signed relay rotation solely to wholly unknown hostnames is outside what Nostr can guarantee and makes that path unavailable until a usable endpoint or DNS returns. An unknown email-style identifier cannot be discovered until NIP-05 is reachable, unless the user supplies an `nprofile` directly; even then, DNS-free use requires a previously retained endpoint or an explicitly supplied reachable transport endpoint that passes the same original-hostname TLS and WebSocket-path checks. Lightning Address/LNURL resolution may be unavailable; that does not affect a known NIP-17 contact whose retained relay endpoint still serves.

**Trust and portability.** NIP-05 first discovery is a name-to-key binding; what is pinned on first successful use is the **key**, not the name. The `addr_sig` separately binds the discovered Nostr key and zkCoins delivery fields to the payment address through the three checks above. A name appears in no value-bearing structure and in no payment-authorising preimage. It enters `name_message`, where the seed holder attests it, and the kind-0 event serialization signed by `op`; neither grants payment authority. Funds remain on `address`, and loss of a domain can impair first discovery through that name but cannot spend or destroy funds, invalidate a key, or unpin a contact. Naming the account under a second domain is not a remedy either, since one name is in force at a time (*One active name* above): first discovery through a lost domain is lost until the holder publishes a new name and communicates it out of band. Domain loss does not break a known contact while at least one retained, original-hostname-authenticated TLS endpoint still completes the relay WebSocket upgrade on its original path; it does not guarantee availability beyond that explicit boundary.

**One name, independent optional bridges.** A name and NIP-17 messaging are both mandatory; what stays optional is each bridge. A name may independently support either, both, or neither:

- Lightning/LNURL: kind-0 includes `"lud16": "alice@example.com"` and the domain serves `https://example.com/.well-known/lnurlp/alice`;
- SMTP/email: the domain accepts ordinary email for `alice@example.com`.

Disabling either bridge **MUST NOT** disable NIP-05 identity, NIP-17 messaging, or native zkCoins delivery. A receive QR may encode the shared identifier; it never needs to expose a raw `zk1…` address or bare `lnurl1…` value.

### 4.4 Note discovery

A recipient (or its always-on node, holding `ivk`) finds its own incoming bundles as follows:

1. The recipient (or its always-on node) holds `ivk` ([Foundations §1.2](#12-key-hierarchy)); `ivk` itself is the detection capability — there is no separate detection key.
2. Pull candidate delivery events from its relay set. The relay **cannot** pre-filter for the recipient (it holds neither `ivk` nor the sender's `esk`), so the recipient — holding `ivk` — performs the match itself: for each candidate's outer `zkepk` tag ([§4.2 step 4](#42-bundle-delivery)) it computes `ss = ECDH(ivk, epk)`, then `Hc("zkCoins/v1/DetectTag", ss ‖ epk)`, and checks it against the outer `zkdt` tag. A match selects the event as the recipient's; a non-match is discarded after one ECDH and one Poseidon hash, with no unwrap attempt, no AEAD work, and no blob fetch.
3. For each matched candidate, unwrap the gift wrap and seal (two NIP-44 decryptions — incurred **only** on a match) to read `blob_id`, derive `K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk)` ([Foundations §1.3](#13-per-coin-keys-note-encryption--detection)), fetch the blob by `blob_id`, and **decrypt** with `K_tx` under ZBE ([§4.2.1](#421-bundle-blob-encryption-zbe-normative)). Successful ZBE authentication confirms the coin is the recipient's.
4. Verify the decrypted bundle against Bitcoin (§4.5) before accepting it.

**Privacy tradeoff (normative note).** Because every coin uses a fresh `epk`, each recipient's events carry **all-distinct** `detect_tag`s ([Foundations §1.3](#13-per-coin-keys-note-encryption--detection)): a tag does not link two of one recipient's coins, and a relay that holds neither `ivk` nor the sender's `esk` can **neither** filter for the recipient **nor** correlate the recipient's events. The residual cost is therefore not linkability but **bandwidth and per-event work**: detection is not server-side filterable, so the recipient pulls the candidate set in full and pays one ECDH plus one Poseidon hash per scanned event (the full AEAD decryption and the blob fetch are incurred only on a match). **Fuzzy message detection** (probabilistic per-coin tags with tunable false-positive rate) is a **future-version (not in v1) scan-efficiency upgrade** that lets a relay return a smaller candidate set without learning who the recipient is; it changes only the tag computation and the scan filter and **MUST** leave every other interface in this page unchanged. It does **not** repair a linkability the deterministic scheme does not introduce.

### 4.5 Recovery

The seed is the **only** required backup ([Requirement 6](/requirements)). Recovery has two paths, in strict priority order:

- **Primary — the node operator's own backup.** The operator **MUST** maintain a real-time restorable backup of the node's local state and bundle store ([§4.8](#48-durability--the-store-everything-invariant) *Operator durability duty*); restoring from it is the normal path and requires no network and no re-verification beyond integrity checks.
- **Emergency fallback — network reconstruction.** After total loss of local data, the complete spendable state is rebuilt from the seed, the public Bitcoin chain, and the bundles retained by other nodes under Data Permanence ([§4.8](#48-durability--the-store-everything-invariant), [§4.6](#46-data-availability)).

The fallback procedure is fully deterministic and trustless:

1. **Re-derive keys and enumerate accounts.** From the seed, re-derive each account root `A` under the **dense, monotone** assignment of [§1.2](#12-key-hierarchy) and thereby `ivk`, `ovk`, `op`, the nullifier key `nk`, `op_secret` (the conditional-NAV randomness key, §1.4), and the spend keys. For `account' = 0, 1, 2, …` derive `Pk₀(account)` and stop at the first index whose `Pk₀` has **never** been published on Bitcoin; a gap of at most **20** consecutive `pending`-only genesises **MAY** be bridged, but a never-published index is always a hard stop. This dense scan is the **sole normative truth** of which accounts exist under the seed — neither account index nor a "previous account" reference is ever on-wire or on-chain. An optional encrypted recovery-manifest hint ([§4.3](#43-addressing-for-delivery)) **MAY** accelerate discovery but **MUST NOT** replace the dense scan. Per account, this step restores the value-bearing payment identifier (`address = H(Pk₀ ‖ nk_commit)` with `nk_commit = Hc("NkCommit", nk)`, §1.4), decryption ability, the detection capability (`ivk`), and — via `op_secret` — the deterministic `nav_rand` needed to rebuild prior conditional-NAV openings. NIP-05 remains the public human/Nostr identity and is not seed-derived.
2. **Rebuild the nullifier accumulator from Bitcoin alone (given the pinned network parameters, §3.6).** Scan Bitcoin for zkCoins nullifier inscriptions (marker `0x42 0x42`, [§3.5](#35-inscription-format)), verify each nullifier's signature over the per-network fixed constant `m_state` for the network the scanner operates on ([§3.2](#32-transition-signing-bip-340--sign-to-contract)), and fold each fresh `Pkᵢ` into the global **nullifier accumulator** by **first-occurrence** in canonical order ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure), [§3.6](#36-chain-scanning)). The accumulator is a **pure function of the on-chain nullifiers** — no off-chain object and no trust in any peer is involved — so this step needs **only** Bitcoin and reconstructs the identical accumulator every honest node holds. The operator can privately recognise its **own** transitions' rotating keys `Pkᵢ` (re-derived from the seed) among the published nullifiers, while the publisher and any third party cannot link them.
3. **Privacy-preserving recovery search (paginated full scan — normative).** Opaque blob replicas and foreign relays **cannot** map an `OwnershipProof(subject)` onto encrypted records they cannot decrypt: there is **no** stable public recipient tag and **no** account-keyed public index ([§4.3](#43-addressing-for-delivery) privacy boundary). Recovery discovery is therefore a **paginated full scan** over kind-`1059` gift-wrap events on the seed-relay set (and any additional relays learned from the [§4.3](#43-addressing-for-delivery) bootstrap manifest), until each subscription reports **`EOSE`** (NIP-01 end-of-stored-events). For every candidate the recovering client runs the local [§4.4](#44-note-discovery) `ivk` match (`ss = ECDH(ivk, epk)`, `detect_tag` check) and **fetches the blob only on a match** — non-matches incur one ECDH + one Poseidon hash and no blob fetch. Pagination **MUST** use ordinary NIP-01 filters (`limit` + `since`/`until`) so a memory-bounded client can cover the relay's retained history. NIP-01 provides **no** exclusive `(created_at, event_id)` resume cursor — `ids` is a positive filter only — so if more than `limit` events share an identical second-granularity `created_at`, advancing `until` alone can skip events and leave a needed `SelfDeliveryRecordV1` undiscovered. The recovering client **MUST** therefore execute the following **gapless scan algorithm**, which sees every event exactly once even under a same-second tie flood: (i) scan newest-first with `until = <now>`, page size `limit = L` (positive implementation bound), and **deduplicate globally by `event.id`** (each event is processed at most once); (ii) the client **MUST NOT** lower `until` under any reached timestamp `t` until it has **proven** that every event at `created_at == t` has been seen — whenever the newest-first scan is about to advance past a reached `created_at = t`, it **MUST** first **fully drain** `t`. Drain is **not** gated on a page returning exactly `L` events (NIP-01 **MAY** return fewer than the requested `limit`); it is required whenever the scan is about to step under `t`. **Full drain** means a **limit-free** follow-up query `since = t, until = t` that the relay serves **in full**, with global `event.id` deduplication (over-fetch at the second boundary is idempotent). **Fail-closed:** if a relay cannot serve that limit-free full delivery at `t` (it caps the response and repeatedly returns only the same subset), the client **MUST** treat `t` as **incomplete** — it **MUST NOT** advance to `until = t − 1`. It **MUST** fall back to other seed-/learned relays and/or an optional exclusive `(created_at, event_id)` cursor relay extension when available; if full drainage succeeds on **no** reachable relay, recovery **MUST** be reported **incomplete** (fail-closed) and **MUST NOT** silently skip `t`. Only after proven full drainage of `t` **MAY** the client continue with `until = t − 1`; (iii) the scan **MUST** end when `until` falls below the earliest possible account timestamp, or when a full relay round at the current `until` yields no new `event.id` and every reached same-second boundary has been proven fully drained. The limit-free same-second boundary drain above remains the **binding baseline** against plain NIP-01; a cursor extension is an optimisation only. The protocol defines **no** new stable recipient tag for recovery.
4. **Account-scoped `/v1/pull` is local-index only.** A capability-gated `POST /v1/pull` ([§5.1](#51-capability-gated-pull), [§7.5](#75-node-rest-api-normative)) returns Private records **only** for a node that has **itself** decrypted and indexed the subject's events under the operational bundle (or a still-valid view grant). Opaque blob replicas that never held `ivk` **MUST NOT** invent an ownership→record mapping: they offer exclusively **enumeration/fetch by locator** (`GET /blossom/<blob_id>`, [§7.4](#74-blossom-blob-store-normative)) once the client already holds a `blob_id` from a matched delivery or from an encrypted `BlobLocatorSet` inside a recovered record. A foreign node that the wallet has **not** entrusted (no bundle, no grant) therefore contributes only as an untrusted Blossom cache, never as an account index.
5. **Verify each recovered artefact against Bitcoin.** For every matched incoming `CoinProof` bundle, the node **MUST** independently run the [§2.3.3](#233-receive) receive checks: verify the recursive per-account proof and open its `nav_commitment` (checking `nav` is a **canonical** accumulator value on the node's own scan, [§2.3.3 step 2](#233-receive), [§3.9](#39-finality-and-reorg-handling)); verify the coin's inclusion in the committed `output_coins_root`; and verify the creating transition's on-chain nullifier `(Pk_create, R_create)` is the **first occurrence** in the rebuilt accumulator with `R_create` opening `H(creating ProofData)` **and `Pk_create == creating_proof.consumed_pubkey`** (the in-circuit clause 10(d) key binding, [§2.1 clause 9](#21-the-compliance-predicate), inherited here via the re-run [§2.3.3 step 4](#233-receive) receive checks) — a mint coin is no exception: its creating transition is the mint, which anchors its own nullifier on Bitcoin and is checked by the same first-occurrence rule ([§2.3.1](#231-mint--issuance), [§3.10](#310-transaction-states)). For every matched **`SelfDeliveryRecordV1`** ([§4.2](#42-bundle-delivery)), apply the §4.2 replay checks (`prev_state_head`, `ash`, proof head, first-occurrence of `own_nullifier`, `occurred_at` consistency). A bundle or record failing any check **MUST** be discarded. A node can only **withhold**, never forge — correctness is guaranteed by the chain and the per-account recursive proofs.
6. **Rebuild `AccountState` and balances.** Sort and replay accepted `SelfDeliveryRecordV1` objects strictly by `send_counter` ([§4.2](#42-bundle-delivery) replay rule), selecting the uniquely highest verified head; fold any verified incoming coins not yet present in that head by re-running the receive transition ([§2.3.3 step 7](#233-receive)) against the nullifier accumulator rebuilt in step 2. The result reconstructs per-asset `balances`, the coin-history SMT, `current_pubkey`, and `send_counter` ([Foundations §1.5](#15-core-data-structures), [Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure)); the latest recovered recursive proof is the lineage head the next transition extends.

The coin **values** of incoming coins are choices others made; they exist only in the `CoinProof` bundles and cannot be derived from the seed or a hash. They come back solely through steps 3–5 — which is why Data Permanence ([§4.8](#48-durability--the-store-everything-invariant)) — permanent retention by sender and every holder, with optional redundant copies ([§4.6](#46-data-availability)) — is a precondition for the emergency path. The **nullifier accumulator**, by contrast, needs only Bitcoin (step 2): it is a pure function of the on-chain nullifiers, so its reconstruction has **no** off-chain DA dependency at all. Asset ids fall out of the coins themselves; only the human-readable asset `name` is external and never recoverable from the chain — it comes back inside recovered bundles whose sender attached `asset_terms` ([Foundations §1.5](#15-core-data-structures)), from the issuer, or — once a holder has the `asset_id` — openly from any holder that has retained them via the Class-B `asset_id → terms` lookup ([§4.6](#46-data-availability), [§7.5](#75-node-rest-api-normative)).

**Why the seed-only scan is complete (normative).** The [§4.3](#43-addressing-for-delivery) recovery-discoverable overlap guarantees that every delivery and self-delivery addressed to the account has its event retained on at least one `seed_relay` and its blob on at least one `blob_store` in the network's signed Bootstrap-Manifest set. That manifest is **not** itself derived from the seed — its `bootstrap_pubkey` is a pinned network parameter, but its relay/store URLs are learned by fetching `GET /v1/info` from any one reachable node and verifying the manifest under that pinned key ([§4.3](#43-addressing-for-delivery)). A recovering wallet therefore needs the seed **and** any one reachable node base URL (the wallet app typically bundles or the user configures one); from there it fetches and verifies the current signed manifest and scans exactly those relays (step 3), so it finds every artefact addressed to it that a live, reachable holder in the seed-discoverable set still serves — kept complete by the [§4.3](#43-addressing-for-delivery) rotation-continuity rule — even after the total loss of its own database **and** its own paired relay. This is zkCoins' form of asking the network for one's data: like a Bitcoin node that serves any block on request, the seed-discoverable relays and blob stores serve every retained artefact to whoever scans them, and the sender's node — having placed both the event and the blob on the seed-discoverable set under the overlap rule — is by construction one of the holders that keeps the artefact recoverable. zkCoins deliberately keeps **no** public directory of "all nodes" and **no** gossip of who holds which account's data ([§4.3](#43-addressing-for-delivery): "no account- or blob-specific public holder gossip"), because such a directory would be exactly the holder-linkability the protocol avoids; recovery therefore targets the seed-discoverable relay set, which the overlap rule makes sufficient, rather than an intentionally-nonexistent global node enumeration.

**Custody during recovery ([Requirement 5](/requirements)).** Rebuilding a node never relocates custody. The wallet re-derives the full key tree from the seed (step 1), but hands the freshly-rebuilt node only the **operational bundle** `{ivk, ovk, op, nk, op_secret}` ([Foundations §1.2](#12-key-hierarchy), [§6.2](#62-wallet--node)); the **seed** and the **SPEND branch** (`skᵢ`) are re-derived and retained **wallet-side** and never leave the wallet — exactly as in normal operation. The emergency path restores the node's *view-and-serve* capability, not spend authority, so [Requirement 5](/requirements) holds unchanged through recovery.

### 4.6 Data availability

There are **two** off-chain object classes carrying value or spendable state — the `CoinProof` bundle (per coin, value-bearing) and the `SelfDeliveryRecordV1` (per transition, fully replayable account head, [§4.2](#42-bundle-delivery)). The nullifier accumulator is **not** an off-chain object: it is a pure function of the on-chain nullifiers ([§3.6](#36-chain-scanning)–[§3.7](#37-the-nullifier-accumulator)), rebuilt by every node from Bitcoin alone with no data-availability assumption at all.

**Availability follows from Data Permanence plus recovery-discoverable placement.** Every holder **MUST** retain its copy of every received artefact indefinitely ([§4.8](#48-durability--the-store-everything-invariant)), and the [§4.3](#43-addressing-for-delivery) recovery-discoverable overlap places each artefact's delivery event on ≥1 network `seed_relay` and its blob in ≥1 network `blob_store`, so a seed-only recovery finds both the locator and the bytes (under the §4.10 operational conditions). Further redundant copies at other nodes only increase durability; they are **not** a quorum, authorise **no** local discard, and create **no** counting or receipt machinery — no fixed replica target, no durability-receipt object, and no trust-list receipt counting.

**Encrypted network redundancy (normative — the second availability layer).** A node's value-bearing artefacts **MUST NOT** live only in its local database. Every node **MUST** ensure that each value-bearing artefact it holds — every `CoinProof` bundle and every `SelfDeliveryRecordV1` — remains available, in its already-encrypted form, on the **Nostr/blob plane** (its paired relay and Blossom store, [§4.1](#41-roles-and-transport), [§7.4](#74-blossom-blob-store-normative)), so the encrypted corpus is redundant with the database rather than captive to it. This re-uses the delivery encryption unchanged (ZBE blobs and gift-wrapped events, [§4.2](#42-bundle-delivery)); it exposes **no** new plaintext and introduces **no** counting, quorum, or receipt object. Any system participant who does not wish to trust a particular node's availability **MAY** operate their **own** Nostr relay and Blossom blob store and subscribe to and retain whichever encrypted artefacts they consider important — a self-custodied copy of the availability they depend on, across both planes, without any node's cooperation beyond ordinary relay and blob serving.

**Two serving classes (normative).** Recovery and serving distinguish two disjoint data classes:

- **Class A — recipient-private** (a subject's own incoming `CoinProof` bundles and `SelfDeliveryRecordV1` records). Served on the two existing paths, **neither authenticated-to-a-foreign-index**: (i) the **anonymous** recovery scan of the retained kind-1059 corpus on the seed-discoverable relays ([§4.5](#45-recovery) step 3), made complete by the [§4.3](#43-addressing-for-delivery) overlap rule and revealing **no** requester identity (the `ivk` match is client-side, [§4.4](#44-note-discovery)); and (ii) the **ownership- or grant-authenticated** indexed pull from a node that has itself decrypted the subject ([§7.5](#75-node-rest-api-normative) `POST /v1/pull`, [§4.5](#45-recovery) step 4). A foreign node that never decrypted the subject serves **neither** an index nor a filtered view — only opaque blobs by locator and the raw event corpus, exactly as [§4.5](#45-recovery) step 4 already mandates. No new authenticated endpoint is introduced.
- **Class B — issuer-originated token provenance** (a token's issuer-originated `asset_terms` — its `IssuanceTerms` display/definition preimage, [§6.5](#65-issuance--token-standards), [Foundations §1.5](#15-core-data-structures) — carried only inside bundles that attach it, so held by some, not necessarily all, of a token's holders). Access is **open**: any node holding a token's `asset_terms` **MUST** serve them by `asset_id` to any requester ([§7.5](#75-node-rest-api-normative) `GET /v1/token/<asset_id>/provenance`). Openness is required — a self-issued token whose issuer has vanished must remain transferable by its holders (from its own bundle and the chain) and displayable by any holder that has retained the terms — and is sound because Class B is the **self-verifying** `IssuanceTerms` preimage only: the requester recomputes `asset_id` from the served terms and rejects any mismatch ([§6.5](#65-issuance--token-standards) mint clause (c)), so a lying holder cannot inject false terms. Class B **MUST NOT** include any private transfer record, foreign `CoinProof` plaintext, holder, amount, or anything revealing who transferred what to whom; the ZK transfer graph is never Class B. This open `asset_id → terms` lookup is a deliberate v1 addition; the residual that it makes an asset's `name`/terms resolvable by anyone holding its `asset_id` (from any holder that has retained the terms) is registered in [Risks](/risks) (it does **not** add a `name → asset_id` registry — that remains a non-goal, [§6.5](#65-issuance--token-standards) *IssuanceTerms transport*).

**Token survival independent of the issuer (normative).** Because a self-issued token's genesis and terms originate solely with its issuer, a receiving node **MUST**, at the moment it accepts an incoming coin, durably capture **everything needed to keep that coin's token alive and transferable without the issuer** — the coin's `CoinProof` bundle and any `asset_terms` it carries ([Foundations §1.5](#15-core-data-structures), [§2.3.2](#232-send) attach rule), alongside the on-chain-anchored validity the receive checks already establish ([§2.3.3](#233-receive), [§4.5](#45-recovery) step 5). Transferability itself never depends on the issuer: a coin is spendable from its own `CoinProof` bundle and the chain ([§4.8](#48-durability--the-store-everything-invariant)), which a holder retains. A holder that lacks only a token's **display terms** it does not itself have — because the issuer's node is gone and no sender attached them — obtains them from any other holder that has retained them through the open Class-B lookup, as long as ≥1 such holder exists ([§7.5](#75-node-rest-api-normative)). This is the data-retentive-by-default rule ([§4.8](#48-durability--the-store-everything-invariant)) applied at receipt: capture the whole provenance now, because the issuer may be unreachable later.

**Opaque replicas (normative).** A blob replica that never decrypts delivery events offers **only** enumeration and fetch by locator (`HEAD`/`GET /blossom/<blob_id>`). It **MUST NOT** claim an account-scoped `/v1/pull` index for subjects whose events it has not itself decrypted ([§4.5](#45-recovery) step 4).

#### Safety invariant (normative)

Custody safety **MUST NOT** depend on availability. Losing availability impairs **recovery** (a bundle may be unrecoverable) but can **never** cause **theft**: an unavailable `CoinProof` bundle cannot be spent by anyone else, and a returned bundle is only accepted after verification against Bitcoin (§4.5, [On-chain §3.6](#36-chain-scanning)). Availability is a liveness property, never a safety property.

### 4.7 Metadata and privacy tradeoffs

- **What a relay learns.** That a zkCoins delivery event was stored at some time — the outer event carries the two per-coin cleartext scan tags `zkdt`/`zkepk` (§4.2 step 4), which are fresh and random-looking per coin, so the relay learns *that* an event is a zkCoins delivery (and its timing/volume) but **not** the sender, recipient, amount, asset, proof, or any link between two events (§4.1–§4.2). The tags identify no party and correlate no coins; the residual exposure is that the protocol itself is recognisable on the wire, not the parties or contents.
- **Human-message metadata differs.** Standard NIP-17 routing uses the recipient's `op_pubkey` in the outer kind-1059 `p` tag. The public gift-wrap event does not reveal the sender identity, and message content remains encrypted. A DM relay or its operator can nevertheless identify or correlate the sender through NIP-42 AUTH, source IP and connection metadata, or its own authentication and admission rules; it also sees the recipient key, timing, and volume. The payment path's per-coin `zkdt`/`zkepk` privacy claim therefore **MUST NOT** be applied to human messages.
- **NIP-05 discovery uses DNS and HTTPS once.** First discovery exposes the queried identifier to its domain and depends on DNS. The client then connects to relevant relay URLs and retains only endpoints that both authenticate TLS for each original hostname and complete the WebSocket relay upgrade on the original path. Once the `op_pubkey`, standard `nprofile`, relay lists, and those endpoints are retained, normal use and cold start for that known contact make no DNS/NIP-05 request (§4.3). This holds only while at least one retained endpoint still serves that relay path.
- **A published `zkcoins` profile is public and permanent.** The kind-0 event carrying `nip05` and the `zkcoins` object ([§7.3](#73-nostr-event-kinds-normative)) is not gift-wrapped: it is public and unencrypted, and — like any Nostr kind-0 — is indexed and archived by ordinary Nostr clients and aggregators, so it cannot be retracted once seen. Publishing it therefore binds that name and public key to `address`, `pk0`, `nk_commit`, and `ivpk` in a searchable public record. `pk0` reaches further than the other three: it is also the account's **genesis on-chain nullifier key**, the `Pk₀` the dense account scan looks for on Bitcoin ([§1.2](#12-key-hierarchy)). So the profile links the name not only to a payment identity but to that account's first transition and its timing on the chain, permanently and for anyone who cares to correlate the two. Later transitions are unaffected — they use rotated keys that never appear in a profile — and the linkage survives any later profile replacement. This is what being payable by a public name consists of ([§4.3](#43-addressing-for-delivery)). A directly issued `Invoice` carries the same fields to one payer instead of to everyone.
- **Detection scan vs. linkability.** Per-coin `detect_tag`s are all-distinct (fresh `epk` per coin, §4.4), so a relay cannot link or filter for the recipient. The genuine residual cost is **bandwidth**: detection runs recipient-side over the candidate set. The future-version (not in v1) fuzzy-message-detection upgrade reduces that bandwidth.
- **Blob-fetch pattern.** A Blossom blob store observes which `blob_id`s one client session fetches; since a blob is fetched only on a `detect_tag` match (§4.4), this groups several of one recipient's deliveries by network session — a correlation the per-coin tags themselves do not create. Mitigations: fetch over the operator's own store (the sovereign default), fetch through Tor, or batch/decoy fetches; the metadata never reveals amounts, parties, or contents (the blob stays encrypted; blob **size** is the one residual content signal, [§4.2.1](#421-bundle-blob-encryption-zbe-normative)).
- **Network presence.** Operating a relay exposes the operator's network address (IP) to peers. Operators that require location privacy **SHOULD** run the relay behind an anonymity network (e.g. a Tor hidden service).
- **Recovery disclosure.** Pulling by ownership proof reveals the requester's identity to a node that already holds a local decrypt-index for that subject ([§4.5](#45-recovery) step 4); the privacy-preserving full scan over kind-1059 events ([§4.5](#45-recovery) step 3) reveals nothing beyond ordinary relay reads and local `ivk` matching. Neither path exposes spend authority, and neither introduces a stable public recipient tag.

### 4.8 Durability — the store-everything invariant

zkCoins is client-side-validated: a coin's spendability and an account's next-transition credential live **entirely** in off-chain artefacts — the `CoinProof` bundle, the `SelfDeliveryRecordV1`, and the recursive proof each carries. Bitcoin holds only the opaque per-transition nullifier ([§3.1](#31-the-on-chain-object)), which **cannot** reconstruct a lost proof. **Losing the off-chain data is losing the funds, permanently** (a `CoinProof` bundle *is* coin custody; a `SelfDeliveryRecordV1` *is* account-head custody). Durability is therefore a hard safety requirement of every node, not best-effort caching.

- **Store everything (MUST).** A node **MUST** durably persist **every** value-bearing artefact the moment it receives it — every `CoinProof` bundle, every delivery event, and every `SelfDeliveryRecordV1` (§4.2) — to its durable store (the kernel's value-bearing PostgreSQL plus blob store; [§6.1](#61-components-and-responsibilities)). It **MUST NOT** treat any such artefact as ephemeral, in-memory-only, or droppable under load. The standing rule is *store everything you can get*: when in doubt, persist. At the moment a node accepts an incoming coin it **MUST** capture not only the coin's own bundle but **everything that could later be needed to keep that coin's token alive and transferable independently of its issuer** — the token's `asset_terms` when the bundle carries them ([§4.6](#46-data-availability) *Token survival independent of the issuer*) — because the issuing node may be unreachable when that information is next needed.
- **Never delete (MUST) — [Data Permanence, Requirement 12](/requirements#12-data-permanence).** Once persisted, a node **MUST NOT** delete, drop, expire, prune, garbage-collect, evict under a retention policy, or otherwise destroy any received artefact — **ever**, and regardless of acknowledgements, redundancy held elsewhere, supersession, age, or storage pressure. Retention is **indefinite and unconditional**. There is **no** drop condition, **no** retention-policy expiry, and **no** "superseded" clean-up: a newer `SelfDeliveryRecordV1` is stored **in addition to**, never in place of, the one it supersedes. Copies held by other nodes only add durability; holding them is **never** a licence to remove a local copy. This applies identically to the kernel store, the API, and any relay or blob store the node runs.
- **Persist before acting (MUST).** The durable write **MUST** precede every externally-visible effect — returning the §4.2 ACK, crediting a coin, or serving the artefact to a peer. A node **MUST** order its work so that a crash at any point can never leave it having acted on data it did not first persist.
- **Operator durability duty (MUST).** Because a lost artefact can lose funds, the node **operator MUST maintain a real-time, restorable backup** of the node's value-bearing PostgreSQL store (and its blob store) at all times, such that a host failure loses no committed artefact. The backup **mechanism** — for PostgreSQL, standard streaming replication / write-ahead-log archiving / point-in-time recovery, and the equivalent for the blob store — is a **deployment and hosting responsibility** and is deliberately **out of scope for the node software and the node repository**: the node ships no backup subsystem, and the operator provisions one from standard tooling. This duty is the *primary* recovery path ([§4.5](#45-recovery)); the network redundancy layers ([§4.6](#46-data-availability)) are the fallback, never a substitute for it.
- **The ACK is a durability confirmation, never a delete trigger.** A node **MUST NOT** return the §4.2 acknowledgement until the artefact is committed to stable storage (fsync / write-ahead log). A valid ACK tells the **sender** that the recipient durably stored the bundle; it does **not** permit the sender to drop its own copy. Under Data Permanence the sender retains its copy indefinitely, exactly like every other holder.

It **MUST NEVER** happen that a node received an artefact bearing on spendability and failed to store it, and it **MUST NEVER** happen that a node deleted one it had stored. Every sovereign node retaining, forever, everything it receives is precisely what makes recovery (§4.5) possible with **no central backup custodian**.

### 4.9 Real-time push delivery

Delivery is **push end-to-end**, with **no polling anywhere** on the path: a payment surfaces in the recipient's app the moment it is verified. Every hop is a live subscription or a server push.

The pipeline is normative:

1. **Sender → mesh.** The sender publishes the gift-wrapped `CoinProof` delivery event to the recipient's advertised relay set and, per the [§4.3](#43-addressing-for-delivery) recovery-discoverable overlap, **MUST** additionally publish the event to ≥1 network `seed_relay` and store the blob in ≥1 network `blob_store` (§4.2); it **MAY** place further optional redundant copies at other holders ([§4.6](#46-data-availability)).
2. **Relay → node (push).** The recipient's node holds a **live subscription** (a standing Nostr `REQ`, which streams matching events as they arrive — a subscription, not a poll loop) to its relay set; the relay **pushes** the matching delivery event the instant it lands, and the node still runs the recipient-side `detect_tag` match on each pushed candidate (§4.4). The node is the always-on component ([§6.1](#61-components-and-responsibilities)) and **MUST** keep this subscription open; it **MUST NOT** poll.
3. **Node verifies (and persists).** The node `detect_tag`-matches (§4.4), fetches the blob, **persists it** (§4.8), decrypts with `K_tx` (re-derived from `ivk`, [§1.3](#13-per-coin-keys-note-encryption--detection)), and **verifies** the recursive proof, its canonical `nav`, and the creating nullifier's first-occurrence anchoring against the accumulator it rebuilt from Bitcoin (§2.3.3), then folds the coin in via the receive transition ([§2.3.3 step 7](#233-receive)). Only a verified coin is credited.
4. **Node → API (push).** On a verified receipt the kernel **pushes** a receipt up its RPC to the API layer over a **server-stream** (e.g. a gRPC stream; [§6.1](#61-components-and-responsibilities)) — never a polled endpoint.
5. **API → wallet (push).** The API layer holds an open **SSE or WebSocket** channel to each subscribed wallet (the SDK keeps the stream open) and **pushes** the receipt. The SDK fires the app's callback and the app shows *payment received* **instantly**.
6. **Backgrounded app (optional).** When the app is closed and cannot hold a live stream, the wallet **MAY** additionally register for an OS push (APNs / FCM). This delivery-of-last-resort sits **outside** the trustless core (it traverses Apple/Google) and **MUST** carry **no** plaintext — only an opaque wake signal; on wake the app re-pulls and re-verifies (steps 3–5) before showing anything.
7. **ACK.** After step 3's verification and durable persist (§4.8), the node returns the §4.2 ACK to the sender, closing the loop.

**Latency.** The only inherent waits are network propagation and the **constant-time** proof verification ([§2.2](#22-proof-types)); there is **no poll interval** on the path. End-to-end receipt is bounded by verification plus propagation, not by any polling cadence.

```mermaid
sequenceDiagram
  participant S as Sender
  participant R as Relay mesh
  participant N as Recipient node
  participant A as API layer
  participant W as SDK and app
  S->>R: publish gift-wrapped CoinProof
  R-->>N: push event — live subscription, no poll
  N->>N: detect_tag match · persist · decrypt · verify
  N-->>S: ACK — durability confirmation
  N-->>A: receipt — gRPC server-stream push
  A-->>W: receipt — SSE/WebSocket push
  W->>W: show "payment received" instantly
```

**Substrate vs fast path (normative).** Nostr is the **durable, global, decentralised substrate**: every delivery **MUST** land on the recipient's advertised relay(s) and on at least one of the network's `seed_relays` ([§4.3](#43-addressing-for-delivery) recovery-discoverable overlap), retained indefinitely under Data Permanence ([§4.8](#48-durability--the-store-everything-invariant)) — it is the source of truth and the network's trustless recovery substrate, the emergency fallback to the operator's own backup ([§4.5](#45-recovery), [§4.10](#410-responsibility-boundaries-and-the-availability-model-normative)). But global mesh propagation plus blob fetch can add latency, so Nostr is not necessarily the fastest *notification* channel. The two concerns are therefore separated:

- **Canonical delivery (durable, MUST):** the gift-wrapped `CoinProof` delivery — its control event over Nostr and its blob in the content-addressed store — retained indefinitely under Data Permanence ([§4.8](#48-durability--the-store-everything-invariant)) and placed on the seed-discoverable set on both planes ([§4.3](#43-addressing-for-delivery)). Source of truth; the network's recovery substrate ([§4.5](#45-recovery) emergency fallback, alongside the operator's own backup).
- **Low-latency notification ping (optional overlay, MAY):** to surface a payment with minimal latency, the sender's node **MAY** additionally send a **direct, out-of-band hint** to the recipient's node/API — e.g. "a coin tagged `detect_tag` is waiting at `blob_id`" — or use a dedicated fast channel, triggering an immediate fetch-and-verify without waiting for mesh propagation.

The fast ping is purely a **wake/accelerate** signal and carries **no trust**: the recipient still fetches the durable artefact, **verifies** it (§2.3.3), and persists it (§4.8) before crediting. A missing, delayed, or lying ping can **never** cause loss, double-credit, or a false receipt — **verification gates trust, Nostr + DA gate recovery, and the fast path gates only latency.** A deployment **MAY** therefore optimise the ping channel freely (a direct WebSocket hint, a fast relay, a push fan-out) without weakening any guarantee. When the recipient runs its own node and relay, local relay delivery already *is* the fast push; the overlay matters mainly across operators.

Continue to [Access & Explorer](#5--access--explorer) for the capability-gated pull endpoint, view grants, and the shareable confirmation links that build on this transport layer.

### 4.10 Responsibility boundaries and the availability model (normative)

zkCoins splits responsibility across three tiers with **no overlap and no shared custody**. This section is normative and consolidates guarantees detailed elsewhere in §4; pointers are given.

**Tier 1 — the wallet (custody of secrets).** The wallet ([§6.2](#62-wallet--node)) is responsible for the secure custody of the seed and the keys derived from it, and for **nothing else**. Its sole custodial object is the seed — the twelve BIP-39 words ([§1.2](#12-key-hierarchy)). The wallet **MUST NOT** be relied upon to store any other information: no coin bundles, no account state, no received-payment data. Backing up the seed is the **user's** responsibility; the seed is the only required backup ([Requirement 6](/requirements)). No other software — no node, no API layer, no relay — ever receives the seed or any SPEND-branch key ([§4.1](#41-roles-and-transport), [§4.5](#45-recovery) *Custody during recovery*). **Simultaneous loss of the wallet software and the seed backup makes the funds permanently and irrecoverably lost — this is by design, a property of self-custody, not a defect.** No recovery mechanism in this specification can or should circumvent it: with no seed there is no key, and with no key there is no spend authority anywhere in the system.

**Tier 2 — the node (custody of data).** The node ([§6.1](#61-components-and-responsibilities)) never receives, derives, or stores the seed or any SPEND-branch key; it holds only the operational bundle `{ivk, ovk, op, nk, op_secret}` ([§1.2](#12-key-hierarchy)), which cannot spend. The node is responsible for the **durable custody of every value-bearing artefact** it ever sees. It is programmed to be **data-retentive by default**: it persists every artefact it receives and **never** deletes any of them ([§4.8](#48-durability--the-store-everything-invariant), [Requirement 12](/requirements#12-data-permanence)). Because losing this data can lose funds, keeping a **real-time backup** of the node's value-bearing PostgreSQL store **and its blob store** is the **operator's responsibility** ([§4.8](#48-durability--the-store-everything-invariant) *Operator durability duty*). The backup mechanism itself is a **deployment/hosting concern served by standard PostgreSQL replication and point-in-time-recovery tooling, plus the equivalent content-addressed replication for the blob store,** and is deliberately **outside the node software's scope** — the node repository does not ship it — but operating a node without it violates the operator's durability duty.

**Tier 3 — the network (redundancy and recovery).** No single node is a trusted custodian of another party's availability. Three independent redundancy layers make data recoverable from the seed (plus one reachable bootstrap entry, below) even after a node is destroyed:

1. **Local durable store + operator backup** (Tier 2) — the primary path ([§4.5](#45-recovery)).
2. **Encrypted publication to the Nostr/blob plane** — every value-bearing artefact also lives, encrypted, on the Nostr relay plane (its event) and the Blossom blob plane (its blob), not solely in one node's database ([§4.6](#46-data-availability) *Encrypted network redundancy*). A participant who does not wish to trust any particular node **MAY** run their own Nostr relay and Blossom blob store and sync whichever encrypted artefacts they consider important — self-custody of availability.
3. **Recovery from the seed** — a wallet that lost everything but its seed rebuilds its state by scanning the seed-discoverable relays for delivery events and fetching their blobs from the seed-discoverable blob stores, which by the [§4.3](#43-addressing-for-delivery) recovery-discoverable overlap rule together hold every artefact — event and blob — addressed to the account ([§4.5](#45-recovery)). Like a Bitcoin node serving any block on request, that seed-discoverable infrastructure serves every retained artefact to whoever scans it.

**The availability guarantee, stated honestly.** Recovery succeeds as long as the recovering wallet can reach **one bootstrap entry** to obtain and verify the current signed Bootstrap Manifest (a reachable node base URL, [§4.3](#43-addressing-for-delivery)) **and** **at least one holder of each plane of the relevant data is still live and reachable** **and** **manifest rotation has preserved recovery-discoverability** (the [§4.3](#43-addressing-for-delivery) rule that a network **MUST NOT** delist a holder still holding recoverable artefacts) — the live holder may be a seed-discoverable relay for the delivery event **and** a seed-discoverable blob store for the blob, the sender's node (which placed both on the seed-discoverable set under the overlap rule), any self-hosted syncing relay/store, or an operator backup. It is an **operational multi-holder guarantee**, not a cryptographic one: exactly as a Bitcoin block survives while ≥1 archival node serves it, a zkCoins artefact survives while ≥1 holder serves it. The dual is deliberate and is the same rule as Tier 1: if **every** copy of a piece of data is lost at once, that data — and any value bound to it — is gone. The three redundancy layers exist to make that simultaneous-total-loss vanishingly unlikely, never to promise it cannot happen. Availability is a **liveness** property throughout; it can impair recovery but can **never** cause theft ([§4.6](#46-data-availability) *Safety invariant*).

## 5 · Access & Explorer

> *In one sentence: the three ways an account can disclose its data on purpose — one transaction, a balance, or the whole history — and the self-hostable explorer that renders each, always cryptographically verifiable against Bitcoin, never trust-based.*

This page specifies how Private data ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure)) is released by a node, the structure of viewing capabilities, and the explorer that renders them.

**Consent is one-way (normative, project-wide).** Consent, once given, cannot be taken back. A disclosure that has happened has happened; a signature that was valid stays valid; a key that left the device is gone. No mechanism in this specification **MAY** be described as undoing any of that, and no security property **MAY** rest on an assumption that it does. What a subject can still control is **forward**: refusing future requests at nodes it operates, letting a capability expire, and declining to issue the next one. Where this document offers such a control it says exactly that much and no more — a revocation set stops future pulls at cooperating nodes, an `expiry` bounds a window, and neither un-sees what a grantee already read. A design that promises retraction offers false safety, which is worse than the plain limit it conceals. All primitives, keys, identifiers, and tags are defined in [Foundations](#1--foundations-normative) and used here unchanged. Normative keywords follow RFC 2119.

Recall the relevant key material from [Foundations §1.2](#12-key-hierarchy): a value-bearing subject is keyed by its cryptographic payment identifier `address = H(Pk₀ ‖ nk_commit)` ([§1.4](#14-identifiers-and-hashes)), while NIP-05 is its public human/Nostr identity; the **operational key** `op` is the node-held Nostr identity key that signs grants and acknowledgements but cannot spend; `ivk`/`ovk` are the viewing keys; and `K_tx` ([§1.3](#13-per-coin-keys-note-encryption--detection)) is the per-coin note key that decrypts exactly one coin. The on-chain nullifier `(Pkᵢ, Rᵢ)` ([§1.4](#14-identifiers-and-hashes), [§3.1](#31-the-on-chain-object)) is the only object written to Bitcoin and the integrity anchor for everything below; the account's transition authorization — its `SpendRecord` ([§1.4](#14-identifiers-and-hashes)) — stays off-chain, its `(Pkᵢ, Rᵢ)` being what a publisher half-aggregates and inscribes ([§3.3](#33-half-aggregation)).

**Disclosure is holder-initiated and account-granular.** All disclosure is opt-in: absent one, [Requirement 2](/requirements) holds in full. Because accounts and addresses are one-to-one ([Foundations §1.2](#12-key-hierarchy)), every account-level disclosure covers the **whole** account; there is no "one address out of many." To keep some activity outside a disclosure, it must live in a **separate account**. This page specifies the disclosure spectrum, narrowest first ([Requirement 9](/requirements)):

| Tier | Reveals | Mechanism | Section |
|---|---|---|---|
| One transaction | exactly 1 payment | bearer per-coin capability `zkview` | [§5.3](#53-per-coin-view-capability), [§5.6](#56-shareable-confirmation-links) |
| Balance (history-private) | one asset's balance, no history | ZK balance attestation (a proof, no key) | [§5.7](#57-balance-attestation-history-private) |
| Full account history | every transaction of the account | view grant `zkgrant` (expiring, forward-stoppable) **or** bearer account view key `zkavk` | [§5.8](#58-address-view-full-history) |

Every disclosure is **read-only** (never the spend branch) and every disclosed fact is **verifiable against Bitcoin**, never asserted by a node or explorer.

### 5.1 Capability-gated pull

Every node exposes exactly one endpoint for Private data — the **pull endpoint** — and it serves a record only after the requester demonstrates a cryptographic capability. The endpoint **MUST NOT** release any Private payload (coin plaintext, amounts, parties, balances, proofs, ciphertext) on an unauthenticated request, and **MUST** restrict the response to the data covered by the presented capability. The pull endpoint recognises exactly two **authorisation** capabilities — the **ownership proof** and the **view grant** — and **no others**.

The bearer view capabilities (`zkview`, [§5.3](#53-per-coin-view-capability); `zkavk`, [§5.8](#58-address-view-full-history)) and the balance attestation ([§5.7](#57-balance-attestation-history-private)) are **not** server authorisations: they are client-side decryption secrets, or a self-contained proof, that an explorer applies to bundles whose blobs it obtains from a blob store ([Transport & Recovery](#4--transport--recovery)) or by self-hosted scanning. They never cause a node to release a Private record it would not otherwise serve; they widen what the *holder of the secret* can read from already-public, encrypted material.

The endpoint **MUST** be unauthenticated only for the Public projection of [§5.5](#55-two-explorer-modes) (on-chain nullifier inscriptions with their half-aggregated `(Pkⱼ, Rⱼ)` sets and publisher identities), which carry no Private data by construction.

A request proceeds as a challenge–response so that captured transcripts cannot be replayed:

```
1. Requester → Node :  PullRequest { subject: address, scope }
2. Node → Requester :  Challenge   { nonce: 32 random bytes,
                                     expiry: unix_seconds, // node MUST reject after expiry
                                     domain: "zkCoins/v1/PullChallenge" }
3. Requester → Node :  PullProof   { one of (a) OwnershipProof | (b) GrantProof }
4. Node → Requester :  the Private records matching `subject` within `scope`,
                       or an error (capability invalid / scope exceeded / challenge expired).
```

The signed challenge message is `chal = H(domain ‖ nonce ‖ chan_bind ‖ subject ‖ expiry)` (`H` and input ordering per [Foundations §1.4, §1.7](#14-identifiers-and-hashes)). `nonce`, `chan_bind`, and `subject` are **32 bytes** each, `expiry` is an **8-byte big-endian** Unix timestamp, and `domain` is the constant tag above — so the concatenation is unambiguous. The node sets `expiry` to a short window after issuance (**RECOMMENDED 60 seconds**); it **MUST** reject a `PullProof` whose `nonce` it did not issue or has already consumed, whose `expiry` has passed, or whose recomputed `chal` does not match, and it **MUST** compare `chal` in **constant time**.

**`scope` (normative).** `scope` has the same shape as a `ViewGrant.scope` ([§5.2](#52-view-grant)) minus the grant-only `expiry`: `{ asset_ids: [asset_id] | "*", not_before: unix_seconds, not_after: unix_seconds }`. **Unbounded sentinels (normative, single pair):** `asset_ids = "*"` means all assets; `not_before = 0` means no lower bound; `not_after = 2⁶³−1` (`9223372036854775807`, the maximum signed 64-bit integer as a `u64` bit-pattern) means no upper bound. These two numeric sentinels are the **only** unbounded encodings — JSON omission, Proto3 zero-defaults, and wire payloads all resolve to this same pair before any scope intersection or hashing. On the public REST surface ([§7.5](#75-node-rest-api-normative)), omitted `not_before` / `not_after` fields **MUST** be normalised by the API layer to `0` / `2⁶³−1` **before** the kernel RPC ([§7.8](#78-kernel-rpc--the-internal-interface-normative)) is invoked and **before** any `request_hash` / `grant_message` is formed. A requester states the scope it wants; the node returns the **intersection** of that requested scope with what the presented capability authorises:

- **(a) OwnershipProof** authorises the subject's full account, so the node returns exactly the requested `scope` (the requester MAY narrow its own view; an omitted/`"*"` scope means the whole account).
- **(b) GrantProof** authorises only `grant.scope`; the node clamps the request to `requested_scope ∩ grant.scope` and answers within that intersection — a broader-or-equal or partially overlapping time range, and an `asset_ids = "*"` request against a narrower grant, are silently clamped to the grant, never widened or rejected. The node **MUST** reject (scope-exceeded) only if the resolved intersection is empty, or if the request explicitly names an `asset_id` that is not in `grant.scope.asset_ids`.

A node **MUST NOT** release any record outside the resolved (intersected) scope.

**`chan_bind` — binding the proof to one server (normative).** `chan_bind` records *which server the requester authenticated*, so a captured proof cannot be replayed against a different node. It is a **fixed 32-byte** value the requester derives from the connection **it** established — **never** a value the node sends:

- **Clearnet (TLS):** `chan_bind = H("zkCoins/v1/PullHost" ‖ host)`. `host` is the **canonical authority** the requester connected to and whose TLS certificate it validated: lowercase ASCII, an internationalised name in its **A-label (punycode)** form, any trailing dot removed, and `":"port` appended **only** when the port is not the default 443. Requester and node **MUST** canonicalise identically.
- **Tor:** `chan_bind` is the **32-byte Ed25519 public key** of the node's **v3** onion service (the key the `.onion` address encodes, **not** the Base32 string). v2 onion services are insecure and **MUST NOT** be used.

To accept a proof, the node recomputes `chan_bind` for **each hostname it authoritatively serves** on that endpoint — the public names under which requesters reach it (and its onion key, if any) — and accepts only if the requester's `chan_bind` matches one of them. It **MUST NOT** derive `host` from attacker-influenceable request metadata such as a forwarded `Host` header. Because the binding is the **host the requester already verifies**, the protocol needs **no** node-specific key material and no node identity beyond the URL itself; node portability ([Requirement 10](/requirements)) is unaffected.

This is what lets a requester safely query a **foreign or public** node: a malicious node `X` cannot relay a requester's `OwnershipProof` to another node `Y` (a proof-forwarding / man-in-the-middle attack), because the requester binds to the host it dialed (`X`) and `Y` recomputes a different `chan_bind`. The only residual case — `X` and `Y` behind **one** hostname and certificate — is a single TLS terminator already serving both and already seeing their plaintext; a finer binding would not change that trust boundary.

**Transport (normative).** The pull endpoint **MUST** be served only over **TLS 1.3 or TLS 1.2** on a hostname the requester can verify, **or** as a **Tor v3 onion service**. Plain HTTP, and any transport that does not authenticate the host, **MUST NOT** be accepted, because `chan_bind` would then bind to nothing.

**Deployment note (non-normative).** Binding to the host rather than to a TLS session secret is deliberate: it survives **TLS-terminating reverse proxies and CDNs** — the node recomputes `chan_bind` from its own hostname regardless of who terminates TLS — and it is computable by **browser-based wallets**, which cannot read TLS session material such as an RFC 9266 `tls-exporter` value. A node that terminates TLS itself **MAY** additionally bind to the `tls-exporter` value (RFC 9266; TLS exporter label `EXPORTER-Channel-Binding`, empty context, 32 bytes) for a tighter, per-session binding; over TLS 1.2 it **MUST** negotiate the Extended Master Secret extension (RFC 7627), without which `tls-exporter` is unsound. This binding is an **optional** hardening and **MUST NOT** be required, because it is unavailable behind a TLS-terminating intermediary or to a browser client.

#### (a) Ownership proof

The requester proves it controls the subject's identity by signing the challenge with the subject's **initial spend key** `sk₀` (the key that fixes `address`, [Foundations §1.4](#14-identifiers-and-hashes)):

```
OwnershipProof = {
  subject    : address,
  public_key : Pk₀,                          // x-only, 32B
  nk_commit  : digest,                       // 32B; the account's nullifier-key commitment — the
                                             //   second half of the address preimage (§1.4). Public,
                                             //   not secret; `nk` is never revealed
  signature  : BIP-340(sk₀, chal)            // 64B
}
```

The node **MUST** verify both `H(Pk₀ ‖ nk_commit) == subject` ([§1.4](#14-identifiers-and-hashes)) and the BIP-340 signature over `chal`, and only then release every Private record whose recipient is `subject`. This is also the **recovery** path. There is **no** tag-based alternative at this endpoint: `detect_tag`s are not enumerable in advance — each depends on its delivery event's fresh `epk` ([Foundations §1.3](#13-per-coin-keys-note-encryption--detection)) — so a requester unwilling to reveal `Pk₀` to a foreign node instead pulls candidate delivery events from the relay mesh and runs the [§4.4](#44-note-discovery) scan locally (see [Transport & Recovery](#4--transport--recovery)). Ownership grants the **subject's full** Private view; it is the one self-disclosure that requires the spend branch.

**Action-bound OwnershipProof domains (normative).** The same `OwnershipProof` shape and `chal` construction gate other owner-only node actions. Each action has its **own** challenge domain so a proof issued for one purpose cannot be replayed for another — exactly as bootstrap separates `"zkCoins/v1/EntrustChallenge"` / `"zkCoins/v1/RevokeChallenge"` from `"zkCoins/v1/PullChallenge"` ([§7.7](#77-wallet--node-bootstrapping-normative)):

| Action / endpoint | Challenge domain | Challenge route | Request |
|---|---|---|---|
| Balance attestation | `"zkCoins/v1/AttestBalanceChallenge"` | `POST /v1/attest/balance/challenge` | `POST /v1/attest/balance` ([§7.5](#75-node-rest-api-normative)) |
| Issue view grant | `"zkCoins/v1/IssueGrantChallenge"` | `POST /v1/grants/challenge` | `POST /v1/grants` ([§7.5](#75-node-rest-api-normative)) |
| Entrust / revoke operational bundle | `"zkCoins/v1/EntrustChallenge"` / `"zkCoins/v1/RevokeChallenge"` | `POST /v1/bootstrap/challenge` | `POST /v1/bootstrap/entrust` / `revoke` ([§7.7](#77-wallet--node-bootstrapping-normative)) |

For **AttestBalance** and **IssueGrant**, the signed challenge binds the request body as well as the action: `chal = H(domain ‖ nonce ‖ chan_bind ‖ subject ‖ expiry ‖ request_hash)`, where `request_hash` is the canonical request digest defined at each endpoint ([§7.5](#75-node-rest-api-normative)). (Bootstrap and pull omit `request_hash` — their `chal` remains `H(domain ‖ nonce ‖ chan_bind ‖ subject ‖ expiry)` as above.) Only an **OwnershipProof** by `sk₀` authorises these actions; a `GrantProof` / view-grant holder **MUST** be rejected (`401 unauthorized`). Possession of the operational bundle on a HOSTED node **never** substitutes for this request authentication — the bundle enables the node to *perform* the action; the OwnershipProof authenticates *who* may trigger it.

#### (b) Delegated view grant

The requester presents an `op`-signed grant (the **view grant** of [§5.2](#52-view-grant)) authorising some grantee key `D`, and signs the challenge with `D`:

```
GrantProof = {
  grant      : ViewGrant,                     // Bech32m `zkgrant`, see §5.2
  grantee_pk : D,                             // x-only, 32B; equals grant.grantee
  signature  : BIP-340(d, chal)              // proves possession of D's secret d
}
```

The node **MUST** (1) verify the grant's `op` signature against the subject's published `op` pubkey, (2) verify `grantee_pk == grant.grantee` and the BIP-340 signature over `chal`, (3) confirm the grant has not expired and is not revoked, and (4) release **only** records inside the grant's scope. The node makes **no** policy decision: it enforces the subject's signed grant, which it verifies cryptographically, and **MUST NOT** broaden the disclosure beyond `scope`.

#### Pull session (normative)

The challenge–response above authorises a **single** `POST /v1/pull` ([§7.5](#75-node-rest-api-normative)): the `nonce` is consumed on use, so it cannot authorise the follow-up `GET /v1/proof/<coin_id>` fetches a client makes after seeing the record list. To bridge those without re-running the challenge per coin, a successful `POST /v1/pull` **also** issues a short-lived **pull session**:

- **Credential.** The node returns an **opaque, node-generated** session token (a bearer secret with no client-parseable structure) alongside the record list. The client presents it on every subsequent `GET /v1/record/<record_id>`, `GET /v1/proof/<coin_id>`, and (when the session was opened by an **OwnershipProof**) `GET /v1/account/state` in an `Authorization: Bearer <token>` header. The token is **not** a capability the client can mint, narrow, or forge — it only references server-side session state.
- **Expiry.** The session carries its **own** expiry, **independent of** the 60-second challenge `nonce` window (§5.1) — RECOMMENDED a few minutes. The node **MUST** reject a token past its session expiry (`410`).
- **Binding (fail-closed).** The session state records the `chan_bind` ([§5.1](#51-capability-gated-pull)), the authenticated `subject`, and the **resolved (intersected) `scope`** of the `POST /v1/pull` that created it. A follow-up request is served **only** if it arrives over a channel whose recomputed `chan_bind` matches the session's (the same host/onion binding as the original proof — a token captured and replayed against a **different** node fails, exactly as a replayed proof does), and it releases a Private record **only** for a `record_id` / coin whose subject is the authenticated `subject` **and** which falls inside the session's resolved `scope` (including `SelfDeliveryRecordV1` state records, [§4.2](#42-bundle-delivery)). A token whose `chan_bind` does not match, whose `subject`/`scope` would be exceeded, or which is expired or unknown **MUST** be rejected — the node never widens disclosure beyond what the originating `POST /v1/pull` authorised.

The pull session is a transport convenience over the **same** authorisation the challenge–response already established; it grants no access the `OwnershipProof`/`GrantProof` did not, and it is the "still-valid pull session" referenced by `GET /v1/record/<record_id>`, `GET /v1/proof/<coin_id>`, `GET /v1/account/state` (ownership sessions **only**), `GET /v1/receipts/stream` ([§7.5](#75-node-rest-api-normative)), and the `GetRecord` / `GetCoinProof` / `GetAccountState` / `SubscribeReceipts` kernel procedures ([§7.8](#78-kernel-rpc--the-internal-interface-normative)) — ownership **and** grant sessions are both admissible on the receipts stream and on record/proof fetch; `GET /v1/account/state` / `GetAccountState` admit **ownership sessions only** (a grant session is `401 unauthorized` — no full-state disclosure under a scoped grant).

### 5.2 View grant

A view grant is a **delegated viewing key**: it permits *seeing, not spending*. It binds a grantee key to a scope and is signed by the subject's operational key `op`. The grant **MUST NOT** contain, and a node **MUST NOT** accept it as authority over, any spend key.

```
ViewGrant = {
  version    : 1,
  subject    : address,                       // whose data is disclosed
  grantee    : D,                             // x-only pubkey authorised to view (32B)
  scope      : {
    asset_ids  : [asset_id] | "*",            // exact AssetId set ([Foundations §1.4]); "*" = all assets
    not_before : unix_seconds,                // 0 = no lower bound (unbounded sentinel, §5.1)
    not_after  : unix_seconds,                // inclusive upper bound; 2⁶³−1 (9223372036854775807) = no upper bound
    expiry     : unix_seconds                 // grant unusable after this instant
  },
  nonce      : 16 random bytes,               // makes grant_id unique
  signature  : BIP-340(op, grant_message)     // 64B; binds all fields above
}

grant_message = H( "zkCoins/v1/Grant" ‖ version ‖ subject ‖ grantee
                 ‖ asset_ids ‖ not_before ‖ not_after ‖ expiry ‖ nonce )
grant_id      = H( grant_message )            // stable handle for revocation
```

The signing tag `"zkCoins/v1/Grant"` is the reserved `Grant` context from [Foundations §1.1](#11-cryptographic-primitives); `H` and the input ordering are per [Foundations §1.4, §1.7](#14-identifiers-and-hashes).

**Byte-level encoding of `grant_message` (normative).** As with `invoice_message` ([§4.3](#43-addressing-for-delivery)), `H(…)` is plain SHA-256 concatenation, not the `Hc` field-encoding of [§1.7.2](#172-field-encoding-e-of-hc-inputs). In declaration order: `version` (1 byte, u8; currently always `0x01`); `subject` (32 bytes, the address digest); `grantee` (32 bytes, x-only); `asset_ids` — one **discriminator byte**, `0x00` for the wildcard `"*"` (no further bytes), or `0x01` followed by a **u32-be count** and that many 32-byte `asset_id` digests in **ascending** order; `not_before`, `not_after`, `expiry` (8 bytes big-endian each, u64, §1.7.3); `nonce` (its 16 raw bytes). Without the `asset_ids` discriminator and count, a wildcard grant and an explicit-list grant — or two explicit lists of different length — could not be distinguished from the concatenated bytes alone; this closes that ambiguity the same way the `invoice_message` fix above closes it for `memo`/`relays`.

**Encoding.** A `ViewGrant` is serialised in the field order above and encoded as **Bech32m** with HRP **`zkgrant`** ([Foundations §1.7](#17-encoding-serialization-and-the-reference-instantiation)), so it is never confused with an `address` (`zk`) or a per-coin capability (`zkview`). A node **MUST** reject a grant under any other HRP. **Payload layout (normative):** `version (1B = 0x01) ‖ subject (32B) ‖ grantee (32B) ‖ asset_ids (**the same discriminator as `grant_message`**: `0x00` = "*", else `0x01` ‖ u32-be count ‖ count × 32B ids ascending) ‖ not_before (8B be) ‖ not_after (8B be) ‖ expiry (8B be) ‖ nonce (16B) ‖ op_signature (64B)`. The `version … nonce` prefix is **byte-identical** to the `grant_message` preimage above, so a node recomputes `grant_message = H("zkCoins/v1/Grant" ‖ version ‖ subject ‖ grantee ‖ asset_ids ‖ not_before ‖ not_after ‖ expiry ‖ nonce)` directly from the decoded payload and verifies `BIP-340(op, grant_message)` against `op_signature`. A decoder MUST reject an unknown version byte, a non-ascending id list, or trailing bytes.

**Revocation is forward-only.** A subject revokes a grant by instructing the node(s) it controls to refuse any `GrantProof` carrying that `grant_id`. Each node **MUST** maintain a revocation set and **MUST** reject a revoked grant at step (3) of [§5.1(b)](#b-delegated-view-grant). Revocation **MUST NOT** be claimed to undo prior disclosure: data already released under the grant, and any independent copy the grantee retained, is permanently outside the subject's control — **already-disclosed data cannot be un-seen**. A node a subject does not control cannot be compelled to honour a revocation; therefore grants **SHOULD** carry a short `expiry` rather than relying on revocation.

### 5.3 Per-coin view capability

The narrowest capability discloses a single coin. It is the per-coin note key `K_tx` from [Foundations §1.3](#13-per-coin-keys-note-encryption--detection), scoped to exactly one coin: it decrypts that coin's `ciphertext` and **nothing else**, and confers no spend authority and no view of any other coin, balance, or transaction.

A per-coin view capability is encoded as **Bech32m** with HRP **`zkview`** ([Foundations §1.7](#17-encoding-serialization-and-the-reference-instantiation)):

```
zkview = Bech32m( HRP = "zkview", data = K_tx )      // 32-byte symmetric note key
```

Unlike a `ViewGrant`, a `zkview` carries no signature: it is a **bearer** secret whose mere possession authorises decryption of its one coin. It is the capability embedded in a shareable confirmation link ([§5.6](#56-shareable-confirmation-links)).

### 5.4 Capabilities at a glance

| Capability | Encoding (HRP) | Authorises | Scope | Bearer? | Forward-stoppable? |
|---|---|---|---|---|---|
| Ownership proof | — (signed challenge) | full Private view of the subject | whole account | no — needs `sk₀` | n/a |
| View grant | Bech32m `zkgrant` | delegated viewing | `asset_ids` × time window | no — needs grantee key `D` | yes, at cooperating nodes — never retroactive |
| Per-coin capability | Bech32m `zkview` | decrypt one coin | exactly one coin | **yes** — `K_tx` is the secret | no |
| Account view key | Bech32m `zkavk` | read full history (or incoming-only) | whole account | **yes** — `ivk‖ovk` (64 B, full) or `ivk` alone (32 B, incoming-only) | no |
| Balance attestation | — (self-contained proof) | confirm one balance | one asset, point-in-time | n/a — a proof, not a key | n/a |

The two **account-wide** capabilities — ownership proof and account view key — cover the whole account by construction ([Foundations §1.2](#12-key-hierarchy)); there is no narrower address-level form. For an account-wide disclosure that is **forward-stoppable**, use a scoped `zkgrant` ([§5.2](#52-view-grant)) rather than the irrevocable bearer `zkavk`.

### 5.5 Two explorer modes

The same node data ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure): plaintext leaves Private, roots Public) is presented in two modes that differ **only** in the capability supplied.

**Public mode.** No capability is presented. The explorer renders **only** Public on-chain data: the stream of nullifier inscriptions with their half-aggregated `(Pkⱼ, Rⱼ)` sets and publisher identities, the global nullifier accumulator folded from them by first-occurrence ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure), [On-chain §3.7](#37-the-nullifier-accumulator)), and aggregate counts (number of inscriptions, per-block transition count, accumulator size), with every nullifier signature checked against Bitcoin. It **MUST NOT** display amounts, `asset_id`s or asset names, balances, addresses, senders, recipients, or anything sourced from a `CoinProof` bundle — none of which are derivable from Public data. (A publisher's identity is the only on-chain link; the rotating per-transition `Pkⱼ` is fresh, so two of an account's nullifiers are unlinkable and the rotation edge `Pkᵢ → Pkᵢ₊₁` never appears on Bitcoin ([Foundations §1.4](#14-identifiers-and-hashes)).)

**Authorised mode.** The viewer supplies the subject's signed **view grant** ([§5.2](#52-view-grant)) (or, for self-view, an ownership proof). The explorer then drives the pull endpoint of [§5.1](#51-capability-gated-pull) on the viewer's behalf and renders that subject's real transactions **within the grant's scope** — and nothing beyond it. Disclosure stays under the subject's control: the subject chooses the grantee, the asset set, and the time window. The explorer is a client of the capability model; it gains **no** privilege the presented capability does not already confer.

**Account model vs. on-chain nullifiers (normative).** zkCoins is an **account model** — each account is a balance and a recursive lineage ([Foundations §1.2](#12-key-hierarchy), [§1.6](#16-trees-one-global-structure-one-per-account-structure)), **not** a UTXO set — so there is no output-graph to walk and an explorer **MUST NOT** render one. The **only object on Bitcoin L1 is the per-transition nullifier `(Pkᵢ, Rᵢ)`** ([On-chain §3.1](#31-the-on-chain-object)), half-aggregated by a publisher into one Taproot reveal ([§3.3](#33-half-aggregation)). The settled on-chain unit is therefore the **transition nullifier**, and an explorer presents **two layers**: the **L1-anchor layer** — the public stream of nullifier inscriptions, the global accumulator folded from them by first-occurrence, and publisher identities (the whole of Public mode) — and the **account layer** — per-account balances and individual transactions, which appear **only** in Authorised and bearer views. A single transaction is tied to its anchor by the *anchoring trail* below; because a publisher inscribes many transitions' nullifiers in one reveal, the same `txid` carries many accounts' nullifiers, and in Public mode the explorer **MUST** present only the half-aggregated `(Pkⱼ, Rⱼ)` set and the publisher, and **MUST NOT** expose which account or transaction any `Pkⱼ` belongs to.

**Data sources (normative).** The explorer is a presentation client over a node's **normal API**; it runs no validator and keeps no index of its own. Public mode is fed **only** by the node's unauthenticated endpoints ([§7.5](#75-node-rest-api-normative): `/v1/chain/inscriptions`, `/v1/chain/accumulator`, `/v1/info`). Authorised mode additionally drives the capability-gated pull endpoint ([§5.1](#51-capability-gated-pull)). Bearer views ([§5.6](#56-shareable-confirmation-links)–[§5.8](#58-address-view-full-history)) additionally fetch the encrypted bundle blob from a blob store the node is paired with ([Transport & Recovery §4.6](#46-data-availability)) and decrypt it **client-side**.

**The anchoring trail.** For any one disclosed transaction the explorer renders the ordered chain that ties the account-layer payment to its Bitcoin anchor: the account-level transaction (amount, asset, time) → its recursive validity proof (`ocr`; [Proofs §2.2](#22-proof-types), [Foundations §1.5](#15-core-data-structures)) → the transition's **on-chain nullifier `(Pkᵢ, Rᵢ)`** ([On-chain §3.1](#31-the-on-chain-object)), shown as a real Bitcoin **`txid`** (the reveal that half-aggregated and inscribed it) at block **`height`** with **confirmations = `tip_height − height + 1`** against the `finality_confirmations` of [§7.5](#75-node-rest-api-normative) `/v1/info` ([On-chain §3.9](#39-finality-and-reorg-handling)) → the resulting **state** ([On-chain §3.10](#310-transaction-states)): `completed` (the nullifier is the **first occurrence** of `Pkᵢ` in the accumulator, with `Pkᵢ` bound to the proof's own `consumed_pubkey` — [§2.1 clause 9](#21-the-compliance-predicate), the disclosure-verifier binding of [§5.6](#56-shareable-confirmation-links)/[§5.7](#57-balance-attestation-history-private)/[§5.8](#58-address-view-full-history) — and its inclusion block is final), `pending`, or `failed`. A mint is no exception — it anchors its own nullifier on Bitcoin and is rendered with the **same three states** as any other transition ([§2.3.1](#231-mint--issuance), [§3.10](#310-transaction-states)). The trail's terminal fact — a real, clickable Bitcoin `txid` and its confirmation count — is what makes *"settled on Bitcoin L1"* concrete; every step is **independently verifiable against Bitcoin and the proofs, never an explorer assertion** ([Requirement 9](/requirements)), and the trustless way to view it is to **self-host** the node and explorer ([§6.6](#66-threat-model-and-trust-configurations)).

### 5.6 Shareable confirmation links

This is the case of [Requirement 9](/requirements): a sender (A) who paid a recipient (B) hands B — or a third party — a link that confirms exactly that one payment, *"here is verifiable proof I sent it."* The link carries just two things: **where to fetch** the one coin's bundle, and **the key to read it**. Everything else — which on-chain record, the amount, the proof — is recovered from the bundle and verified against Bitcoin.

**Carrying the link secret (normative — governs the shareable links of §5.6–§5.8).** Each shareable link carries a **bearer secret** (a `zkview` `K_tx`, a `zkavk`, or a balance proof). It **MUST** be transported so the secret never reaches a server:

- **Custom-scheme form (canonical, preferred):** a `zkcoins:…` URI is dispatched **locally** by a registered handler (wallet/explorer app); the secret never enters a network request. Carrying it in the URI path is therefore safe.
- **HTTPS fallback:** the secret — and **every** other link component after the app route (in §5.6 the bundle locator; in §5.7 the address, `asset_id` and proof; in §5.8 the address; plus any optional holder hint) — **MUST** be placed in the URL **fragment** (`#…`); the HTTPS path is only the app route (e.g. `/tx`) and the link **MUST** carry **no query string**. A browser never transmits the fragment to the server, so the secret appears in **no** server log, **no** proxy — including a TLS-terminating one — and **no** `Referer` header. The explorer **MUST** be a **client-side** application that reads the fragment, fetches the bundle blob from a blob store, and **decrypts and verifies entirely on the client**. The routes that serve shareable links **MUST NOT** be server-rendered from the link's contents; static assets plus client-side hydration is the conforming shape (the server cannot receive the fragment in any case). A conforming explorer **MUST NOT** transmit a `K_tx`, `zkavk`, or balance proof to any server. A conforming explorer **MUST** apply `Referrer-Policy: no-referrer` — via the HTTP response header, or the `<meta name="referrer" content="no-referrer">` fallback where header control is unavailable. Because the secret travels in the fragment — which is never included in a `Referer` regardless — this is defense-in-depth, not the primary protection.
- **Holder-hint parse rule (normative).** An optional holder hint, if present, is the **final** fragment component, written `;h=<locator>`; its `<locator>` value **MUST** be percent-encoded so it contains no `/`, `:`, or `;`. A parser splits the fragment on the first literal `;h=`: everything before is the link's components, everything after is the percent-encoded locator. The hint is an optimisation only and carries no secret.
- **Scope of "never reaches a server" (normative).** The fragment keeps the secret and all link components from the **explorer (app) host** and every HTTP intermediary (server logs, proxies, `Referer`). It does **not** hide (a) that the **blob store serving the bundle learns `blob_id`** when the bundle blob is fetched, nor (b) the **DNS/SNI metadata** revealing which explorer/blob-store host was contacted. Both are addressed only by self-hosting the explorer and blob store or using Tor — so the "never reaches a server" guarantee is scoped to the **explorer/app host and HTTP intermediaries**, not the blob store.
- An explorer **MUST** be self-hostable ([Requirement 9](/requirements), consistent with [§6.1](#61-components-and-responsibilities)) and **MAY** be served as a Tor onion service, so even the host metadata (DNS/SNI) is the operator's own.

**Residual (non-normative).** On an untrusted device the fragment still persists in local browser history and memory; no link scheme protects a compromised endpoint. A bearer link **SHOULD NOT** be opened on a device the holder does not trust; if unavoidable, use a private/ephemeral session and clear history afterward.

**Link grammar.** A confirmation link is two Bech32m values — a content **locator** and a per-coin **view capability** — under a host-independent URI:

```
zkcoins:tx/<bundle>/<view>

  <bundle> = Bech32m( HRP "zkbid",  blob_id )    ; blob_id = H(ciphertext) of the CoinProof bundle
                                                 ; ([Transport & Recovery §4.2](#42-bundle-delivery));
                                                 ; content-addressed, so ANY blob store holding the blob
                                                 ; serves it — no node-specific locator is needed
  <view>   = Bech32m( HRP "zkview", K_tx )       ; the per-coin note key ([§5.3](#53-per-coin-view-capability));
                                                 ; decrypts exactly one coin; the bearer secret of the link
```

The `/` delimiter is unambiguous: a Bech32m string contains neither `/` nor `:`. The two HRPs `zkbid` and `zkview` ([Foundations §1.7.7](#177-bech32m-and-bitcoin-conventions)) are distinct, so a viewer **MUST** reject a value presented under the wrong HRP and can never confuse the locator for the key.

An explorer **MAY** render the same pair as a clickable web URL — `https://<explorer-host>/tx#<bundle>/<view>` — where `/tx` is only the app route and the `<bundle>`/`<view>` pair lives in the URL **fragment** (per the link-transport rules above, so the secret never reaches the server). The host is only a renderer: any instance is equivalent and self-hostable, and a viewer **MUST** treat the `<bundle>`/`<view>` pair, not the host, as authoritative. A holder hint **MAY** be appended **inside the fragment** as `…#<bundle>/<view>;h=<locator>` (`op:<op-pubkey>` or `@<relay-url>`) to speed resolution, parsed per the holder-hint parse rule above; it travels in the fragment, **never** as a query or path component, so it is never sent to any server. It is an optimisation only and is never required.

**Flow.** The viewer (an explorer that is neither A nor B, or one the viewer self-hosts):

1. **Fetch** the `CoinProof` bundle blob by `blob_id` from a blob store ([Transport & Recovery §4.2](#42-bundle-delivery), [§4.6](#46-data-availability)) — any holder that has the blob answers — and verify `H(ciphertext) == blob_id` (content-addressed self-check).
2. **Decrypt** the coin with `<view>` (`K_tx`); render the single transaction — **amount, asset, time, status** (the [On-chain §3.10](#310-transaction-states) transaction state).
3. **Verify against Bitcoin.** Check the coin's inclusion in `output_coins_root`; verify the spender's recursive validity proof and open its `nav_commitment` with the bundle's `nav_opening`, checking `nav` is a canonical accumulator value on the viewer's own scan ([Foundations §1.4, §1.5](#14-identifiers-and-hashes), [§3.9](#39-finality-and-reorg-handling)); and confirm the coin's **creating transition's on-chain nullifier `(Pk_create, R_create)`** (from the bundle's `creating_nullifier`) is the **first occurrence** of `Pk_create` in the accumulator the viewer rebuilt from Bitcoin, with `R_create` opening `H(creating ProofData)` **and `Pk_create == creating_proof.consumed_pubkey`** (the creating proof's exposed consumed key, [§2.1 clause 9](#21-the-compliance-predicate)) — i.e. state **`completed`** ([On-chain §3.6](#36-chain-scanning), [§3.10](#310-transaction-states)). The `Pk_create == creating_proof.consumed_pubkey` binding is **normative for this disclosure verifier** (the viewer is a third party, not the account's successor or receiver): without it a malicious **subject** could prove a valid `C`-proof of a fork-loser or never-anchored state and point the link at a **fresh-key naked nullifier** it published (`R_create` S2C-opening `H(creating ProofData)`, permissionless per [§3.3](#33-half-aggregation)/[§3.4](#34-the-publisher)) to make an unanchored state read `completed`; binding the anchored **key** to the proof's own consumed key closes that fresh-key substitution here exactly as clause 10(d) does in-circuit. A coin produced by a **mint** ([§2.3.1](#231-mint--issuance)) is verified the same way: its creating transition is the mint, which anchors its own on-chain nullifier, so the explorer checks that nullifier's **first-occurrence `completed`** state exactly as for any other coin — in addition to re-verifying the mint's recursive proof (an `InitialProof`, or an `AccountUpdateProof` carrying `asset_issuance` for a follow-up mint). The viewer trusts **Bitcoin and the proofs — never the explorer's assertion**.

Steps 1–3 are the single-transaction form of the *anchoring trail* ([§5.5](#55-two-explorer-modes)): the explorer renders the payment together with the anchoring nullifier inscription's `txid`, its confirmation count, and the [§3.10](#310-transaction-states) state.

**Properties.**

- **Bearer.** Whoever holds the link can view that one transaction; `K_tx` is the secret. `blob_id` is a public locator that reveals nothing without `K_tx`. The link **MUST** travel over a channel the sender trusts.
- **Scoped.** It discloses that single transaction in full and **nothing else** — no other transactions, no balances, no counterparties beyond that payment, and no spend authority. It does reveal `coin.recipient` (B's address) for *this* payment, and — through the bundle's `nav_opening` — the sender's proving-time accumulator value (`nav` is always `size_final`, the shared final ordinal with no account link); per-relationship unlinkability is an account choice ([Foundations §1.2](#12-key-hierarchy)). A link holder also holds the coin's `CoinProof` and is therefore a co-output holder in the D-18 sense — it learns that other outputs of the same transition exist (and the output-count bucket), nothing more ([§6.7](#67-security-properties-summary)).
- **Availability.** Because the locator is `blob_id = H(ciphertext)`, **every** holder that has the blob can serve it ([Transport & Recovery §4.6](#46-data-availability), [§4.8](#48-durability--the-store-everything-invariant)); confirmation never hinges on A — or any specific node — being online.
- **On-chain privacy intact.** Neither `blob_id` nor `K_tx` ever appears on Bitcoin; [Requirement 2](/requirements) is unaffected.
- **Length.** Two 32-byte values in Bech32m make a fixed, compact link; the floor is the 256-bit `K_tx`, which is the access secret and cannot be shortened.

The explorer is a **self-hostable presentation layer** and **MUST NOT** be a trusted authority: every figure it shows is independently verifiable against Bitcoin and the proof by the viewer.

### 5.7 Balance attestation (history-private)

The narrowest *account-level* disclosure proves a balance **without exposing the account's transaction history**. The subject produces a zero-knowledge proof that its on-chain-committed account state holds a given balance of one asset, and hands over only that proof. It reveals the address, the asset, the number, and the public `anchor` below — never any coin plaintext, counterparty, or amount-flow, and **not** the account's receive-recency (the conditional NAV stays hidden behind its commitment; the attestation exposes only a **global** accumulator ceiling, not the subject's own prefix length). The anchor is a genuine metadata disclosure and a documented limit of this design; see *Properties* below.

It re-uses the account's own recursive validity proof ([Proofs §2.2](#22-proof-types)) as the anchor — there is no global account-keyed tree to point at ([Foundations §1.6](#16-trees-one-global-structure-one-per-account-structure)). That proof's public input `new_account_state_hash` is the hash of the very `AccountState` being attested. The proof was bound — by the transition's sign-to-contract nonce — into the on-chain nullifier `(Pk_anchor, R_anchor)` of the account's most-recent anchored spend, which is on Bitcoin as the **first occurrence** of `Pk_anchor` in the accumulator (state `completed`). The attestation therefore stands on the **real, Bitcoin-anchored** state via that nullifier — and because the statement binds `Pk_anchor == pi.consumed_pubkey` (statement 5 below), the anchored key is the proof's **own consumed key**, so a subject cannot substitute a fresh-key naked nullifier for a fork-loser or never-anchored state; it cannot assert a false one.

```
BalanceAttestation:
  public inputs (revealed):
    { subject : address,
      asset_id,
      balance : B,
      nav_ceiling,                                   // a GLOBAL nullifier-accumulator value (the ≥6-confirmation-final prefix `size_final` at attestation time) — NOT the
                                                     //   subject's own nav; verifier checks it is
                                                     //   canonical on its own scan (§3.7, §3.9)
      size_ceiling,                                  // u64 size of nav_ceiling; public so a verifier can check size_ceiling ≤ size_final and rebuild mth_ceiling
      anchor  : { txid, block_hash, height,
                  Pk_anchor, R_anchor } }            // the on-chain nullifier of the account's
                                                     //   most-recent anchored transition (§3.1);
                                                     //   Pk_anchor is bound to pi.consumed_pubkey
                                                     //   (statement 5), not a free witness

  witness (hidden):
    { AccountState S,
      pi,                                             // the account's recursive validity proof for S
      nav_opening = { nav, nav_rand },                // opens pi.ProofData.nav_commitment
      nav_consistency,                                // RFC-6962 consistency proof prefix(nav ⊑ nav_ceiling) (§3.7)
      size,                                           // u64 sizes (and tree-heads mth, mth_ceiling) of the attested nav and the disclosed nav_ceiling
      spend_record,                                   // the account's transition authorization
                                                     //   {Pk_anchor, signature} for this state (§1.4)
      R_prime }                                       // sign-to-contract opening of spend_record.signature

  statement (domain tag "zkCoins/v1/BalanceProof"):
    1. S.owner == subject
    2. S.balances[asset_id] == B
    3. pi verifies under the canonical verifier data, and pi.ProofData.new_account_state_hash == ash(S)
    4. spend_record.signature opens, with R_prime, to t = H(bytes(R_prime) ‖ H(pi.ProofData))
                                                                    (sign-to-contract, On-chain §3.2),
       so the on-chain nullifier (Pk_anchor, R_anchor) commits exactly this pi; `R_anchor` **equals** `spend_record.signature`'s nonce `R` — the anchor pair is the signature's own `(Pk_anchor, R)`, not a free public input
    5. Pk_anchor == pi.consumed_pubkey (the proof's exposed consumed key, §2.1 clause 9), so the
       anchored KEY is the one this state's transition actually consumed — NOT a free witness. The
       key binding is REQUIRED: without it a malicious subject could attest a fork-loser or
       never-anchored balance by pointing at a fresh-key naked nullifier whose R_anchor S2C-opens
       H(pi.ProofData) (permissionless, §3.3/§3.4) — see §5.6 step 3
    6. pi.ProofData.nav_commitment == Hc("NavCommit", nav_root ‖ nav_rand),
       nav_root == Hc("NfLog/Root", size ‖ mth),
       nav_ceiling == Hc("NfLog/Root", size_ceiling ‖ mth_ceiling),
                                                     (the DISCLOSED ceiling is itself a committed log
                                                      root — its size_ceiling/mth_ceiling are NOT free
                                                      witnesses, so nav_consistency proves a prefix
                                                      between two committed roots)
       AND prefix(nav ⊑ nav_ceiling) via nav_consistency, size ≤ size_ceiling
                                                     (the RFC-6962 log-consistency relation of §3.7:
                                                      the attested state's hidden nav is a prefix of the
                                                      disclosed global ceiling — proving its whole lineage
                                                      is anchored, WITHOUT revealing the subject's own nav)
    7. network_id == Hc("Network", network_tag_bytes)
                                                     (the public input, last field of C_balance's layout
                                                      [§2.5](#25-circuit-dimensioning-normative); constrained
                                                      against the compile-time network constant of the build —
                                                      proof-level binding only; does not bind any signature)
```

**Host-side anchor checks (normative, outside the circuit).** The circuit cannot prove Bitcoin inclusion. The verifier **MUST** itself check, against its own scan: that `(Pk_anchor, R_anchor)` is inscribed at the disclosed `(txid, block_hash, height)`; that it is the **first occurrence** of `Pk_anchor` ([§3.6](#36-chain-scanning)); and that its state is `completed` ([§3.10](#310-transaction-states)). These are verifier-side preconditions of accepting the attestation, exactly like the `nav_ceiling` canonicality check.

The verifier checks the proof, that `nav_ceiling` is a **canonical** nullifier-accumulator value per its **own** scan ([§3.7](#37-the-nullifier-accumulator), [§3.9](#39-finality-and-reorg-handling), with `size_ceiling ≤ size_final` (the verifier recomputes `mth_ceiling = MTH(D[0:size_ceiling])` on its own scan and checks `nav_ceiling == Hc("NfLog/Root", size_ceiling ‖ mth_ceiling)`, statement 6's binding) so every authenticated position is in the ≥6-confirmation-final prefix (§3.9) — since the subject's own `nav` is proven a prefix of it, every dependency folded into the attested state is anchored), and that the on-chain nullifier `(Pk_anchor, R_anchor)` at `anchor` (`txid`) is the **first occurrence** of `Pk_anchor` in the accumulator it rebuilt from Bitcoin — i.e. state `completed` ([On-chain §3.6](#36-chain-scanning), [§3.10](#310-transaction-states)) at `{block_hash, height}`. No node, relay, or explorer is trusted. Because `nav_ceiling` is a **global** accumulator value shared by every account, it discloses nothing account-specific; the subject **MUST** set it to a recent global value chosen independently of its own view — RECOMMENDED the ≥6-confirmation-final prefix `size_final` at attestation time — and **MUST NOT** set it to (or derive it from) its own `nav`, which would leak the subject's prefix length. A verifier that wants a freshness bound **MAY** prescribe the `nav_ceiling` it will accept (e.g. its own current `size_final`); the subject then proves `prefix(nav, that ceiling)`, and the verifier learns only that the state is no fresher than a value it already holds. Because the anchor is the account's most-recent **anchored transition** (the transition whose nullifier is on Bitcoin), the attestation binds the balance **as of that transition**. Since **every** state-advancing transition now anchors — a receive included ([§2.1 clause 1](#21-the-compliance-predicate), [§3.10](#310-transaction-states)) — a receive that credits new coins is itself an anchored transition, so the attestation can bind the newer balance as soon as that receive reaches `completed`, with no need to wait for a subsequent spend.

**Reference link — attestation share-link grammar (normative).** Any self-hostable explorer instance is equivalent. Write `BalanceAttestationV1 ≜ serialize(BalanceAttestation)` — the canonical §7.1 binary of the public inputs + proof ([§7.1](#71-serialization-conventions-normative)). The link carries the attested `(address, asset_id)` together with one **discriminated** attestation component:

```
zkcoins:balance/<address>/<asset_id>/<attestation>

  <address>  = Bech32m( HRP "zk", subject )          ; the attested account
  <asset_id> = lowercase-hex 32-byte asset_id          ; the attested asset (§1.4)
  <attestation> is exactly one of:

  (a) Inline form
      i:<base64url-no-pad(BalanceAttestationV1)>
      — the full canonical attestation bytes, Base64url without padding (RFC 4648 §5,
        no `=` pad). Permitted only when len(BalanceAttestationV1) ≤ max_blob_bytes
        (the §7.4 / §7.5 `/v1/info` advertised Blossom size limit). A larger artefact
        MUST use form (b).

  (b) Content-addressed form
      h:<zkatt>
      <zkatt> = Bech32m( HRP "zkatt", SHA-256(BalanceAttestationV1) )
      — a 32-byte content handle. Fetch requires a BlobLocatorSet (below); the fetched
        body MUST satisfy SHA-256(body) == the 32-byte payload of <zkatt> (hash match)
        and then decode as BalanceAttestationV1 (field checks below).
```

The `/` delimiter is unambiguous: Bech32m and Base64url-no-pad strings contain neither `/` nor (for the discriminator) a bare leading `i:`/`h:` that collides with an HRP. A viewer **MUST** reject an unknown discriminator, a wrong-HRP `zkatt`, trailing bytes after a well-formed component, or an inline body whose decoded length exceeds `max_blob_bytes`.

**`BlobLocatorSet` (normative, form (b) only).** An ordered, non-empty list of base URLs of Blossom stores expected to serve `GET /blossom/<sha256>` of the `BalanceAttestationV1` bytes (the same locator role as `blob_locators` in [§4.2](#42-bundle-delivery)). Encoding on the wire: a single percent-encoded string of the locators joined by ASCII `,` (each locator percent-encoded so it contains no `/`, `:`, or `;` when embedded — same percent-encoding discipline as the [§5.6](#56-shareable-confirmation-links) holder-hint parse rule). Form (b) is not fetchable without a `BlobLocatorSet`; a conforming producer of a usable `h:` link **MUST** supply one.

**Privacy — locators only in the opt-in fragment (normative).** On the HTTPS fallback the secret/proof components — `<address>`, `<asset_id>`, `<attestation>`, and any `BlobLocatorSet` — **MUST** live in the URL **fragment** only, per the link-transport rules of [§5.6](#56-shareable-confirmation-links):

```
https://<explorer-host>/balance#<address>/<asset_id>/<attestation>
https://<explorer-host>/balance#<address>/<asset_id>/h:<zkatt>;h=<BlobLocatorSet>
```

The path is only the app route `/balance`; the link **MUST** carry **no query string**. The `BlobLocatorSet` **MUST NOT** appear as a path or query component that would mint a stable public URL for the attestation's hosting — it is an **opt-in fragment suffix** (parsed with the [§5.6](#56-shareable-confirmation-links) `;h=` holder-hint rule). The content handle `h:<zkatt>` itself is content-addressed (a hash of the bytes, not a public index of who attested). On the custom-scheme form a producer **MAY** append `;h=<BlobLocatorSet>` after `<attestation>` by the same parse rule; for form (b) that suffix is required for fetch.

**Verification of a share link (normative).** The viewer:

1. Parses `<address>`, `<asset_id>`, and the `<attestation>` discriminator.
2. Obtains `BalanceAttestationV1` bytes — (a) by Base64url-no-pad decode of the inline body, or (b) by fetching from any locator in the `BlobLocatorSet` and checking `SHA-256(body) ==` the 32-byte `zkatt` payload (reject on mismatch or wrong length).
3. Decodes `serialize(BalanceAttestation)` per [§7.1](#71-serialization-conventions-normative) (reject wrong-width fields, missing/wrong-width `network_id`, length-prefix overflow, trailing bytes).
4. Checks `subject` equals `<address>`, `asset_id` equals `<asset_id>`, `network_id` equals the verifier's network, then verifies the attestation statement and host-side anchor checks of this section (proof under `C_balance`, canonical `nav_ceiling`, first-occurrence `completed` anchor).

An explorer **MAY** render the custom-scheme form as the HTTPS fragment form above; the host is only a renderer.

**Properties.**

- **Reveals the number, plus its anchor.** No balance-changing transaction, coin amount, counterparty, history, or receive-recency leaks — the witness never leaves the proof, and `nav_ceiling` is a global accumulator value, not the subject's own prefix. The public `anchor = {txid, Pk_anchor, R_anchor, …}` does identify the **one** anchoring nullifier (its inscription and on-chain time) so the verifier can check `completed`; this is inherent to standing on a Bitcoin anchor, and `Pk_anchor` is the same rotating key a payee of that transition already sees. This is a documented **v1 limit**: a future protocol version **MAY** replace the public `anchor` with a zero-knowledge **set-membership proof** over the inscribed nullifiers — proving the attested state stands on *some* first-occurrence `completed` nullifier without naming which — closing this disclosure; a version that does so is the planned upgrade referenced by [Requirement 9(b)](/requirements). v1 documents the disclosure instead.
- **Point-in-time.** It attests to the balance *as of `anchor`*. A later spend does not make the proof false (it remains true about that anchor) but no longer reflects the current balance; a fresh proof re-attests.
- **Unforgeable for a third party.** Producing it requires the account's Private `AccountState` (hence its view data); no one can attest a balance for an address whose state they cannot see, and the statement can only ever prove the true committed value.
- **Read-only.** It carries no key and no spend authority.

### 5.8 Address view (full history)

The broadest disclosure renders an account's **entire** transaction history. Because accounts and addresses are one-to-one ([Foundations §1.2](#12-key-hierarchy)), this *is* an account-wide view — there is no "one address out of many." To keep some activity out of such a view, it must live in a separate account.

There are two forms, with the **same result** but different **forward** control. A subject **SHOULD** prefer (a) when it wants to bound the window or stop future pulls at its own nodes, and use (b) only when a simple paste-able link outweighs having no forward control at all. Neither form retracts anything already read (*Consent is one-way* above): (a) buys an `expiry` and a refusal at cooperating nodes, not undisclosure.

**(a) Forward-stoppable — view grant.** The subject issues a `ViewGrant` ([§5.2](#52-view-grant)) with `scope.asset_ids = "*"` and the desired time window to a grantee key `D`, and the viewer drives the Authorised explorer mode ([§5.5](#55-two-explorer-modes)). It is **non-bearer** (the viewer must hold `D`'s secret), scoped, and **forward-only revocable**.

**(b) Bearer — account view key.** The subject hands over a bearer link carrying the account viewing keys themselves:

```
zkavk = Bech32m( HRP = "zkavk", data = ivk ‖ ovk )    // 64B; ivk = incoming, ovk = outgoing
                                                       ; ivk alone (32B) = incoming-only variant

zkcoins:addr/<address>/<zkavk>
  <address> = Bech32m( HRP "zk", H(Pk₀ ‖ nk_commit) )   ; the account whose full history is disclosed
  — an explorer MAY render it as https://<explorer-host>/addr#<address>/<zkavk>
  — a holder hint MAY be appended INSIDE the fragment as …#<address>/<zkavk>;h=<locator>, parsed
    per the holder-hint parse rule in §5.6; it travels in the fragment, never as a query or path
    component, so it is never sent to any server. It is an optimisation only. The account's coins
    are found by deriving detect_tags from ivk and scanning the mesh, so no locator is required.
```

The secret travels in the fragment per the link-transport rules in [§5.6](#56-shareable-confirmation-links).

**Flow.** The explorer holds `ivk` ([Foundations §1.3](#13-per-coin-keys-note-encryption--detection)), finds the account's coins by scanning the relay mesh ([Transport & Recovery](#4--transport--recovery)) and recomputing each candidate's `detect_tag` from `ss = ECDH(ivk, epk)` (a `;h=<locator>` fragment hint, if present, only speeds resolution), decrypts incoming coins with `ivk` and recovers outgoing-coin plaintext with `ovk` — opening each `SelfDeliveryRecordV1` `output_ref.out_ciphertext` via `K_out = HKDF("zkCoins/v1/OutKey", ovk ‖ epk)` ([§1.3](#13-per-coin-keys-note-encryption--detection), [§4.2](#42-bundle-delivery)) — and renders the full history (under the 32-byte `ivk`-only form no `ovk` is present: outgoing-coin recovery is skipped and only the incoming side of the history is rendered) — checking every transaction against Bitcoin (coin inclusion → the creating transition's on-chain nullifier is the **first occurrence** `completed` ([On-chain §3.6](#36-chain-scanning), [§3.10](#310-transaction-states)), with `Pk_create == creating_proof.consumed_pubkey` (the [§5.6](#56-shareable-confirmation-links) disclosure-verifier key binding, [§2.1 clause 9](#21-the-compliance-predicate)) → recursive proof and canonical `nav`, as in [§5.6](#56-shareable-confirmation-links)). Mint coins are no exception: the mint is itself a state-advancing transition that anchors its own nullifier, so its entry is checked and rendered with the same `completed`/`pending`/`failed` states (alongside re-verifying the mint's recursive proof — an `InitialProof`, or an `AccountUpdateProof` carrying `asset_issuance` for a follow-up mint), as in §5.6. The explorer is never trusted.

**Properties.**

- **Bearer & irrevocable.** Whoever holds the link sees everything `ivk`/`ovk` unlock — under the `ivk`-only form, only what `ivk` unlocks — past **and future** — until the account is abandoned. The viewing keys cannot be rotated without moving to a new account; there is no revocation. Use form (a) when it matters that the window can be bounded and future pulls refused at nodes you operate; neither form retracts what a holder already read ([§5](#5--access--explorer) *Consent is one-way*).
- **Account-granular.** It reveals the whole account, never a subset ([Foundations §1.2](#12-key-hierarchy)). Compartmentalisation = separate accounts.
- **Read-only.** It carries no spend authority: the SPEND branch is a hardened sibling of the VIEW branch ([Foundations §1.2](#12-key-hierarchy)) and cannot be derived from `ivk`/`ovk`.
- **Verifiable.** Every figure is independently checked against Bitcoin and the proof.



## 6 · System Architecture

> *In one sentence: how node, wallet, and explorer fit together, why running your own node is the trustless default, and how permissionless asset creation and node portability come out of the same design.*

This page specifies **how the parts fit together**: the three components (node, wallet, explorer), the wallet↔node relationship, node portability and multi-node operation ([Requirement 10](/requirements)), the node's external interfaces, versioned issuance ([Requirement 8](/requirements)), and the threat model. It builds strictly on [Foundations](#1--foundations-normative) — the key hierarchy (§1.2), per-coin keys (§1.3), identifiers (§1.4), and the nullifier accumulator (§1.6) — and references the sibling sections for the mechanisms they own rather than re-specifying them.

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) are used per RFC 2119.

### 6.1 Components and responsibilities

zkCoins is exactly three components. The split between them is **packaging, not a trust boundary**: it mirrors the Bitcoin full-node model (a validator plus a thin key-holder). The one line never crossed is the SPEND branch — it lives only in the wallet.

#### The full system stack — hardware to app

Those three trustless components do not run in a vacuum: they sit inside a larger operational stack. **This specification covers the whole of it — hardware to app — not only the trustless core.** Because the system is split across several repositories, the docs repository is the single place that describes the system end to end. The layers, top to bottom, and their owning repos:

```mermaid
flowchart TB
  a["End-user app · Explorer web-app"] --> b["SDK"]
  b --> c["zkCoins API + own PostgreSQL"]
  c --> d["zkCoins node + PostgreSQL + Publisher"]
  d --> e["bitcoind · Nostr relay"]
  e --> f["Docker"]
  f --> g["Operating system"]
  g --> h["Hardware"]
```

| Layer | What runs there | Repo | Role / trust |
|---|---|---|---|
| **App · Explorer** | end-user wallet UI (NIP-05 receive identity §4.3, push receipts §4.9) · public explorer web-app | `zk-coins/app` · `zk-coins/explorer` | presentation; the app holds keys on-device, the explorer holds none |
| **SDK** | thin client — on-device client-side primitives (key derivation, hashing, signing), node/API calls | `zk-coins/sdk` | custody stays on the device; REST + stream client |
| **zkCoins API** (+ own PostgreSQL) | the sole public REST surface; features `wallet`, `explorer`, `publisher`, and the two bridges, each switched on by the operator | `zk-coins/api` | present whenever a wallet or explorer is served; owns a **non-value-bearing** database |
| **zkCoins node** (+ PostgreSQL + Publisher) | the trustless **kernel**, gRPC only: scan · accumulator · verify · prove · store · publisher/broadcaster · Nostr transport | `zk-coins/node` | the trustless core; owns the **value-bearing** database (§4.8) |
| **bitcoind · Nostr relay** | Bitcoin L1 settlement and ordering · off-chain transport and data availability | upstream (own or external) | inherits Bitcoin's trust; transport trusted only for availability (§4.1) |
| **Docker · OS · Hardware** | container runtime, host operating system, physical machine | — | the operational substrate the operator provides |

Every layer above the substrate is the operator's own in the sovereign deployment (*Running a node*, below); the SPEND branch never leaves the top layer — the app/wallet on the user's own device ([Foundations §1.2](#12-key-hierarchy)).

#### The node — validator, prover, transport, store

The node is the always-on workhorse. It **MUST** be runnable as a single self-contained container with no operator-specific dependencies ([Requirement 7](/requirements)). Its responsibilities:

- **Bitcoin scanner.** Reads Bitcoin L1, extracts inscribed nullifiers (marker `0x42 0x42`, Foundations §1.4), verifies each nullifier's signature over the per-network fixed constant `m_state` for the network the scanner operates on, and folds each fresh `Pkᵢ` into the global nullifier accumulator by **first-occurrence** (Foundations §1.6). The accumulator is a **pure function of the on-chain nullifiers** — rebuilt from Bitcoin alone, with no off-chain data-availability dependency. See [On-chain Layer](#3--on-chain-layer).
- **Prover** (optional — see *Node roles* below). Builds the per-account recursive validity proofs for transactions it is asked to construct. A node that *also* acts as a publisher additionally **half-aggregates** collected transition signatures (§3.3, no proof, no secret keys). See [Proofs & State Transitions](#2--proofs--state-transitions).
- **Transport and messaging.** Serves and fetches the off-chain delivery **events** via its paired Nostr relay and the `CoinProof` bundle **blobs** via its co-located Blossom store ([§7.4](#74-blossom-blob-store-normative)), performs `detect_tag` discovery for coin bundles, and sends/receives standard NIP-17 human messages using kind-10050 DM relays — through the operator's paired relay and blob store and the relays advertised by contacts ([§6.6](#66-threat-model-and-trust-configurations)). See [Transport & Recovery](#4--transport--recovery).
- **Data store.** Durably persists **every** value-bearing and accumulator artefact it receives — the *store-everything* invariant ([§4.8](#48-durability--the-store-everything-invariant)) — plus rebuilt tree state; the operator layers a real-time backup on top of this store, outside the node software's own scope ([§4.8](#48-durability--the-store-everything-invariant) *Operator durability duty*, [Requirement 6](/requirements)).
- **Capability-gated API.** Answers **Private** reads only against a valid ownership proof or view grant, and accepts transaction submissions; the one open exception is the non-private token-provenance read (`read.provenance`, [§7.5](#75-node-rest-api-normative), [§4.6](#46-data-availability) Class B). See [Access & Explorer](#5--access--explorer) and §6.4 below.

**Keys it holds.** For accounts that delegate to it, the node holds the **operational bundle** `{ivk, ovk, op, nk, op_secret}` (Foundations §1.2): `ivk` to detect and decrypt incoming coins, `ovk` to recover outgoing-coin plaintext, `op` to act as the account's standard Nostr identity, encrypt/decrypt NIP-17 messages, and sign kind-0 metadata, kind-10050 relay lists, NIP-59 seals, view grants, and acknowledgements, and `nk` to derive nullifiers when building proving witnesses ([§2.1 clause 4](#21-the-compliance-predicate)). For a *foreign* account it holds only an `op`-signed **view grant**, never the bundle directly.

**What it cannot do.** A node **MUST NOT** be able to spend, forge, or double-spend: it never holds any SPEND-branch key (the rotating `skᵢ`), and value integrity is enforced by proof soundness and the nullifier accumulator, not by the node's honesty. `nk` (held for the node's own accounts only) enables nullifier derivation and therefore linkage of *that account's own* spends — a privacy consideration internal to the operator, never spend authority. A foreign node **MAY** lie or withhold data, but it cannot make the account's own node accept an unverifiable answer (§6.3).

#### Node roles — core vs optional

Two programs, two decisions. The **kernel** (`zk-coins/node`) is one binary whose parts — scanner, accumulator, verification, state store, prover, publisher — share the whole [Foundations](#1--foundations-normative) layer and are selected per deployment by **configuration**, never by running a different binary. It speaks gRPC only. The **API layer** (`zk-coins/api`) is the separate program that carries every public REST surface, and its operator switches its features on one by one. The SPEND branch is never any of this (Foundations §1.2).

A node operator decides whether to run the kernel alone or the kernel with an API in front of it. An API operator decides, independently, which of the features below to serve.

**Wire advertisement (normative):** `GET /v1/info` ([§7.5](#75-node-rest-api-normative)) carries a `features` array whose elements are drawn from the **closed** set `{wallet, explorer, publisher, lightning_bridge, mail_bridge}`, listing exactly what this API has enabled. Unknown values **MUST** be ignored on read; a feature absent from the array is **off**, and a client **MUST** treat it as absent rather than attempting it (fail-closed). The kernel reports its own configured parts through the kernel `Info` message ([§7.8](#78-kernel-rpc--the-internal-interface-normative)); that report is operator-internal and reaches a public client only as far as `/v1/info` relays it.

**Kernel parts** (`zk-coins/node`, gRPC only):

| Part | Core or optional | Default |
|---|---|---|
| Bitcoin scanner · nullifier-accumulator · proof **verification** · state store | **Core** — every kernel | always on |
| Nostr transport: bundle delivery, standard NIP-17 messaging on kind-10050 DM relays addressed by key, known-contact pinning ([§4.3](#43-addressing-for-delivery), [§7.3](#73-nostr-event-kinds-normative)) | **Core** | always on |
| **Prover** — builds the recursive validity proofs | **Core** *if* this deployment proves at all | on / off |
| **Publisher** — half-aggregates collected transition nullifiers and inscribes them ([§3.4](#34-the-publisher)) | optional | **off** |

**API features** (`zk-coins/api`, the public REST surface). Each is off until the operator enables it, and each is named in the `features` array above:

| Feature | What it opens | Default |
|---|---|---|
| `wallet` | proving, submission, and capability-gated pull for the accounts this API serves — plus the NIP-05 names for those accounts, since hosting a wallet and naming it are one feature ([§4.3](#43-addressing-for-delivery)) | **off** |
| `explorer` | the public read surface an explorer consumes: chain projection, accumulator, inclusion proofs, blob fetch ([Access & Explorer](#5--access--explorer)) | **off** |
| `publisher` | the [§7.6](#76-publisher-interface-normative) hand-off endpoint, forwarded to a kernel whose publisher part is on | **off** |
| `lightning_bridge` | Lightning ⇄ zkCoins swaps at the operator edge ([extension](/lightning-bridge)) | **off** |
| `mail_bridge` | SMTP interop for the account's NIP-05 identifier ([extension](/mail-bridge)) | **off** |

A few standard **deployments** follow:

- **Sovereign personal** — kernel with prover on, plus an API serving `wallet` for the owner's own account and nothing else. No foreign accounts, no publisher, no bridges. This is the private default.
- **Public service** — the same, with `wallet` open to accounts that delegate to it, and whichever further features the operator chooses. Proving for someone else means receiving that account's plaintext witness, so this is where the privacy trade-off for *its users* sits ([§6.6](#66-threat-model-and-trust-configurations)); it is opt-in, never forced.
- **Validating node** — kernel alone: verification and accumulator, no prover, no publisher, no API. It follows and checks the chain and answers nobody.
- **Publisher back end** — kernel with the publisher part on, fronted by an API serving `publisher` alone. It needs an `op` key, a relay presence, and its hand-off endpoint — no name, no domain, no DNS ([§3.8](#38-fees-and-economics)).
- **Explorer host** — an API serving `explorer` in front of a kernel, plus the stateless explorer frontend itself ([§6.1](#61-components-and-responsibilities) *Running a node*). It holds no keys and serves no wallet.

#### Kernel and API — two boundaries (RPC inward, REST outward)

The optional roles split from the core along **one clean seam**, which fixes where the broadcaster, the prover, and the databases live:

- **Inward — the kernel RPC.** The trustless **kernel** (`zkcoins-node`) exposes a typed, server-to-server **RPC** (gRPC recommended: a `.proto` contract with codegen for Rust and clients). Its procedures are verb-shaped — `scanChain`, `accumulatorPath`, `prove(witness)`, `submitTransition`, and a `subscribe` server-stream of receipts (§4.9). This RPC is the **stable contract** everything else builds on; an alternative API layer, an indexer, or a power user can build against it — exactly as the Bitcoin ecosystem builds on `bitcoind`'s RPC. The full procedure set, its transport, and the boundary's trust model are fixed in §7.8.
- **Outward — the public REST API.** The **API layer** (`zk-coins/api`, its own repository and container) consumes the kernel RPC and is the **sole** public surface ([§6.4](#64-external-interfaces-abstract)): every request from a wallet, the SDK, the app, or the explorer arrives here as REST. The kernel speaks gRPC and nothing else, so **every** deployment with any public surface at all runs an API container — a wallet or explorer host under the `wallet`/`explorer` features, a publisher back end under `publisher`, since the [§7.6](#76-publisher-interface-normative) hand-off is a public endpoint too. Only a **validating node**, which serves nobody and exposes nothing, runs the kernel alone.

This seam answers three placement questions normatively:

- **Publishing and proving are kernel work; their public endpoints are API features.** Half-aggregating and inscribing need accumulator state, the proving stack, and `bitcoind` — all kernel-side ([§3.4](#34-the-publisher)). The API layer **MUST NOT** touch Bitcoin and **MUST NOT** prove; under its `publisher` feature it exposes the [§7.6](#76-publisher-interface-normative) hand-off and forwards it down the kernel RPC, and under `wallet` it forwards transition intents and wallet signatures ([§7.8](#78-kernel-rpc--the-internal-interface-normative)). The work stays where the state is; only the door is the API's.
- **Two databases, two owners.** The kernel is the **sole writer and reader** of the **value-bearing / accumulator** PostgreSQL — the store-everything database ([§4.8](#48-durability--the-store-everything-invariant)). The API layer **MUST NOT** read or write it directly; it obtains and submits all zkCoins state through the kernel RPC. Purely operational API state — operator-hosted NIP-05 name claims, rate-limit counters, API keys, push-subscription registrations — is **not** value-bearing (losing it loses a hosting convenience, never funds, since address and keys are seed-derivable) and lives in a **separate** database owned by the API layer (its own PostgreSQL in a public-service deployment). Neither owner touches the other's store. A **validating node**, which exposes nothing at all, runs no API and therefore has only the kernel database. A **publisher back end** does run an API — serving `publisher` alone, since the [§7.6](#76-publisher-interface-normative) hand-off is a public endpoint — but that API holds no account state, so its database is empty in practice and **MAY** be omitted. A sovereign personal deployment does serve a wallet, so it has both, whether as two database processes or as two schemas under one.
- **Names live above the kernel.** The API and app layers resolve an account's email-style name ([§4.3](#43-addressing-for-delivery)), and an API layer running the `wallet` feature issues names for the accounts it serves — hosting a wallet and giving it a name are one feature, not two. A holder **MAY** instead bring a name from a self-hosted domain or any third-party NIP-05 provider. The kernel takes `op_pubkey`, `nprofile`, or an `addr_sig`-carrying object for everything it is asked to do, so a publisher back end runs on an `op` key, a relay presence, and its own hand-off endpoint ([§3.8](#38-fees-and-economics)).
- **Packaging and deployment.** Serving a wallet or an explorer means running the API container and its own database alongside the kernel stack of *Running a node* below; the difference between a **sovereign personal** and a **public-service** deployment is then which features that API enables and for whose accounts, not whether it exists. A **publisher back end** likewise runs an API container, enabling `publisher` alone. Only a **validating node** exposes nothing and runs the kernel stack alone. The boundary is between **components**, not between processes: the kernel parts serve no REST and the API parts touch neither Bitcoin nor the value-bearing store, whatever they are packaged into. Kernel and API **MAY** therefore ship as one repo and one binary — with the RPC as an internal crate boundary — and a small deployment **MAY** run them as one process against one database process, provided each component still owns only its own schema and the public listener is the API's. Splitting into separate repos, containers, and database instances is the public-service arrangement and the one *Running a node* below describes.

```mermaid
flowchart TB
  app["wallet app · SDK"]
  expl["explorer"]

  subgraph apilayer["API layer — own repo/container · the only public surface"]
    api["public REST /v1/<br/>features: wallet · explorer<br/>publisher · bridges"]
    apidb[("postgresql<br/>API app state")]
  end

  subgraph kernel["zkcoins-node — trustless kernel"]
    core["scan · accumulator · verify · store"]
    prover["prover"]
    bcast["broadcaster / publisher"]
  end

  pg[("postgresql<br/>value-bearing + accumulator")]
  btc["bitcoind"]

  app -->|"REST · SSE/WS push"| api
  expl -->|"REST"| api
  api -->|"gRPC — kernel RPC"| core
  api --- apidb
  core --- prover
  core --- bcast
  core ==>|"sole writer/reader"| pg
  bcast -->|"inscribe · broadcast"| btc
```

#### The wallet — thin key-holder

The wallet holds the **seed** and is the sole custodian of the SPEND branch (`A/0'`, i.e. the rotating `skᵢ`; Foundations §1.2). It also derives `nk`, but delegates `nk` to its own node as part of the operational bundle (§1.2, §6.2) — the node needs it to build proving witnesses. Its responsibilities:

- Derive all keys deterministically from the seed (Foundations §1.2); hold **no** node-specific value-bearing state.
- Sign each transition — produce `BIP-340(skᵢ, m_state)` over the per-network fixed `m_state = "zkCoins/v1/StateUpdate/{mainnet|testnet|regtest}"` (Foundations §1.4) with the sign-to-contract tweak that binds the transition's off-chain `H(ProofData)` in the nonce. The node derives the nullifiers `nf = Hc("Nullifier", nk ‖ coin.identifier)` from the operational bundle's `nk` while building the witness ([§2.1 clause 4](#21-the-compliance-predicate)). The resulting transition's on-chain nullifier `(Pkᵢ, Rᵢ)` is handed to a publisher off-chain ([§7.6](#76-publisher-interface-normative)); the wallet does **not** itself touch Bitcoin.
- Delegate the operational bundle to its **own** node, or issue a scoped view grant to a **foreign** node (§6.2).
- Fetch authoritative state from its node(s), which **verify** it against Bitcoin on the wallet's behalf (§6.2; [Requirement 4](/requirements): "the receiver, or its own node acting on its behalf"), before signing or accepting a received coin.

**What it cannot do.** The wallet **MUST NOT** be required to be online continuously: detection, decryption, and serving are delegated to the node so that liveness does not depend on the wallet. The wallet performs no relay duty itself.

#### The explorer — stateless presentation

The explorer is a **stateless** read surface over one or more nodes. It holds **no keys** and no private state of its own. Given a per-coin view capability `K_tx` (Foundations §1.3) — carried in a shareable link — it decrypts and presents exactly one transaction and verifies that confirmation against Bitcoin ([Requirement 9](/requirements)). It **MUST** be self-hostable and **MUST NOT** assert any fact it cannot derive verifiably from a node's data and the chain. It is a separate **frontend** — its own repository and its own container, a sibling of the wallet app, **not** part of the node program — and offers no publisher or wallet-hosting role; it reads a node's public endpoints. See [Access & Explorer](#5--access--explorer).

#### Running a node — what an operator deploys

The logical roles above map onto a small `docker compose` stack of **six distinct containers** — `bitcoind`, `nostr-relay`, `zkcoins-node`, `zkcoins-api`, `postgresql`, and `explorer` — each an independently deployable building block. Only `zkcoins-api` listens publicly; `zkcoins-node` speaks `kernel.v1` gRPC on the internal network and terminates nothing from outside it. The two components own separate schemas, which a small deployment **MAY** host in the one `postgresql` container above and a public service separates. The **sovereign default** is that every container is the operator's own: that is the trustless, private path the system is designed around, and the one a serious user should choose. But the blocks are **composable**, not welded together — the `zkcoins-node` reaches its `bitcoind` and its `nostr-relay` over defined interfaces ([§6.4](#64-external-interfaces-abstract)), so each **MAY** instead be pointed at an **external** instance, and a minimal deployment **MAY** run the node against an external `bitcoind` and external relay(s) without operating either itself. Relying on an external block is a deliberate **trust/privacy trade-off** — the same spectrum as pointing a Bitcoin wallet at someone else's Electrum server ([§6.6](#66-threat-model-and-trust-configurations)) — and **never** a custody risk: the account's own node re-verifies every result against Bitcoin on the wallet's behalf before it acts ([Requirement 4](/requirements), [§6.2](#62-wallet--node)).

```mermaid
flowchart TB
  wallet["Wallet — SPEND keys only<br/>(user device, never containerised)"]

  subgraph stack["Sovereign node deployment — one docker compose stack (6 containers)"]
    direction TB
    explorer["explorer<br/>stateless presentation"]
    zapi["zkcoins-api<br/>public REST /v1/ · capability gate"]
    znode["zkcoins-node<br/>scanner · prover · kernel.v1 gRPC"]
    relay["nostr-relay<br/>off-chain bundle transport"]
    pg[("postgresql<br/>node state · bundles")]
    bitcoind["bitcoind<br/>Bitcoin full node"]
  end

  chain(["Bitcoin network"])
  mesh(["Nostr network"])

  wallet -->|"submit · verify vs Bitcoin — TLS or Tor"| zapi
  wallet -.->|"open one tx — TLS or Tor"| explorer
  explorer -->|"read"| zapi
  zapi -->|"kernel.v1 gRPC — operator-internal"| znode
  znode -->|"chain RPC"| bitcoind
  znode -->|"relay protocol"| relay
  znode --- pg
  bitcoind <-->|"read · broadcast"| chain
  relay <-->|"deliver · indefinitely retained; optional redundant copies"| mesh
```

The containers, each shipped and run independently. The first four are the kernel stack; the API pair is added by any deployment that serves a wallet or an explorer:

- **`bitcoind` — Bitcoin full node.** The source of truth for **reading** the chain (the scanner) and for **broadcasting** the publisher's Taproot reveal transactions. The operator's own `bitcoind` is the default and the only fully trustless option; the node **MAY** instead be configured against an **external** `bitcoind` (one the operator trusts, or a shared instance), trading some privacy and eclipse-resistance for operational simplicity ([§6.6](#66-threat-model-and-trust-configurations)).
- **`nostr-relay` — transport.** A full Nostr relay that stores and serves the gift-wrapped delivery **events** — the node's Blossom blob store ([§7.4](#74-blossom-blob-store-normative)) serves the `CoinProof` bundle **blobs** those events reference — and carries standard NIP-17 messages ([Transport & Recovery](#4--transport--recovery)). It runs as its **own container**; the node connects to it over the relay protocol. The operator's own relay is the default for zkCoins bundle traffic; NIP-17 messages are published to each recipient's kind-10050 relays, which may be external.
- **`zkcoins-node` — the kernel.** Bitcoin scanner, prover, publisher, data store, Nostr transport. One self-contained container that connects out to `bitcoind` and `nostr-relay` and persists to PostgreSQL; it exposes the `kernel.v1` gRPC on an operator-internal channel only ([§7.8](#78-kernel-rpc--the-internal-interface-normative)) and never holds a SPEND key.
- **`postgresql` — node database.** Persists the rebuilt nullifier set and the off-chain bundles (the concrete backing of the data-store role). Its own container.
- **`zkcoins-api` — the public surface.** The only component reachable from a public client: it terminates every REST endpoint of [§7.5](#75-node-rest-api-normative), enforces the capability gate, and consumes the kernel gRPC. Its enabled `features` decide what it answers, except the open `read.provenance` token-provenance read, which is served whenever the node holds the terms regardless of `features` ([§6.4](#64-external-interfaces-abstract)). Present whenever the deployment serves a wallet or an explorer.
- **`postgresql` (API) — API database.** The non-value-bearing store of [§6.1](#61-components-and-responsibilities): served accounts' name claims, rate-limit counters, API keys, push-subscription registrations. Its own container, alongside the API.
- **`explorer` — stateless presentation.** The read surface ([Access & Explorer](#5--access--explorer)), its own container reading the API's `explorer` feature; it holds no keys. It is **optional** — a headless deployment **MAY** omit it.
- **Reachability** (not a container) — an internet domain with TLS, or a Tor onion service for IP privacy, so wallets, explorers, and peer nodes can reach the node's API and its relay.

The two outward-facing blocks — the **chain source** and the **transport relay** — are the pluggable slots. Each is the operator's own by default (sovereign) or an external instance (a trust/privacy trade-off); everything else the operator always runs:

```mermaid
flowchart LR
  subgraph run["What the operator always runs"]
    direction TB
    znode["zkcoins-node"]
    pg[("postgresql")]
    explorer["explorer<br/>(optional)"]
  end

  subgraph srcsel["Chain source — pick one"]
    direction TB
    b_own["bitcoind — own<br/>(default · sovereign)"]
    b_ext["external bitcoind<br/>(trust/privacy trade-off)"]
  end

  subgraph trsel["Transport — pick one or more"]
    direction TB
    r_own["nostr-relay — own<br/>(default · sovereign)"]
    r_ext["external relay(s)<br/>(trust/privacy trade-off)"]
  end

  explorer --> znode
  znode --- pg
  znode ==>|"chain RPC (default)"| b_own
  znode -.->|"or"| b_ext
  znode ==>|"relay protocol (default)"| r_own
  znode -.->|"or / additionally"| r_ext
```

The only thing that is **never** part of a node deployment is the SPEND branch — those keys live solely in the wallet, on the user's device ([Foundations §1.2](#12-key-hierarchy)).

### 6.2 Wallet ↔ node

The wallet is a **thin client**. It never delegates spend authority; it delegates only viewing and serving:

- **Own node.** The wallet entrusts its node with the full operational bundle `{ivk, ovk, op, nk, op_secret}` (Foundations §1.2) over an authenticated channel — concretely, the ownership-proof-gated entrust/revoke endpoints and canonical bundle encoding of [§7.7](#77-wallet--node-bootstrapping-normative), carried over the node's already-mandatory TLS/Tor transport ([§7.5](#75-node-rest-api-normative)). The node can then receive, decrypt, discover, prove, and serve on the account's behalf 24/7. None of the bundle can spend.
- **Foreign node.** The wallet **MUST NOT** hand a foreign operator the bundle. Instead it issues that node a scoped, `op`-signed **view grant** (Bech32m HRP `zkgrant`, Foundations §1.7) that authorises a bounded read — defined in [Access & Explorer](#5--access--explorer).

Before it signs, the wallet fetches the current authoritative state from its node: the account's latest `AccountState` via ownership-gated `GET /v1/account/state` ([§7.5](#75-node-rest-api-normative) — canonical bytes, `send_counter`, `current_pubkey = Pkᵢ`, last state-nullifier `(Pk, R)`, and the proof/state-head locator), plus the relevant nullifier-set state and input bundles (pull / `GET /v1/proof/<coin_id>`). Verifying that state against Bitcoin is the **node's** job, performed on the wallet's behalf — the Bitcoin full-node model ([Requirement 4](/requirements) is always "the receiver, **or its node on its behalf**"): the wallet trusts **its own** node exactly as a Bitcoin wallet trusts its own `bitcoind`, and trust is reduced by **self-hosting**, never by bolting verification onto the thin client. The wallet **does** check the signing-key index before signing: `derive(A / 0' / send_counter).pubkey == current_pubkey == txn_pubkey` ([§1.2](#12-key-hierarchy), [§7.5](#75-node-rest-api-normative) wallet-side recomputation); Bitcoin- and recursive-proof verification stay node-side under the v1 trust model. Relying on a *foreign* node instead is the deliberate trade-off of §6.6.

### 6.3 Node portability and multi-node operation

[Requirement 10](/requirements) is met structurally for custody and transacting: **a wallet depends on no node-specific value-bearing state.** Wallet keys and scanning secrets are derived from the seed (Foundations §1.2–§1.4); value-bearing coin and state bundles are content-addressed, permanently retained, fetchable, and independently verifiable ([§4.5](#45-recovery), [§4.8](#48-durability--the-store-everything-invariant), [§4.6](#46-data-availability)); and the one global structure — the nullifier accumulator — is reconstructable by any node from the on-chain nullifiers alone (Foundations §1.6, [On-chain §3.6–§3.7](#36-chain-scanning)). No such state is tied to one node. The accumulator itself is a **pure function of the on-chain nullifiers** and therefore has no off-chain data-availability dependency: any node at the same Bitcoin tip computes the identical accumulator, trusting no peer. Recovery of spendable coins still depends on permanently retained off-chain bundles under [Requirement 6](/requirements) / [Requirement 12](/requirements#12-data-permanence), exactly as §4.5–§4.8 specify.

- A wallet **MAY** switch nodes at any time, by configuration alone, with no migration of value-bearing state. No node can lock a wallet's funds in. Preserving the non-value-bearing residuals named below can require re-issuing or transferring them.
- A wallet **MAY** use **multiple nodes simultaneously** — querying several, submitting through one or more.

**Why multi-node is safe.** Every node answer is proof-carrying and verifiable against Bitcoin ([Requirement 4](/requirements)); an honest node returns verifiable truth, and a dishonest one cannot forge a valid recursive proof or a valid on-chain nullifier signature ([§3.2](#32-transition-signing-bip-340--sign-to-contract)). In the node model (§6.2), verification lives node-side: a wallet that operates **its own node** (the sovereign default) has that node check every foreign answer, keeps the answer that verifies, and ignores the rest — the **"at least one honest node"** property: correctness holds as long as ≥1 queried node is honest. A wallet configured **only** with foreign nodes gets *discrepancy detection* from fan-out rather than proof: on **any** disagreement between its configured nodes it **MUST** fail closed and surface the conflict instead of picking a side. The configurations this yields are summarised in [§6.6](#66-threat-model-and-trust-configurations).

**Selecting the latest state under multiple verifying answers.** Multi-node fan-out can return **more than one** answer that verifies — typically because the queried nodes are at different sync states (each holds a valid snapshot of the lineage at a different `send_counter`). The wallet **MUST** select as authoritative "latest" the answer with the **highest `send_counter`** among those that qualify, before signing the next transition: a candidate **qualifies** when every **state-advancing** transition in its lineage — sends, receives, and mints included — is anchored, its on-chain nullifier in state `completed` ([§3.10](#310-transaction-states)), each nullifier's key bound to its transition's `consumed_pubkey` (the in-circuit clause 1 (iii) / clause 10(d) binding, [§2.1 clause 9](#21-the-compliance-predicate), re-run by the candidate's own recursive proof, so no fresh-key substitution qualifies). A mint transition ([§2.3.1](#231-mint--issuance)) is **not** exempt: it publishes its own `(Pkᵢ, Rᵢ)` and must reach `completed` like any other transition before the candidate qualifies; its validity is additionally attested by the candidate's own recursive proof. Two verifying answers with the **same** `send_counter` but **different** `new_account_state_hash` are an account-level fork — the SPEND-key holder signed two parallel transitions at the same counter. A wallet that detects this **MUST NOT** sign a further transition until the user resolves it, because sole legitimate control of `sk₀` and `skᵢ` never produces equivocation; detection here means either operator error (the same seed driven from two wallet instances against stale state) or a custody breach of the SPEND branch. The protocol does **not** automatically pick a fork-winner; the choice is the holder's. When **no** candidate qualifies (e.g. every recent spend is still within finality), the wallet builds the next transition against the highest-counter candidate whose state-advancing transitions are **final** (`nav = size_final`, §2.3.2 step 5); a not-yet-final candidate is simply not yet spendable, so the wallet waits; deployments handling extreme value **SHOULD** wait for `completed` before extending.

**Three portability residuals — the honest scope of "no node-specific value-bearing state".** [Requirement 10](/requirements)'s *"no node-specific value-bearing state"* covers the state a wallet needs to keep transacting: keys and the accumulator are seed-/chain-derived, while coin and state bundles are content-addressed, replicated, fetchable, and independently verifiable. None is tied to one node, so the switch and multi-node paths above carry **no value-state** migration step. Three **non-value-bearing** residuals are worth naming; none is a lock-in or a custody break:

- **Grant revocation is node-local and best-effort.** A view-grant revocation set lives on the node(s) the subject instructs ([§5.2](#52-view-grant)): "a node a subject does not control cannot be compelled … grants **SHOULD** carry a short `expiry`" (§5.2). On a node switch or in multi-node operation the subject **MUST** re-issue each still-active revocation to the new or additional nodes — a property of the best-effort revocation channel, not of node-specific *value* state; the coins and their spendability port regardless.
- **An abandoned node keeps its view.** A node that held the account's **operational bundle** `{ivk, ovk, op, nk, op_secret}` retains a permanent incoming-receive-and-decrypt view of the account after the wallet switches away, because the account's viewing keys cannot be rotated without moving to a **new account** ([§5.8](#58-address-view-full-history)). This is a **privacy** residual ([Requirement 2](/requirements)) — the old operator can still decrypt coins later sent to that address — not a custody break or a lock-in: the switch itself is complete, spend authority never left the wallet ([Requirement 5](/requirements)), and the new node serves the account fully.
- **Known-contact continuity uses local state.** The retained §4.3 contact record — keyed by the contact's pinned `op_pubkey`, with its known names, standard `nprofile`, last valid kind-10050 DM relays, optional pinned payment identity, and original-hostname-authenticated TLS/WebSocket endpoints — is not seed- or chain-derived. Switching nodes or recovering from the seed alone **without transferring that record** therefore resets trust-on-first-use and loses DNS-free cold-start reachability for that contact; the contact must be rediscovered when DNS returns. Transferring the record is **local deployment behavior, not a zkCoins or Nostr wire protocol**, so this specification states only what a client must not do with what it holds: a partial record **MUST NOT** be presented as providing DNS-free continuity, an existing pin **MUST NOT** be silently discarded or replaced, and a client that has lost its pin set **MUST NOT** silently re-pin a previously known contact as if it were a first contact ([§4.3](#43-addressing-for-delivery) *Payment-identity pinning*). A deployment that wants continuity across a node switch **SHOULD** transfer the complete record through an authenticated operator-controlled facility. None of this affects custody or spendability.

### 6.4 External interfaces (abstract)

The node exposes six interface families, specified here at an implementation-neutral level; the owning sections define their exact payloads.

| Interface | Direction | Capability required | Purpose | Specified in |
|---|---|---|---|---|
| **read.account** | wallet/node → node (pull) | an **ownership proof** (sign the challenge with `sk₀`) **or** an `op`-signed **view grant** | fetch `AccountState`, balances, owned coins, and their bundles — concrete: record locators via [§5.1](#51-capability-gated-pull) pull; the **authoritative** current `AccountState` (canonical bytes + `send_counter` / `current_pubkey` / last state-nullifier) via **ownership-gated** `GET /v1/account/state` ([§7.5](#75-node-rest-api-normative), [§7.8](#78-kernel-rpc--the-internal-interface-normative) `GetAccountState`) | [Access & Explorer](#5--access--explorer) · [§7.5](#75-node-rest-api-normative) |
| **read.proof** | wallet → node (pull) | an **ownership proof** **or** an `op`-signed **view grant** (within its scope) | fetch a `CoinProof` and its `inclusion_proof` for re-verification | [Access & Explorer](#5--access--explorer) · [Proofs](#2--proofs--state-transitions) |
| **submit.tx** | wallet → node (push) | none (proof is self-authenticating) | submit a transition for proving and on-chain publication | [On-chain Layer](#3--on-chain-layer) |
| **relay.\*** | any ↔ node (Nostr + Blossom) | standard NIP-17 identity/message events; NIP-44 / NIP-59 envelope; `detect_tag` for `CoinProof` discovery; Blossom `blob_id` for `CoinProof` blob fetch | NIP-05/profile discovery, NIP-17 messaging, off-chain `CoinProof` delivery, note discovery, permanent retention (Data Permanence, §4.8) | [Transport & Recovery](#4--transport--recovery) |
| **explorer.read** | explorer → mesh / node | a bearer view secret (`zkview` per coin, `zkavk` for full history) or a balance attestation, applied **client-side** | render a disclosed view: one transaction, full account history, or a balance | [Access & Explorer](#5--access--explorer) |
| **read.provenance** | any → node | **none** — open, unauthenticated ([§4.6](#46-data-availability) Class B) | fetch the issuer-originated `asset_terms` for an `asset_id` (self-verifying), so a token survives the loss of its issuer | [§7.5](#75-node-rest-api-normative) `GET /v1/token/<asset_id>/provenance` |

The `read.account` path is **capability-gated**: a node **MUST** reject a request that does not present a valid ownership proof or `op`-signed view grant. Bearer view secrets (`zkview`/`zkavk`) and balance attestations are **not** node authorisations — the explorer applies them client-side to bundle blobs obtained from a blob store or a holder, so `explorer.read` widens only what the secret-holder can decrypt from already-public material ([Access & Explorer §5.1](#51-capability-gated-pull)). The `submit.tx` path needs no capability because the submitted transition carries its own validity proof and self-authenticating `SpendRecord`; a node **MUST** verify that proof before publishing.

**Which surface belongs to which program.** The families above split cleanly. **relay.\*** is the kernel's own transport plane — the Nostr relay (event delivery, `detect_tag` discovery, NIP-17 messaging by key, contact pinning) and the co-located Blossom blob store (the content-addressed `CoinProof` blob fetch) — and runs whether or not an API exists. Everything else in the table is REST and therefore reaches a client only through the API layer ([§6.1](#61-components-and-responsibilities)): `read.account` and `read.proof` under the `wallet` feature, `submit.tx` under `wallet`, the publisher hand-off ([§7.6](#76-publisher-interface-normative)) under `publisher`, and the public chain projection an explorer reads under `explorer`. `explorer.read` stays what it was — bearer view secrets applied client-side to already-public material, never a node authorisation. `read.provenance` is the one open, unauthenticated REST read (issuer-originated token provenance, [§4.6](#46-data-availability) Class B) — it discloses no Private data and needs no capability, and — unlike the capability-gated REST surfaces — it is **not** gated by a `features` flag: any API instance that has captured a token's `asset_terms` **MUST** serve them to any requester ([§4.6](#46-data-availability)), so this read is never answered `404 feature_disabled` and is served independently of `wallet`/`explorer`. Resolving names, and issuing them for served accounts, is API-layer work under `wallet`. A client learns what an instance serves from the closed `features` array on `GET /v1/info` and **MUST** treat anything absent from it as absent.

### 6.5 Issuance — token standards

A new asset is created by fixing its `asset_id` ([Foundations §1.4](#14-identifiers-and-hashes)) under exactly one **token standard** — a numbered issuance schema, its `issuance_version`, that fixes the rules governing the asset's supply and minting (analogous to a token standard such as ERC-20 or ERC-721). The choice of standard is **mandatory and unambiguous**: every asset declares exactly one, its `issuance_version` is bound into the `asset_id` itself, and every coin of the asset carries that standard by construction — the `issuance_version` is committed into `asset_id`, so a coin minted under one standard can never be reinterpreted under another, and a holder that has the asset's `asset_terms` can read which standard, and therefore which rules, an asset follows. There is **no default standard and no unversioned asset**: the mint circuit accepts a coin only under a defined standard, and an `issuance_version` outside the catalog below makes the proof fail ([Proofs §2.1 clause 3](#21-the-compliance-predicate)). The defined token standards are:

- **[Token standard 1 — single-issuer, uncapped](#token-standard-1--single-issuer-uncapped)** (`issuance_version == 1`) — creator-bound issuance with no protocol-enforced supply cap; the creator **MAY** mint any amount at any time, and supply discipline is the creator's commitment rather than a protocol guarantee.
- **[Token standard 2 — auditable capped supply](#token-standard-2--auditable-capped-supply)** (`issuance_version == 2`) — creator-bound issuance with a protocol-enforced maximum supply `cap_total` that any holder holding the asset's terms can verify from those terms alone.

Both are equal, first-class standards; a creator chooses the one whose guarantees the asset needs. Further standards are added over time (see [Adding new token standards](#adding-new-token-standards) below).

**Single-issuer model (both standards).** The asset's `asset_id` commits to `creator_pubkey = Pk₀` (Foundations §1.4) — it binds the **initial spend key alone**, **not** the full account address `H(Pk₀ ‖ nk_commit)` (§1.4). Mint authority therefore rests with the **holder of `sk₀` for that `Pk₀`**: only that party can sign a mint (the circuit's clause-3(b) check `H(creator_pubkey ‖ nk_commit) == owner` still requires `sk₀`, using whichever account's own `nk_commit` is minting), so mint authority is **monopolised on the creator's spend key** by construction. Because a single `Pk₀` can back **several** accounts (same `Pk₀`, different `nk_commit`, hence different addresses, §1.2), the correspondence `asset_id ↔ issuing account` is **one-to-many** across those accounts — benign for token standard 1 (every such account is controlled by the same `sk₀`-holder, and token standard 1 permits undetectable creator over-issuance below); **token standard 2** ([auditable capped supply](#token-standard-2--auditable-capped-supply)) below bounds total emission across **all** accounts sharing the asset's `creator_pubkey` by binding the mint to the account's **genesis** transition, so the single `Pk₀` those accounts share is admitted at most once by first-occurrence (§3.6) and the asset is minted at most once globally. *"Permissionless issuance"* in this spec means **anyone can create their own asset** — not that anyone can mint someone else's. Within their own asset, the creator **MAY** mint any amount at any time; token standard 1 imposes no protocol-level cap. Supply discipline is a **creator's commitment**, not a protocol guarantee — holders trust the creator the way they would any single-issuer asset. Over-issuance **amount** is **not** detectable at the protocol level under token standard 1: a creator over-mints by appending further valid sequential mint transitions, each at a freshly incremented `send_counter` with a distinct rotated `Pkᵢ` (§2.1) — a single linear lineage, not a fork. Because every mint is now a **state-advancing transition that anchors on Bitcoin** ([§2.3.1](#231-mint--issuance), [§3.10](#310-transaction-states)), each such over-mint **does** leave a public on-chain artefact — its nullifier `(Pkᵢ, Rᵢ)` — so issuance **frequency and timing** are chain-visible, but the minted **amount** stays hidden (zero-knowledge), so a creator can still inflate supply undetectably as to quantity. What the anchoring **does** close is the mint-**fork**: two mints (or a mint and any other transition) that advance from the **same** prior state share the identical `current_pubkey = Pkᵢ`, publish the **same** nullifier key `Pkᵢ`, and the global accumulator admits each `Pkᵢ` **at most once** by first-occurrence (§3.6), so the later fork is the rejected loser (§3.10 `failed`); and because a mint's successor or receiver binds `Pk_prev`/`Pk_create` to the mint's **exposed consumed key** ([§2.1 clause 1](#21-the-compliance-predicate) (iii) / clause 10(d)), the fork cannot evade that collision with a fresh-key naked nullifier — so **a creator cannot issue two conflicting coins against one state**. The fork is additionally forced onto the same input-coin `nf` where inputs exist (the `nk` deriving `nf` is committed to the account by `nk_commit`, [§2.1 clause 4](#21-the-compliance-predicate)). Protocol-enforced, auditable supply is [token standard 2](#token-standard-2--auditable-capped-supply) below.

#### Token standard 1 — single-issuer, uncapped

```
IssuanceTerms_v1 = {
  asset_id          : field,        // = Hc("AssetId", genesis_tag ‖ creator_pubkey
                                    //         ‖ H(name) ‖ decimals ‖ issuance_version)
                                    //   (Foundations §1.4)
  creator_pubkey    : 32 bytes,     // = Pk₀ of the issuing account (x-only); the circuit
                                    //   verifies H(creator_pubkey ‖ nk_commit) == prev_account_state.owner
                                    //   because the SPEND key rotates per transition and Pk₀
                                    //   is otherwise irrecoverable in-circuit from owner = H(Pk₀ ‖ nk_commit)
  issuance_version  : u8 = 1,       // the schema version this asset is created under
  name_hash         : digest,       // = H(name); the human-readable name is NEVER on-chain
  decimals          : u8,           // display precision; bound into asset_id, no in-circuit effect
  terms_hash        : field         // = Hc("IssuanceTerms", asset_id ‖ issuance_version)
                                    //   (token standard 1 has no fields beyond what asset_id already binds;
                                    //   issuance_version is re-absorbed here as belt-and-
                                    //   suspenders explicit version-binding — redundant with
                                    //   asset_id but harmless; later versions extend this list)
}
```

The token-standard-1 mint proof (see [Proofs & State Transitions](#2--proofs--state-transitions)) **MUST** verify, in-circuit, that:

- (a) `issuance_version == 1` — this branch accepts only token-standard-1 mints;
- (b) `H(creator_pubkey ‖ prev_account_state.nk_commit) == prev_account_state.owner` — binds the issuance to the asset's creator account (only the holder of `sk₀` can produce a witnessed `creator_pubkey` that, with the account's committed `nk_commit`, has the SHA-256 image `owner = H(Pk₀ ‖ nk_commit)`, since SHA-256 is preimage-resistant in-circuit);
- (c) `asset_id == Hc("AssetId", genesis_tag ‖ creator_pubkey ‖ name_hash ‖ decimals ‖ issuance_version)` — the token-standard-1 `asset_id` derivation of [Foundations §1.4](#14-identifiers-and-hashes);
- (d) `terms_hash == Hc("IssuanceTerms", asset_id ‖ issuance_version)` — the `terms_hash` recomputation.

Mint clauses (a)–(d) are the entire token-standard-1 mint circuit: it defines no protocol-enforced cap, no per-mint quantum, no time window, and no signer set beyond the creator — that is the standard, not a limitation to be lifted later; token standard 2 (below) is the standard that adds a protocol-enforced cap. The `Mint(asset_id) = amount` flow into [Proofs §2.1 clause 3](#21-the-compliance-predicate) (per-asset balance conservation) is the only other constraint a token-standard-1 mint participates in.

#### Token standard 2 — auditable capped supply

**Token standard 2** gives an asset a **protocol-enforced maximum supply**: of a token-standard-2 asset there are provably at most `cap_total` units, and any holder holding the asset's `asset_terms` can verify that bound from those terms alone. Where token standard 1 leaves over-issuance undetectable as to quantity, token standard 2 makes the cap a protocol guarantee.

The mechanism reuses the accumulator's first-occurrence rule rather than adding any new on-chain object. Because a genuinely capped supply must bound mints **across every account that shares the asset's `creator_pubkey`** (§6.5, single-issuer model), and the only globally-unique, on-chain, once-admitted value tied to `creator_pubkey = Pk₀` is `Pk₀` itself under the accumulator's first-occurrence rule (§3.6), a token-standard-2 asset is minted in **exactly one** transition: the issuing account's **genesis** transition, which consumes `Pk₀` and publishes the on-chain nullifier `(Pk₀, R)`. Every account that shares `Pk₀` competes for the **same** `Pk₀` accumulator key, which is admitted **at most once** globally, so at most one genesis mint of that asset can ever settle — even across accounts. That single mint emits exactly `amount ≤ cap_total`, so the total supply is provably `≤ cap_total`. No per-coin `nf` is placed on Bitcoin and no supply-specific accumulator is introduced: `Pk₀` first-occurrence is the uniqueness anchor.

```
IssuanceTerms_v2 = {
  asset_id          : field,        // = Hc("AssetIdV2", genesis_tag ‖ creator_pubkey
                                    //         ‖ H(name) ‖ decimals ‖ issuance_version
                                    //         ‖ cap_total ‖ terms_salt)   (Foundations §1.4)
  creator_pubkey    : 32 bytes,     // = Pk₀ of the issuing account (x-only)
  issuance_version  : u8 = 2,       // the schema version this asset is created under
  name_hash         : digest,       // = H(name); the human-readable name is NEVER on-chain
  decimals          : u8,           // display precision; bound into asset_id
  cap_total         : u128,         // the provable maximum total supply, in base units
  terms_salt        : 32 bytes,     // secret blind so cap_total is not brute-forceable from the
                                    //   public asset_id; reaches holders inside asset_terms (and openly by asset_id, §4.6 Class B)
  terms_hash        : field         // = Hc("IssuanceTermsV2", asset_id ‖ issuance_version
                                    //         ‖ cap_total ‖ terms_salt)
}
```

The token-standard-2 mint proof **MUST** verify, in-circuit, that:

- (a) `issuance_version == 2` — this branch accepts only token-standard-2 mints;
- (b) `H(creator_pubkey ‖ prev_account_state.nk_commit) == prev_account_state.owner` — the same creator binding as token standard 1: only the holder of `sk₀` can supply a witnessed `creator_pubkey` whose SHA-256 image with the account's committed `nk_commit` equals `owner`;
- (c) `asset_id == Hc("AssetIdV2", genesis_tag ‖ creator_pubkey ‖ name_hash ‖ decimals ‖ issuance_version ‖ cap_total ‖ terms_salt)` — the token-standard-2 `asset_id` derivation of [Foundations §1.4](#14-identifiers-and-hashes), including `cap_total` and `terms_salt` in the committed preimage;
- (d) `terms_hash == Hc("IssuanceTermsV2", asset_id ‖ issuance_version ‖ cap_total ‖ terms_salt)` — the `terms_hash` recomputation;
- (e) **cap enforcement.** `amount ≤ cap_total`, with both values range-checked to `[0, 2^128 − 1]` and compared as exact non-negative integers via the wide-integer gadgets of [§2.6](#26-in-circuit-non-native-cryptography-normative), never as field elements or by a modular comparison;
- (f) **genesis binding (the uniqueness anchor).** `prev_account_state.send_counter == 0` **and** `prev_account_state.current_pubkey == creator_pubkey` (`= Pk₀`) — the token-standard-2 mint **MUST** be the issuing account's genesis transition, so it consumes `Pk₀` and publishes `(Pk₀, R)` as its on-chain nullifier (§3.1). Because `asset_id` binds `creator_pubkey = Pk₀` and `Pk₀` is admitted to the global accumulator **at most once** by first-occurrence (§3.6) across **all** accounts sharing `Pk₀`, this makes a second settled token-standard-2 mint of the same `asset_id` impossible;
- (g) **emission.** For the minted asset `a`, `Out(a) == Mint(a) == amount` and `In(a) == 0`; the emission **MUST** leave this transition as explicit output coins built by [§2.1 clauses 5–6](#21-the-compliance-predicate) and folded into `output_coins_root`. The mint **MUST NOT** self-credit its freshly created coin — neither into `balances` ([§2.1 clause 7](#21-the-compliance-predicate)), nor through the `received_coins[]` admission path ([§2.1 clause 10](#21-the-compliance-predicate)), nor into this transition's own coin-history (clause 8); the creator credits any self-addressed minted output only through clause 10 in a **later** transition, exactly like any other received coin — closing a self-receive/replay shortcut.

A token-standard-2 mint is otherwise an ordinary state-advancing transition: it anchors its `(Pk₀, R)` nullifier on Bitcoin and reaches `completed` under the same first-occurrence rule as every send, receive, and token-standard-1 mint (§3.10) — there is no separate batching or anchoring path, and no `nf_mint`. Consequence: an account may issue **one** capped asset, in its genesis transition; a creator who wants several capped assets uses several accounts (several `Pk₀`s). After the genesis mint the account rotates to `Pk₁` and operates normally, but can never mint that asset again because `Pk₀` is spent.

**Auditability.** The public `asset_id` commits to `cap_total`, and `asset_terms` (§1.5) carries the `cap_total`/`terms_salt` preimage to any holder that holds it, who recomputes `asset_id` and thereby confirms the cap the issuer is bound to ([§2.3.3 step 6](#233-receive)). The at-most-one-mint guarantee of (f) is unconditional and on-chain — at most one genesis mint can settle, so the supply is capped for everyone — and any holder that has the terms is additionally assured of the exact `cap_total` bound.

#### Adding new token standards

`IssuanceTerms_v2` (above) adds a protocol-enforced supply cap. Later token standards — standard 3, … — **MAY** introduce further supply rules (per-mint quantum, time windows, multi-signer mint authority, redemption mechanisms, etc.). Each new version is a separate `IssuanceTerms` schema with its own circuit-enforced rules; the version-binding through `asset_id` ([Foundations §1.4](#14-identifiers-and-hashes)) guarantees that a coin minted under one version cannot be misinterpreted under another.

The dispatch model is **fixed by the cyclic-recursion constraint** of [Proofs §2.1 clause 1](#21-the-compliance-predicate): the verifier data **MUST** be fixed and identical in prover and verifier, so a single account's recursive lineage cannot cross verifier-data boundaries. Adding token standard 2 therefore **MUST** take the form of an **in-circuit version branch within the same circuit** `C` — extending `C` to accept both `issuance_version == 1` and `issuance_version == 2` mints — *not* a separate per-version circuit, which would break cyclic recursion the moment an account that minted under token standard 1 attempts to mint under token standard 2 in the same lineage. The single-circuit-with-version-branching dispatch is therefore the only PCD-compatible option; `IssuanceTerms_v2`'s rule set (above) lives inside that `issuance_version == 2` branch of `C`.

The human-readable `name` and the display `decimals` are the asset's `IssuanceTerms` display metadata (above); they are **never** placed on-chain — only `name_hash = H(name)` and `decimals` are bound into `asset_id`, so the `name` itself is **never reconstructable from on-chain data** (Foundations §1.4) — a holder obtains them, if at all, through the `asset_terms` transport below.

#### IssuanceTerms transport

`asset_id` is a hash: a holder cannot invert it into the asset's `name`, `decimals`, `creator_pubkey`, or `issuance_version`, and no chain data helps ([Foundations §1.4](#14-identifiers-and-hashes)). The terms therefore reach holders along the value's own path (and, once a holder has the `asset_id`, openly from any holder that has retained the terms, [§4.6](#46-data-availability) Class B / [§7.5](#75-node-rest-api-normative)): inside `CoinProof` bundles, as the optional `asset_terms` field of the bundle plaintext ([Foundations §1.5](#15-core-data-structures)), attached by the sender under the SHOULD/first-hop-MUST rule of [§2.3.2](#232-send) (the MUST fires on the terms' own first hop to a given recipient, not the coin's, and binds only a sender that itself holds terms passing the [§2.3.3 step-6](#233-receive) recompute — a holder without them MAY still spend the asset onward, opaquely) — or directly from the issuer out-of-band (e.g. alongside an `Invoice`). Either way the receiver trusts no one: it recomputes `asset_id` from the presented terms and rejects a mismatch ([§2.3.3 step 6](#233-receive)), so accepted terms are exactly as trustworthy as the `asset_id` itself. The `issuance_version` carried in `asset_terms` tells the receiver which schema's `asset_id` derivation to recompute (token standards 1 and 2: [Foundations §1.4](#14-identifiers-and-hashes)).

**Name resolution is a non-goal; open terms-by-`asset_id` is provided.** The protocol deliberately defines **no** registry mapping `name`s to `asset_id`s, no on-chain name record, and no name-resolution service, and enforces **no** name uniqueness — two creators MAY issue assets with the same `name`; only the `asset_id` is the asset's identity, and a wallet MUST key assets by `asset_id`, never by `name`. It **does** provide the reverse, self-verifying direction: given an `asset_id` a holder already has, its `asset_terms` are openly resolvable from any holder that has retained them ([§4.6](#46-data-availability) Class B, [§7.5](#75-node-rest-api-normative)) so a token survives its issuer as long as ≥1 such holder exists. The residual that this makes an asset's `name`/terms resolvable by anyone who holds its `asset_id` is an accepted trade-off ([Risks](/risks)); it is **not** a `name → asset_id` index and reveals no transfer, holder, or amount.

### 6.6 Threat model and trust configurations

Custody is **cryptographically safe in every configuration**: no node holds a SPEND-branch key (Foundations §1.2), value integrity is enforced by proof soundness and the nullifier accumulator, and every state-advancing transition's nullifier reaches the accumulator only as an immutable on-chain publication folded by first-occurrence (§3.6). The three wallet–node configurations differ only in **privacy** and in **whom you trust for correctness and availability** — never in custody:

- **Own wallet + own node.** Full privacy, trustless correctness, safe custody. The node sees your plaintext, but you are the operator, so nothing leaks.
- **Own wallet + multiple foreign nodes.** Plaintext is disclosed to all of them; the wallet gets fail-closed discrepancy detection (§6.3): with ≥1 honest node it never *accepts* a false answer, but any single dishonest node can stall it (it halts on disagreement), and consistent collusion of all configured nodes defeats it; custody safe. Running your own node removes this trade-off.
- **Own wallet + a single foreign node.** Plaintext disclosed to it; you trust it for correctness and liveness (it can lie or omit — including, for a send, proposing outputs that redirect the payment or drop the change output entirely (burn), since the thin wallet cannot independently check `ocr` against the outputs it posted before signing, see below); it **cannot** forge a signature, double-spend, or spend without your key — custody (key theft) safe.

**Nostr messaging follows `op` custody.** The component holding `op` can decrypt incoming NIP-17 messages and can sign outgoing messages as that Nostr identity. With an own node this is under the user's control; a hosted provider holding the operational bundle can read messages, impersonate the account on Nostr, and publish a new kind-0 advertising a different `zkcoins` payment identity under the same `op_pubkey` — what bounds the damage is not an inability to spend (`op` genuinely cannot spend zkCoins) but the [§4.3](#43-addressing-for-delivery) payment-identity pin, under which a changed `address`, `pk0`, `nk_commit`, or `ivpk` for an already-pinned contact warns the sender rather than being adopted silently. Ordinary external NIP-17 correspondents never receive `op`; they interoperate through the public key and standard events alone. This is the existing operational-bundle trust boundary, not an additional bridge trust assumption.

**Send-intent integrity is a correctness property, not custody.** "Cannot forge a signature, double-spend, or spend without your key" above is precise about **custody**: a node without the SPEND key can never produce a valid `txn_sig`, so it can never move a coin unilaterally, in every configuration. It does not mean every field a node proposes for the wallet's cooperative signature is independently checked by the wallet. For a send, the sole prover — in both the **own node** and **single foreign node** rows above — chooses the witness, including which `output_templates[]` (hence which `output_coins_root`) it builds the proof from, before the wallet ever sees it ([§7.5](#75-node-rest-api-normative)). Because the thin wallet runs no Poseidon (the thin-client rule), it cannot recompute `output_coins_root` from the templates it posted and so signs the node-reported `ocr` on trust that the node proved the templates it was given, not others ([§7.5](#75-node-rest-api-normative)). A dishonest or compromised single foreign node can therefore redirect a send's outputs to a party of its choosing, or drop an output — including the per-asset change coin — entirely (burn), within one cooperative signature — a correctness failure of the same kind this section already asks a foreign operator to be trusted for, not a break of the custody guarantee (no signature is forged, no coin moves without the wallet's key), but its effect on the sender is the same as theft. Self-hosting, or using only a node vetted for correctness and not merely liveness, is the only mitigation this design offers; see [Risks](/risks).

**Node building blocks — own vs external.** Independently of the wallet↔node choice above, a node operator also chooses where its `bitcoind` and its `nostr-relay` come from ([§6.1](#61-components-and-responsibilities)). Running both yourself is the sovereign default. Pointing the node at an **external `bitcoind`** trades privacy (that node sees your chain queries) and raises eclipse exposure (the inherited assumption below), but **cannot** affect custody or correctness beyond that eclipse exposure — the node still re-verifies every inscription, bundle, and proof against its Bitcoin chain view ([Requirement 4](/requirements) via §6.2), and an external `bitcoind` can distort only that chain view, which the inherited ≥1-honest-peer assumption bounds. Using **external relay(s)** for transport sits on the same spectrum as any foreign relay: trusted only for availability and metadata-minimisation, never for correctness or custody (§4.1). Both are deliberate trade-offs, not new trust roots.

**Inherited assumption.** zkCoins anchors on Bitcoin and therefore inherits Bitcoin's network-liveness assumption: if **all** of a node's peers lie (an eclipse attack), even a self-hosted node can be fed a false view of the chain. zkCoins adds no new consensus and so neither weakens nor strengthens this "≥1 honest peer" assumption.

**Bitcoin reorg handling.** zkCoins v1 fixes finality at **6 confirmations** (the [§3.9](#39-finality-and-reorg-handling) hard project directive). A reorg of up to 5 blocks touches only non-final nullifiers and is absorbed by deterministic **canonical replay** ([§3.9](#39-finality-and-reorg-handling), [§3.10](#310-transaction-states)); because nothing final depends on a non-final nullifier, no account is stranded within that window. A reorg of **6 or more blocks** can displace a final nullifier and **MAY break zkCoins** — an explicit, accepted v1 limitation, not a recovery case. A nullifier classified `completed` at 6 confirmations is treated as final; deployments **MAY** surface **6 confirmations** as the finality threshold (the Bitcoin-industry default) and deployments handling extreme value **MAY** add out-of-band confirmation policies on top of it.

**Freeze-resistance ([Requirement 3](/requirements)).** No node **other than the transition's selected prover** can **freeze** — indefinitely block the spending of — coins it does not own; publishing is permissionless. (The **selected prover** — your own node, or a foreign node you delegate witness-building to — is the separate thin-client trust boundary: it can strand your key, so **self-host or vet the prover**; registered as D-17, [Risks](/risks).) Publishing is **permissionless and contention-free** ([§3.4](#34-the-publisher)): a nullifier references **no shared global state**, so any participant MAY run a publisher and a wallet MAY direct its own node to act as its publisher with **no** ordering slot to win and no single sequential writer — a publisher that censors a nullifier or sits on it collects nothing and is simply **bypassed** (the censored spender re-submits to another publisher or has its own node self-publish, and first-occurrence makes redundant publication idempotent). On the read side, symmetrically, **no node can lock a wallet's funds in** ([§6.3](#63-node-portability-and-multi-node-operation)): a wallet switches nodes for custody and transacting by configuration alone. Freeze-resistance therefore reduces to the same permissionless-publishing and node-portability properties that give custody safety; no party — node, publisher, or federation — **other than the holder's own selected prover** (the thin-client boundary above, D-17) holds the authority to withhold a holder's own coins. The one honest limit is **liveness under data availability**: if every holder of a needed `CoinProof` bundle is lost the affected coin cannot be reconstructed ([§4.6](#46-data-availability), [§4.8](#48-durability--the-store-everything-invariant)), but that is a liveness failure under permanent retention, not a freeze exercised by any party.

**Trust base ([Requirement 3](/requirements)).** The trust base is **software, keys, and Bitcoin** alone: no **trusted hardware**, secure enclave, HSM, or TEE is part of it. A spend is authorised by a BIP-340 signature under a software-derived key ([§1.2](#12-key-hierarchy)) and validated by proof soundness plus the on-chain nullifier accumulator ([§6.1](#61-components-and-responsibilities)), so the *"trusted hardware"* party [Requirement 3](/requirements) enumerates has no role in the system to compromise.

### 6.7 Security-properties summary

How this architecture maps to the [Requirements](/requirements) at a glance:

| Requirement | How the architecture meets it |
|---|---|
| **1 · Bitcoin-only base** | One node component scans and inscribes to Bitcoin L1; no separate chain, token, or consensus. |
| **2 · Private** | Only opaque, rotating per-transition nullifiers `(Pkᵢ, Rᵢ)` are public on-chain; per-coin encryption (Foundations §1.3) gates all plaintext to capability holders. |
| **3 · Trustless** | No node, server, publisher, or other third party holds a spending key; only the wallet does (§6.1); integrity from proofs + nullifier accumulator, not node honesty (§6.6). |
| **4 · Client-side validation** | The receiver's own node re-verifies every incoming coin and every foreign answer against Bitcoin before the account acts on it (§6.2–§6.3; [Requirement 4](/requirements) is "the receiver, or its node on its behalf"). |
| **5 · Custody only in wallet** | SPEND branch never leaves the wallet; only the operational bundle / view grants are delegated (§6.2); the rotated key is wallet-verifiable via `npk_commit` (§2.1 clause 2, D-21). |
| **6 · Recovery** | Node store (with operator backup) is the normal path; seed + chain + the artefacts served by the network's seed-discoverable relays and blob stores are the emergency fallback (§4.3/§4.5, §6.1). |
| **7 · Self-hostable** | The node is one self-contained container; a deployment is a single `docker compose` stack (node · bitcoind · nostr-relay · PostgreSQL · explorer), each block pluggable as own-or-external, with no operator-specific dependencies (§6.1). |
| **8 · Multi-asset** | `asset_id` plus the version-bound token standards — `IssuanceTerms_v1` (uncapped) and `IssuanceTerms_v2` (auditable capped supply, `cap_total`) — let anyone create their own asset; the creator is the sole minter (§6.5). |
| **9 · Selective disclosure** | Three opt-in disclosure tiers, each verifiable against Bitcoin: a single transaction via a per-coin `K_tx` (§5.6), a history-private balance attestation (§5.7), and a full-history account view grant (§5.8); rendered by a self-hostable, stateless explorer (§6.1). |
| **10 · Node portability** | No node-specific value-bearing wallet state; switch and multi-node by configuration alone for custody and transacting, with non-value portability residuals explicit (§6.3). |
| **11 · Standard identity and messaging** | Identity keys are seed-derived (§1.2); standard NIP-17/kind-10050 messaging on that key, interoperable with ordinary Nostr clients (§4.1, §7.3). The app and API layers give every account they serve one email-style name and the signed payment object bound to it; the holder attests the name with `sk₀` (`name_sig`), and the name is replaceable and survivable on loss (§4.3). Lightning and SMTP bridges remain independent and optional. |
| **12 · Data Permanence** | A node never deletes received data: every artefact is stored completely and retained indefinitely; no drop, expiry, pruning, or supersession clean-up (§4.8). Availability follows from that permanence plus the §4.3 recovery-discoverable overlap (event on ≥1 `seed_relay`, blob in ≥1 `blob_store`); further redundant copies only add durability (§4.6). Revocation ceases use of an operational bundle while the stored copy remains retained, marked revoked (§7.7). |
| **13 · Recovery availability from the seed alone** | A wallet that lost everything but its seed rebuilds its full state, because the §4.3 recovery-discoverable overlap places every delivery event on ≥1 network `seed_relay` and every blob in ≥1 network `blob_store` (§4.3/§4.5); the guarantee is operational (a reachable bootstrap node, ≥1 live holder per plane, and continuity-preserving manifest rotation, §4.3), not cryptographic, and a token survives its issuer via the open Class-B provenance read (§4.6/§7.5). |

*(This table is the architecture summary; the [Requirements traceability](#requirements-traceability) table at the top of this page is the canonical requirement→mechanism map.)*

**Precise v1 privacy statement (normative).** zkCoins v1 guarantees unlinkability against the **public-chain observer**: from Bitcoin data alone, no observer can determine any payment's amount, asset, sender, or receiver, or attribute two on-chain nullifiers to the same account, coin, or user ([Requirement 2](/requirements); [§2.1 clause 9](#21-the-compliance-predicate), [§3.1](#31-the-on-chain-object)). Against **protocol counterparties** the guarantee is bounded, and the bounds are final for v1: a co-output holder of one transition learns that other outputs of that same transition exist — including the power-of-two output-count bucket its `inclusion_proof.depth` reveals ([§1.7.5](#175-poseidon-merkle-tree-used-for-ocr-and-inr)) — without identifying them (D-18); any party holding `CoinProof`s of two **consecutive** transitions of one account can link them (the earlier proof's public `new_account_state_hash` equals the later coin's `creating_prev_ash`) — under the deferred fee mechanism a repeatedly reused publisher would be the automatic instance of this (D-19); in v1 it holds no `CoinProof` at all and its residual channel is the pre-anchor `Pkᵢ` each hand-off discloses — rotation or self-publish removes the edge; a wallet-selected hosted prover sees the transition's plaintext intent, and the account's own node — holding the operational bundle — has a standing capability to decrypt and link the account's own activity (D-17; the own node's standing operational-bundle visibility is the §6.6 trust model, [Risks](/risks) 'Node plaintext visibility'); and issuance frequency/timing are chain-visible ([§3.10](#310-transaction-states)). Each boundary is registered in the [Paper-Deviation Analysis](/paper-conformance-analysis) and catalogued with its mitigation in [Risks](/risks); none extends to the public-chain observer.

## 7 · Wire Formats & Node Interfaces

> *In one sentence: the concrete bytes on the wire — how every object defined abstractly above is serialised, the exact Nostr event kinds and Blossom endpoints that move bundles, and the versioned HTTP API a node exposes — so any conforming implementations interoperate without further negotiation.*

[§6.4](#64-external-interfaces-abstract) lists the node's interface families abstractly; this section fixes them concretely. It is normative for protocol version v1. All primitives, identifiers, and tags are from [Foundations](#1--foundations-normative). The HTTP surface is versioned under `/v1/`; a breaking change is a new version prefix, never a silent change to `/v1/`. Normative keywords follow RFC 2119.

### 7.1 Serialization conventions (normative)

Two encodings are used, each for a fixed purpose:

- **Canonical binary** — for every object that is hashed, signed, content-addressed, or fed in-circuit: `serialize(AccountState)` ([§1.7.4](#174-serializeaccountstate)), the 96-byte `SpendRecord` (`Pkᵢ (32B) ‖ signature (64B)`, [§1.4](#14-identifiers-and-hashes)), the on-chain **nullifier inscription** payload (`format 0x00` raw / `0x01` half-aggregated, [§3.5](#35-inscription-format)), and proofs (`ProofWithPublicInputs::to_bytes()`, [§1.7.9](#179-proof-system-parameters-normative)). These layouts are byte-exact and **MUST NOT** be re-encoded as JSON when hashed. A `CoinProof` bundle is serialised as the **length-prefixed concatenation** of its fields in declaration order ([§1.5](#15-core-data-structures)): each variable-length field (`proof`, `inclusion_proof`, `asset_terms.name`, `ciphertext`) is prefixed with a `u32-be` byte length; each fixed field uses its §1.7.3 width. The **optional** `asset_terms?` field contributes exactly one **presence byte** — `0x00` = absent, `0x01` = present — followed by its encoding only when present; any other presence value makes the bundle malformed and **MUST** be rejected. A present `asset_terms` is encoded as `creator_pubkey` (32 bytes) ‖ `decimals` (1 byte, u8) ‖ `issuance_version` (1 byte, u8) ‖ `u32-be len(name)` ‖ `name` (a raw byte string, UTF-8 validity is display-only per [§1.5](#15-core-data-structures); at most **255 bytes** per [§1.5](#15-core-data-structures) — a longer `name` is likewise malformed); when `issuance_version == 2` the `name` field is followed by `cap_total` (16 bytes, `u128` big-endian) ‖ `terms_salt` (32 bytes), and these two trailing fields **MUST** be absent for `issuance_version == 1` (a bundle that includes or omits them against its version is malformed and **MUST** be rejected); an `asset_terms` whose `issuance_version` byte is neither `0x01` nor `0x02` is malformed and **MUST** be rejected. The nested fixed-width fields serialize in declaration order with no extra framing: `creating_nullifier` as `Pk_create (32B) ‖ R_create (32B) ‖ R'_create (32B)` and `nav_opening` as `size (8B, u64 big-endian) ‖ mth (32B) ‖ nav_rand (32B)` — the conditional-NAV value is the log pair `(size, mth)` ([§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)), and `nav_root = Hc("NfLog/Root", size ‖ mth)` is its committed form ([§1.5](#15-core-data-structures)). A bundle is **malformed** — and **MUST** be rejected without further processing — if any fixed-width field has the wrong length, any `u32-be` length prefix exceeds the remaining bytes, the presence byte is not `0x00`/`0x01`, the `asset_terms` version/trailing-field rules above are violated, or decoding leaves trailing bytes. These rules fix exactly one byte string per bundle, preserving the `blob_id` determinism of §4.2.1. This is the byte string ZBE encrypts (§4.2.1) and Blossom content-addresses. The half-aggregated nullifier body is the `(Pkⱼ, Rⱼ)` pairs plus one shared `s_agg` of [§3.5](#35-inscription-format) `format 0x01`; a raw single nullifier is `Pkᵢ ‖ Rᵢ ‖ sᵢ` (`format 0x00`).
- **JSON (UTF-8)** — for REST control payloads only (requests, job status, info, challenges). Binary values inside JSON are **lowercase hex** unless a field is explicitly Bech32m (addresses, grants, view caps, link locators per [§1.7.7](#177-bech32m-and-bitcoin-conventions)). JSON objects are parsed in **strict** mode: unknown fields are ignored on read but a conforming producer emits exactly the fields specified; missing required fields are a hard error. Numeric amounts that may exceed 2⁵³ (`u64`/`u128`) are encoded as **decimal strings**, never JSON numbers, to avoid float coercion.

**`serialize(BalanceAttestation)` / `BalanceAttestationV1` (normative).** `subject (32B) ‖ asset_id (32B) ‖ balance (16B, u128 big-endian) ‖ nav_ceiling (32B root) ‖ size_ceiling (8B, u64 big-endian) ‖ txid (32B, internal order §1.7.7) ‖ block_hash (32B, internal order) ‖ height (8B, u64 big-endian) ‖ Pk_anchor (32B) ‖ R_anchor (32B) ‖ network_id (32B, canonical Poseidon `HashOut` encoding per [§1.7.1](#171-poseidon-instance-and-digest-encoding)) ‖ u32-be len(proof) ‖ proof` — the `C_balance` public inputs (§2.5, §5.7) in this fixed order as their **raw** 32-byte / width-pinned values (**not** the in-circuit limb stream), with `network_id` the **last** public input of `C_balance` (there is no `consumed_pubkey` on that circuit), followed by the length-prefixed Plonky2 proof bytes (§1.7.9). Write **`BalanceAttestationV1 ≜ serialize(BalanceAttestation)`** — the same byte string the §5.7 share-link forms `i:` / `h:` and the §7.5 `attestation` field / job `result.attestation` carry (hex-encoded on the REST surface); a decoder MUST reject wrong-width fields, a missing or wrong-width `network_id`, a length prefix exceeding the remaining bytes, or trailing bytes.

**`serialize(BlobLocatorSet)` (normative).** An ordered holder-hint list for one content-addressed blob. The **32-byte `blob_id` is context**, not part of this set (it is carried beside the set — e.g. `fee_blob_id` on [§7.6](#76-publisher-interface-normative), `blob_id` on a delivery payload or `output_ref`, or the self-delivery record's own content address). Canonical binary:

```
serialize(BlobLocatorSet) :=
  u16-be holder_count
  ‖ holder_count × ( u16-be url_len ‖ UTF-8(base_url) )
```

**Bounds (normative, fail-closed).** `1 ≤ holder_count ≤ MAX_BLOB_HOLDERS` with **`MAX_BLOB_HOLDERS = 16`**; for each entry, `1 ≤ url_len ≤ MAX_HOLDER_URL_LEN` with **`MAX_HOLDER_URL_LEN = 2048`**; each `base_url` is the `url_len` UTF-8 bytes of an absolute `http`/`https` base URL (no NULs). A decoder **MUST** reject `holder_count = 0`, `holder_count > MAX_BLOB_HOLDERS`, any `url_len = 0` or `url_len > MAX_HOLDER_URL_LEN`, a length prefix exceeding the remaining bytes, non-UTF-8, or trailing bytes after the last holder. Order is significant (first entry is the preferred fetch target). On the wire, when the set is encrypted under a note key (publisher fee hand-off, [§7.6](#76-publisher-interface-normative)), the carrier is **`NIP44Binary(K_tx, "blob-locators", serialize(BlobLocatorSet))`** ([§1.3](#13-per-coin-keys-note-encryption--detection)); open under (`label = "blob-locators"`, variable-length parse of this layout). Inside an already-encrypted `SelfDeliveryRecordV1` or delivery interior the framed bytes appear **raw** (no second AEAD).

**`serialize(SelfDeliveryRecordV1)` (normative).** The account's self-addressed state/transition record ([§4.2](#42-bundle-delivery)) is a **tagged, fully length-prefixed** envelope — every variable-length field carries an explicit length so a pure receive (no output `CoinProof`s) remains fully replayable:

```
magic (4B ASCII "SDR1") ‖ version (1B = 0x01) ‖ record_kind (1B)
‖ send_counter (8B u64-be) ‖ prev_state_head (32B)
‖ u32-be len(AccountState) ‖ serialize(AccountState)          // §1.7.4
‖ u32-be len(recursive_proof) ‖ recursive_proof               // §1.7.9
‖ serialize(ProofData)                                        // 192B fixed, §1.4
‖ own_nullifier = Pk (32B) ‖ R (32B) ‖ R' (32B)
‖ proof_block_anchor = block_hash (32B) ‖ height (4B u32-be)  // proof-context tip; strict ancestor of inclusion_block; NOT publisher AggregateStateNullifierV3 header, §4.2
‖ inclusion_block = block_hash (32B) ‖ height (4B u32-be)     // first-occurrence inclusion of (Pk, R), §4.2
‖ occurred_at (8B u64-be)                                     // MTP(inclusion_block) only, §4.2
‖ u16-be N_spent ‖ N_spent × coin_id (32B)                    // spent or folded coin.identifiers
‖ u16-be M ‖ M × output_ref                                   // canonical output order, §2.1 clause 5
‖ serialize(BlobLocatorSet)                                   // holders of THIS SelfDeliveryRecordV1 blob
```

Each **`output_ref`** is `coin_id (32B) ‖ blob_id (32B) ‖ epk (32B x-only) ‖ u16-be len(out_ciphertext) ‖ out_ciphertext ‖ serialize(BlobLocatorSet)` — where `out_ciphertext` = UTF-8 bytes of the NIP-44 Base64 payload from `NIP44Binary(K_out, "K_tx", K_tx)` ([§1.3](#13-per-coin-keys-note-encryption--detection)) and the trailing `serialize(BlobLocatorSet)` lists the ordered Blossom holders of **that** outgoing coin's encrypted `CoinProof` blob (so an `ovk` recoverer knows where to fetch it). The final record-level `serialize(BlobLocatorSet)` is the holder set of the **SelfDeliveryRecordV1 blob itself** (the ZBE ciphertext this envelope becomes). `M = 0` for a pure receive ([§2.3.3](#233-receive)); `N_spent = 0` for a pure mint that spends no prior coin. A trailing byte after the record-level `BlobLocatorSet`, a length prefix exceeding the remaining bytes, an unrecognised `magic`/`version`/`record_kind`, a malformed `BlobLocatorSet`, or a wrong-width fixed field makes the record **malformed** and **MUST** be rejected. This byte string is what ZBE encrypts for self-delivery content-addressing (`blob_id = H(ciphertext)`, [§4.2.1](#421-bundle-blob-encryption-zbe-normative)) and is the concrete framing behind every multi-device sync and emergency state rebuild of [§4.2](#42-bundle-delivery)/[§4.5](#45-recovery) and every "recover outgoing-coin plaintext" capability of [§1.3](#13-per-coin-keys-note-encryption--detection) and [§5.8](#58-address-view-full-history). The complete plaintext — including every `BlobLocatorSet` — **MUST** remain inside the encrypted blob — the outer gift-wrap exposes only `zkdt`/`zkepk` ([§4.2](#42-bundle-delivery)).

### 7.2 Transport map (normative)

| Plane | Carries | Mechanism | Section |
|---|---|---|---|
| **Bitcoin L1** | half-aggregated nullifier `(Pkⱼ, Rⱼ)` (~64 B/tx) | Taproot commit/reveal, witness-payload marker prefix `0x42 0x42` | [§3.5](#35-inscription-format) |
| **Nostr relay** (WebSocket) | standard profiles and NIP-17 messages; gift-wrapped zkCoins delivery events, ACKs, and publisher profiles | NIP-01, NIP-05, NIP-17, NIP-44 v2, NIP-59 (§7.3) | [§4.1](#41-roles-and-transport)–[§4.3](#43-addressing-for-delivery) |
| **Blossom** (HTTP) | encrypted `CoinProof` / `SelfDeliveryRecordV1` blobs (append-only) | content-addressed blob store (§7.4) | [§4.6](#46-data-availability), [§4.8](#48-durability--the-store-everything-invariant) |
| **Node REST** (HTTPS/Tor) | submit, proving jobs, capability-gated pull, public chain projection | versioned `/v1/` API (§7.5) | [§5.1](#51-capability-gated-pull), [§6.4](#64-external-interfaces-abstract) |
| **Kernel RPC** (internal) | proving · state reads · capability-gated pull · receipts · publish (server-to-server) | gRPC, private channel, `kernel.v1` (§7.8) | §7.8 |

A node deployment exposes the **four externally-visible planes** above ([§6.1](#61-components-and-responsibilities)): a bitcoind-backed scanner/inscriber, a Nostr relay, a Blossom store, and the public REST API. The REST plane is served by the **API layer** on top of the internal **kernel RPC** (§7.8) — the kernel RPC is never public. A wallet needs only one node's base URL; from `/v1/info` it learns the network's bootstrap manifest (seed relays, blob stores, operator IDs, [§4.3](#43-addressing-for-delivery)) plus that node's own relay and Blossom URLs.

### 7.3 Nostr event kinds (normative)

zkCoins uses the account's `op` key as its ordinary Nostr identity ([§4.1](#41-roles-and-transport)). Standard NIP-17 direct messages and kind-10050 DM relay lists are **mandatory** for human messaging. Publishing a kind-0 profile, and carrying a NIP-05 name, are **mandatory for every account the app and API layers serve** and belong to the naming layer above the protocol ([§4.3](#43-addressing-for-delivery)); they oblige neither a kernel-only deployment, which carries no account of its own, nor an ordinary Nostr peer that is not a zkCoins wallet. Every conforming client **MUST** be able to consume all four when a counterparty does use them. The separate zkCoins payment transport remains metadata-minimising: its outer kind-1059 delivery events reveal only the per-coin `zkdt`/`zkepk` scan tags of [§4.2 step 4](#42-bundle-delivery), and its inner kinds are visible only after the recipient unwraps.

| Kind | Name | Class | Purpose |
|---|---|---|---|
| `0` | Nostr user metadata | replaceable | standard profile; `nip05` and the additive `zkcoins` object are mandatory for an account served by the app or API layers, `lud16` only when the Lightning bridge is enabled. An ordinary Nostr account carries neither |
| `1059` | NIP-59 gift wrap | regular | outer envelope (ephemeral key), as NIP-59 |
| `13` | NIP-59 seal | regular | inner seal, as NIP-59 |
| `14` | NIP-17 direct-message rumor | (rumor — unsigned, inside the seal) | human chat message, exactly as NIP-17 |
| `10050` | NIP-17 DM relay list | replaceable | recipient's preferred relays for NIP-17 messages |
| `1420` | zkCoins delivery rumor | (rumor — unsigned, inside the seal) | the `DeliveryEvent.payload` of [§4.2](#42-bundle-delivery) |
| `1421` | zkCoins ACK rumor | (rumor — inside the seal) | the acknowledgement of [§4.2](#42-bundle-delivery) ACK rule |
| `30421` | zkCoins publisher profile | addressable | `{version, relays}` — v1 publishing is sponsored, so no payment identity and no `addr_sig` ([§3.8](#38-fees-and-economics)); `op`-signed, `d` tag = hex `op_pubkey`, `pubkey` = that same key |
| `30422` | zkCoins operator endpoint | addressable | signed `OperatorEndpointV1` of [§4.3](#43-addressing-for-delivery) (global infrastructure only); `d` tag = hex `operator_id` |
| `30423` | zkCoins bootstrap manifest | addressable | signed `BootstrapManifestV1` of [§4.3](#43-addressing-for-delivery); `d` tag = network tag |

**User metadata (kind 0).** An account served by the app or API layers **MUST** publish a standard kind-0 event authored and signed by its `op` key, and its JSON `content` **MUST** carry the account's normalized name in `nip05` — that is what lets any ordinary Nostr client complete the reverse check and reach the account by name ([§4.3](#43-addressing-for-delivery)). The `nip05` value is the account's one name in force ([§4.3](#43-addressing-for-delivery) *One active name*), and the `zkcoins` object's `name_sig` attests it; a consumer accepts that name and rejects one the profile does not attest. The `content` **MUST** also carry the §4.3 `zkcoins` object — that is what makes the account payable by its name — and **MAY** carry any other standard Nostr metadata field. A profile without a valid object is not payable through the profile, which never affects the name or NIP-17 messaging; an ordinary Nostr account that is not a zkCoins wallet has no object at all. When present, the object has exactly the fields `{version, network, address, pk0, nk_commit, ivpk, relays, addr_sig, name_sig}`: `version` is the JSON number `1`; `network` is one of `mainnet`, `testnet`, or `regtest`; `address` is Bech32m; `pk0`, `nk_commit`, and `ivpk` are lowercase hex of exactly 32 bytes; `relays` is a non-empty JSON array of relay URL strings used for kinds 1420/1421; and `addr_sig` and `name_sig` are each lowercase hex of exactly 64 bytes — `name_sig` over the profile's `nip05` value per [§4.3](#43-addressing-for-delivery) *Name consent*. `op_pubkey` is the kind-0 author and is not duplicated in the object. `lud16` is emitted only when the optional Lightning bridge is enabled for that name, and **MUST** then equal the profile's normalized `nip05` value ([Lightning bridge](/lightning-bridge)). Like the rest of a kind-0 profile, it is **not** gift-wrapped — it is intentionally public so any sender can discover it — but its disclosure is limited to the payment fields an `Invoice` would also carry, plus the `nip05` identifier and the object's `version`/`network` ([§4.3](#43-addressing-for-delivery)).

**Profile verification — two checklists (normative).** A consumer runs the one its discovery path supports.

*Payment-object checklist* — applies wherever a `zkcoins` object is consumed, whatever led the consumer to the event:

1. the kind-0 event signature verifies under its author, and that author equals the `op_pubkey` the consumer arrived with — the pinned key of a known contact, the key an addressable event or `nprofile` named, or, on a first discovery through a name, the key the NIP-05 response mapped that name to;
2. `version = 1`, the expected `network`, lowercase-hex fields of the stated widths, valid Bech32m `address`, non-empty `zkcoins.relays`;
3. `H(pk0 ‖ nk_commit) == address`;
4. `addr_sig` verifies under `pk0` over the profile-fixed `invoice_message` with the event author as `op_pubkey`;
5. the [§4.3](#43-addressing-for-delivery) payment-identity pin check for an already-pinned counterparty.

*Name checklist* — applies **only** when the consumer reached the event by resolving a name: the reverse `nip05` match, check (iv) of [§4.3](#43-addressing-for-delivery) — `name_sig` valid under `pk0` over `name_message` for the resolved name — and, for messaging, kind-10050 readiness ([§4.3](#43-addressing-for-delivery) *First discovery*, *Name consent*). A resolved name whose `name_sig` is absent or invalid **MUST NOT** be accepted or presented for that identity, which never affects payment through the profile or NIP-17 messaging with it. A consumer that arrived by `op_pubkey` — from an addressable event, an `nprofile`, an `Invoice`, or an existing contact — runs it not at all, with the single exception of an existing contact whose profile announces a changed `nip05`: that triggers the display-only revalidation of [§4.3](#43-addressing-for-delivery) *Name changes*, and until it succeeds the contact is shown unresolved.

An absent or invalid `zkcoins` object disables payment through that profile only. Ordinary Nostr users without that object remain fully valid NIP-17 correspondents.

**Private direct messages (NIP-17).** Human one-to-one messages **MUST** follow NIP-17 without a zkCoins extension:

1. The unsigned rumor is kind `14`; its `pubkey` is the sender's `op_pubkey`, its plaintext string `content` is the message, and it has **exactly one** `p` tag, naming the sole recipient's `op_pubkey`. An additional recipient `p` tag is a different room and is outside this normative one-to-one profile. Standard NIP-17 reply tags may be used.
2. The sender produces **two independent NIP-59 seal-and-gift-wrap constructions** over that one rumor — one **to the recipient**, one **to the sender itself** — and **MUST NOT** reuse a single seal across them. For each copy, let `P` be that copy's own outer recipient: the recipient's `op_pubkey` for the recipient copy, the sender's own `op_pubkey` for the retained sender copy.
3. For each copy independently: NIP-44-v2-encrypt the rumor under `conversation_key(op, P)` — the copy's **own** outer recipient, so the sender copy is sealed to the sender — and sign the resulting kind-13 seal with `op`. In both copies the seal `pubkey` **MUST** equal the rumor `pubkey` **MUST** equal the sender's `op_pubkey`.
4. For each copy independently: wrap that copy's seal in a kind-1059 gift wrap under its **own** fresh random one-time wrapper key, with **exactly one** outer recipient `p` tag naming that copy's `P`, as NIP-59 requires. The two copies therefore carry **distinct seal ciphertexts** and **distinct** outer kind-1059 `pubkey` values; both **MUST** differ.
5. Each copy is published **only** to the relays in that receiver's latest valid kind-10050 event. If no valid kind-10050 event with at least one `relay` tag is known, that identity is not ready for NIP-17 and the client **MUST NOT** guess a relay or silently use another DM protocol.

The seal and gift-wrap `created_at` values **SHOULD** be independently randomized to a time no more than two days in the past and **MUST NOT** be placed in the future. The rumor retains the message's canonical creation time. Before any network write, the sender **MUST** verify that every destination relay belongs to the latest valid kind-10050 set for that particular receiver copy; a destination outside that set aborts that publish attempt.

**Receive and validation flow (one-to-one, normative).** For an inbound receiver copy, the client validates in this order and rejects the message immediately on any failure:

1. Recompute the outer kind-1059 event ID, verify its signature under its one-time `pubkey`, require `kind = 1059`, and require **exactly one** outer recipient `p` tag naming the local receiver `op_pubkey` before attempting decryption. For a locally retained sender copy, that sole outer recipient `p` **MUST** name the local sender `op_pubkey`. Any additional outer recipient `p` is invalid for this one-to-one profile.
2. NIP-44-v2-decrypt the outer `content` with the local recipient key. Parse a kind-13 seal, require `kind = 13`, recompute its event ID, verify its signature under the seal `pubkey`, and require `tags` to be exactly the empty array.
3. NIP-44-v2-decrypt the seal `content` under `conversation_key(local key, seal.pubkey)` — for a retained sender copy that is the sender's conversation key to itself, matching the per-copy send construction above. Parse an **unsigned** kind-14 rumor: require `kind = 14`; `sig` **MUST** be absent; `id` **MUST** equal the ordinary Nostr event hash recomputed from its fields; `created_at` **MUST** be present; `content` **MUST** be a non-empty plain-text UTF-8 string — the human message body, exactly as NIP-17, **never** required to be JSON-shaped or parsed as JSON; and the rumor **MUST** have exactly one recipient `p` tag. For an inbound receiver copy that tag **MUST** name the local recipient. For a locally retained sender copy it **MUST** name the recorded conversation counterparty while the outer `p` names the local sender.
4. Require the seal `pubkey` to equal the rumor `pubkey`. For a locally retained sender copy, also require both values to equal the local sender's `op_pubkey`; a foreign author cannot become a local sent message. Only after every check succeeds may the client authenticate the plaintext as a message from that Nostr public key and store or display it.

Malformed ciphertext, parsing failures, unexpected kinds, missing or wrong recipient tags, extra seal tags, a signed rumor, a bad ID or signature at either signed layer, a wrong rumor ID, or a seal/rumor public-key mismatch **MUST** be discarded without display, notification, reply, or fallback. A rejected event **MUST NOT** mutate conversation state.

New human messages **MUST NOT** use kind `4` / NIP-04 and **MUST NOT** silently fall back to it. A client **MAY** read historical NIP-04 messages. Kinds `1420` and `1421` are restricted to zkCoins coin-bundle delivery and acknowledgements and **MUST NOT** carry chat text. No `zkcoins` profile object, custom endpoint, event kind, tag, or capability marker is required for an ordinary NIP-17 peer to send, receive, or reply.

**DM relay list (kind 10050).** This standard replaceable event is signed by `op`, has empty `content`, and contains one or more `relay` tags with the relays on which the account receives NIP-17 gift wraps. A zkCoins account **MUST** publish and keep a valid kind-10050 event discoverable by ordinary NIP-01 `authors`/`kinds` filters on the relays it is reachable on — its `nprofile` hints, any name's NIP-05 relay hints, and the configured discovery/bootstrap relays. This obligation is independent of whether the account carries a name. Senders use exactly these DM relays; the `zkcoins.relays` array is for payment delivery and does not replace kind 10050.

**Delivery rumor (kind 1420).** Built per NIP-59: the rumor (unsigned event) has `kind = 1420` and `content` = the JSON of the [§4.2](#42-bundle-delivery) `DeliveryEvent.payload`. Field encoding (normative, **one** JSON mapping — no free URL list):
- `blob_id` — lowercase-hex of the 32-byte content hash;
- `blob_locators` — the **base64url-no-pad** string of **`serialize(BlobLocatorSet)`** (canonical binary holder list of [§7.1](#71-serialization-conventions-normative); `blob_id` is context beside the set, not inside it). A decoder **MUST** base64url-no-pad-decode this string and parse the result as `serialize(BlobLocatorSet)` under the §7.1 bounds; any decode failure, non-canonical padding/alphabet, trailing garbage after decode, or a malformed `BlobLocatorSet` **MUST** reject the payload. A free JSON array (or other list) of URL strings is **not** a conforming encoding and **MUST** be rejected;
- `ack_nonce` — lowercase-hex of the 32-byte sender-chosen nonce;
- optional `record_kind` when the blob is a `SelfDeliveryRecordV1` — closed JSON **string** literal `record_kind ∈ {"mint","send","receive"}` (same value set as `transition_kind` on [§7.5](#75-node-rest-api-normative) `PullResult`; the transition class of the enclosed `SelfDeliveryRecordV1`, mirroring the binary `record_kind` of [§4.2](#42-bundle-delivery) / [§7.1](#71-serialization-conventions-normative)). Any other value, a non-string, or presence when the blob is not a `SelfDeliveryRecordV1` **MUST** reject the payload.

It is sealed (kind 13, NIP-44-encrypted to the recipient's `IVPK`) and gift-wrapped (kind 1059, fresh ephemeral key) so the relay learns neither party; the **outer** kind-1059 event carries **exactly** the two cleartext scan tags `["zkdt", <detect_tag hex>]` and `["zkepk", <epk hex>]` ([§4.2 step 4](#42-bundle-delivery)) and **MUST NOT** carry `blob_id`, holder URLs, `record_kind`, or coin ids in cleartext. The recipient finds candidates by the [§4.4](#44-note-discovery) scan: the relay cannot pre-filter, so the recipient pulls kind-1059 events and matches the outer tags with one ECDH and one Poseidon hash per event, unwrapping only matches.

**ACK rumor (kind 1421).** `content` is exactly the JSON object `{detect_tag, blob_id, ack_nonce, op_sig}` with **four closed fields** and no others — `op_sig` lives **inside** this JSON content, never as a Nostr tag and never outside the rumor. All four values are **lowercase hex** of the underlying raw bytes (`detect_tag` 32 B, `blob_id` 32 B, `ack_nonce` 32 B, `op_sig` **exactly 64 B** / 128 hex chars). `op_sig` is the BIP-340 signature by the recipient's `op` over the fixed preimage `ack_message = H("zkCoins/v1/Ack" ‖ detect_tag ‖ blob_id ‖ ack_nonce)`, where `detect_tag`, `blob_id`, and `ack_nonce` enter as their **raw 32-byte** values (not their hex encodings) in that exact order ([§4.2](#42-bundle-delivery)). A decoder **MUST** reject missing/extra fields, non-lowercase-hex, wrong hex widths, or an `op_sig` that is not exactly 64 decoded bytes. Sealed and gift-wrapped back to the sender.

**Publisher profile (kind 30421).** An addressable event a publisher publishes so spenders can find it ([§3.8](#38-fees-and-economics)). Because v1 publishing is **sponsored** — no fee, no fee coin, no fee address ([§3.8](#38-fees-and-economics)) — the profile advertises only where to reach the publisher. `content` = JSON `{version, relays}` — **two closed fields**, no others: `version` the JSON number `1`, `relays` a non-empty JSON array of relay URL strings. The event is signed by the publisher's `op` key and its `pubkey` **MUST** equal that key, which is the `publisher_pubkey` a spender names in its transition-submit request ([§7.5](#75-node-rest-api-normative)); a `publisher_pubkey` with no such event is the §7.5 `unknown_publisher` error.

There is deliberately **no** payment-identity block here: with nothing to pay, there is nothing to bind. That is what keeps a v1 publisher to a key, a relay presence, and an endpoint — no account, no address, no `sk₀`, no wallet, no DNS, no name. The paid variant of this event, which carries `{fee_address, fee_asset_id, fee, pk0, nk_commit, ivpk, addr_sig}` and requires all three payment checks before a fee-bearing hand-off, is specified in [§3.8.1](#381-fee-coin-mechanism-deferred) and is **not part of v1**.

A spender reaches the publisher's [§7.6](#76-publisher-interface-normative) hand-off over **REST**, not over Nostr, so a publisher also operates a reachable HTTP endpoint alongside its key and its relay presence: the `relays` above say where this profile and the publisher's Nostr traffic are found, and they are **not** an endpoint for the hand-off. The base URL is resolved from the publisher's signed `OperatorEndpointV1` (kind 30422, [§4.3](#43-addressing-for-delivery)) whose `d` tag equals the hex `publisher_pubkey` and whose event author **MUST** equal that same key; a `publisher_pubkey` with no such authenticated endpoint event is the [§7.5](#75-node-rest-api-normative) `unknown_publisher` error, exactly as a missing profile is. Both events are signed by the one `op` key, so authenticating either binds the other to the same operator.

Kind 30421 lies in the **addressable** range, so per NIP-01 it **MUST** carry a `d` tag; its canonical value is the hex `op_pubkey`, and the event `pubkey` **MUST** equal that key. Because `d` is the author's own key, the event is uniquely addressed by `(kind, pubkey)` in practice — the tag is required for NIP-01 conformance rather than for addressing, and a consumer **MUST** reject a kind-30421 event whose `d` is absent or differs from its author.

Under the deferred fee mechanism ([§3.8.1](#381-fee-coin-mechanism-deferred)) the profile instead carries `{fee_address, fee_asset_id, fee, relays, pk0, nk_commit, ivpk, addr_sig}` and a spender verifies it from that event alone, in order: (i) `H(pk0 ‖ nk_commit) == fee_address`; (ii) `addr_sig` under `pk0` over the profile-fixed `invoice_message` (`amount = 0`, all-zero `asset_id`, empty `memo`, `recipient` = `fee_address`, the event author as `op_pubkey`, and that event's `relays`); (iii) the event signature under the author `op_pubkey` — and only then encrypts a fee `CoinProof` to the verified `ivpk`. **None of that applies in v1**, where the profile carries no such fields and a spender that finds them rejects the profile. The publisher's Bitcoin identity is just the reveal-transaction key ([§3.4](#34-the-publisher)) — there is **no** on-chain publisher protocol key.

**Operator endpoint (kind 30422) and bootstrap manifest (kind 30423).** Replaceable addressable events carrying the signed [§4.3](#43-addressing-for-delivery) `OperatorEndpointV1` / `BootstrapManifestV1` JSON (keys and signatures hex per §7.1). Both are **intentionally public** and carry **only** global, account-independent infrastructure. They **MUST NOT** list account addresses, `blob_id`s, per-blob holders, or recovery identifiers.

### 7.4 Blossom blob store (normative)

Bundle blobs — ZBE-encrypted `CoinProof` or `SelfDeliveryRecordV1` blobs ([§4.2.1](#421-bundle-blob-encryption-zbe-normative), [§7.1](#71-serialization-conventions-normative)) — are stored and fetched by SHA-256 content address using **Blossom** (BUD-01/02). The Blossom store is **append-only** (no `DELETE`) under Data Permanence ([§4.8](#48-durability--the-store-everything-invariant), [Requirement 12](/requirements#12-data-permanence)): once a blob is accepted, the store **MUST NOT** delete, expire, or otherwise destroy it. A node MUST expose, under its base URL, the path prefix `/blossom`:

| Method | Path | Purpose | Auth |
|---|---|---|---|
| `GET` | `/blossom/<sha256>` | fetch a blob by its lowercase-hex SHA-256 (`= blob_id`) | none (ciphertext is already encrypted) |
| `HEAD` | `/blossom/<sha256>` | existence / size probe | none |
| `PUT` / `POST` | `/blossom/upload` | store a blob; the server computes `blob_id = H(body)` and returns it | authorization event (below); a private store admits only its account/known peers, a Bootstrap-Manifest `blob_store` also admits recovery-overlap uploads from any node ([§4.3](#43-addressing-for-delivery)) |

**Upload request form (normative — interoperable).** `PUT` and `POST` on `/blossom/upload` are equivalent. The **request body is the raw blob bytes only** (the ZBE ciphertext or other content-addressed payload — **not** multipart, **not** JSON-wrapped). Binding metadata travels in **fixed headers**:

| Header | Value | Required |
|---|---|---|
| `Authorization` | `Nostr <base64(event JSON)>` (kind `24242`, below) | **yes** |
| `Content-Type` | `application/octet-stream` | **yes** |

Multipart or JSON request bodies on `/blossom/upload` are **not** a conforming v1 form and **MUST** be rejected (`415` or `400`).

**Authorization event (normative).** `PUT`/`POST /blossom/upload` carry the header `Authorization: Nostr <base64(event JSON)>` with a Nostr event of **kind `24242`** signed by the account's `op` key ([§1.2](#12-key-hierarchy)):

- `kind`: `24242`; `pubkey`: the `op` x-only key (hex).
- tags: `["t", "upload"]`; `["x", <lowercase-hex SHA-256 of the exact request body bytes>]` (this equals the resulting `blob_id`); `["expiration", <unix seconds, decimal string>]`.
- `created_at` **MUST** satisfy `created_at ≤ now + 60` (seconds; clock-skew allowance) **and** `created_at ≥ now − replay_window`, where `replay_window` is a fixed server-side bound (**RECOMMENDED 300 s / 5 min**); `content` empty.

The server **MUST** reject (`401`) an event whose signature, `kind`, `t` tag (mismatched method), or `x` tag (mismatching the body hash) fails; reject (`401`) an expired or future-dated event (`expiration` past, or `created_at` outside the window above — too far in the future beyond 60 s skew, or older than `replay_window`); reject (`403`) a PUT/POST whose `op` key is not the paired account's or a configured peer's (**except** that a `blob_store` listed in the network's Bootstrap Manifest — [§4.3](#43-addressing-for-delivery) recovery-discoverable overlap — **MUST** additionally accept a recovery-overlap upload from **any** node's `op`; this is the blob-plane analogue of a `seed_relay` accepting any published delivery event, and remains subject to the size limit below, the authorization-event checks above, and operator **admission control** — per-source rate-and-quota limits (`429 rate_limited`, [§7.8](#78-kernel-rpc--the-internal-interface-normative)) applied **before** acceptance. Because `op` keys are permissionless, per-identity quotas **bound but cannot cryptographically prevent** Sybil-rotated spam, so a manifest `blob_store` carries the same open-acceptance spam surface as an open `seed_relay` — an accepted operational residual mitigated only by the operator's admission policy; a private, non-manifest store keeps the paired-account/configured-peer restriction); and reject (`413`) a body over the advertised size limit. A successful PUT/POST returns `200` with JSON body:

```
{
  "blob_id": <lowercase-hex 32B>           // = H(body)
}
```

where `blob_id = H(body)` — the content address of [§4.2.1](#421-bundle-blob-encryption-zbe-normative). Uploading bytes already present is idempotent and returns the same `blob_id`. `GET /blossom/<blob_id>` returns the raw bytes and is unauthenticated (ciphertext is self-protecting, §4.2.1).

`GET /blossom/<sha256>` MUST return the exact bytes whose SHA-256 equals `<sha256>` or `404`; a client MUST verify `H(body) == <sha256>` on receipt (content-addressed self-check) and reject a mismatch. Beyond the mandatory copy at ≥1 network `blob_store` ([§4.3](#43-addressing-for-delivery) recovery-discoverable overlap), **further** redundant copies ([§4.6](#46-data-availability)) are placed by `PUT`-ing the same blob to other holders' `/blossom/upload` endpoints; every holder retains its copy indefinitely ([§4.8](#48-durability--the-store-everything-invariant)). Account-specific holder hints (`BlobLocatorSet`) live only in the **encrypted** delivery / self-delivery interior ([§4.2](#42-bundle-delivery), [§4.3](#43-addressing-for-delivery)) — never as a public directory on the Blossom plane.

### 7.5 Node REST API (normative)

This is the **public, outward** surface — what a wallet, SDK, or explorer speaks. It is served by the **API layer** on top of the kernel RPC (§7.8), and only by it: the kernel speaks gRPC and is never reachable from a public client ([§6.1](#61-components-and-responsibilities) *Kernel and API — two boundaries*). Each Private, submit, and chain endpoint below maps to a kernel-RPC procedure (§7.8); the trivial `GET /` (listing) and `GET /health` (liveness) endpoints are API-local and need no kernel call. Which endpoints an instance actually serves follows from its enabled `features` ([§6.1](#61-components-and-responsibilities)); a request against a disabled feature **MUST** be answered `404 feature_disabled` — the sole exception is the open `GET /v1/token/<asset_id>/provenance` read, which is not `features`-gated and is served whenever the node holds the terms ([§6.4](#64-external-interfaces-abstract), [§4.6](#46-data-availability) Class B).

All paths are relative to the node base URL and MUST be served over TLS 1.3/1.2 or a Tor v3 onion service ([§5.1](#51-capability-gated-pull)). Errors use HTTP status + a JSON `{ "error": "<machine_code>", "message": "<human>" }` body — **except** `GET /health/ready`, which uses its own readiness shape below and is **not** an instance of this generic error body. Idempotent mutating requests (`submit`) MUST honour an `Idempotency-Key` request header. The key is an opaque client string of at most 64 bytes; a node MUST retain the mapping `Idempotency-Key → job_id` and the associated request hash (body fingerprint) **indefinitely** under Data Permanence ([§4.8](#48-durability--the-store-everything-invariant)) — no TTL, no expiry, and no deletion of persisted idempotency data. A known key **always** yields the same outcome with no time bound: a repeat of the same key with a byte-identical body returns the original `202 { job_id }`; the same key with a different body is rejected `409 idempotency_conflict`.

**Multi-network projection (normative).** A deployment serves one or more networks in **parallel**. Each `kernel.v1` upstream (§7.8) is **single-network** — its `Info.network` names exactly one of `mainnet`, `testnet`, `regtest` — and the **API layer MAY multiplex** several single-network upstreams behind one public origin so a client can reach every served network at once (never a redeploy between them). The network is then a **mandatory path segment**: every endpoint in this section **except** the origin-local `GET /`, `GET /health`, the discovery endpoint `GET /v1/networks`, and the content-addressed, network-agnostic `/blossom/…` plane is served under the prefix `/v1/{network}/`, where `{network}` is one of the served network names — e.g. `/v1/mainnet/info`, `/v1/testnet/tx`, `/v1/mainnet/chain/accumulator`. (A single-network deployment **MAY** additionally serve the same endpoints without the prefix as a convenience, but the prefixed form is canonical and, when a network is served, **MUST** be accepted.) The following rules are normative and **fail-closed**:

- **Discovery.** `GET /v1/networks` (network-less) → `{ networks: [ { network: <mainnet|testnet|regtest>, base_path: "/v1/<network>" } ] }` lists **exactly** the networks this deployment currently serves; a network appears **only after** it is ready to serve — i.e. its `GET /v1/{network}/health/ready` would answer `{ ready: true }` (it has passed its [Path to mainnet](/implementation-mandate) readiness gate: step 7 for `testnet`, step 9 for `mainnet`). `GET /` carries the additional closed key `networks` resolving to this endpoint. `GET /v1/{network}/info` returns exactly the `/v1/info` object defined below, with its `network` field equal to `{network}`.
- **Per-network readiness.** `GET /v1/{network}/health/ready` is the readiness of **that** network's upstream (the readiness shape defined below); the origin-local `GET /health` is only the multiplexing process's own liveness.
- **Unserved vs. unavailable.** A request whose `{network}` the deployment does **not** serve **MUST** be answered `404 network_unavailable`; a request for a **served** `{network}` whose upstream is currently unreachable **MUST** be answered `503 dependency_unavailable` (and that network's `GET /v1/{network}/health/ready` answers `{ ready: false, reason: dependency_unavailable }`). The two conditions are **never** conflated, and there is **no** default network — an omitted or unknown `{network}` never falls back to another.
- **Upstream identity (anti-confusion).** Before serving or advertising a `{network}`, the API **MUST** verify the mounted upstream's `Info.network` (§7.8) **equals** `{network}`; on mismatch it **MUST NOT** serve or list that network. This closes the mis-wired `mainnet → testnet-kernel` (or any cross-network) routing hole.
- **Strict network scoping.** Custody, addresses, coins, capability challenges/sessions and their nonce stores, the `Idempotency-Key → job_id` store, and account records are **per-network**: the API **MUST NOT** serve a record, session, challenge, or idempotency mapping created under one network in response to a request under another. Each network's kernel already holds its own value store (§7.8); the API's own non-value-bearing stores are keyed by network.

**Public (unauthenticated) — the Public projection of [§5.5](#55-two-explorer-modes); no Private data:**

| Method | Path | Returns |
|---|---|---|
| `GET` | `/` | `{ name, version, endpoints }` — `endpoints` is an object mapping each **closed** logical name below to an absolute URL or a root-relative path (UTF-8 string values only; unknown keys ignored on read; a conforming producer emits exactly the closed key set for the surfaces this deployment exposes, and **MUST** omit keys for unadvertised optional roles). **Closed keys** (all §7.4 / §7.5 surfaces): `health`, `health_ready`, `networks`, `info`, `chain_accumulator`, `chain_inscriptions`, `chain_nullifier`, `tx`, `jobs`, `jobs_stream`, `jobs_sign`, `jobs_cancel`, `attest_balance_challenge`, `attest_balance`, `grants_challenge`, `grants`, `pull_challenge`, `pull`, `record`, `proof`, `account_state`, `receipts_stream`, `publish_spendrecord`, `bootstrap_challenge`, `bootstrap_entrust`, `bootstrap_revoke`, `blossom_get`, `blossom_head`, `blossom_upload`, `token_provenance` |
| `GET` | `/health` | `200 "ok"` once the process is up |
| `GET` | `/health/ready` | readiness probe — **both** success and not-ready answers use the **same** object `{ ready: bool, reason?: <closed string> }` (and **MAY** carry diagnostic fields `bitcoin_tip_height`, `root`, `size`, `scanner_lag` when known, where `root = nav_root = Hc("NfLog/Root", size ‖ mth)` (§3.7)). **HTTP 200** with `{ ready: true }` (no `reason`) when the node is ready to serve consensus-dependent reads and credits; **HTTP 503** with `{ ready: false, reason: <one of the closed set> }` otherwise. Closed `reason ∈ {syncing, scanner_lag, circuit_mismatch, deep_reorg, dependency_unavailable}` — a node **MUST** use exactly one of these values and **MUST NOT** invent further codes. This endpoint is **explicitly excluded** from the generic `{ "error", "message" }` error-body shape above |
| `GET` | `/v1/info` | `{ network, protocol_version: "v1", circuit_digests: { C, C_balance }, bootstrap_pubkey: <hex32 x-only>, relay_url, blossom_url, max_blob_bytes, finality_confirmations: 6, activation_height: <u64>, max_tx_inputs: 8, max_tx_outputs: 8, max_rx_coins: 4, max_account_assets: 32, features: [<closed feature strings>], bootstrap: BootstrapManifestV1 }` — `network ∈ {mainnet, testnet, regtest}` is the sole network tag (v1 pins Bitcoin network 1:1 to this tag; there is **no** separate `bitcoin_network` field). `bootstrap_pubkey` is the network-parameter pin of [§3.6](#36-chain-scanning) / [§4.3](#43-addressing-for-delivery) under which `bootstrap.manifest_sig` **MUST** verify. `features` is the closed advertisement set of [§6.1](#61-components-and-responsibilities): each element ∈ `{wallet, explorer, publisher, lightning_bridge, mail_bridge}`, naming exactly what this API instance serves; a feature absent from the array is off and a client **MUST** treat it as absent. `bootstrap` mirrors the per-network signed [§4.3](#43-addressing-for-delivery) manifest (seed relays, blob stores, operator IDs only; **no** account- or blob-specific fields) |
| `GET` | `/v1/chain/accumulator` | `{ size, root, tip_block_hash, tip_height }` — the current `NAV(tip)` as `(size, root)` with `root = nav_root = Hc("NfLog/Root", size ‖ mth)` (§3.7) ([§3.7](#37-the-nullifier-accumulator); NAV(tip) is `(size, mth)` now) |
| `GET` | `/v1/chain/inscriptions?from_height=&from_tx_index=&from_vin_index=&limit=` | paginated list of zkCoins nullifier inscriptions. **Query (normative):** `from_height` optional, default `0`; `from_tx_index` optional, default `0`; `from_vin_index` optional, default `0` — together the **inclusive** lexicographic lower bound on the reveal input's `(height, tx_index, vin_index)` triple ([§3.5](#35-inscription-format)/[§3.6](#36-chain-scanning): a reveal transaction **MAY** carry multiple inscriptions in different `vin_index` values); `limit` optional, default `100`, valid range `1..1000` — `limit = 0` or `limit > 1000` → `400 bounds_exceeded`. **Response:** `{ inscriptions: [ { txid, height, tx_index, vin_index, count, format, nullifiers: [{ pubkey, r, state }], confirmation_state } ], next_height?: <u64>, next_tx_index?: <u64>, next_vin_index?: <u64> }` — each inscription carries its reveal-input `vin_index`; the half-aggregated `(Pkⱼ, Rⱼ)` set of each inscription ([§3.5](#35-inscription-format)), whose signatures the node has verified against Bitcoin; each `nullifiers[i].state` is that member's §3.10 state (`completed` \| `pending` \| `failed`) — members of one aggregate MAY differ by first-occurrence (a later `Pk` collision is `failed` while earlier members stay `pending`/`completed`); `confirmation_state ∈ {pending, completed}` is **only** the reveal transaction's confirmation depth relative to the §3.9 6-confirmation floor (not a per-nullifier aggregate of §3.10) and **MUST NOT** carry `failed`. **Stable sort (normative):** ascending `(height, tx_index, vin_index)` of the reveal input (then the §3.6 payload-member order inside one inscription). **Pagination cursor (normative):** when more results remain, **all three** of `next_height`, `next_tx_index`, and `next_vin_index` are present and form the **exclusive** triple-cursor after the last returned inscription — the `(height, tx_index, vin_index)` of the first not-yet-returned inscription in sort order; a client requests the next page with `from_height = next_height`, `from_tx_index = next_tx_index`, and `from_vin_index = next_vin_index` (so a page that ends mid-transaction does **not** duplicate or skip remaining `vin_index` inscriptions of that reveal). When no further results remain, **all three** cursor fields are **absent**. A response **MUST NOT** carry a proper subset of the three cursor fields |
| `GET` | `/v1/chain/nullifier/<pubkey>` | a self-verifying **RFC-6962 inclusion** proof for the account-state key `<pubkey> = Pkᵢ` against the current accumulator log when present (the Path-B service of [§3.7](#37-the-nullifier-accumulator)): `{ present, position?: <u64>, leaf?: <Rᵢ hex>, audit_path: [hex] (≤ 64), tree_size: <u64>, root, tip_block_hash, tip_height }` — when `present: true`, `position` / `leaf` / `audit_path` form an authenticated inclusion proof of `(Pkᵢ, Rᵢ)` at its position; when `present: false`, the body is an **unauthenticated local-index absence answer** (the node's `Pk → (pos, R)` index has no entry) — **not** an RFC-6962 non-inclusion proof and **MUST NOT** back a credit (`tip_block_hash` 32B, internal order) |

**Accumulator `root` (normative).** In **every** §7 surface — `GET /v1/chain/accumulator`, `GET /health/ready`, `GET /v1/chain/nullifier/<pubkey>`, and the kernel `AccumulatorTip` / `NullifierPath` — the field `root` denotes the **byte-unique** committed value `nav_root = Hc("NfLog/Root", size ‖ mth)` (§3.7), always paired with its `size`; it is **never** the bare Merkle-tree-head `mth`.

**Submit & proving (no capability — the proof is self-authenticating, [§6.4](#64-external-interfaces-abstract)):**

| Method | Path | Body / Returns |
|---|---|---|
| `POST` | `/v1/tx` | body = a transition request (see below) → `202 { job_id, status: "accepted" }` |
| `GET` | `/v1/jobs/<job_id>` | `{ job_id, kind, status, phase?, progress, result?, error? }`; `status ∈ {accepted, proving, awaiting_signature, publishing, completed, failed, cancelled}` — the **only** field clients **MUST** dispatch on; `phase` is an **optional, non-stable diagnostic string** matching `[a-z0-9_]{1,64}` (implementation-local sub-step labels such as `witness_build` or `half_agg`; **MUST NOT** be treated as a stable enum and **MUST NOT** drive client control flow); in terminal states (`completed` \| `failed` \| `cancelled`) `phase` is **absent**; honours `Retry-After` on non-terminal polls |
| `GET` | `/v1/jobs/<job_id>/stream` | Server-Sent Events: one `phase` event per phase change (diagnostic only — clients dispatch on the embedded `status`), a terminal `complete`/`error` event |
| `POST` | `/v1/jobs/<job_id>/sign` | body = `{ signature: <hex64 — bytes(R) ‖ bytes(s), §3.2>, s2c_nonce: <hex32 — x-only R'> }` — the wallet returns the BIP-340 transition signature over the **per-network fixed** message `m_state = "zkCoins/v1/StateUpdate/{mainnet\|testnet\|regtest}"` (with the sign-to-contract tweak binding the witness-determined `H(ProofData)` in its nonce) and `s2c_nonce = R'`, the pre-tweak sign-to-contract nonce point — a **non-secret** curve point the node forwards to the publisher for the fee-`ocr` check ([§3.8](#38-fees-and-economics), [§7.6](#76-publisher-interface-normative)). The wallet signs only after the node surfaces `H(ProofData)` in the `awaiting_signature` phase; it never blind-signs a node-supplied message — the message is the per-network fixed constant, and the SPEND key never leaves the wallet ([§2.3](#23-state-transitions)) |
| `POST` | `/v1/jobs/<job_id>/cancel` | cancels a not-yet-published job |
| `POST` | `/v1/attest/balance/challenge` | body = `{ subject: <zk-address> }` → `{ nonce: <hex32>, expiry: <u64>, domain: "zkCoins/v1/AttestBalanceChallenge" }` — §5.1 `Challenge` shape under the action-bound [AttestBalance domain](#a-ownership-proof); the node stores `(nonce → subject, action = attest_balance, expiry)` |
| `POST` | `/v1/attest/balance` | body = `{ subject: <zk-address>, asset_id: <hex32>, nav_ceiling?: <hex32>, size_ceiling?: <u64>, challenge: { nonce: <hex32>, expiry: <u64> }, ownership_proof: OwnershipProofJson }` (omit both ceilings ⇒ node uses its current `size_final`; if `nav_ceiling` is given, `size_ceiling` **MUST** accompany it so the node can rebuild `mth_ceiling` and enforce `size_ceiling ≤ size_final`, §5.7) → `202 { job_id }` — a `C_balance` proving job under the same job model; `nav_ceiling` is the 32-byte `nav_root` of the requested ceiling and, when **omitted**, defaults to the node's current `size_final` prefix, with the node recovering `(size_ceiling, mth_ceiling)` from its own scan; result carries the [§5.7](#57-balance-attestation-history-private) `BalanceAttestation` (public inputs + proof, canonical §7.1 binary as hex). **Auth (normative):** a fresh action-bound **OwnershipProof** by `sk₀` over `chal = H(domain ‖ nonce ‖ chan_bind ‖ subject ‖ expiry ‖ request_hash)` with `domain = "zkCoins/v1/AttestBalanceChallenge"` and `request_hash = H("zkCoins/v1/AttestBalance" ‖ subject ‖ asset_id ‖ ceiling_encoding)`, where `ceiling_encoding` is one discriminator byte `0x00` when both ceilings are omitted, or `0x01 ‖ nav_ceiling (32B) ‖ u64-be(size_ceiling)` when both are present (any other combination is `400 malformed_request`); `ownership_proof` is the [§5.1(a)](#a-ownership-proof) / `OwnershipProofJson` shape. A `GrantProof`, a missing/invalid/wrong-domain OwnershipProof, a `chal` mismatch, or a body `challenge.expiry` that does not equal the stored challenge expiry → `401 unauthorized`; an unknown, already-consumed, or expired `nonce` → `410 challenge_expired` (same codes as the pull path). The node **MUST** hold the subject's operational bundle to *prove* ([§7.7](#77-wallet--node-bootstrapping-normative)), but bundle possession **never** replaces this request authentication |
| `POST` | `/v1/grants/challenge` | body = `{ subject: <zk-address> }` → `{ nonce: <hex32>, expiry: <u64>, domain: "zkCoins/v1/IssueGrantChallenge" }` — §5.1 `Challenge` shape under the action-bound [IssueGrant domain](#a-ownership-proof); the node stores `(nonce → subject, action = issue_grant, expiry)` |
| `POST` | `/v1/grants` | body = `{ subject: <zk-address>, grantee_pk: <hex32>, scope: { asset_ids: [<hex32>] \| "*", not_before?: <u64>, not_after?: <u64> }, expiry: <u64>, challenge: { nonce: <hex32>, expiry: <u64> }, ownership_proof: OwnershipProofJson }` → `{ grant: <Bech32m zkgrant string> }` — the node signs the [§5.2](#52-view-grant) grant with the account's `op` key. **Auth (normative):** a fresh action-bound **OwnershipProof** by `sk₀` over `chal = H(domain ‖ nonce ‖ chan_bind ‖ subject ‖ expiry ‖ request_hash)` with `domain = "zkCoins/v1/IssueGrantChallenge"` and `request_hash = H("zkCoins/v1/IssueGrant" ‖ subject ‖ grantee_pk ‖ asset_ids ‖ not_before ‖ not_after ‖ expiry)` — `asset_ids` / time fields encoded exactly as in `grant_message` ([§5.2](#52-view-grant); omitted `not_before`/`not_after` encode as `0` / `2⁶³−1`). A `GrantProof` or any non-owner capability → `401 unauthorized` (**no-escalation**: a view-grant delegate **MUST NOT** mint further grants). Missing/invalid/wrong-domain OwnershipProof, a `chal` mismatch, or a body `challenge.expiry` that does not equal the stored challenge expiry → `401 unauthorized`; unknown/consumed/expired `nonce` → `410 challenge_expired`. The node **MUST** hold the subject's operational bundle (to use `op`), but bundle possession **never** replaces this request authentication |

**`TransitionRequest` (normative).** The `POST /v1/tx` body is exactly this JSON object (encodings per [§7.1](#71-serialization-conventions-normative): 32-byte values lowercase hex, addresses Bech32m, `u128` amounts decimal strings):

```
TransitionRequest = {
  kind             : "mint" | "send" | "receive",   // required; any other value is malformed
  subject          : <zk-address, Bech32m>,          // required; the account — the node MUST hold its
                                                     //   operational bundle (§7.7), else reject
  next_pubkey      : <hex32, x-only>,                // required; the rotated spend key Pkᵢ₊₁ (§1.2)
  npk_rand         : <hex32>,                        // required; 32 unmodified CSPRNG/getRandomValues bytes per attempt (§2.1 clause 2); fail-closed if unavailable; never reused (hygiene; equality leak only on same-key retries)
  input_coins      : [ <hex32 coin.identifier> ],    // kind == "send": required, 1..max_tx_inputs;
                                                     //   MUST be absent otherwise
  output_templates : [ OutputTemplate ],             // kind ∈ {"send","mint"}: required,
                                                     //   1..max_tx_outputs (incl. change; a fee coin only under the deferred §3.8.1);
                                                     //   MUST be absent for kind == "receive"
  publisher_pubkey : <hex32>,                        // optional; presence matrix with fee_address below
  fee_address      : <zk-address>,                   // deferred (§3.8.1): MUST be absent in v1; presence matrix below
  fold_coin_ids    : [ <hex32 coin.identifier> ],    // kind == "receive": required, 1..max_rx_coins
                                                     //   (§2.1 clause 10); MUST be absent otherwise
  genesis_pubkey   : <hex32, x-only>,                // kind == "receive" only: required when the receive
                                                     //   runs as an InitialProof — the account's first
                                                     //   transition, prev_proof absent (§2.1 clause 1, §2.3.3);
                                                     //   MUST be absent for an AccountUpdateProof and for
                                                     //   kind ∈ {"mint","send"}
  issuance         : {                               // kind == "mint": required; MUST be absent otherwise
    creator_pubkey   : <hex32, x-only>,              //   required; the creator's base pubkey Pk₀ — a
                                                     //     domain-separated input to asset_id (§6.5); the
                                                     //     node returns it from GET /v1/token/<asset_id>/provenance
    name             : <UTF-8 string, ≤ 255 bytes>,  //   (§1.5; name_hash = H(name), §1.4)
    decimals         : <u8>,
    issuance_version : 1 | 2,                        //   any other value is malformed (§2.1 clause 3)
    amount           : <decimal-string u128>,
    cap_total        : <decimal-string u128>,        //   present iff issuance_version == 2 (§6.5)
    terms_salt       : <hex32>                       //   present iff issuance_version == 2
  },
}

OutputTemplate = {
  recipient : <zk-address>,
  asset_id  : <hex32>,
  amount    : <decimal-string u128>,                 // range-checked to [0, 2^128 − 1] (§1.7.3)
  delivery  : DeliveryCredential                     // optional; required for every non-self output
                                                     //   (presence rule below)
}

// Closed tagged union. Any other `type` is 400 malformed_request.
// The two variants have separate, complete check-lists: a kind-0 event
// carries no Invoice `sig` under `op_pubkey`, and an Invoice carries no
// kind-0 event signature — routing either through the other's list is
// structurally unsatisfiable.
DeliveryCredential =
  | { type: "invoice", invoice: Invoice }            // full §1.5 / §4.3 Invoice
  | { type: "profile", event: <kind-0 event> }       // full canonical kind-0 event
                                                     //   (author, created_at, Nostr signature)
```

**`creator_pubkey` and `genesis_pubkey` — base-pubkey carriers (normative).** `issuance.creator_pubkey` is **required** for every `kind == "mint"`; it carries the creator's base pubkey Pk₀, which hashes into `asset_id` as a domain-separated input ([§6.5](#65-issuance--token-standards)) and which the open `GET /v1/token/<asset_id>/provenance` read later returns to a caller. `genesis_pubkey` is **required** for a genesis receive — a `kind == "receive"` transition the node runs as an **InitialProof**: the account's first transition, with `prev_proof` absent and `prev_account_state` the canonical empty account ([§2.1 clause 1](#21-the-compliance-predicate), [§2.3.3](#233-receive)) — and supplies the genesis account's initial `txn_pubkey`; it **MUST** be absent for an `AccountUpdateProof` receive and for `kind ∈ {"mint","send"}`. A missing required field, a field present where forbidden, or a value not exactly 32 bytes is malformed: the node **MUST** reject the request with `400 malformed_request` and **MUST NOT** start a job, as for every other `TransitionRequest` presence-rule violation below. These fields are [§1.7.8](#178-reference-instantiation-status-final-for-v1) **between-step-3-and-step-7** additive §7 wire changes: `creator_pubkey` is already a bound circuit input that hashes into `asset_id`, so its wire field only transports a value the circuit already consumes; `genesis_pubkey` transports the initial `txn_pubkey` the account model already binds rather than introducing a new circuit input. Neither field changes a circuit element, a pinned vector, or a digest, and neither moves a trust boundary. The same clause names the open `GET /v1/token/<asset_id>/provenance` read as the stated precedent for this class of addition, so neither field creates a new protocol version.

**`delivery` — the delivery credential (normative).** This field is the wire carrier that closes the §4.3 gap: the node needs the recipient's `{ivpk, op_pubkey, relays}` to deliver (§4.2), and a bare address is not resolvable. It is a [§1.7.8](#178-reference-instantiation-status-final-for-v1) **between-step-3-and-step-7** wire addition: it touches **neither** a circuit element **nor** a pinned vector **nor** a digest, and therefore is **not** a new protocol version under that clause. Verification is **kernel-only** ([§6.1](#61-components-and-responsibilities)): the API layer forwards `delivery` **unchanged**, **MUST NOT** mark it verified, and **MUST NOT** log it (retention rule below).

**Check-list `type: "invoice"` (normative).** The kernel **MUST** verify, in order: the three [§4.3](#43-addressing-for-delivery) checks — (i) `H(pk0 ‖ nk_commit) == invoice.recipient`; (ii) `addr_sig` valid under `pk0` over `invoice_message`; (iii) `sig` valid under `op_pubkey` over `invoice_message` — **and** byte-exact equality of `invoice.recipient`, `invoice.asset_id`, and `invoice.amount` with the enclosing `OutputTemplate`'s `recipient`, `asset_id`, and `amount`, **and** the structural invariants of the [§1.5](#15-core-data-structures)/[§4.3](#43-addressing-for-delivery) `Invoice`: fixed-width fields at their stated widths and at least one valid relay URL. Any failure is `400 malformed_request`.

**Check-list `type: "profile"` (normative).** The kernel **MUST** verify the [§4.3](#43-addressing-for-delivery) profile chain, in order: (i) recompute the NIP-01 event `id` from the canonical fields (`pubkey`, `created_at`, `kind`, `tags`, `content`) and require byte-equality with the supplied `event.id` — the same first step the [§7.3](#73-nostr-event-kinds-normative) receive path already requires before any signature check; (ii) the kind-0 event signature under its author; (iii) `H(pk0 ‖ nk_commit) == zkcoins.address`; (iv) `addr_sig` under `pk0` over the profile-fixed `invoice_message`; (v) `version = 1`, the expected `network`, lowercase-hex fields of the stated widths, and at least one valid relay URL — **and** `zkcoins.address == output.recipient`. Amount and asset are **not** compared: a profile is an **addressing credential**, not a payment authorisation. Any failure is `400 malformed_request`.

**Profile freshness is relay-relative (normative property, not a guarantee).** Against replay the profile variant additionally requires that the node know **no newer** kind-0 of the same author (NIP-01 replaceable; on a `(created_at, id)` tie the lower `id` wins) and that `created_at` fall inside an implementation-defined window relative to the kernel clock. That freshness is **only as good as the node's relay view**: a relay that withholds a newer profile is an availability limit **no signature closes** — the same formulation discipline [§4.3](#43-addressing-for-delivery) already applies to name-consent currency (*What `name_sig` proves, and what it does not*). Implementations **MUST** state this as a property of the responding relays and of any local high-water mark they retain, never as a global "latest event" guarantee.

**`delivery` presence rule (normative).** `delivery` is **required** on every `OutputTemplate` that is **not** a self-output — for `kind == "send"` **and** for `kind == "mint"` with outputs to third parties ([§6.5](#token-standard-2--auditable-capped-supply) token standard 2 forbids self-credit in the creating transition, so third-party mint outputs are the normal case). Absent there: `400 malformed_request` (no deferred failure at delivery time). For `kind == "receive"` there are no `output_templates`, and therefore no `delivery`. A self-output **MAY** omit `delivery`; a present `delivery` on a self-output **MUST** still satisfy the matching check-list if supplied, but is not required for delivery (the node already holds the subject's operational bundle).

**Self-output (normative, narrow).** An output is a self-output **if and only if** `decoded(output.recipient) == decoded(request.subject) == persisted AccountState.owner` **and** the active operational bundle is held under **exactly** that subject. Neither a hit in any delivery-target store nor "the node already knows this `ivpk`" discharges the exception — on a node that holds bundles for many accounts that would open a cross-account gap. Bech32m spelling variants are compared on the decoded 32-byte address, not the string.

**Per-output binding (normative).** Each `delivery` belongs to **exactly** its enclosing `OutputTemplate`, never to the transition as a whole. When two or more `output_templates` of the same transition share the same `recipient`, `asset_id`, and `amount`, field equality alone does not uniquely pair a credential with an output instance: the kernel **MUST** bind each `delivery` by **array position** — `output_templates[i].delivery` authorises only `output_templates[i]` — and **MUST NOT** re-resolve a verified target through a shared address-keyed store that a later insert could overwrite. A verified credential is therefore an amount-specific, reusable recipient credential bound to one output slot of one job, not a one-shot payment authorisation and not a transition-wide token.

**What the node retains after a successful check (implementation mandate, not a technical enforcement).** After a successful check the kernel **MUST** retain **only** `{ivpk, op_pubkey, relays}` and the target's local validity window; `pk0`, `nk_commit`, `memo`, and the signatures **MUST** be discarded and **MUST NOT** be persisted or logged. The API layer forwards `delivery` unchanged, **MUST NOT** verify it, and **MUST NOT** log it. This is an **implementation mandate**, not a technical enforcement: what a process may observe in working memory, a trace, or a crash dump is not closed by a MUST sentence. The mandate exists because `pk0` is the account's genesis on-chain nullifier key and links the recipient to its first Bitcoin appearance ([§4.3](#43-addressing-for-delivery) already names this D-19 linkage class).

**Publisher / fee-address presence matrix (normative, closed).** Exactly one of the following cases holds; any other combination is **malformed** (`400 malformed_request`). **In v1 only (a) and (c) are admissible** — publishing is sponsored and there is no fee coin ([§3.8](#38-fees-and-economics)), so `fee_address` **MUST** be absent from every request and a request carrying it is malformed. Case (b) is specified for the deferred fee mechanism of [§3.8.1](#381-fee-coin-mechanism-deferred) and **MUST NOT** be implemented in v1:

| Case | `publisher_pubkey` | `fee_address` | Meaning |
|---|---|---|---|
| **(a) Self-publish** | **absent** | **MUST be absent** | the wallet's own node self-publishes ([§3.4](#34-the-publisher)); **no** fee coin, **no** `fee_address` |
| **(b) Publisher + fee** *(deferred — not v1)* | **present** | **present** | external publisher hand-off with fee: `fee_address` **MUST** equal the `recipient` of **exactly one** `output_template` — the publisher-fee coin ([§3.8](#38-fees-and-economics)); zero or more than one matching template is malformed |
| **(c) Fee-less hand-off** — **the v1 external path** | **present** | **absent** | external publisher hand-off **without** a fee coin, which in v1 is the only external form; admissible when that publisher's policy accepts the hand-off ([§7.6](#76-publisher-interface-normative); fee policy is not consensus, [§3.8](#38-fees-and-economics)) |

A `kind == "receive"` transition produces no outputs ([§2.3.3](#233-receive)) and therefore cannot use case (b); it is self-published (a) or fee-less-handed to a publisher (c). The same applies to a mint whose creator pays no publisher. A request violating any other presence rule above (a field present for the wrong `kind`, a missing required field, a count outside its bound) is likewise **malformed**: the node **MUST** reject it with `400 malformed_request` and MUST NOT start a job.

The **proving handshake** keeps custody in the wallet: the wallet posts the transition intent (input coin references, output `CoinTemplate`s — including the publisher-fee coin when case (b) of the publisher presence matrix applies — the optional `publisher_pubkey` / `fee_address` per that matrix, and the rotated `next_pubkey`); the node (prover) builds the witness — from which the six `ProofData` fields, hence `H(ProofData)`, are fully determined before any proving — folds `next_pubkey` into `new_account_state_hash`, transitions the job to `awaiting_signature`, and exposes the six `ProofData` fields plus `H(ProofData)` **and MUST echo `txn_pubkey = Pkᵢ` and `send_counter`** (the `awaiting_signature` shape below, [§1.4](#14-identifiers-and-hashes)); the wallet, having fetched the authoritative head via `GET /v1/account/state`, **MUST** refuse to sign unless `derive(A / 0' / send_counter).pubkey == current_pubkey == txn_pubkey` (the SPEND child at index `send_counter` of the [§1.2](#12-key-hierarchy) path `A/0'/i'`; Bitcoin- and recursive-proof verification remain node-side under the v1 trust model); then signs the **per-network fixed** message `m_state = "zkCoins/v1/StateUpdate/{mainnet|testnet|regtest}"` with `skᵢ`, applying the sign-to-contract tweak that binds the witness-determined `H(ProofData)` into the nonce `R = R' + H(bytes(R') ‖ H(ProofData))·G` ([§2.1 clause 2](#21-the-compliance-predicate), [§3.2](#32-transition-signing-bip-340--sign-to-contract)), and `POST`s `{ signature, s2c_nonce }` (where `s2c_nonce` carries `R'`, x-only hex) to `/sign` (the node needs `R'` — the non-secret pre-tweak nonce — to forward to a publisher for the fee-`ocr` check when a fee coin is present); the node then finalises the recursive proof (which verifies `txn_sig` over `m_state` in-circuit and opens the S2C tweak against this `H(ProofData)`, and because `new_account_state.current_pubkey = next_pubkey` is folded into `H(ProofData)`, the custody signature authorises the rotation `Pkᵢ → Pkᵢ₊₁` on **every** transition, [§2.1 clause 2](#21-the-compliance-predicate)); it finalises the `SpendRecord` + `CoinProof`s, delivers recipient `CoinProof`s over Nostr (§4.2), hands the nullifier `(Pkᵢ, Rᵢ, sᵢ, R')` and — when case (b) — the fee coin's **ZBE** delivery reference (`fee_blob_id` + encrypted locator + `epk`, [§7.6](#76-publisher-interface-normative)) to the chosen publisher, or self-publishes under case (a), and self-delivers a `SelfDeliveryRecordV1` (§4.2). A pure mint ([§2.3.1](#231-mint--issuance)) and a receive transition ([§2.3.3 step 7](#233-receive)) follow the **same** flow — including publication: each is a state-advancing transition, so its nullifier `(Pkᵢ, Rᵢ, sᵢ, R')` is handed to a publisher or self-published by the wallet's own node (§3.3–§3.4, §7.6) just like a send, and its `next_pubkey` is authorised by the same in-circuit signature check.

**Job polling and streaming (normative).** On a `GET /v1/jobs/<job_id>` while the job is non-terminal (`status ∉ {completed, failed, cancelled}`), the node returns `200` with the status JSON and a **`Retry-After` header in seconds** (RECOMMENDED: `2` while `proving`/`publishing`, `0` while `awaiting_signature` since the client must act). `progress` is a float in `[0,1]`. The `GET /v1/jobs/<job_id>/stream` endpoint is **Server-Sent Events** (`Content-Type: text/event-stream`); each frame is `event: <name>\ndata: <json>\n\n` where `<name>` is one of:

- `phase` — `data` = `{ "status": "...", "phase"?: "...", "progress": 0.0–1.0 }`, emitted on each status or diagnostic-phase change; `phase` is the same optional non-stable `[a-z0-9_]{1,64}` diagnostic string as on the poll object (absent when the node has no sub-step label to report);
- `complete` — `data` = the terminal job JSON (`{ job_id, kind, status: "completed", result }` — **no** `phase`), emitted once, then the stream closes;
- `error` — `data` = `{ job_id, status: "failed"|"cancelled", error }` (**no** `phase`), emitted once, then the stream closes.

`status` uses the closed literal set of the `/v1/jobs/<job_id>` object above; clients **MUST** dispatch only on `status`. `phase` is diagnostic-only and **MUST NOT** be required for correct client behaviour. A client that cannot hold an SSE connection falls back to polling with `Retry-After`.

**Receipts stream — auth and transport (normative).** `GET /v1/receipts/stream` ([§7.8](#78-kernel-rpc--the-internal-interface-normative) `SubscribeReceipts`, [§4.9](#49-real-time-push-delivery) push source) carries Private data (`coin_id`, `asset_id`, `amount`) and so is capability-gated exactly like the pull endpoint: the client **MUST** first open a **pull session** ([§5.1](#51-capability-gated-pull) challenge → `OwnershipProof` **or** `GrantProof`, [pull session](#pull-session-normative)) and call `/v1/receipts/stream` presenting that session's bearer token (`Authorization: Bearer <token>`) over the same `chan_bind`-bound channel the session was issued on. **Any** still-valid ownership **or** grant pull session is admissible — not only ownership sessions. The stream's subject and scope are taken from the **server-side session state** (the authenticated `subject` and the **resolved (intersected) `scope`** recorded at `POST /v1/pull`); the request body/path carries **no** `subject` field. A node **MUST** emit only receipts whose coin falls inside that stored subject + resolved scope, and **MUST NOT** emit a receipt for any other subject or out-of-scope coin on that connection. **Auth errors (normative, fail-closed):** missing or invalid bearer token (absent `Authorization`, malformed token string that is not a node-issued session credential) → `401 unauthorized`; unknown, expired, or `chan_bind`-mismatching session → `410 session_expired` (the same split `GET /v1/proof/<coin_id>` uses — never collapse expiry/unknown/channel-mismatch into `401`).

**Transport.** `Content-Type: text/event-stream`; each frame is `event: receipt\ndata: <json>\n\n` where `data` is the [§7.8](#78-kernel-rpc--the-internal-interface-normative) `Receipt` object (`{ coin_id, asset_id, amount, state, credited_at }`, all hex/decimal per [§7.1](#71-serialization-conventions-normative)). Reconnect is client-driven: on disconnect the client reconnects and recovers any missed receipts via the ordinary pull endpoint ([§5.1](#51-capability-gated-pull)) — the stream is a latency accelerator, never the sole source of truth, matching the [§4.9](#49-real-time-push-delivery) substrate-vs-fast-path split. A WebSocket transport carrying the identical `Receipt` event body is an allowed alternative.

**Job result, `awaiting_signature`, and error shapes (normative).** The `/v1/jobs/<job_id>` object carries phase- and outcome-specific payloads in three additional fields; `kind` echoes the `TransitionRequest.kind` (`"mint"|"send"|"receive"`, above) that started the job, or `"attest_balance"` for jobs started by `POST /v1/attest/balance`:

```
// present only while status == "awaiting_signature":
awaiting_signature = {                     // all lowercase hex (§7.1); u64 as JSON number
    new_account_state_hash,                   // ash (§1.4)
    output_coins_root,                        // ocr
    input_nullifiers_root,                    // inr
    coin_history_root,
    nav_commitment,
    npk_commit,                               // H("zkCoins/v1/NpkCommit" ‖ next_pubkey ‖ npk_rand), §2.1 clause 2
    proof_data_hash,                          // H(ProofData) = SHA-256(serialize(ProofData)), §1.4
    txn_pubkey,                               // Pkᵢ (x-only) — MUST equal prev_account_state.current_pubkey (§2.1 clause 2)
    send_counter                              // u64; the entry counter i of this transition (§1.5); skᵢ = A/0'/i'
  }

// present only once status == "completed":
result = {
  new_account_state_hash : hex,              // ash; ProofData.new_account_state_hash (§1.4)
  output_coins_root      : hex,
  input_nullifiers_root  : hex,
  output_coin_ids        : [hex],             // coin.identifier of every output coin produced;
                                              //   empty for kind == "receive" (§2.3.3, which
                                              //   spends and outputs nothing)
  publisher_pubkey?      : hex,               // present for **every** externally published kind
                                              //   (mint \| send \| receive) that used case (b) or (c)
                                              //   of the publisher presence matrix above; absent on
                                              //   self-publish (case a) and on attest_balance jobs.
                                              //   Echoes the SpendRecord's publisher hand-off target (§7.6)
  attestation?           : hex                // present only for kind == "attest_balance": the §5.7
                                              //   BalanceAttestation (public inputs + proof, canonical §7.1 binary)
}

// present only once status ∈ {failed, cancelled}:
error = { error: machine_code, message: string }   // the §7.5 generic error-body shape, above
```

An `attest_balance` job (kind `"attest_balance"`) uses the **same** phase strings except it has **no** `awaiting_signature` phase (C_balance needs no wallet signature) — it goes `proving` → `completed` with `result.attestation`, or `failed`.

**Wallet-side recomputation (normative, fail-closed).** The six surfaced digests are the complete `ProofData` ([§1.4](#14-identifiers-and-hashes)); `txn_pubkey` and `send_counter` are additional handshake fields the node **MUST** echo so the wallet can select `skᵢ`. Before signing, the wallet **MUST** (a) verify the surfaced `npk_commit` equals `H("zkCoins/v1/NpkCommit" ‖ next_pubkey ‖ npk_rand)` recomputed from **its own** chosen `next_pubkey` and the **fresh** `npk_rand` it supplied — a mismatch means the node folded a different rotation key, and the wallet **MUST** refuse to sign (this is what makes the key rotation wallet-verifiable, [Requirement 5](/requirements)); (b) rebuild the 192-byte `serialize(ProofData)` from the six fields (the §1.4 field order), recompute `H(ProofData) = SHA-256(serialize(ProofData))` itself — SHA-256 is wallet-native; no Poseidon is involved — and verify it equals the surfaced `proof_data_hash`; and (c) check the signing-key binding `derive(A / 0' / send_counter).pubkey == current_pubkey == txn_pubkey`, where `current_pubkey` is the value from the authoritative `GET /v1/account/state` response (or the equal field inside that response's `serialize(AccountState)`) and `txn_pubkey` / `send_counter` are the values echoed in this `awaiting_signature` — a mismatch means the node is proposing a different transition index or spend key than the head the wallet holds, and the wallet **MUST** refuse to sign. On any mismatch the wallet **MUST** refuse to sign. The wallet therefore never signs a hash it did not recompute from field values it has seen, and never signs with an `skᵢ` that does not match the head's `current_pubkey`. Bitcoin- and recursive-proof verification of the head remain the **node's** job under the v1 trust model ([§6.2](#62-wallet--node), [Requirement 4](/requirements)).

`machine_code` is a **closed** enumeration (normative): a node **MUST** use exactly the codes below for the conditions below, and `internal_error` for any condition not listed — it **MUST NOT** invent additional codes (clients dispatch on them). For the `/v1/tx` and `/v1/jobs/*` family:

| `machine_code` | Meaning |
|---|---|
| `invalid_input_coin` | an `input_coins` entry is unknown to the node, already spent locally, or fails ownership/history/identifier binding ([§2.1 clause 2](#21-the-compliance-predicate)) |
| `insufficient_balance` | the requested `output_templates` exceed the input value for some asset ([§2.1 clause 3](#21-the-compliance-predicate)) |
| `bounds_exceeded` | `input_coins`, `output_templates`, or `fold_coin_ids` exceeds `max_tx_inputs`/`max_tx_outputs`/`max_rx_coins` (above, [§2.5](#25-circuit-dimensioning-normative)) |
| `unknown_publisher` | `publisher_pubkey` does not resolve to **both** a reachable, authenticated kind-`30421` publisher profile and the kind-`30422` `OperatorEndpointV1` giving its hand-off base URL, each authored by that same key ([§7.3](#73-nostr-event-kinds-normative)) |
| `stale_message` | the `/sign` body's sign-to-contract nonce does not open the `H(ProofData)` this job surfaced in its `awaiting_signature` phase (§3.2) |
| `invalid_signature` | the `/sign` body's BIP-340 signature or sign-to-contract tweak does not verify against `txn_pubkey` ([§2.1 clause 2](#21-the-compliance-predicate)) |
| `job_not_found` | the `job_id` is unknown to this node |
| `wrong_phase` | `/sign` or `/cancel` was called while the job is not in the `status` that accepts it |
| `proving_failed` | witness assembly or proof generation failed |
| `publish_rejected` | the chosen publisher rejected the finalised `SpendRecord` ([§7.6](#76-publisher-interface-normative)); `message` carries the publisher's `reason` |
| `circuit_digest_mismatch` | the node's own build does not match the `circuit_digests` it advertises at `/v1/info` ([§1.7.9](#179-proof-system-parameters-normative)) |

Additional codes (closing the enumeration across §7.4–§7.7 surfaces):

| `machine_code` | HTTP | Meaning |
|---|---|---|
| `malformed_request` | 400 | body violates a normative shape of this section (`TransitionRequest` presence rules, missing or failed `OutputTemplate.delivery` credential check, unknown `delivery.type`, §7.1 JSON rules, wrong-HRP Bech32m, non-hex where hex is required) |
| `idempotency_conflict` | 409 | the same `Idempotency-Key` was replayed with a different body (mapping retained indefinitely; a known key never expires or is forgotten) |
| `unauthorized` | 401 | §5.1 capability invalid (bad signature/`chal`/grant), action-bound OwnershipProof missing/invalid/wrong-domain on `/v1/attest/balance` or `/v1/grants` (including a `GrantProof` presented where only owner auth is accepted — no-escalation), Blossom auth-event rejected, missing/invalid pull-session bearer token (absent or malformed — not merely expired), or a **grant** pull session presented to ownership-only `GET /v1/account/state` |
| `scope_exceeded` | 403 | §5.1 resolved-scope violation, non-peer PUT |
| `challenge_expired` | 410 | pull/bootstrap/attest/grants `nonce` expired, already consumed, or unknown |
| `session_expired` | 410 | pull-session token expired, unknown, or presented over a channel whose `chan_bind` does not match (incl. `GET /v1/receipts/stream`, `GET /v1/record/<record_id>`, `GET /v1/proof/<coin_id>`, and `GET /v1/account/state`) |
| `not_found` | 404 | unknown `blob_id`, `record_id`/`coin_id` outside the session's scope-visible set, unknown job (`job_not_found` stays canonical for the jobs family) |
| `payload_too_large` | 413 | Blossom body over the advertised limit |
| `rate_limited` | 429 | API-layer rate limit (operator policy, [§7.8](#78-kernel-rpc--the-internal-interface-normative)) |
| `dependency_not_final` | 409 | a submitted transition depends on a nullifier position `≥ size_final` (not yet 6-confirmation-final) or on a fork-loser that can never finalize; the wallet must wait for finality (or abandon a fork-loser dependency) and resubmit |
| `internal_error` | 500 | any condition not covered by a listed code |

HTTP status for the earlier jobs-family table: `invalid_input_coin`, `insufficient_balance`, `bounds_exceeded`, `unknown_publisher` → `400` (rejected at submit) or, when detected only during proving, they appear as the terminal job `error`; `stale_message`, `invalid_signature`, `wrong_phase` → `409`; `job_not_found` → `404`; `proving_failed`, `publish_rejected` → terminal job `error` objects (the job poll itself returns `200`); `circuit_digest_mismatch` → `503`. `202` is the only success status for `POST /v1/tx`; `200` for every other success.

The `GET /v1/jobs/<job_id>/stream` `complete`/`error` frames (above) carry the same `result`/`error` objects; the `phase` frame carries `awaiting_signature` inline in its `data` once `phase == "awaiting_signature"`.

**Capability-gated pull — the [§5.1](#51-capability-gated-pull) challenge–response, made concrete:**

| Method | Path | Body / Returns |
|---|---|---|
| `POST` | `/v1/pull/challenge` | body = `{ subject: <zk-address>, scope?: { asset_ids: [<hex32>] \| "*", not_before?: <u64>, not_after?: <u64> } }` ([§5.1](#51-capability-gated-pull) shape; omitted scope = `"*"`/unbounded) → `{ nonce: <hex32>, expiry: <u64>, domain: "zkCoins/v1/PullChallenge" }`. The node stores `(nonce → subject, requested scope, expiry)`; the later proof is bound to exactly that tuple |
| `POST` | `/v1/pull` | body = `{ nonce: <hex32>, expiry: <u64>, proof: OwnershipProofJson \| GrantProofJson }` where `OwnershipProofJson = { type: "ownership", subject: <zk-address>, public_key: <hex32>, nk_commit: <hex32>, signature: <hex64> }` and `GrantProofJson = { type: "grant", grant: <Bech32m zkgrant string>, grantee_pk: <hex32>, signature: <hex64> }` — the [§5.1(a)/(b)](#a-ownership-proof) objects verbatim; `signature` covers `chal = H(domain ‖ nonce ‖ chan_bind ‖ subject ‖ expiry)` ([§5.1](#51-capability-gated-pull)) → **`PullResult`** `{ records: [ { record_id: <hex32>, record_type: "coinproof" \| "self_delivery", transition_kind?: "mint" \| "send" \| "receive", blob_id: <hex32>, occurred_at: <u64> } ], session: <opaque string>, session_expiry: <u64> }` — generic record refs spanning both per-coin `CoinProof` blobs and `SelfDeliveryRecordV1` state records ([§4.2](#42-bundle-delivery)). **`record_type`** (closed, required) discriminates the returned byte body for `GET /v1/record/<record_id>`: `"coinproof"` → canonical `CoinProof` bytes; `"self_delivery"` → canonical `SelfDeliveryRecordV1` bytes. **`transition_kind`** (closed, when present) is the transition class only (`"mint"` \| `"send"` \| `"receive"`) — **not** a body-type tag; required for `record_type = "self_delivery"` (mirrors the SDR's on-wire `record_kind`), optional for `record_type = "coinproof"`. There is **no** free-form `string` and **no** dual-purpose numeric kind that mixes body type with transition class. `blob_id = H(ciphertext)` of the ZBE blob ([§4.2.1](#421-bundle-blob-encryption-zbe-normative)); `occurred_at` is the server's chain-derived first-occurrence time for the record's own nullifier when known, else `0`; **only** a node that has **itself** decrypted/indexed the subject's events under the operational bundle or a still-valid grant **MUST** answer ([§4.5](#45-recovery) step 4) — an opaque replica **MUST** return an empty `records` list (or `404`/`403` policy) rather than invent an ownership→record map; body `expiry` is the challenge expiry from issuance (bound into `chal`) and a body `expiry` that does not equal the stored challenge expiry is capability-invalid; or `401`/`403`/`410` on capability-invalid / scope-exceeded / challenge-expired |
| `GET` | `/v1/record/<record_id>` | the canonical binary of the Private record (`CoinProof` **or** `SelfDeliveryRecordV1`, discriminated by the pull entry's **`record_type`** — `"coinproof"` vs `"self_delivery"`; **not** by `transition_kind`), served **only** within a still-valid [pull session](#pull-session-normative) (`Authorization: Bearer <token>`) for an authorised subject and within its resolved `scope`; binary (canonical §7.1); replaces the CoinProof-only bound of the legacy coin-scoped fetch for state records; `410` on an expired/foreign-channel token; `404` if `record_id` is unknown or outside scope |
| `GET` | `/v1/proof/<coin_id>` | the `CoinProof` for `coin_id`, served **only** within a still-valid [pull session](#pull-session-normative) (presented as `Authorization: Bearer <token>`) for an authorised subject and within its resolved `scope`; binary (canonical §7.1); retained as a coin-scoped convenience over `GET /v1/record/<record_id>`; `410` on an expired/foreign-channel token |
| `GET` | `/v1/account/state` | **ownership-gated** authoritative account-state read (realises the state half of [§6.4](#64-external-interfaces-abstract) `read.account`; kernel `GetAccountState`, [§7.8](#78-kernel-rpc--the-internal-interface-normative)): served **only** within a still-valid [pull session](#pull-session-normative) opened by an **OwnershipProof** (`Authorization: Bearer <token>`; same pull-session pattern as `GET /v1/proof/<coin_id>`). Returns JSON `{ account_state: <hex — serialize(AccountState), §1.7.4>, state_head: <hex32 — ash of the spendable head>, head_record_id?: <hex32 — Private-record locator of the head SelfDeliveryRecordV1 when indexed>, send_counter: <u64>, current_pubkey: <hex32 — Pkᵢ, the key that signs the next transition>, last_nullifier?: { pubkey: <hex32>, r: <hex32> } }` — `send_counter` / `current_pubkey` **MUST** equal the corresponding fields inside `account_state`; `last_nullifier` is the head transition's on-chain nullifier `(Pk, R)` when the account has advanced at least once, else omitted (canonical empty account, [§2.2](#22-proof-types)). **Auth (normative, fail-closed, same split as pull):** missing/invalid bearer (absent `Authorization`, malformed token, or a **grant** session presented here) → `401 unauthorized`; unknown, expired, or `chan_bind`-mismatching session → `410 session_expired`; never collapse expiry/unknown/channel-mismatch into `401` |
| `GET` | `/v1/receipts/stream` | Server-Sent Events: one receipt event per credited coin inside the pull session's stored `subject` + resolved `scope` (ownership **or** grant session; `Authorization: Bearer <token>`; missing/invalid token → `401`, unknown/expired/`chan_bind`-mismatch → `410 session_expired`) — the public front of `kernel.v1` `SubscribeReceipts` ([§7.8](#78-kernel-rpc--the-internal-interface-normative)) and the [§4.9](#49-real-time-push-delivery) push source |

**Open token provenance ([§4.6](#46-data-availability) Class B, [§6.5](#65-issuance--token-standards)):**

| Method | Path | Body / Returns |
|---|---|---|
| `GET` | `/v1/token/<asset_id>/provenance` | **Open — no capability, no authentication** (kernel `GetTokenProvenance`, [§7.8](#78-kernel-rpc--the-internal-interface-normative)). Returns the issuer-originated `IssuanceTerms` preimage the node captured for `asset_id`, in the schema of its `issuance_version`: token standard 1 → `{ asset_id: <hex32>, issuance_version: 1, creator_pubkey: <hex32>, name: <hex — raw `name` bytes; `H(name)` is what binds into `asset_id`, so bytes are returned rather than a JSON string, which cannot round-trip a UTF-8-invalid `name`>, decimals: <u8> }`; token standard 2 → the same plus `{ cap_total: <decimal-string u128>, terms_salt: <hex32> }`. The client **MUST** re-derive `asset_id` from the returned preimage exactly as [Foundations §1.4](#14-identifiers-and-hashes) / [§6.5](#65-issuance--token-standards) mint clause (c) specify — token standard 1: `Hc("AssetId", genesis_tag ‖ creator_pubkey ‖ H(name) ‖ decimals ‖ 1)`; token standard 2: `Hc("AssetIdV2", genesis_tag ‖ creator_pubkey ‖ H(name) ‖ decimals ‖ 2 ‖ cap_total ‖ terms_salt)` — and **MUST** reject a response whose recomputed id ≠ the requested `asset_id`. The response is therefore **self-verifying against the public `asset_id`** and is never trusted on the server's word; a lying holder cannot serve false terms. Returns `404 not_found` when the node holds no terms for `asset_id`. Serving is **best-effort availability, not consensus** — it carries only issuer-originated definition data, **never** any transfer record, holder, amount, or foreign `CoinProof` plaintext ([§4.6](#46-data-availability) Class-B bound) |

`GET /v1/token/<asset_id>/provenance` is the **sole** endpoint in this API that is served fully **unauthenticated and open** outside the Public projection above — no capability, no `OwnershipProof`, and no `GrantProof` ([§4.6](#46-data-availability) Class B) — and uses the existing `200`/`404` status codes, plus `400 malformed_request` for a malformed `asset_id` (not 32-byte hex), introducing no new `machine_code`.

The node computes `chan_bind` from **its own** authoritative hostname/onion key and accepts a proof only if the requester's `chan_bind` matches ([§5.1](#51-capability-gated-pull)); it MUST compare `chal` in constant time, reject a reused or expired `nonce`, and never broaden disclosure beyond `scope`. Bearer view secrets (`zkview`, `zkavk`) and balance attestations are **not** sent to this API — they are applied client-side to blobs fetched from Blossom ([§5.1](#51-capability-gated-pull), [§6.4](#64-external-interfaces-abstract)).

### 7.6 Publisher interface (normative)

An API layer running the `publisher` feature ([§6.1](#61-components-and-responsibilities)) exposes one additional endpoint so spenders can hand it nullifiers to inscribe; it forwards them to a kernel whose publisher part is on, and that kernel does the half-aggregating and inscribing (§3.4, §3.8). The endpoint is **permissionless** — no ownership proof, bearer token, or auth challenge is required; a well-formed request is never answered with `401`/`403` for lack of credentials.

| Method | Path | Body / Returns |
|---|---|---|
| `POST` | `/v1/publish/spendrecord` | body = `{ public_key: <hex32 x-only>, r: <hex32 x-only>, s: <hex32 scalar>, r_prime: <hex32 x-only>, fee_blob_id?: <hex32 — deferred, MUST be absent in v1>, fee_blob_locators?: <string — deferred, MUST be absent in v1>, fee_epk?: <hex32 x-only — deferred, MUST be absent in v1>, block_anchor: { block_hash: <hex32, internal order §1.7.7>, height: <u32> } }` → on success or policy/crypto rejection: **HTTP 200** `{ accepted: bool, reason?: <closed reason>, batch_eta?: <u64> }`; on malformed wire body: **HTTP 400** `{ "error": "malformed_request", "message": "…" }`; on internal failure: **HTTP 500** `{ "error": "internal_error", "message": "…" }` — the transition's on-chain nullifier `(public_key = Pkᵢ, r = Rᵢ)` and its BIP-340 scalar `s = sᵢ`, plus `r_prime = R'`, the spender's **non-secret** pre-tweak sign-to-contract nonce point (symmetric to the `/sign` body of [§7.5](#75-node-rest-api-normative)) that opens the S2C tweak `Rᵢ = R' + H(bytes(R') ‖ H(ProofData))·G`, the fee-coin **ZBE delivery reference** (when present), and the freshness `block_anchor` |

**Fee-coin transport (deferred — not v1; [§3.8.1](#381-fee-coin-mechanism-deferred)).** A v1 node **MUST** reject any request carrying `fee_blob_id`, `fee_epk`, or `fee_blob_locators`, in whole or in part, with `400 malformed_request` and **MUST NOT** fetch, decrypt, or otherwise act on them; the rules below describe the deferred mechanism only. When a fee coin is present ([§7.5](#75-node-rest-api-normative) presence matrix case (b)), the fee `CoinProof` is delivered as an **ordinary ZBE blob encrypted to the publisher's `fee_address` `IVPK`** under the same note-key / ZBE path as every other recipient coin ([§1.3](#13-per-coin-keys-note-encryption--detection), [§4.2](#42-bundle-delivery), [§4.2.1](#421-bundle-blob-encryption-zbe-normative), [§3.8](#38-fees-and-economics) step 3). The publish body carries **only**:

- `fee_blob_id` — `blob_id = H(ciphertext)` of the ZBE-encrypted fee `CoinProof` ([§4.2.1](#421-bundle-blob-encryption-zbe-normative));
- `fee_blob_locators` — **`NIP44Binary(K_tx, "blob-locators", serialize(BlobLocatorSet))`** for that blob's holders ([§1.3](#13-per-coin-keys-note-encryption--detection), [§7.1](#71-serialization-conventions-normative)); conversation key is the same hand-off `K_tx` as the fee coin (re-derived below); the REST field carries the **UTF-8 of the NIP-44 Base64 payload** as a string (never cleartext holder URLs);
- `fee_epk` — a **fresh** per-hand-off ephemeral x-only public key so the publisher kernel re-derives `ss = ECDH(ivk, fee_epk)`, `K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ fee_epk)`, opens `fee_blob_locators` under (`label = "blob-locators"`, variable-length `serialize(BlobLocatorSet)` parse), fetches the ZBE blob, and **decrypts** it.

There is **no** `fee_coinproof` field and **no** other carrier of fee-`CoinProof` plaintext on this endpoint: sending the §7.1 canonical `CoinProof` bytes in the clear over TLS would expose the coin, its proof public inputs / `ProofData`, and `creating_prev_ash` to every TLS terminator, reverse proxy, and CDN on the path (a D-19 linkage regression). The three fee fields are **either all present** (case (b)) **or all absent** (fee-less case (c) / self-publish does not use this endpoint for the fee path); a partial set is **malformed**.

In v1 the fee fields are always absent — publishing is sponsored ([§3.8](#38-fees-and-economics)) — so everything below that is conditioned on their presence describes the deferred mechanism of [§3.8.1](#381-fee-coin-mechanism-deferred) and **MUST NOT** be implemented in v1. The publisher receives **only** the nullifier points/scalars, the fee ZBE delivery reference (when present), and `block_anchor` — no payment- or change-coin plaintext, no spend key, and no visibility into the account's rotation edge (the rotated `next_pubkey` lives only inside the off-chain, hashed account state, [§1.4](#14-identifiers-and-hashes)). The necessary exception is the fee coin itself: after the publisher kernel **decrypts** the ZBE blob with `ivk`, it holds the fee `CoinProof` addressed to its own `fee_address` and verifies that recursive proof and plaintext as part of accepting the hand-off ([§3.8](#38-fees-and-economics), [Risks](/risks)).

**HTTP status discipline (normative).**

| Condition | HTTP | Body |
|---|---|---|
| Wire body violates the normative shape (wrong types/widths, unknown fields that break decoding, partial fee-field set, `block_anchor.height` outside `u32`, non-hex where hex is required, etc.) | **400** | `{ "error": "malformed_request", "message": "…" }` — same §7.5 error-body shape; **no** `{accepted:false}` |
| Body is well-formed but the hand-off is cryptographically or by policy rejected | **200** | `{ accepted: false, reason: <closed reason> }` |
| Hand-off accepted | **200** | `{ accepted: true, batch_eta: <u64> }` |
| Internal publisher failure | **500** | `{ "error": "internal_error", "message": "…" }` |

There is **no** auth-gated rejection code on this permissionless endpoint.

**`reason` (normative, closed enumeration).** Present **only** when HTTP 200 and `accepted == false`. A publisher **MUST** use exactly one of the values below and **MUST NOT** invent additional values (same closed-enumeration discipline as the [§7.5](#75-node-rest-api-normative) `machine_code` set):

| `reason` | Meaning |
|---|---|
| `invalid_signature` | the BIP-340 signature `(Rᵢ, sᵢ)` over the per-network fixed `m_state` under `Pkᵢ` fails ([§3.2](#32-transition-signing-bip-340--sign-to-contract)) |
| `invalid_s2c_opening` | `r_prime = R'` does not open the S2C binding `Rᵢ = R' + t·G` with `t = H(bytes(R') ‖ H(ProofData))` ([§3.2](#32-transition-signing-bip-340--sign-to-contract)) — only applicable when a fee coin is present so `H(ProofData)` is available |
| `invalid_fee_coinproof` | ZBE decryption fails, or the opened fee object is not a valid `CoinProof` under [§7.1](#71-serialization-conventions-normative) / [§2.3.3](#233-receive) verification |
| `fee_address_mismatch` | the opened fee coin's `recipient` is not the publisher's `fee_address` |
| `ocr_mismatch` | the fee coin is not an output under the **same `ocr`** the nullifier's `R'` opens ([§3.8](#38-fees-and-economics)) |
| `fee_too_low` | fee coin amount / asset fails the quoted `fee` / `fee_asset_id` (amount too low under a known asset) |
| `unknown_fee_asset` | fee coin `asset_id` is not the publisher's accepted `fee_asset_id` |
| `policy` | publisher policy declines the hand-off (including a fee-less hand-off the publisher does not accept) |
| `anchor_stale` | `block_anchor` fails the §3.5 bound (not a strict ancestor within the gap rule, or otherwise unusable for intended inclusion) |

`batch_eta` is the number of seconds, as a `u64`, until the publisher's next expected inscription; it is present **only** when `accepted == true`. On the kernel wire (`PublishResult`, [§7.8](#78-kernel-rpc--the-internal-interface-normative)) both `reason` and `batch_eta` are **proto3 `optional`** so presence is distinguishable from the scalar defaults (`""` / `0`); the presence invariants are **iff** the JSON rules above (`reason` present ⇔ `accepted == false`; `batch_eta` present ⇔ `accepted == true`).

**Verification order (normative).** The publisher **MUST**, before accepting a well-formed body — steps 2 and 3 are conditioned on fee fields a v1 request never carries and therefore run only under the deferred mechanism of [§3.8.1](#381-fee-coin-mechanism-deferred):

1. verify the nullifier's BIP-340 signature `(Rᵢ, sᵢ)` over the **per-network fixed** message `m_state` under `Pkᵢ` ([§3.2](#32-transition-signing-bip-340--sign-to-contract)) — fail → `invalid_signature`;
2. when the three fee fields are present: re-derive `K_tx` from `ivk` and `fee_epk`, open `fee_blob_locators` as `NIP44Binary(K_tx, "blob-locators", ·)` and parse `serialize(BlobLocatorSet)` ([§7.1](#71-serialization-conventions-normative)) — fail → `invalid_fee_coinproof`; fetch the ZBE blob by `fee_blob_id` via those holders, **decrypt** it under `K_tx` ([§4.2.1](#421-bundle-blob-encryption-zbe-normative)), and open the fee `CoinProof` — fail → `invalid_fee_coinproof`;
3. when a fee coin was opened: recompute `H(ProofData)` from the fee `CoinProof`'s embedded proof public inputs and check the sign-to-contract binding with `r_prime` — fail → `invalid_s2c_opening`; check `recipient == fee_address` — fail → `fee_address_mismatch`; check `asset_id` / amount against the quoted fee — fail → `unknown_fee_asset` / `fee_too_low`; check the fee coin is under the **same `ocr`** `R'` opens ([§3.8](#38-fees-and-economics)) — fail → `ocr_mismatch`;
4. check `block_anchor` is within the §3.5 bound (a strict ancestor of the intended inclusion block within the gap rule, [§3.5](#35-inscription-format)); `block_anchor.height` values outside the on-chain `u32` range are rejected as malformed (400), not as `anchor_stale` — fail of the bound itself → `anchor_stale`.

When the three fee fields are **absent** — always, in v1 — the fee checks above do not apply and the publisher accepts or declines the hand-off purely by its own policy (`policy` if declined — fee policy is not consensus, [§3.8](#38-fees-and-economics)) — the signature and `block_anchor` checks remain mandatory, while the sign-to-contract opening cannot be checked publisher-side (no fee `CoinProof` means no `H(ProofData)` source) and is verified downstream by every receiver ([§2.3.3 step 4](#233-receive)); this is the hand-off shape of a pure receive or an unpaid mint ([§7.5](#75-node-rest-api-normative) presence matrix case (c)), and self-publish ([§3.4](#34-the-publisher)) needs no fee at all. On acceptance the publisher **half-aggregates** the nullifier's signature with others it has collected ([§3.3](#33-half-aggregation)) — no recursive proof, no secret keys — and inscribes the resulting **`AggregateStateNullifierV3`** ([§3.3](#33-half-aggregation), [§3.5](#35-inscription-format)) on Bitcoin; every node then folds each `Pkⱼ` into the accumulator by first-occurrence ([§3.6](#36-chain-scanning)). A publisher is permissionless and contention-free: any node MAY run this endpoint, and a wallet MAY point at its own node as publisher (self-publish, §3.4).

### 7.7 Wallet ↔ node bootstrapping (normative)

A wallet is configured with **one** node base URL (and MAY hold several for the multi-node fan-out of [§6.3](#63-node-portability-and-multi-node-operation)). From `/v1/info` it learns the network, the pinned `circuit_digests` (which it MUST check against its own pinned constants before trusting any proof the node returns), the pinned `bootstrap_pubkey` under which it **MUST** verify the bootstrap manifest, that node's relay and Blossom URLs, the protocol bounds, and the per-network **bootstrap manifest** (seed relays, blob stores, operator trust-list IDs — global infrastructure only, [§4.3](#43-addressing-for-delivery)). The wallet derives all keys from the seed under the dense account assignment of [§1.2](#12-key-hierarchy); it entrusts its **own** node with the operational bundle `{ivk, ovk, op, nk, op_secret}` over the authenticated channel defined below and issues a scoped `zkgrant` to any **foreign** node ([§5.2](#52-view-grant)). Switching nodes is a configuration change with no migration of value-bearing state ([§6.3](#63-node-portability-and-multi-node-operation)): every value-bearing object is either seed-derivable or fetchable, content-addressed and verifiable, from the network's seed-discoverable holders ([§4.3](#43-addressing-for-delivery); recovery needs a reachable node for the manifest, ≥1 live holder per plane (a `seed_relay` for the event and a `blob_store` for the blob), and manifest rotation that preserved recovery-discoverability ([§4.3](#43-addressing-for-delivery)), [§4.10](#410-responsibility-boundaries-and-the-availability-model-normative)). Non-value-bearing state follows the explicit §6.3 portability residuals.

**Operational bundle wire encoding (normative).** The entrusted bundle is a fixed 161-byte string, in the [§1.2](#12-key-hierarchy) field order:

```
serialize(OperationalBundle) := version (1 byte, = 0x01) ‖ ivk (32B) ‖ ovk (32B) ‖ op (32B) ‖ nk (32B) ‖ op_secret (32B)
```

Each of the five secrets is a 256-bit scalar ([§1.7.3](#173-fixed-widths)); a node MUST reject an unrecognised `version` byte.

**Bootstrap endpoints (normative).** A wallet entrusts and revokes the bundle at its own node's base URL, gated by proof of the account's `sk₀` — the same **ownership proof** already defined for the [§5.1](#51-capability-gated-pull) pull endpoint, so no new authentication primitive is introduced:

| Method | Path | Body / Returns |
|---|---|---|
| `POST` | `/v1/bootstrap/challenge` | body = `{ subject: address, action: "entrust" \| "revoke" }` → `{ nonce, expiry, domain }` (§5.1 `Challenge` shape) — `domain = "zkCoins/v1/EntrustChallenge"` or `"zkCoins/v1/RevokeChallenge"` per `action`, distinct from the [§5.1](#51-capability-gated-pull) `"zkCoins/v1/PullChallenge"` domain so a proof issued for one purpose cannot be replayed for another |
| `POST` | `/v1/bootstrap/entrust` | body = `{ challenge: { nonce: <hex32>, expiry: <u64> }, ownership_proof: OwnershipProofJson, bundle: <hex322> }` → `{ accepted: bool }` — `challenge` is `{ nonce: <hex32>, expiry: <u64> }` (the node looks up subject/action it stored at issuance; `expiry` is taken from the body and **MUST** equal the stored value — a mismatch is rejected as a recomputed-`chal` mismatch under [§5.1](#51-capability-gated-pull), which the [§7.5](#75-node-rest-api-normative) error table maps to `401 unauthorized`); `ownership_proof` is the [§7.5](#75-node-rest-api-normative) `OwnershipProofJson` shape verbatim (the [§5.1(a)](#a-ownership-proof) `OwnershipProof` over `chal = H(domain ‖ nonce ‖ chan_bind ‖ subject ‖ expiry)` under the `"zkCoins/v1/EntrustChallenge"` domain); `bundle` is the 161-byte `serialize(OperationalBundle)` as lowercase hex (`<hex322>`, §7.1), carried over the transport already mandatory for this API (TLS 1.3/1.2 or Tor v3, [§7.5](#75-node-rest-api-normative)) — no additional application-layer encryption is layered on top, matching every other sensitive body this API already carries under that same transport guarantee |
| `POST` | `/v1/bootstrap/revoke` | body = `{ challenge: { nonce: <hex32>, expiry: <u64> }, ownership_proof: OwnershipProofJson }` → `{ revoked: bool }` — `challenge` is `{ nonce: <hex32>, expiry: <u64> }` (the node looks up subject/action it stored at issuance; `expiry` is taken from the body and **MUST** equal the stored value — a mismatch is rejected as a recomputed-`chal` mismatch under [§5.1](#51-capability-gated-pull), which the [§7.5](#75-node-rest-api-normative) error table maps to `401 unauthorized`); `ownership_proof` is the [§7.5](#75-node-rest-api-normative) `OwnershipProofJson` shape verbatim, under the `"zkCoins/v1/RevokeChallenge"` domain |

A node MUST verify `chan_bind` and `chal` for these two endpoints exactly as [§5.1](#51-capability-gated-pull) requires for a pull `OwnershipProof` — constant-time comparison, single-use `nonce`, `expiry` enforced — before accepting an entrust or revoke request.

**Fail-closed revocation.** On a verified `/v1/bootstrap/revoke`, a node MUST (1) immediately and permanently **cease all use** of the bundle for any further proving, discovery, decryption, or serving on the subject's behalf, and (2) mark the stored copy of `{ivk, ovk, op, nk, op_secret}` as revoked for use — **without** deleting the stored data (Data Permanence, [§4.8](#48-durability--the-store-everything-invariant)). As with view-grant revocation ([§5.2](#52-view-grant)), this binds only a node the subject still controls and can still reach: it stops *that* node's future use, but — like any already-disclosed secret — it **cannot** compel a node that has gone rogue, been compromised, or already exfiltrated the bundle to honour the cease-use, and it does **not** undo any plaintext that node already observed. None of `ivk`/`ovk`/`op`/`nk`/`op_secret` can be rotated independently of the account `A` they are derived under ([§1.2](#12-key-hierarchy)); a subject who suspects the bundle itself is compromised, rather than merely switching operators, MUST move to a new account to regain confidentiality of future activity.

### 7.8 Kernel RPC — the internal interface (normative)

[§6.1](#61-components-and-responsibilities) splits the node along one seam: a trustless **kernel** that exposes a typed **RPC inward**, and an optional **API layer** that exposes the public REST surface of §7.5 **outward** on top of it. This section fixes the inward boundary. Where §7.5 is the *public* contract a wallet, SDK, or explorer speaks, the kernel RPC is the *internal* contract the API layer consumes; the kernel serves no REST at all, so that boundary is always a real RPC call.

**Transport.** The kernel RPC is **gRPC** over a versioned Protocol-Buffers contract (package `kernel.v1`), with generated clients for the kernel (Rust) and any API-layer language. It is reached over a **private, operator-internal** channel only — loopback, a private container network, or mTLS between the API and kernel containers — and is **never** exposed to the public internet; only the §7.5 REST surface is public. A breaking change is a new package version (`kernel.v2`), never a silent change to `kernel.v1` (mirroring the §7.5 `/v1/` rule). The contract is parameterised by the same network tag as the circuits (§2.5, [§1.7.9](#179-proof-system-parameters-normative)), so a client and kernel on different networks cannot interoperate.

**Trust at this boundary.** The kernel RPC is a **trusted, server-to-server** channel *inside one operator's deployment*; it is deliberately **not** capability-gated the way §7.5 is. Public authorisation — ownership-proof challenges, `zkgrant` view grants, rate-limiting, idempotency, and optional NIP-05 name hosting — is the **API layer's** responsibility (§7.5, [§5.1](#51-capability-gated-pull)); the kernel trusts its caller for *access*, never for *correctness*. The custody and soundness invariants of [§6.1](#61-components-and-responsibilities) and [§6.6](#66-threat-model-and-trust-configurations) hold regardless of the caller: the kernel never holds a SPEND-branch key, never accepts a proof it has not verified, and is the **sole writer and reader** of the value-bearing store ([§4.8](#48-durability--the-store-everything-invariant)). A faulty or malicious API layer can refuse or lie to *its own users* — a liveness/privacy failure for them, identical to relying on a dishonest foreign node ([§6.6](#66-threat-model-and-trust-configurations)) — but **cannot** make the kernel forge, steal, or double-spend.

**Who enforces the capability gate.** The "a request without a valid ownership proof or view grant **MUST** be rejected" rule of [§5.1](#51-capability-gated-pull)/[§6.4](#64-external-interfaces-abstract) binds to the **API layer**, the component that terminates every public endpoint. It performs the §5.1 challenge–response, **including the `chan_bind` host/onion-key binding, which MUST be computed from the public host it authoritatively serves and MUST NOT be re-derived by the kernel from forwarded request metadata** (a forwarded `Host` header is attacker-influenceable, the §5.1 footgun). `OpenPullChallenge` is what issues the nonce a caller needs in order to authorise at all, so the API **MUST** be able to invoke it for an as-yet-unauthorised caller, subject to its own rate limiting and request validation; it invokes `Pull`/`GetRecord`/`GetCoinProof`/`GetAccountState` only for a caller whose response to that challenge has **already been verified** (`GetAccountState` additionally requires an **ownership** session — a grant session is rejected as `unauthorized` upstream); the kernel's pull procedures release records to that caller and do not re-run the capability gate (in the monolith the same code path runs both).

**Redeem-body `expiry` (normative).** Every challenge redeem carries the challenge `expiry` the node returned at issuance (`POST /v1/pull` as a top-level field beside `nonce`; `POST /v1/attest/balance`, `POST /v1/grants`, `POST /v1/bootstrap/entrust`, and `POST /v1/bootstrap/revoke` inside `challenge`). The API layer **MUST** reconstruct `chal` — including that `expiry` — and verify the OwnershipProof or GrantProof **before** consuming the nonce, and it **MUST NOT** need a local challenge store to do so: the store lives with the kernel, and a two-process deployment keeps the API layer stateless ([§6.1](#61-components-and-responsibilities), [§7.5](#75-node-rest-api-normative)). Body `expiry` is **not** trusted input: it is bound into `chal` and therefore into the signature, so a forged or altered value yields a different `chal` and **MUST** fail verification under the same code this document assigns a `chal` mismatch (`401 unauthorized` on the public REST surface). An implementer that **does** hold a challenge store (including the monolith) **MUST** still require the body `expiry` to equal the stored value and **MUST** reject a mismatch under that same code — never silently prefer the stored value over the body. This keeps a single reading of the field across monolith and split deployments. Nothing else about the challenge–response is relaxed: the nonce remains single-use, the domain remains action-bound, `chan_bind` remains server-side, and a `GrantProof` remains rejected where only owner auth is accepted.

**Procedures.** `service Kernel` (package `kernel.v1`); each procedure backs the §7.5/§7.6 REST endpoint in the last column. The complete normative contract follows the table.

| Procedure | Kind | Purpose | Backs |
|---|---|---|---|
| `GetInfo` | unary | network, `protocol_version`, `circuit_digests`, `bootstrap_pubkey`, finality + bounds, `features`, sync/`ready` (+ `ready_reason` when not ready) | `GET /v1/info`, `/health/ready` |
| `GetAccumulator` | unary | current `{ size, root, tip_block_hash, tip_height }` | `GET /v1/chain/accumulator` |
| `ListInscriptions` | server-stream | zkCoins nullifier inscriptions from a `(height, tx_index, vin_index)` cursor (paginated; defaults `from_height=0`, `from_tx_index=0`, `from_vin_index=0`, `limit=100`) | `GET /v1/chain/inscriptions` |
| `GetNullifierPath` | unary | Path-B answer for an account-state key `Pkᵢ`: RFC-6962 **inclusion** when present, else unauthenticated local-index absence (`present: false` — not an RFC-6962 non-inclusion proof; [§3.7](#37-the-nullifier-accumulator)) | `GET /v1/chain/nullifier/<pubkey>` |
| `SubmitTransition` | unary | accept a transition intent, start a proving job → `job_id` | `POST /v1/tx` |
| `GetJob` | unary | job-status snapshot | `GET /v1/jobs/<id>` |
| `StreamJob` | server-stream | one event per phase change, terminal `complete`/`error` | `GET /v1/jobs/<id>/stream` |
| `SignTransition` | unary | deliver the wallet's BIP-340 transition signature for the `awaiting_signature` phase | `POST /v1/jobs/<id>/sign` |
| `CancelJob` | unary | cancel a not-yet-published job | `POST /v1/jobs/<id>/cancel` |
| `OpenPullChallenge` | unary | issue a pull nonce for a subject + scope | `POST /v1/pull/challenge` |
| `Pull` | unary | release Private record refs for a verified ownership proof / grant (local decrypt-index only, [§4.5](#45-recovery)) | `POST /v1/pull` |
| `GetRecord` | unary | one Private record (`CoinProof` or `SelfDeliveryRecordV1`) within a valid [pull session](#pull-session-normative) | `GET /v1/record/<record_id>` |
| `GetCoinProof` | unary | one `CoinProof` within a valid [pull session](#pull-session-normative) ([§5.1](#51-capability-gated-pull)); coin-scoped convenience over `GetRecord` | `GET /v1/proof/<coin_id>` |
| `GetAccountState` | unary | authoritative current `AccountState` (canonical bytes + head locator + `send_counter` / `current_pubkey` + last state-nullifier) within a valid **ownership** [pull session](#pull-session-normative) | `GET /v1/account/state` |
| `SubscribeReceipts` | server-stream | verified-receipt events for the pull session's stored subject + resolved scope as coins are credited — the §4.9 push source | `GET /v1/receipts/stream` (§7.5); the §4.9 push source |
| `Publish` | unary | hand a nullifier `(Pkᵢ, Rᵢ, sᵢ, R')` + optional fee ZBE delivery (`fee_blob_id` / `fee_epk` / `fee_blob_locators`) to the publisher role, if enabled | `POST /v1/publish/spendrecord` (§7.6) |
| `EntrustOperationalBundle` | unary | store the §7.7 operational bundle for an already-authorised subject (the API layer runs the §5.1 gate) | `POST /v1/bootstrap/entrust` |
| `RevokeOperationalBundle` | unary | fail-closed cease-use; retain the bundle, marked revoked, for an already-authorised subject | `POST /v1/bootstrap/revoke` |
| `AttestBalance` | unary | start a `C_balance` proving job for a balance attestation for an already-authorised **owner** (the API layer runs the action-bound OwnershipProof gate of [§5.1](#51-capability-gated-pull)/[§7.5](#75-node-rest-api-normative); GrantProof **MUST** be rejected upstream) | `POST /v1/attest/balance` |
| `IssueViewGrant` | unary | sign a [§5.2](#52-view-grant) grant with the account's `op` key for an already-authorised **owner** (API-layer OwnershipProof gate; **no-escalation** — a grant delegate must not reach this procedure) | `POST /v1/grants` |
| `GetTokenProvenance` | unary | issuer-originated `IssuanceTerms` for an `asset_id` the node has captured (open — the API layer runs **no** capability gate for this one; [§4.6](#46-data-availability) Class B) | `GET /v1/token/<asset_id>/provenance` (§7.5) |

**`kernel.v1` message contract (normative).** The following Protocol-Buffers definition is the complete, normative `kernel.v1` contract. Conventions: every 32-byte protocol value is `bytes` and its length **MUST** be exactly 32 (a violation is `INVALID_ARGUMENT`); `block_anchor.height` is `uint32`, matching the on-chain 4-byte field ([§1.7.3](#173-fixed-widths)) — a value outside `[0, 2^32−1]` is `INVALID_ARGUMENT`; `u128` amounts are decimal strings (mirroring [§7.1](#71-serialization-conventions-normative)); timestamps are `uint64` Unix seconds; enumerated states use the literal §7.5 strings. The API layer performs the entire §5.1 capability gate ([§7.8 *Who enforces the capability gate*](#78-kernel-rpc--the-internal-interface-normative)); the kernel receives `chan_bind` only as an **opaque 32-byte equality token** to bind sessions — it never derives or interprets it.

```proto
syntax = "proto3";
package kernel.v1;

service Kernel {
  rpc GetInfo(GetInfoRequest) returns (Info);
  rpc GetAccumulator(GetAccumulatorRequest) returns (AccumulatorTip);
  rpc ListInscriptions(ListInscriptionsRequest) returns (stream Inscription);
  rpc GetNullifierPath(NullifierPathRequest) returns (NullifierPath);
  rpc SubmitTransition(TransitionRequest) returns (JobHandle);
  rpc GetJob(JobRequest) returns (Job);
  rpc StreamJob(JobRequest) returns (stream JobEvent);
  rpc SignTransition(SignRequest) returns (Job);
  rpc CancelJob(JobRequest) returns (Job);
  rpc OpenPullChallenge(PullChallengeRequest) returns (Challenge);
  rpc Pull(PullRequest) returns (PullResult);
  rpc GetRecord(RecordRequest) returns (RecordBlob);
  rpc GetCoinProof(CoinProofRequest) returns (CoinProofBlob);
  rpc GetAccountState(AccountStateRequest) returns (AccountStateResult);
  rpc SubscribeReceipts(SubscribeReceiptsRequest) returns (stream Receipt);
  rpc Publish(PublishRequest) returns (PublishResult);
  rpc EntrustOperationalBundle(EntrustRequest) returns (EntrustResult);
  rpc RevokeOperationalBundle(RevokeRequest) returns (RevokeResult);
  rpc AttestBalance(AttestRequest) returns (JobHandle);
  rpc IssueViewGrant(GrantRequest) returns (GrantResult);
  rpc GetTokenProvenance(GetTokenProvenanceRequest) returns (TokenProvenance);
}

message GetInfoRequest {}
message Info {
  string network = 1;                      // exactly one of "mainnet" | "testnet" | "regtest" — 1:1 to the §2.2 tags
                                           //   (Bitcoin network is pinned 1:1 to this tag; no separate bitcoin_network field)
  reserved 2;                              // was bitcoin_network; removed (v1: bitcoin_network == network always)
  string protocol_version = 3;             // "v1"
  map<string, bytes> circuit_digests = 4;  // {"C": 32B, "C_balance": 32B} (§1.7.9)
  string relay_url = 5;
  string blossom_url = 6;
  uint32 finality_confirmations = 7;       // 6 (§3.9)
  uint32 max_tx_inputs = 8;                // §2.5 bounds
  uint32 max_tx_outputs = 9;
  uint32 max_rx_coins = 10;
  uint32 max_account_assets = 11;
  bool ready = 12;                         // backs /health/ready
  uint64 bitcoin_tip_height = 13;
  bytes accumulator_root = 14; // = nav_root (§3.7)
  uint64 scanner_lag = 15;
  uint64 max_blob_bytes = 16;              // §7.4 Blossom advertised size limit
  uint64 activation_height = 17;           // pinned per-network scan origin (§3.6)
  BootstrapManifest bootstrap = 18;        // §4.3 global infrastructure only
  repeated string kernel_parts = 19;       // which kernel parts this kernel runs: each ∈
                                           //   {"scanner","prover","publisher"}. NOT the §7.5 /v1/info
                                           //   `features` array — that is API-layer configuration the API
                                           //   owns and constructs itself, and the kernel cannot know it.
  optional string ready_reason = 20;       // set iff ready == false; closed set (§7.5 /health/ready):
                                           //   "syncing" | "scanner_lag" | "circuit_mismatch" | "deep_reorg"
                                           //   | "dependency_unavailable"
  bytes bootstrap_pubkey = 21;             // 32B x-only; pinned network-parameter trust anchor for BootstrapManifest (§3.6, §4.3)
}
message BootstrapManifest {
  string network = 1;
  string protocol_version = 2;             // "v1"
  repeated string seed_relays = 3;
  repeated string blob_stores = 4;
  repeated bytes operator_ids = 5;         // 32B x-only each
  uint64 issued_at = 6;
  uint64 expires_at = 7;
  bytes manifest_sig = 8;                  // 64B BIP-340
}

message GetAccumulatorRequest {}
message AccumulatorTip { bytes root = 1; bytes tip_block_hash = 2; uint64 tip_height = 3; uint64 size = 4; } // root = nav_root = Hc("NfLog/Root", size ‖ mth) (§3.7)

message ListInscriptionsRequest {
  // Defaults (API-normalised before RPC when the REST query omits them, §7.5): from_height = 0,
  //   from_tx_index = 0, from_vin_index = 0, limit = 100. Valid limit ∈ 1..1000; 0 or >1000 →
  //   INVALID_ARGUMENT / HTTP 400 bounds_exceeded.
  // Proto3: optional so absence is distinguishable from zero; a caller that sets limit = 0 is rejected.
  // Inclusive lexicographic lower bound on (height, tx_index, vin_index); REST response carries
  //   next_height + next_tx_index + next_vin_index as the exclusive triple-cursor (§7.5) — all three
  //   together or all three absent. The kernel stream itself yields Inscription messages in stable
  //   (height, tx_index, vin_index) sort order (then §3.6 payload-member order inside one inscription).
  optional uint64 from_height = 1;
  optional uint32 limit = 2;
  optional uint64 from_tx_index = 3;
  optional uint64 from_vin_index = 4;
}
message Nullifier {
  bytes pubkey = 1;                        // Pkⱼ, §3.1
  bytes r = 2;                             // Rⱼ, §3.1
  string state = 3;                        // §3.10 per-member: "completed" | "pending" | "failed"
}
message Inscription {
  bytes txid = 1;                          // internal byte order (§1.7.7)
  uint64 height = 2;
  uint32 count = 3;
  uint32 format = 4;                       // 0x00 raw | 0x01 half-aggregated (§3.5)
  repeated Nullifier nullifiers = 5;       // each element carries its own state (§7.5)
  string confirmation_state = 6;           // reveal-tx confirmation only: "pending" | "completed"
                                           //   (never "failed"; not a top-level §3.10 aggregate state)
  uint64 tx_index = 7;                     // reveal-tx index within the block
  uint64 vin_index = 8;                    // reveal-input index within the tx; with height+tx_index
                                           //   forms the triple sort/cursor key (§3.6, §7.5)
}

message NullifierPathRequest { bytes pubkey = 1; }
message NullifierPath {
  bytes root = 1; uint64 tip_height = 2; bool present = 3;
  bytes leaf = 4;                          // Rᵢ when present, else empty
  uint64 position = 5;                     // log position p when present
  repeated bytes audit_path = 6;           // ≤ 64 × 32B RFC-6962 inclusion audit path when present
                                           //   (§1.7.6, §3.7); empty when present == false
  uint64 tree_size = 7;                    // log size against which an inclusion proof is stated
  bytes tip_block_hash = 8;                // 32B, internal order (§1.7.7)
  // present == false is an unauthenticated local-index absence answer, NOT an RFC-6962
  //   non-inclusion proof; MUST NOT back a credit (§3.7 Path B).
}

message OutputTemplate {
  string recipient = 1;
  bytes asset_id = 2;
  string amount = 3;
  DeliveryCredential delivery = 4;         // required for every non-self output; absent on
                                           //   self-outputs (§7.5 presence rule). Verification
                                           //   is kernel-only (§6.1, §7.5); the API forwards
                                           //   the field unchanged and MUST NOT mark it verified.
}
// Closed tagged union matching §7.5 DeliveryCredential. Exactly one arm is set;
// any other shape is malformed_request. The two variants have separate, complete
// check-lists (§7.5): invoice runs the three §4.3 Invoice checks plus byte-exact
// equality of recipient/asset_id/amount with this OutputTemplate; profile runs the
// §4.3 profile chain plus zkcoins.address == output.recipient (amount and asset
// are not compared — a profile is an addressing credential, not a payment
// authorisation). This field is a §1.7.8 between-step-3-and-step-7 wire addition
// (neither circuit nor pinned vector nor digest).
message DeliveryCredential {
  oneof body {
    Invoice invoice = 1;                   // type "invoice" — full §1.5 / §4.3 Invoice
    Kind0Event profile_event = 2;          // type "profile" — full canonical kind-0 event
  }
}
message Invoice {
  string amount = 1;
  string recipient = 2;                    // zk-address (Bech32m string)
  bytes asset_id = 3;
  string memo = 4;                         // empty when absent
  bytes pk0 = 5;                           // 32B x-only
  bytes nk_commit = 6;                     // 32B
  bytes ivpk = 7;                          // 32B
  bytes op_pubkey = 8;                     // 32B x-only
  repeated string relays = 9;
  bytes addr_sig = 10;                     // 64B BIP-340 under pk0
  bytes sig = 11;                          // 64B BIP-340 under op_pubkey
}
message Kind0Event {
  bytes id = 1;                            // 32B event id
  bytes pubkey = 2;                        // 32B author (op_pubkey)
  uint64 created_at = 3;
  uint32 kind = 4;                         // MUST be 0
  string tags_json = 5;                    // canonical JSON array of tags (NIP-01; typically [])
  string content = 6;                      // JSON content carrying the zkcoins object
  bytes sig = 7;                           // 64B Nostr event signature under author
}
message Issuance {
  string name = 1; uint32 decimals = 2; uint32 issuance_version = 3;
  string amount = 4;
  string cap_total = 5;                    // set iff issuance_version == 2
  bytes terms_salt = 6;                    // set iff issuance_version == 2
  bytes creator_pubkey = 7;                // Pk₀ (32B x-only); required — binds into asset_id (§6.5)
}
message TransitionRequest {
  string kind = 1;                         // "mint" | "send" | "receive"
  string subject = 2;                      // zk-address (Bech32m string)
  bytes next_pubkey = 3;
  bytes npk_rand = 11;                     // 32 unmodified CSPRNG bytes per attempt (§2.1 clause 2)
  repeated bytes input_coins = 4;
  repeated OutputTemplate output_templates = 5;
  bytes publisher_pubkey = 6;              // empty ⇒ self-publish (case a); set ⇒ case (b) or (c)
  string fee_address = 7;                  // deferred (§3.8.1): MUST be empty in v1 (§7.5 matrix cases (a)/(c))
  repeated bytes fold_coin_ids = 8;
  bytes genesis_pubkey = 12;               // recipient's Pk₀ (32B x-only); required for a genesis receive, absent otherwise (§2.3.3)
  Issuance issuance = 9;
  string idempotency_key = 10;             // §7.5 Idempotency-Key pass-through
}

message JobHandle { string job_id = 1; string status = 2; }
message JobRequest { string job_id = 1; }
message AwaitingSignature {
  bytes new_account_state_hash = 1; bytes output_coins_root = 2;
  bytes input_nullifiers_root = 3; bytes coin_history_root = 4;
  bytes nav_commitment = 5; bytes npk_commit = 6;
  bytes proof_data_hash = 7;    // §7.5 awaiting_signature shape
  bytes txn_pubkey = 8;         // Pkᵢ (x-only); MUST equal prev_account_state.current_pubkey
  uint64 send_counter = 9;      // entry counter i; skᵢ = A/0'/i' (§1.2, §7.5)
}
message JobResult {
  bytes new_account_state_hash = 1; bytes output_coins_root = 2;
  bytes input_nullifiers_root = 3; repeated bytes output_coin_ids = 4;
  bytes publisher_pubkey = 5;              // set for every externally published kind (b)/(c); empty on self-publish (§7.5)
  bytes attestation = 6;                   // set only for attest jobs (§5.7 BalanceAttestation bytes)
}
message JobError { string error = 1; string message = 2; }          // §7.5 machine_code shape
message Job {
  string job_id = 1; string kind = 2; string status = 3;
  string phase = 4;                           // optional non-stable diagnostic [a-z0-9_]{1,64} (§7.5);
                                              //   empty when absent / in terminal status; clients dispatch on status only
  float progress = 5;
  AwaitingSignature awaiting_signature = 6;   // set only while status == "awaiting_signature"
  JobResult result = 7;                       // set only once status == "completed"
  JobError error = 8;                         // set only once status ∈ {"failed","cancelled"}
}
message JobEvent { string event = 1; Job job = 2; }                 // event: "phase"|"complete"|"error"
message SignRequest { string job_id = 1; bytes signature = 2; bytes s2c_nonce = 3; }  // signature length MUST be 64, s2c_nonce length MUST be 32 (INVALID_ARGUMENT otherwise)

message Scope {                              // §5.1 scope; all_assets=true ⇔ asset_ids "*"
  repeated bytes asset_ids = 1; bool all_assets = 2;
  uint64 not_before = 3; uint64 not_after = 4;
  // INVARIANT: exactly one of all_assets == true (⇔ asset_ids empty) or a non-empty asset_ids
  //   MUST hold; all_assets == false with empty asset_ids is INVALID_ARGUMENT.
  // UNBOUNDED SENTINELS (identical to the §5.1 JSON scope — single pair, no Proto-only zero
  //   convention): not_before = 0 means no lower bound; not_after = 2⁶³−1
  //   (9223372036854775807) means no upper bound. Proto3 scalar default 0 is therefore
  //   correct for not_before but **MUST NOT** be read as unbounded for not_after — a bare
  //   not_after = 0 is a closed window ending at the epoch. The API layer normalises omitted
  //   JSON fields to these sentinels before the RPC (§5.1, §7.5).
}
message PullChallengeRequest {
  string subject = 1; Scope requested_scope = 2;
  string action = 3;                        // "" (pull) | "entrust" | "revoke" (§7.7 domains)
                                            //   | "attest_balance" | "issue_grant" (§7.5 action-bound
                                            //   OwnershipProof domains; scope unused for those two)
}
message Challenge { bytes nonce = 1; uint64 expiry = 2; string domain = 3; }
message PullRequest {
  bytes nonce = 1;                          // consumes the §5.1 challenge (single use)
  string subject = 2;                       // the subject the API layer authenticated
  Scope resolved_scope = 3;                 // the already-intersected scope (§5.1) — the kernel
                                            //   trusts the API layer for ACCESS, never widens
  bytes chan_bind = 4;                      // opaque 32B equality token for session binding (§5.1)
  string authority = 5;                     // closed: "ownership" | "grant"; which capability the API layer
                                            //   verified at §5.1 — the kernel records it on the session so
                                            //   GetAccountState can admit ownership only; retires the
                                            //   x-zkcoins-session-authority metadata key
}
message RecordRef {
  bytes record_id = 1;                     // opaque 32B id of this Private record
  string record_type = 2;                  // closed: "coinproof" | "self_delivery" — body-type discriminator (§7.5)
  string transition_kind = 3;              // closed: "mint" | "send" | "receive"; required for self_delivery;
                                           //   optional (empty) for coinproof — NOT a body-type tag
  bytes blob_id = 4;                       // H(ciphertext), §4.2.1
  uint64 occurred_at = 5;                  // first-occurrence-derived; 0 if unknown
}
message PullResult { repeated RecordRef records = 1; string session = 2; uint64 session_expiry = 3; }
message RecordRequest { bytes record_id = 1; string session = 2; bytes chan_bind = 3; }
message RecordBlob {
  bytes canonical = 1;                     // §7.1 CoinProof or SelfDeliveryRecordV1 bytes
  string record_type = 2;                  // closed: "coinproof" | "self_delivery" — discriminates canonical
  string transition_kind = 3;              // closed: "mint" | "send" | "receive"; required for self_delivery;
                                           //   optional (empty) for coinproof
}
message CoinProofRequest { bytes coin_id = 1; string session = 2; bytes chan_bind = 3; }
message CoinProofBlob { bytes canonical = 1; }                      // the §7.1 canonical CoinProof bundle bytes

// ownership pull session only — grant sessions are UNAUTHENTICATED/unauthorized (§7.5)
message AccountStateRequest { string session = 1; bytes chan_bind = 2; }
message AccountStateResult {
  bytes account_state = 1;                 // serialize(AccountState), §1.7.4
  bytes state_head = 2;                    // ash of the spendable head (32B)
  bytes head_record_id = 3;                // 32B Private-record locator; empty if not indexed
  uint64 send_counter = 4;                 // MUST equal AccountState.send_counter
  bytes current_pubkey = 5;                // Pkᵢ (32B x-only); MUST equal AccountState.current_pubkey
  bytes last_nullifier_pk = 6;             // 32B; empty iff no prior state-advancing transition
  bytes last_nullifier_r = 7;              // 32B; empty iff last_nullifier_pk empty
}

// session + chan_bind only — subject/scope come from the server-side pull-session state
// (ownership or grant), never from a client-supplied subject field (analogous to CoinProofRequest)
message SubscribeReceiptsRequest { string session = 1; bytes chan_bind = 2; }
message Receipt {
  bytes coin_id = 1; bytes asset_id = 2; string amount = 3;
  string state = 4;                         // §3.10 state at emission
  uint64 credited_at = 5;
}

message BlockAnchor { bytes block_hash = 1; uint32 height = 2; }    // hash internal order (§1.7.7); height matches the on-chain u32 (§1.7.3)
message PublishRequest {
  bytes public_key = 1; bytes r = 2; bytes s = 3; bytes r_prime = 4;
  bytes fee_blob_id = 5;                    // 32B; deferred (§3.8.1): MUST be empty in v1 ⇒ fee-less (§7.6)
  BlockAnchor block_anchor = 6;
  bytes fee_epk = 7;                        // 32B x-only; empty iff fee_blob_id empty; fresh per hand-off
  bytes fee_blob_locators = 8;              // UTF-8 of NIP44Binary(K_tx, "blob-locators", serialize(BlobLocatorSet)); empty iff fee_blob_id empty
}
message PublishResult {
  bool accepted = 1;
  optional string reason = 2;               // present iff accepted == false; closed set (§7.6):
                                            //   "invalid_signature" | "invalid_s2c_opening" | "invalid_fee_coinproof"
                                            //   | "fee_address_mismatch" | "ocr_mismatch" | "fee_too_low"
                                            //   | "unknown_fee_asset" | "policy" | "anchor_stale"
                                            //   (proto3 optional: absence ≠ empty string)
  optional uint64 batch_eta = 3;            // seconds to next inscription; present iff accepted == true
                                            //   (proto3 optional: absence ≠ 0)
}
message EntrustRequest { bytes nonce = 1; string subject = 2; bytes bundle = 3; bytes chan_bind = 4; }   // bundle = the 161-byte §7.7 serialization
message EntrustResult { bool accepted = 1; }
message RevokeRequest { bytes nonce = 1; string subject = 2; bytes chan_bind = 3; }
message RevokeResult { bool revoked = 1; }  // §7.7 fail-closed revocation: cease all use of {ivk, ovk, op, nk, op_secret} (no deletion — Data Permanence)
// API layer has already verified the action-bound OwnershipProof (§5.1 / §7.5); kernel trusts
// the caller for ACCESS and consumes the single-use nonce for audit/idempotency of the gate
message AttestRequest {
  string subject = 1; bytes asset_id = 2;
  bytes nav_ceiling = 3;                    // 32B nav_root; empty ⇒ node's current size_final
  uint64 size_ceiling = 4;                  // 0 ⇒ derive from size_final
  bytes nonce = 5;                          // consumes the AttestBalanceChallenge (single use)
  bytes chan_bind = 6;                      // opaque 32B equality token (§5.1)
}
message GrantRequest {
  string subject = 1; bytes grantee_pk = 2; Scope scope = 3; uint64 expiry = 4;
  bytes nonce = 5;                          // consumes the IssueGrantChallenge (single use)
  bytes chan_bind = 6;                      // opaque 32B equality token (§5.1)
}
message GrantResult { string grant = 1; }
message GetTokenProvenanceRequest { bytes asset_id = 1; }  // asset_id length MUST be exactly 32 (INVALID_ARGUMENT otherwise)
message TokenProvenance {
  // returned only when the node holds captured IssuanceTerms for asset_id; otherwise
  //   NOT_FOUND (API maps to 404 not_found, §7.5)
  uint32 issuance_version = 1;             // 1 | 2
  bytes creator_pubkey = 2;                // 32B
  bytes name = 3;                          // raw name bytes; H(name) binds into asset_id
  uint32 decimals = 4;
  string cap_total = 5;                    // decimal u128; set iff issuance_version == 2
  bytes terms_salt = 6;                    // 32B; set iff issuance_version == 2
}
```

**Wire-completeness fields (normative).** `Issuance.creator_pubkey = 7` and `TransitionRequest.genesis_pubkey = 12` ratify the base-pubkey values the reference node proto already carries, with the same presence rules as [§7.5](#75-node-rest-api-normative): `creator_pubkey` is required for a mint, while `genesis_pubkey` is required for a genesis receive and absent otherwise. A presence-rule violation, including the genesis-receive case, is `INVALID_ARGUMENT` / `malformed_request` / `400` under the `SubmitTransition` row of the per-procedure error table. `PullRequest.authority` is a closed string, `"ownership"` or `"grant"`, that carries which capability the API layer verified at [§5.1](#51-capability-gated-pull); the kernel records it on the pull session so `GetAccountState` can admit an ownership session only, as stated above under **Who enforces the capability gate.** Its absence or any other value is `INVALID_ARGUMENT` / `malformed_request` / `400` under the `Pull` row of the per-procedure error table. The field retires the out-of-contract `x-zkcoins-session-authority` gRPC metadata key: the discriminator is now a first-class part of the `kernel.v1` contract, so a client built from the `.proto` alone can open a session the kernel accepts. [§1.7.8](#178-reference-instantiation-status-final-for-v1) makes an addition to the §7 wire formats between runbook step 3 and step 7 — spanning both the §7.5 REST body and the §7.8 gRPC messages — not a new protocol version when it touches no circuit element, pinned vector, or digest, provided a specification PR states why; this amendment supplies that statement. `authority` has no circuit involvement, and the two pubkey fields transport values the circuit or account model already binds, as the §7.5 paragraph above explains. None changes a circuit element, a pinned vector, or a digest, and the API layer continues to perform the entire capability gate, so none moves a trust boundary.

A breaking change to any message or procedure is a new package (`kernel.v2`), never an in-place edit ([§1.7.8 v1 freeze](#178-reference-instantiation-status-final-for-v1)).

**Error contract (normative, closed, deterministic).** Every failed `kernel.v1` procedure returns a `google.rpc.Status` whose primary `code` is one of the eight gRPC codes below and whose `details` **MUST** include exactly one `google.rpc.ErrorInfo` with:

- `ErrorInfo.reason` = the §7.5 `machine_code` string for that condition (closed enumeration; never invent codes);
- `ErrorInfo.domain` = `"kernel.v1"`;
- `ErrorInfo.metadata["http_status"]` = the decimal HTTP status string that pins the REST mapping (e.g. `"400"`, `"401"`, `"410"`, `"503"`) — including the **410 special cases** `challenge_expired` / `session_expired`, which share gRPC `UNAUTHENTICATED` with `unauthorized` but **MUST NOT** collapse to HTTP 401.

The eight admissible gRPC codes and their §7.5 meaning classes:

| gRPC `Status.code` | Meaning class | Typical §7.5 `machine_code`s |
|---|---|---|
| `INVALID_ARGUMENT` | malformed request, wrong types/widths, bounds exceeded | `malformed_request`, `bounds_exceeded`, `invalid_input_coin`, `insufficient_balance`, `unknown_publisher` |
| `NOT_FOUND` | unknown job / record / coin / blob outside the authorised set | `job_not_found`, `not_found` |
| `FAILED_PRECONDITION` | wrong phase, stale S2C, dependency not final, idempotency conflict, invalid signature at `/sign` | `wrong_phase`, `stale_message`, `invalid_signature`, `dependency_not_final`, `idempotency_conflict` |
| `UNAUTHENTICATED` | missing/invalid capability or session (incl. grant-on-ownership-only) | `unauthorized`, `challenge_expired`, `session_expired` |
| `PERMISSION_DENIED` | resolved-scope violation | `scope_exceeded` |
| `RESOURCE_EXHAUSTED` | rate limit or payload size | `rate_limited`, `payload_too_large` |
| `UNAVAILABLE` | not ready / circuit-digest mismatch | `circuit_digest_mismatch` (and not-ready answers that surface as HTTP `503` on `/health/ready` with the readiness body `{ready:false, reason}`, **not** the generic error shape) |
| `INTERNAL` | **only** conditions not covered by a listed code | `internal_error` |

Terminal job outcomes that appear inside a successful `GetJob` / `StreamJob` payload (`proving_failed`, `publish_rejected` as `JobError.error`) are **not** gRPC Status failures of those procedures — the procedure itself returns `OK` with `Job.status ∈ {"failed","cancelled"}`. A procedure **MUST NOT** invent additional gRPC codes or `ErrorInfo.reason` values. **Server-streams** (`ListInscriptions`, `StreamJob`, `SubscribeReceipts`) that fail **MUST** end the stream with the **same** `google.rpc.Status` + `ErrorInfo` detail shape (no distinct stream-only error vocabulary).

An independent API layer **MUST** map each kernel error onto the §7.5 REST surface by reading `ErrorInfo.metadata["http_status"]` and `ErrorInfo.reason` — never by re-interpreting free-text `Status.message`. The mapping is total and deterministic: equal `(code, reason, http_status)` always yields the same HTTP status and `{ "error": reason, "message": … }` body.

**Per-procedure error table (normative).** Each procedure lists the `Status.code` / `ErrorInfo.reason` / `http_status` triples it **MAY** emit; a condition outside its row is `INTERNAL` / `internal_error` / `500`. Empty cells mean the procedure does not emit that class.

| Procedure | `INVALID_ARGUMENT` | `NOT_FOUND` | `FAILED_PRECONDITION` | `UNAUTHENTICATED` | `PERMISSION_DENIED` | `RESOURCE_EXHAUSTED` | `UNAVAILABLE` | `INTERNAL` |
|---|---|---|---|---|---|---|---|---|
| `GetInfo` | — | — | — | — | — | — | not-ready → `503` (when used for `/health/ready`) | `internal_error`/`500` |
| `GetAccumulator` | — | — | — | — | — | — | not-ready → `503` | `internal_error`/`500` |
| `ListInscriptions` | `bounds_exceeded`/`400` (`limit` ∉ `1..1000`), `malformed_request`/`400` (non-numeric query) | — | — | — | — | `rate_limited`/`429` | not-ready → `503` | `internal_error`/`500` |
| `GetNullifierPath` | `malformed_request`/`400` (pubkey width) | — | — | — | — | `rate_limited`/`429` | not-ready → `503` | `internal_error`/`500` |
| `SubmitTransition` | `malformed_request`/`400`, `bounds_exceeded`/`400`, `invalid_input_coin`/`400`, `insufficient_balance`/`400`, `unknown_publisher`/`400` | — | `idempotency_conflict`/`409`, `dependency_not_final`/`409` | — | — | `rate_limited`/`429` | `circuit_digest_mismatch`/`503` | `internal_error`/`500` |
| `GetJob` | `malformed_request`/`400` | `job_not_found`/`404` | — | — | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `StreamJob` | `malformed_request`/`400` | `job_not_found`/`404` | — | — | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `SignTransition` | `malformed_request`/`400` (sig/`s2c_nonce` width) | `job_not_found`/`404` | `wrong_phase`/`409`, `stale_message`/`409`, `invalid_signature`/`409` | — | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `CancelJob` | `malformed_request`/`400` | `job_not_found`/`404` | `wrong_phase`/`409` | — | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `OpenPullChallenge` | `malformed_request`/`400` | — | — | — | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `Pull` | `malformed_request`/`400` | — | — | `unauthorized`/`401`, `challenge_expired`/`410` | `scope_exceeded`/`403` | `rate_limited`/`429` | — | `internal_error`/`500` |
| `GetRecord` | `malformed_request`/`400` | `not_found`/`404` | — | `unauthorized`/`401`, `session_expired`/`410` | `scope_exceeded`/`403` | `rate_limited`/`429` | — | `internal_error`/`500` |
| `GetCoinProof` | `malformed_request`/`400` | `not_found`/`404` | — | `unauthorized`/`401`, `session_expired`/`410` | `scope_exceeded`/`403` | `rate_limited`/`429` | — | `internal_error`/`500` |
| `GetAccountState` | `malformed_request`/`400` | — | — | `unauthorized`/`401` (missing/invalid bearer **or** grant session), `session_expired`/`410` | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `SubscribeReceipts` | `malformed_request`/`400` | — | — | `unauthorized`/`401`, `session_expired`/`410` | `scope_exceeded`/`403` | `rate_limited`/`429` | — | `internal_error`/`500` |
| `Publish` | `malformed_request`/`400` | — | — | — | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `EntrustOperationalBundle` | `malformed_request`/`400` | — | — | `unauthorized`/`401`, `challenge_expired`/`410` | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `RevokeOperationalBundle` | `malformed_request`/`400` | — | — | `unauthorized`/`401`, `challenge_expired`/`410` | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `AttestBalance` | `malformed_request`/`400` | — | — | `unauthorized`/`401`, `challenge_expired`/`410` | — | `rate_limited`/`429` | `circuit_digest_mismatch`/`503` | `internal_error`/`500` |
| `IssueViewGrant` | `malformed_request`/`400` | — | — | `unauthorized`/`401`, `challenge_expired`/`410` | — | `rate_limited`/`429` | — | `internal_error`/`500` |
| `GetTokenProvenance` | `malformed_request`/`400` (asset_id width) | `not_found`/`404` | — | — | — | `rate_limited`/`429` | — | `internal_error`/`500` |

(`Publish` policy/crypto rejections remain **successful** RPC responses with `PublishResult.accepted == false` and a closed `reason`, mirroring §7.6 HTTP 200 — they are not gRPC Status failures.)

**Proving handshake across the boundary.** Proving is kernel-side — it needs the accumulator state and the proving stack ([§6.1](#61-components-and-responsibilities)). The API layer **forwards** the wallet's transition intent to `SubmitTransition` and the wallet's signature to `SignTransition`; the witness is built and the recursive proof produced **inside the kernel**; the SPEND signature is produced **only** in the wallet and passes through the API layer and the kernel RPC verbatim (§7.5 proving handshake, [§2.3](#23-state-transitions)). The kernel RPC therefore never carries a SPEND-branch secret — only a finished BIP-340 signature over the **per-network fixed** message `m_state` (with the sign-to-contract tweak binding the witness-determined `H(ProofData)`) and the non-secret pre-tweak S2C nonce point `R'` the kernel forwards to the publisher for the fee-`ocr` check ([§3.8](#38-fees-and-economics), [§7.6](#76-publisher-interface-normative)). (`nk` and `op_secret` are part of the operational bundle, [§1.2](#12-key-hierarchy)/[§6.2](#62-wallet--node), and live kernel-side for witness construction — `nk` for nullifiers, `op_secret` for the `nav_rand` derivation — but neither can spend.) Proof construction and chain scanning are **internal** kernel work driven by `SubmitTransition` and the chain scanner ([§3.6](#36-chain-scanning)) — not separately-callable procedures (the illustrative `prove`/`scanChain` verbs of [§6.1](#61-components-and-responsibilities) are these internal steps, not RPC entry points). The `awaiting_signature` payload returned by `GetJob` / `StreamJob` **MUST** carry `txn_pubkey` and `send_counter` exactly as §7.5; the wallet checks `derive(A / 0' / send_counter).pubkey == current_pubkey == txn_pubkey` against `GetAccountState` before signing.

**Real-time receipts.** `SubscribeReceipts` is the gRPC server-stream the API layer relays to its public SSE/WebSocket channel ([§4.9](#49-real-time-push-delivery) steps 4–5). The request is `{ session, chan_bind }` — **not** `{ subject }` — matching `CoinProofRequest`: the kernel looks up the pull-session state (ownership **or** grant), checks `chan_bind` equality against the session record, and filters emitted events to that session's stored `subject` and resolved `scope`. Missing/invalid session credential is rejected by the API layer as `401 unauthorized`; unknown, expired, or `chan_bind`-mismatching session as `410 session_expired` ([§7.5](#75-node-rest-api-normative)) — the same `UNAUTHENTICATED` + `ErrorInfo.metadata.http_status` split as the per-procedure error table above. The kernel emits a receipt the instant it has verified and durably persisted ([§4.8](#48-durability--the-store-everything-invariant)) an in-scope incoming coin, so the push pipeline carries no trust the recipient does not re-derive.

**Stores and transport planes.** The value-bearing store ([§4.8](#48-durability--the-store-everything-invariant)) and the Blossom blob store (§7.4) are owned by the kernel; the API layer reaches blobs through the kernel or the public `/blossom` path (§7.4), **never** by touching the kernel's database directly ([§6.1](#61-components-and-responsibilities)). The Nostr relay plane (§7.3) is driven by the kernel with the account's `op` key and includes both the paired `nostr-relay` for zkCoins transport and contacts' kind-10050 DM relays for NIP-17. The minimum known-contact state required by §4.3 is retained by the component that performs messaging. Any API-layer-only state — operator-hosted NIP-05 names, rate-limits, push-subscription registrations — lives in the API layer's **own** store ([§6.1](#61-components-and-responsibilities)), never in the kernel's value-bearing store.



## Relationship to the source papers

zkCoins v1 implements the *Shielded CSV* construction — on-chain half-aggregated account-state nullifiers, NISSHAC commitments ([§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative)), Bitcoin first-occurrence arbitration ([§3.6](#36-chain-scanning)), and the conditional-NAV **dependency discipline**, realised over the [§3.7](#37-the-nullifier-accumulator) **RFC-6962 log-consistency** relation — a Certificate-Transparency consistency port registered as **D-05** that replaces the paper's ToS `IsPrefix` history relation (whose `DistinctElement` no-op branch is out under **D-16**) — with every load-bearing deviation **registered**, per the project's [contribution rule](https://github.com/zk-coins/docs/blob/develop/CONTRIBUTING.md), in the [Paper-Deviation Analysis](/paper-conformance-analysis). The load-bearing v1 deviations are: **D-05** the RFC-6962 append-only-log accumulator (a Certificate-Transparency consistency port replacing the paper's ToS history relation, [§3.7](#37-the-nullifier-accumulator)); **D-16** bounded 6-confirmation finality in place of the paper's arbitrary-depth conditional-NAV no-op ([§3.9](#39-finality-and-reorg-handling)); **D-09** sponsored publishing with no protocol fee, deferring both the spender-picks-publisher fee coin and the paper's first-to-publish-wins design ([§3.8](#38-fees-and-economics), [§3.8.1](#381-fee-coin-mechanism-deferred)); **D-13** the multi-asset token-standard layer ([§6.5](#65-issuance--token-standards)); and the accepted privacy boundaries **D-17–D-20** ([§6.7](#67-security-properties-summary)). The delivery, recovery, access, and operations layers ([§4](#4--transport--recovery)–[§7](#7--wire-formats--node-interfaces)) formalize what the papers leave open and are extensions, not deviations.

## Glossary

A short, scannable reference for the jargon, notation, and identifier names used throughout the specification. Each entry links back to its defining section. For the full reading order start at the [Contents](#contents).

### Notation

- **`H(x)`** — SHA-256 of the byte string `x`. ([§1.1](#11-cryptographic-primitives))
- **`Hc(tag, x₁, …)`** — Poseidon-over-Goldilocks hash, domain-separated by `tag`, of the field-encoded inputs. ([§1.1](#11-cryptographic-primitives), [§1.7](#17-encoding-serialization-and-the-reference-instantiation))
- **`a ‖ b`** — byte concatenation.
- **`P = k·G`** — secp256k1 scalar multiplication; `G` is the generator.
- **`ECDH(k, P) = x(k·P)`** — x-coordinate of the shared secp256k1 point.
- **Lowercase keys (`skᵢ`, `nk`, `ivk`, `ovk`, `op`)** — secret scalars; their public points are written `<name>·G` or as named pubkeys (`Pkᵢ`, `IVPK`, `op_pubkey`). BIP-340 public keys are x-only (32 bytes). ([§1.2](#12-key-hierarchy))

### A–Z

- **AccountState** — `{owner, nk_commit, balances, current_pubkey, send_counter, coin_history_root}`; private bookkeeping, never on-chain in plaintext. `nk_commit = Hc("NkCommit", nk)` binds the account's nullifier key to its identity ([§2.1](#21-the-compliance-predicate) clause 4). Its hash `ash` is bound by every transition's proof. ([§1.5](#15-core-data-structures))
- **AccountUpdateProof** — the proof type for any transition after the first; consumes the account's previous proof and emits a new one (PCD). ([§2.2](#22-proof-types))
- **`address`** — `H(Pk₀ ‖ nk_commit)`; the protocol's only value-bearing cryptographic payment identifier, fixed at account creation from seed-derived keys and encoded as Bech32m `zk`; commits to both the initial spend key and the account's nullifier-key commitment. A *name* is a disposable label above it, never a substitute for it. ([§1.4](#14-identifiers-and-hashes), [§4.3](#43-addressing-for-delivery))
- **`AggregateStateNullifierV3`** — the on-chain object: a half-aggregated set of per-transition account-state nullifiers `(Pkⱼ, Rⱼ)` plus one shared aggregate scalar `s_agg`, inscribed in one Bitcoin reveal (NISSHAC, [§3.3](#33-half-aggregation)); each node folds each fresh `Pkⱼ` into the accumulator by first-occurrence. Per-transition unit is the pair `(Pkᵢ, Rᵢ)`. ([§1.4](#14-identifiers-and-hashes), [§3.1](#31-the-on-chain-object), [§3.5](#35-inscription-format))
- **anchoring trail** — the ordered chain an explorer renders to tie one account-layer transaction to its Bitcoin anchor: transaction → recursive proof → the transition's on-chain nullifier `(Pkᵢ, Rᵢ)`, shown as a real Bitcoin `txid` with confirmations and the [§3.10](#310-transaction-states) state (`completed` = first occurrence + final). ([§5.5](#55-two-explorer-modes))
- **`ash` (account_state_hash)** — `Hc("AccountState", serialize(AccountState))`. ([§1.4](#14-identifiers-and-hashes), [§1.7.4](#174-serializeaccountstate))
- **`asset_id`** — `Hc("AssetId", genesis_tag ‖ Pk₀ ‖ H(name) ‖ decimals ‖ issuance_version)` for a token-standard-1 asset, or `Hc("AssetIdV2", genesis_tag ‖ Pk₀ ‖ H(name) ‖ decimals ‖ issuance_version ‖ cap_total ‖ terms_salt)` for a token-standard-2 asset; globally unique per asset, binds the creator's `Pk₀` and the token standard (issuance-schema version) (and, for token standard 2, the supply cap), never carries the human-readable name on-chain. ([§1.4](#14-identifiers-and-hashes), [§6.5](#65-issuance--token-standards))
- **`asset_terms`** — optional `CoinProof`-bundle field: the plaintext `IssuanceTerms` of `coin.asset_id` (token standard 1 carries `{creator_pubkey, name, decimals, issuance_version}`; token standard 2 also carries `cap_total`, `terms_salt`), travelling inside the ZBE-encrypted bundle blob, and — once a holder has the `asset_id` — additionally resolvable via the open Class-B lookup from any holder that has retained them ([§4.6](#46-data-availability), [§7.5](#75-node-rest-api-normative)). Self-authenticating — the receiver recomputes `asset_id` from it and rejects the bundle on mismatch; if absent, the coin stays valid but the wallet carries the asset as an opaque `asset_id`. ([§1.5](#15-core-data-structures), [§2.3.3](#233-receive), [§6.5](#65-issuance--token-standards))
- **`balances`** — `map<asset_id, amount>` in `AccountState`; the account's multi-asset bookkeeping. ([§1.5](#15-core-data-structures))
- **Bech32m** — text encoding used for addresses (`zk`), view grants (`zkgrant`), per-coin view caps (`zkview`), bearer account view keys (`zkavk`), confirmation-link blob locators (`zkbid`), and balance-attestation content handles (`zkatt`). ([§1.7.7](#177-bech32m-and-bitcoin-conventions))
- **`blob_store`** — a content-addressed Blossom store ([§7.4](#74-blossom-blob-store-normative)) holding `CoinProof` / `SelfDeliveryRecordV1` blobs; a network `blob_store` listed in the Bootstrap Manifest is the seed-discoverable holder of blob bytes for recovery ([§4.3](#43-addressing-for-delivery)). ([§4.3](#43-addressing-for-delivery), [§7.4](#74-blossom-blob-store-normative))
- **Blossom** — content-addressed HTTP blob store (one per node) holding ZBE-encrypted `CoinProof` blobs (`blob_id = H(ciphertext)`). ([§7.4](#74-blossom-blob-store-normative))
- **`block_anchor`** — `{block_hash, height}` of the Bitcoin tip an inscription's proofs are built against; bounded by `N = 100` blocks behind the inclusion block. ([§3.5](#35-inscription-format))
- **Bundle (CoinProof)** — `{coin, proof, inclusion_proof, creating_prev_ash, creating_nullifier, nav_opening, asset_terms?, epk, ciphertext, detect_tag}`; the off-chain object that is the recipient's receipt and — once folded into the recipient's own lineage by a receive transition ([§2.3.3 step 7](#233-receive)) — the basis of its spend credential. ([§1.5](#15-core-data-structures))
- **Cap (per coin)** — see *capability*; the smallest is `zkview` per-coin. ([§5.3](#53-per-coin-view-capability))
- **`cap_total`** — a token-standard-2 asset's provable maximum total supply, a `u128` bound into `asset_id` via `AssetIdV2` and enforced in-circuit (`amount ≤ cap_total` at the single genesis mint). Carried to holders inside `asset_terms`. ([§6.5](#token-standard-2--auditable-capped-supply))
- **Capability** — a cryptographic permission to view some Private record (ownership proof, view grant, bearer view key, per-coin view cap, balance attestation). ([§5.4](#54-capabilities-at-a-glance))
- **Capability-gated pull** — the node API serves Private records only after the requester presents a valid capability; `PullResult` lists generic `{record_id, record_type, transition_kind?, blob_id, occurred_at}` refs (`record_type ∈ {"coinproof","self_delivery"}` discriminates the body; `transition_kind ∈ {"mint","send","receive"}` is the transition class only), and `GET /v1/record/<id>` fetches state or coin records. Only a node with a local decrypt-index answers account pull. ([§5.1](#51-capability-gated-pull), [§4.5](#45-recovery), [§7.5](#75-node-rest-api-normative))
- **Circuit digest** — a circuit's `verifier_only.circuit_digest` (Poseidon `HashOut`, 32 bytes); both `circuit_digest(C)` and `circuit_digest(C_balance)`, one each per network tag, are pinned protocol constants advertised in `/v1/info.circuit_digests`; a node rejects any proof whose verifier-data digest does not match the pinned constant for the network it operates on. ([§1.7.9](#179-proof-system-parameters-normative), [§2.5](#25-circuit-dimensioning-normative), [V.4](#v4-poseidon-derived-values))
- **Class A / Class B** — the two serving classes of [§4.6](#46-data-availability): Class A is a subject's recipient-private records, served either by the anonymous client-side recovery scan ([§4.5](#45-recovery)) or by an ownership-/grant-gated indexed pull ([§7.5](#75-node-rest-api-normative)); Class B is issuer-originated token provenance (`asset_terms`), openly resolvable by `asset_id` from any holder that has retained the terms (404 when none does). ([§4.6](#46-data-availability))
- **`Coin`** — `{identifier, recipient, amount, asset_id}`; the off-chain value-carrying unit. ([§1.5](#15-core-data-structures))
- **Coin-history SMT** — per-account, Private; sparse Merkle tree keyed by `coin.identifier`, leaf state `{0=absent, 1=received-unspent, 2=spent}`; root folded into `ash`. ([§1.6](#16-trees-one-global-structure-one-per-account-structure), [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log))
- **`coin.identifier`** — `Hc("Coin", prev_account_state_hash ‖ recipient ‖ asset_id ‖ amount ‖ coin_index)`; the `prev_account_state_hash` is the **prior** `ash` of the transition that creates the coin (breaks the would-be recursion with `new_ash`, see [§1.4](#14-identifiers-and-hashes)). Binds the coin's `recipient` and `amount` into the commitment so value and ownership are conserved across account boundaries — recomputed in-circuit at [§2.1 clauses 2(c)/5/10](#21-the-compliance-predicate). Fixed at creation. ([§1.4](#14-identifiers-and-hashes))
- **CoinProof** — see *Bundle*.
- **CoinTemplate** — `{recipient, amount, asset_id}`; the sender's per-payee instruction inside a `Send`. ([§1.5](#15-core-data-structures))
- **`completed` (transaction state)** — the on-chain nullifier's signature verifies (§3.2) and its `Pkᵢ` is the **first occurrence** of that key in the accumulator (§3.6) **AND** its inclusion block has ≥ 6 confirmations, at which point it is **final**; the only state in which a receiver MAY credit; a reorg of ≥6 blocks MAY reverse it — an accepted v1 limitation, not a recovery case (§3.9). ([§3.10](#310-transaction-states))
- **conditional NAV** — a transition's chain-derived nullifier-accumulator value `nav` that contains every nullifier it depends on (its prior account state's nullifier and each input/received coin's creating-transition nullifier); exposed only through the hiding `nav_commitment` (the fifth `ProofData` field), carried forward monotonically by `prefix`, and required canonical on a verifier's own scan. Reorg handling is bounded by the 6-confirmation finality directive (§3.9), not by a no-op branch. ([§1.4](#14-identifiers-and-hashes), [§2.1 clause 1](#21-the-compliance-predicate), [§3.9](#39-finality-and-reorg-handling))
- **Cyclic recursion** — one fixed circuit verifies proofs of itself; verifier data is constant, so proof size and verification time are constant. ([§2.2](#22-proof-types))
- **Data Permanence** — a node never deletes received data: every artefact is stored completely and retained indefinitely and unconditionally (no drop, expiry, pruning, supersession clean-up, or time-bounded retention). Applies to protocol artefacts, idempotency mappings, and stored accumulator log entries (orphaned/non-canonical entries are excluded from the active view, never removed from the store). ([Requirement 12](/requirements#12-data-permanence), [§4.8](#48-durability--the-store-everything-invariant))
- **DeliveryEvent** — Nostr delivery: rumor payload `{blob_id, blob_locators, ack_nonce}` (optional `record_kind ∈ {"mint","send","receive"}` for self-delivery — closed JSON string literals, same value set as §7.5 `transition_kind`), NIP-44 encrypted to `IVPK` and NIP-59 gift-wrapped under an ephemeral key; the **outer** kind-1059 event carries **only** the per-coin scan tags `zkdt`/`zkepk` in cleartext. `blob_locators` is the **base64url-no-pad** of `serialize(BlobLocatorSet)` (`holders` only; `blob_id` is context) inside the sealed payload. The `ack_nonce` is a fresh sender-chosen 32-byte value the recipient echoes in the kind-1421 ACK content `{detect_tag, blob_id, ack_nonce, op_sig}`, binding the ACK to this delivery attempt. ([§4.2](#42-bundle-delivery), [§7.3](#73-nostr-event-kinds-normative))
- **`detect_tag`** — `Hc("DetectTag", ss ‖ epk)`, where `ss = ECDH(esk, IVPK) = ECDH(ivk, epk)`; per-coin, all-distinct, recipient-side scan only (one ECDH + one hash per candidate) — no relay filter and no cross-coin linkability. ([§1.3](#13-per-coin-keys-note-encryption--detection), [§4.4](#44-note-discovery))
- **`epk` (ephemeral pubkey)** — `esk·G`, drawn fresh per output coin; the recipient's `K_tx` and `detect_tag` are derived from it. ([§1.3](#13-per-coin-keys-note-encryption--detection))
- **`failed` (transaction state)** — the nullifier is rejected by the scan (structural/`block_anchor` violation §3.5, signature failure §3.2, or a **later** occurrence of an already-folded `Pkᵢ` — a double-spend loser §3.6); receiver MUST NOT credit; forward-sticky on a fixed canonical chain, can only change which of two racing nullifiers wins via reorg. ([§3.10](#310-transaction-states))
- **Fee coin** — **deferred, not part of v1** ([§3.8.1](#381-fee-coin-mechanism-deferred)). In the deferred paid design, an ordinary output coin a spender adds to its transition, addressed to a chosen publisher's `fee_address`, reimbursing the publisher in zkCoins. v1 publishing is **sponsored**: no fee coin exists, and a publisher is not reimbursed ([§3.8](#38-fees-and-economics)).
- **Field, field element** — a value in 𝔽 (Goldilocks, `p = 2^64 − 2^32 + 1`); a Poseidon digest is **four** field elements (32 bytes). ([§1.1](#11-cryptographic-primitives), [§1.7.1](#171-poseidon-instance-and-digest-encoding))
- **Fuzzy message detection (FMD)** — future-version (not in v1) probabilistic relay-side pre-filter; reduces the recipient's download volume, not its linkability (the per-coin scheme already has none). ([§1.3](#13-per-coin-keys-note-encryption--detection), [§4.7](#47-metadata-and-privacy-tradeoffs))
- **`GetTokenProvenance`** — the kernel RPC behind the open REST read `GET /v1/token/<asset_id>/provenance`; returns the self-verifying `IssuanceTerms` for an `asset_id` when the node has retained them (Class B); `404 not_found` otherwise. ([§7.5](#75-node-rest-api-normative), [§7.8](#78-kernel-rpc--the-internal-interface-normative))
- **Goldilocks** — the proof field `𝔽` with prime `p = 2^64 − 2^32 + 1`; pinned for Poseidon. ([§1.1](#11-cryptographic-primitives))
- **Half-aggregation** — non-interactive compression of many transitions' BIP-340 nullifier signatures into one shared aggregate scalar `s_agg`, retaining each `(Pkⱼ, Rⱼ)`; publisher-side, **off-chain before inscription** ([§3.3](#33-half-aggregation)); only the aggregated result is inscribed (no secret keys, no proof) so `m` nullifiers cost ~64 bytes each.
- **`Hc`** — see *Notation*.
- **HKDF** — HKDF-SHA-256 (RFC 5869), used for symmetric/derived secrets (`K_tx`, `K_out`, `nav_rand`, ZBE's `kb`); the `HKDF(tag, material)` shorthand's `IKM`/`salt`/`info`/`L` parameter mapping is fixed once, normatively, in [§1.1](#11-cryptographic-primitives). ([§1.1](#11-cryptographic-primitives))
- **InitialProof** — the first transition of an account; `prev_proof` is absent and `prev_account_state` is the canonical empty account. ([§2.2](#22-proof-types))
- **`inr` (input_nullifiers_root)** — Poseidon Merkle root over a transition's spent `nf`s under tag `NullifiersRoot`. ([§1.4](#14-identifiers-and-hashes), [§1.7.5](#175-poseidon-merkle-tree-used-for-ocr-and-inr))
- **Inscription** — Taproot commit/reveal envelope whose witness payload starts with the 2-byte marker `0x42 0x42` and carries a half-aggregated nullifier set `(Pkⱼ, Rⱼ)` + `s_agg` (~64 B per transition). ([§3.5](#35-inscription-format))
- **Invoice** — `{amount, recipient, asset_id, memo?, pk0, nk_commit, ivpk, op_pubkey, relays, addr_sig, sig}`; the off-chain payer-facing addressing object. `addr_sig` is a BIP-340 signature by `sk₀` that chains the address-holder to every field, including the choice of `ivpk` and `op_pubkey`; `sig` is the per-issuance BIP-340 signature by `op` that the recipient's online relay applies. Both are required. ([§1.5](#15-core-data-structures), [§4.3](#43-addressing-for-delivery))
- **`IssuanceTerms`** — the versioned record bound to an `asset_id` that fixes its mint rules. Token standard 1 is creator-only with no protocol-enforced cap, quantum, or time window — `{asset_id, creator_pubkey, issuance_version=1, name_hash, decimals, terms_hash}`. Later token standards MAY add protocol-enforced supply rules. Terms reach holders inside `CoinProof` bundles (the `asset_terms` field, [§1.5](#15-core-data-structures)), directly from the issuer, or openly by `asset_id` from any holder that has retained them ([§4.6](#46-data-availability) Class B), verified by recomputing `asset_id` — there is no `name → asset_id` registry. ([§6.5](#65-issuance--token-standards))
- **`issuance_version`** — the asset's token-standard selector: `1` (uncapped) or `2` (auditable capped supply) — [§6.5](#65-issuance--token-standards); bound into `asset_id` so coins minted under different versions are distinct. ([§1.4](#14-identifiers-and-hashes), [§6.5](#65-issuance--token-standards))
- **`ivk`** — incoming viewing key (VIEW branch); detects and decrypts incoming coins; cannot spend. ([§1.2](#12-key-hierarchy))
- **`IVPK`** — `ivk·G`; the recipient's incoming-view pubkey, used to encrypt delivery events and as the ECDH counterpart. ([§1.3](#13-per-coin-keys-note-encryption--detection))
- **`K_tx`** — `HKDF("NoteKey", ss ‖ epk)`; per-coin symmetric note key; decrypts exactly one coin's ciphertext. ([§1.3](#13-per-coin-keys-note-encryption--detection))
- **Lineage (account)** — the account's chain of recursive proofs, each consuming its predecessor; carried in constant size by PCD. ([§2.2](#22-proof-types))
- **`m_state`** — the **per-network fixed** protocol-constant message (`"zkCoins/v1/StateUpdate/mainnet"` \| `"…/testnet"` \| `"…/regtest"`) every account transition on that network signs; the transition's specifics are bound into the signature's nonce by sign-to-contract (`H(ProofData)`), not into the message, which keeps the on-chain nullifier at ~64 bytes and lets a scanner verify with no off-chain data using the per-network fixed constant for the network the scanner operates on. Closes on-chain cross-network replay of a raw `(Pk, R, s)`. ([§1.4](#14-identifiers-and-hashes), [§3.2](#32-transition-signing-bip-340--sign-to-contract))
- **`network_id`** — `Hc("Network", network_tag_bytes)`; public input of `C` and `C_balance` (4 Goldilocks field elements); **placement differs by circuit:** in **`C`**, `network_id` lies **after `consumed_pubkey`**; in **`C_balance`** there is **no** `consumed_pubkey` and `network_id` is the **last** public input. Proof-level network binding only — does **not** bind the BIP-340 signature. ([§1.4](#14-identifiers-and-hashes), [§2.5](#25-circuit-dimensioning-normative), [§5.7](#57-balance-attestation-history-private))
- **Mint** — the issuance transition; produces a creator-owned coin under the asset's token standard — `IssuanceTerms_v1` (uncapped) or `IssuanceTerms_v2` (auditable capped supply via `cap_total`, §6.5) (the creator of the asset is its sole minter; anyone can create their own asset, no one can mint someone else's); spends no input coin but is a **state-advancing** transition that consumes its state's one-time key `Pkᵢ` and **publishes its on-chain nullifier `(Pkᵢ, Rᵢ)`**, arbitrated by first-occurrence exactly like a spend — its receiver both re-verifies the mint's recursive proof (an `InitialProof`, or an `AccountUpdateProof` carrying `asset_issuance` for a follow-up mint) and checks that nullifier's `completed` state. ([§2.3.1](#231-mint--issuance), [§3.10](#310-transaction-states), [§6.5](#65-issuance--token-standards))
- **`NAV(tip)`** — `(accumulator, tip_block_hash, tip_height)`; the accumulator's value at a stated Bitcoin tip; an authenticated membership (inclusion) answer is meaningful only relative to a `NAV`. Path-B `present: false` is an unauthenticated index answer, not a tip-anchored non-inclusion proof. ([§3.7](#37-the-nullifier-accumulator))
- **`nav_commitment`** / **`nav_opening`** — the fifth `ProofData` field, `Hc("NavCommit", nav_root ‖ nav_rand)`: the **hiding** commitment to a transition's conditional NAV that a proof exposes publicly, so chain observers learn nothing of the account's receive-recency. Opened (`nav_opening = {nav, nav_rand}`) to a coin's recipient (via the `CoinProof` bundle) or a disclosure verifier, who checks `nav` is canonical on their own scan; under the deferred fee mechanism the fee coin's `nav_opening` would be handed to the publisher ([§3.8.1](#381-fee-coin-mechanism-deferred)) — v1 hands it none — and by default it opens the shared `size_final` ordinal (identical for every prover at a given tip), so it reveals no receive-recency. ([§1.4](#14-identifiers-and-hashes), [§2.1](#21-the-compliance-predicate), [§2.3.2](#232-send), [§2.3.3](#233-receive))
- **`nav_rand`** — `HKDF("zkCoins/v1/NavRand", op_secret ‖ u64-be(send_counter))`; the deterministic 256-bit randomness that makes `nav_commitment` hiding; reproducible by any holder of the operational bundle (so a fresh node rebuilds any prior opening) and MUST NOT be derived from `nav`. ([§1.4](#14-identifiers-and-hashes))
- **`npk_commit`** — the sixth `ProofData` field, `H("zkCoins/v1/NpkCommit" ‖ next_pubkey ‖ npk_rand)` (SHA-256): a **hiding** commitment to the rotated `next_pubkey`, computed by the wallet so it can verify the node folded its own rotation key (§2.1 clause 2, §7.5 fail-closed); `npk_rand` is **32 unmodified CSPRNG / `getRandomValues` bytes** per attempt (fail-closed if unavailable; no scalar reduction, no HKDF), never reused (hygiene). Equal `npk_commit` / rotation-linkage from reused `npk_rand` arises only on **same-key retries** (same `next_pubkey`). ([§1.4](#14-identifiers-and-hashes), [§2.1](#21-the-compliance-predicate))
- **`nf` (nullifier)** — `Hc("Nullifier", nk ‖ coin.identifier)`; **in-circuit bookkeeping only** — folded into `input_nullifiers_root`, never published; **no `nf` ever appears on Bitcoin** (the on-chain object is the account-state nullifier `(Pkᵢ, Rᵢ)`, [§3.1](#31-the-on-chain-object)); unlinkable to the coin without `nk`. ([§1.4](#14-identifiers-and-hashes))
- **name (NIP-05 identifier)** — the normalized public label (`user@domain`), one in force per account, provided by the app or API layers and attested by the holder's `name_sig` ([§4.3](#43-addressing-for-delivery) *Name consent*), that maps through `/.well-known/nostr.json?name=user` to the account's `op_pubkey`. It is **operational, not cryptographic**: resolved and hosted by the API layer or an external NIP-05 provider and never by the node kernel, never seed-derived, and in no value-bearing structure — it enters only `name_message`, where the seed holder attests it, and the `op`-signed kind-0 serialization, neither of which carries payment authority — hence freely replaceable, and its loss costs reachability under that name, never a key, a balance, or a pinned contact. DNS is used only for first discovery through a name or explicit revalidation, never for normal use of a contact with retained relay endpoints that passed original-hostname TLS authentication and the WebSocket relay upgrade on the original path. End-user apps present names exclusively ([Implementation Mandate](/implementation-mandate#app-layer-identity-and-contacts-normative)). ([§4.3](#43-addressing-for-delivery))
- **NIP-17** — standard private direct messages: a kind-14 rumor, NIP-44-v2-encrypted inside a kind-13 seal and separately kind-1059-gift-wrapped to recipient and sender, published to each receiver's kind-10050 DM relays. Mandatory for human messaging; no NIP-04 fallback. ([§7.3](#73-nostr-event-kinds-normative))
- **`nprofile`** — the standard NIP-19 profile identifier containing only `op_pubkey` and relay-URL hints. It carries no IP addresses or zkCoins fields. The client separately retains IP endpoints only after original-hostname TLS authentication and a successful WebSocket relay upgrade on the original path; this local transport state, not the `nprofile` alone, permits DNS-free use of known contacts. ([§4.3](#43-addressing-for-delivery))
- **NIP-44 v2** — encrypted message format (ECDH-secp256k1 → HKDF-SHA-256 → ChaCha20 + HMAC-SHA-256); used for zkCoins delivery controls, acknowledgements, and standard NIP-17 messages. ([§1.1](#11-cryptographic-primitives), [§4.2](#42-bundle-delivery), [§7.3](#73-nostr-event-kinds-normative))
- **`NIP44Binary`** — labelled helper mapping binary protocol values onto NIP-44 v2's UTF-8 plaintext interface: `NIP44Binary(key, label, b) := NIP44_v2(key, UTF8("zkcoins-bin-v1:" ‖ label ‖ ":" ‖ base64url_no_pad(b)))`; stored fields are the UTF-8 of NIP-44's Base64 payload; open checks prefix, label, canonical base64url-no-pad, and expected length fail-closed. Call sites: `ciphertext` (`"coin"`, 112 B) and `out_ciphertext` (`"K_tx"`, 32 B). ([§1.3](#13-per-coin-keys-note-encryption--detection))
- **NIP-59** — Nostr seal and gift-wrap framing. zkCoins coin delivery uses fresh per-coin scan tags that identify neither party; standard NIP-17 gift wraps instead carry the receiver's `op_pubkey` in an outer `p` tag for routing. ([§4.2](#42-bundle-delivery), [§7.3](#73-nostr-event-kinds-normative))
- **NISSHAC** — Non-Interactive Signature Half-Aggregation with Commitments: the *Shielded CSV* scheme that half-aggregates `n` BIP-340 signatures into `(R₁ … Rₙ, s_agg)` while each `Rᵢ` sign-to-contract-commits that transition's `H(ProofData)`; the source of the half-aggregate verification equation and the commitment-opening relation the on-chain nullifiers rely on. ([§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative), [§3.3](#33-half-aggregation))
- **`nk`** — nullifier key (own hardened branch `A/3'`, account-level; part of the operational bundle held by the wallet **and** its own node); used only in-circuit to compute `nf`s — it cannot spend, but links the account's own spends, so it never goes to a foreign node. ([§1.2](#12-key-hierarchy))
- **`op_secret`** — hardened `A/4'` secret in the operational bundle; keys the deterministic `nav_rand = HKDF("zkCoins/v1/NavRand", op_secret ‖ u64-be(send_counter))` derivation (§1.4); a role-free secret because `nav_rand` is disclosed to coin recipients and disclosure verifiers, so its generating key must have no other use (§1.2); cannot spend. ([§1.2](#12-key-hierarchy))
- **Nullifier accumulator** — global **append-only Merkle log** (RFC 6962 over Poseidon, §1.7.6) over the first-occurrence sequence of on-chain `(Pkᵢ, Rᵢ)`; supports authenticated inclusion + log-consistency proofs (the consistency `SUBPROOF` is an implementation-internal circuit witness, not a v1 wire object); Path-B may also return an unauthenticated local-index absence answer — not an RFC-6962 non-inclusion proof; rebuilt from Bitcoin alone given the pinned network parameters (§3.6). ([§1.6](#16-trees-one-global-structure-one-per-account-structure), [§3.7](#37-the-nullifier-accumulator), [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log))
- **Nullifier-accumulator log / consistency proof** — the RFC-6962 append-only Merkle log and its inclusion/log-consistency proofs (§1.7.6, §3.7); the consistency `SUBPROOF` node-list is circuit-internal in v1 (not a public wire object).
- **`ocr` (output_coins_root)** — Poseidon Merkle root over a transition's output `coin.identifier`s under tag `CoinsRoot`. ([§1.4](#14-identifiers-and-hashes), [§1.7.5](#175-poseidon-merkle-tree-used-for-ocr-and-inr))
- **on-chain nullifier `(Pkᵢ, Rᵢ)`** — the **only** object zkCoins writes to Bitcoin: the account-state nullifier of one state-advancing transition — `Pkᵢ` the rotating `current_pubkey`, `Rᵢ` the sign-to-contract nonce committing `H(ProofData)`. A publisher half-aggregates many into one inscription; every node folds each `Pkᵢ` into the accumulator by first-occurrence. ~64 B/tx before aggregation. ([§1.4](#14-identifiers-and-hashes), [§3.1](#31-the-on-chain-object))
- **`op`** — the account's operational and standard Nostr identity key; held by the node; signs kind-0 profiles, kind-10050 relay lists, NIP-17 seals, view grants, and acknowledgements and decrypts NIP-17 messages; cannot spend. ([§1.2](#12-key-hierarchy), [§6.6](#66-threat-model-and-trust-configurations))
- **`out_ciphertext`** — per-outgoing-coin `NIP44Binary(K_out, "K_tx", K_tx)` with `K_out = HKDF("zkCoins/v1/OutKey", ovk ‖ epk)`; UTF-8 of the NIP-44 Base64 payload; carried in each `SelfDeliveryRecordV1.output_ref` so an `ovk` holder can recover outgoing plaintext. ([§1.3](#13-per-coin-keys-note-encryption--detection), [§4.2](#42-bundle-delivery))
- **`ovk`** — outgoing viewing key (VIEW branch); recovers outgoing-coin plaintext via the per-coin `out_ciphertext`; cannot spend. ([§1.2](#12-key-hierarchy), [§1.3](#13-per-coin-keys-note-encryption--detection))
- **Ownership proof** — a BIP-340 signature by `sk₀` over a node-issued challenge; grants the subject's full Private view. ([§5.1(a)](#a-ownership-proof))
- **`SelfDeliveryRecordV1`** — tagged, fully length-prefixed self-addressed state/transition envelope (`magic "SDR1" ‖ version ‖ record_kind ‖ send_counter ‖ prev_state_head ‖ AccountState ‖ proof+ProofData ‖ own nullifier (Pk,R,R') ‖ proof_block_anchor ‖ inclusion_block ‖ occurred_at ‖ spent/folded coin_ids ‖ output_refs`); `proof_block_anchor` is the proof-context tip under which the proof was built (strict ancestor of inclusion; **not** the publisher-chosen on-chain `AggregateStateNullifierV3` header `block_anchor`); `inclusion_block` is first-occurrence of `(Pk,R)`; `occurred_at = MTP(inclusion_block)` only; fully replayable including pure receives; entire plaintext encrypted; outer gift-wrap shows only `zkdt`/`zkepk`. ([§4.2](#42-bundle-delivery), [§7.1](#71-serialization-conventions-normative))
- **Bootstrap Manifest** — per-network signed/content-addressed list of **global** seed relays, blob stores, and operator IDs; mirrored from `/v1/info`; no account- or blob-specific fields. ([§4.3](#43-addressing-for-delivery), [§7.5](#75-node-rest-api-normative))
- **`BlobLocatorSet`** — ordered holder base-URL list (`holders` only); the `blob_id` is **context beside** the set, never a member of it; carried only inside encrypted delivery / self-delivery interiors — never as public holder gossip. Wire form: `serialize(BlobLocatorSet)` ([§7.1](#71-serialization-conventions-normative)). ([§4.2](#42-bundle-delivery), [§4.3](#43-addressing-for-delivery))
- **Path A (verifier path)** — a verifier that maintains the full nullifier accumulator itself by scanning the marker inscriptions (§3.5–§3.6), verifying each nullifier's signature, and folding each fresh `Pkᵢ` by first-occurrence. Answers membership / absence queries on the `Pkᵢ`-keyed accumulator by direct local lookup, revealing nothing. Storage grows with admitted nullifiers. ([§3.7](#37-the-nullifier-accumulator))
- **Path B (verifier path)** — a light-client verifier that holds no accumulator and asks any Path-A node for a Path-B answer for `Pkᵢ`: either a self-verifying **RFC-6962 inclusion** proof of `(Pkᵢ, Rᵢ)` at position `p`, or an **unauthenticated local-index absence answer** (`present: false` — **not** an RFC-6962 non-inclusion proof). Display/delegation only — crediting is Path-A-only ([§2.3.3 step 4](#233-receive)); a Path-B answer, single or combined, MUST NOT back a credit. ([§3.7](#37-the-nullifier-accumulator))
- **PCD (Proof-Carrying Data)** — a recursion-based proof system: each transition consumes a previous proof and emits a new one; one constant-size proof attests the entire history. ([§2](#2--proofs--state-transitions))
- **`pending` (transaction state)** — the nullifier is inscribed and its signature verifies, but its inclusion block has < 6 confirmations; receiver MUST NOT credit. There is no data-availability sub-state — the nullifier is entirely on Bitcoin — and its `Pkᵢ` is already folded into the accumulator from `pending` onward, so double-spend protection takes effect at publication. ([§3.10](#310-transaction-states))
- **`Pkᵢ`** — `skᵢ·G`; the rotating per-transition signing pubkey (x-only); `Pk₀` fixes the address. Also the on-chain nullifier key of a state-advancing transition. ([§1.2](#12-key-hierarchy))
- **Poseidon** — algebraic hash over Goldilocks used inside the proof circuit; reference instance is Plonky2's `PoseidonGoldilocksConfig`. ([§1.1](#11-cryptographic-primitives), [§1.7.1](#171-poseidon-instance-and-digest-encoding))
- **`ProofData`** — `{new_account_state_hash, output_coins_root, input_nullifiers_root, coin_history_root, nav_commitment, npk_commit}`; the proof's public inputs (six 32-byte digests, 192-byte `serialize`). ([§1.4](#14-identifiers-and-hashes), [§2.1 clause 9](#21-the-compliance-predicate))
- **Publisher** — permissionless, contention-free agent that collects transition nullifiers, **half-aggregates** their BIP-340 signatures (§3.3, no proof, no secret keys), and inscribes the resulting `(Pkⱼ, Rⱼ)` set on Bitcoin; never holds any customer coin or proof — in v1 it receives no coin or proof at all, only the nullifier hand-off; under the deferred fee mechanism the one object it would receive is its **own fee coin's** `CoinProof` ([§3.8.1](#381-fee-coin-mechanism-deferred), [§7.6](#76-publisher-interface-normative)); cannot forge (every signature is re-checked by each scanner), only censor or delay — and is trivially bypassed by another publisher or self-publish. ([§3.4](#34-the-publisher)) In v1 a publisher is **sponsored** — it takes no fee, and therefore needs only an `op` key, a relay presence, and the HTTP endpoint its kind-30422 event names for the [§7.6](#76-publisher-interface-normative) hand-off: no zkCoins account, no fee address, no `sk₀`, no wallet, no DNS ([§3.8](#38-fees-and-economics)).
- **Receive (transition)** — the `C` execution that folds verified incoming coins into the account's own lineage: in-circuit verification of each creating proof, admission binding to the creating transition's on-chain nullifier as a member of the receiver's conditional NAV, balance credit, and coin-history admission; a **state-advancing** transition that consumes its state's one-time key `Pkᵢ` and **publishes its own on-chain nullifier `(Pkᵢ, Rᵢ)`** (~64 bytes), which MUST reach `completed` before its newly-folded coins are creditable by others. ([§2.1 clause 10](#21-the-compliance-predicate), [§2.3.3 step 7](#233-receive), [§3.10](#310-transaction-states))
- **recovery-discoverable overlap** — the normative rule ([§4.3](#43-addressing-for-delivery)) that every delivery event is published to ≥1 network `seed_relay` and every blob stored in ≥1 network `blob_store`, so a seed-only recovery finds both the event locator and the blob bytes (under the §4.10 operational conditions). ([§4.3](#43-addressing-for-delivery))
- **Recursive verification** — see *PCD*; clause 1 of the predicate. ([§2.1](#21-the-compliance-predicate))
- **`seed_relay`** — a network Nostr relay listed in the signed Bootstrap Manifest; the seed-discoverable holder of delivery events for recovery ([§4.3](#43-addressing-for-delivery)). ([§4.3](#43-addressing-for-delivery))
- **`send_counter`** — monotonic counter inside `AccountState`; increments per transition. ([§1.5](#15-core-data-structures))
- **`serialize(AccountState)`** — canonical byte serialization; preimage for `ash`. ([§1.7.4](#174-serializeaccountstate))
- **`serialize(ProofData)` / `H(ProofData)`** — canonical `new_account_state_hash ‖ output_coins_root ‖ input_nullifiers_root ‖ coin_history_root ‖ nav_commitment ‖ npk_commit` (192 bytes); `H(ProofData) = SHA-256(serialize(ProofData))` is the transition's sign-to-contract tweak digest. ([§1.4](#14-identifiers-and-hashes), [§3.2](#32-transition-signing-bip-340--sign-to-contract))
- **Sign-to-contract (S2C)** — a BIP-340 signature's nonce is tweaked by `t = H(bytes(R') ‖ H(ProofData))` (even-y normalisation and redraw per [§3.2](#32-transition-signing-bip-340--sign-to-contract) steps 1b/3b), anchoring an off-chain object to that signature with no extra on-chain bytes. zkCoins uses it **once**: each transition binds its off-chain `H(ProofData)` into the nonce `Rᵢ` of the single transition signature over the per-network fixed `m_state`, so the on-chain nullifier `(Pkᵢ, Rᵢ)` commits exactly that transition and is verified in-circuit ([§2.1 clause 2](#21-the-compliance-predicate)). ([§3.2](#32-transition-signing-bip-340--sign-to-contract))
- **`skᵢ`** — rotating per-transition signing key (SPEND branch); `sk₀` is the initial key that fixes the address. ([§1.2](#12-key-hierarchy))
- **SMT (Sparse Merkle Tree)** — 256-bit-depth Merkle tree with default-hashed empty subtrees; used for the **per-account coin-history** root (the global nullifier accumulator is now an append-only Merkle log, §1.7.6). ([§1.6](#16-trees-one-global-structure-one-per-account-structure), [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log))
- **SpendRecord** — `{public_key: Pkᵢ (32B), signature (64B)}` = 96 bytes (the normative byte order of [§1.4](#14-identifiers-and-hashes)); the account's **off-chain transition authorization** — one per transition, a BIP-340 signature over the per-network fixed `m_state` with S2C over `H(ProofData)`. Its on-chain nullifier `(Pkᵢ, Rᵢ)` is what a publisher half-aggregates and inscribes; **every** state-advancing transition produces one and publishes it — a mint's and a pure receive's included. ([§1.4](#14-identifiers-and-hashes), [§3.4](#34-the-publisher))
- **`ss` (shared secret)** — `ECDH(esk, IVPK) = ECDH(ivk, epk)`; the input to both `K_tx` and `detect_tag`, under distinct domain tags. ([§1.3](#13-per-coin-keys-note-encryption--detection))
- **Tag (domain-separation tag)** — the string `"zkCoins/v1/<context>"` prefixed to every `Hc`/`HKDF` call; reusing a tag for two purposes is forbidden. ([§1.1](#11-cryptographic-primitives))
- **`terms_salt`** — a token-standard-2 asset's secret 32-byte blind, bound into `asset_id` via `AssetIdV2` so `cap_total` is not brute-forceable from the public `asset_id`; reaches holders inside `asset_terms`, and — once a holder has the `asset_id` — openly via the Class-B lookup ([§4.6](#46-data-availability), [§7.5](#75-node-rest-api-normative)). ([§6.5](#token-standard-2--auditable-capped-supply))
- **Transaction state** — see `completed`, `failed`, and `pending` ([§3.10](#310-transaction-states)).
- **Transition** — one execution of the compliance predicate `C` (mint, send, or receive). ([§2.3](#23-state-transitions))
- **View grant** — `op`-signed delegated viewing key (Bech32m `zkgrant`), scoped by `asset_ids` and time. ([§5.2](#52-view-grant))
- **ZBE (zkCoins Bundle Encryption)** — chunked ChaCha20-Poly1305 AEAD framing for content-addressed `CoinProof` bundle blobs; key `HKDF("zkCoins/v1/BlobKey", K_tx)`, 64 KiB chunks, per-chunk counter nonce + index-binding AAD. NIP-44 v2 permits extended-length plaintext through `2^32-1` bytes but uses ChaCha20 + HMAC-SHA-256; ZBE remains separate because proof blobs need chunkwise authenticated processing, bounded memory, and blob-oriented framing/retry rather than large Nostr control events. It is the only off-chain blob class — the nullifier accumulator is rebuilt from Bitcoin, not from any off-chain object. ([§4.2.1](#421-bundle-blob-encryption-zbe-normative))
- **`zkavk`** — bearer account view key (Bech32m), payload `ivk ‖ ovk` (64 B; full history) or `ivk` alone (32 B; incoming-only variant); non-revocable. ([§1.7.7](#177-bech32m-and-bitcoin-conventions), [§5.8](#58-address-view-full-history))
- **`zkbid`** — bearer confirmation-link locator (Bech32m), payload `blob_id = H(ciphertext)`; content-addresses the one coin's bundle so any replica can serve it. ([§5.6](#56-shareable-confirmation-links))
- **`zkgrant`** — see *View grant*.
- **`zkview`** — bearer per-coin view capability (Bech32m), payload `K_tx`; decrypts exactly one coin. ([§5.3](#53-per-coin-view-capability))

### See also

- [Contents](#contents) — the order to read the spec sections in.
- [Requirements](/requirements) — the thirteen non-negotiable properties this glossary's identifiers exist to satisfy.
- [Test vectors](#test-vectors-conformance-harness) — worked-example values for the identifiers above.



## Test vectors (conformance harness)

> *In one sentence: a fixed worked example with concrete hex values for every identifier defined by SHA-256/Bech32m (computed and pinned here) and for the Poseidon-derived values produced by the reference implementation (never hand-authored).*

This page exists so that the node, the SDK's independent primitive-level re-implementation, and any future implementation can **bit-for-bit verify** they implement the spec's derivations identically. Where a value depends only on SHA-256 / Bech32m / byte serialization (per [§1.4](#14-identifiers-and-hashes) and [§1.7](#17-encoding-serialization-and-the-reference-instantiation)), it is pinned here. Where a value depends on Poseidon over Goldilocks ([§1.1](#11-cryptographic-primitives), [§1.7.1](#171-poseidon-instance-and-digest-encoding)) — and therefore on the reference instantiation, final for v1 ([§1.7.8](#178-reference-instantiation-status-final-for-v1)) — its **formula** is pinned and its **bytes** are those produced by the reference implementation (never hand-authored). No Poseidon byte values are guessed or fabricated here.

### V.1 Sample inputs

The sample keys are **illustrative**, not derived from a real BIP-32 path. Real wallets derive `Pk₀`, `Pk₁`, `nk` from the seed via [§1.2](#12-key-hierarchy); for the purpose of exercising the byte-level identifier derivations on this page, they are fixed deterministically as `SHA-256` of fixed ASCII strings:

| Symbol | Definition | Hex (32 bytes) |
|---|---|---|
| `Pk₀_sample` | `H("zkCoins/v1/test-vector/Pk0")` | `5dcffebb708081e3cc78b22f54d260467022c095a67da835f50713a36ee40746` |
| `Pk₁_sample` | `H("zkCoins/v1/test-vector/Pk1")` | `fba3ea150382de6f39a07348d327b1efa8c120da1ee599148ff6fed7803465fb` |
| `nk_sample` | `H("zkCoins/v1/test-vector/nk")` | `2dc00b27c0d2991514b1b997af97b0e12c5da159b5726481124032c1578115b2` |
| `npk_rand@0` | `H("zkCoins/v1/test-vector/npk_rand")` (fixture blind for `npk_commit@0`, §2.1 clause 2) | `a04b10a7ac57db9e12b2cac644653f97ffdfc4911935f21f027936f60c543b98` |
| `npk_commit@0` | `H("zkCoins/v1/NpkCommit" ‖ Pk₁_sample ‖ npk_rand@0)` (SHA-256; the sixth ProofData field, §1.4) | `7d014dfd4b58080f7a68124ef28936c8da039135a8b7e0b25ce14e287e6d7026` |

Asset definition:

| Field | Value |
|---|---|
| `name` (UTF-8) | `USD-Demo` |
| `H(name)` | `aff024cf2705e0450bfb51b461a1ed90c125efe0e43554191380b69a6a6be313` |
| `decimals` | `0x02` (2) |
| `genesis_tag` | ASCII `zkCoins/v1/genesis` (18 bytes: `7a6b436f696e732f76312f67656e65736973`) |

`Pk₀_sample` is treated as an x-only 32-byte string for the purpose of `address = H(Pk₀ ‖ nk_commit)`; a real BIP-340 key must be a valid x-coordinate on secp256k1. This caveat does not affect the `address`/Bech32m derivation, which depends only on the byte inputs (the 32-byte `Pk₀` concatenated with the 32-byte `nk_commit`), not on curve validity.

### V.2 Address derivation (SHA-256 + Bech32m — pinned)

```
Pk₀_sample      (32B) = 5dcffebb708081e3cc78b22f54d260467022c095a67da835f50713a36ee40746
nk_commit_sample(32B) = 444981ebd6edc1116dc1a13d51e7ed2c47988cc66ad5fb95c12de4f2efa4456e
address               = H(Pk₀_sample ‖ nk_commit_sample)     ; 64-byte preimage (§1.4)
                      = e38121742a22e04e51175eb3e38a66df7e7e691c0041c169bc3a2592696f803d
zk-bech32m            = zk1uwqjzap2ytsyu5ght6e78znxmal8u6guqpquz6du8gjey6t0sq7st3s86p
```

A conforming implementation **MUST** produce, from the inputs above, exactly the `address` bytes that `H(Pk₀_sample ‖ nk_commit_sample)` yields and its Bech32m string; both are Poseidon-dependent via `nk_commit_sample` (V.4) and were produced by the reference implementation. The address preimage is the **64-byte** concatenation `Pk₀_sample ‖ nk_commit_sample`. The Bech32m HRP is `zk`; the encoding is per [§1.7.7](#177-bech32m-and-bitcoin-conventions). The Bech32m checksum constant is the BIP-350 value `0x2BC830A3`.

**V.2-ext — real derivation chain (pinned).** Unlike the illustrative V.1 samples, this chain exercises the real [§1.2](#12-key-hierarchy) derivation end to end (BIP-39 → BIP-32 all-hardened → HKDF). Mnemonic (the BIP-39 reference test mnemonic): `abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about`, passphrase empty; account index `0'`. All values SHA-256/HMAC/secp256k1-derived and therefore pinned (node + SDK byte-equal per the V.7 parity matrix):

| Symbol | Path / formula | Hex (32B unless noted) |
|---|---|---|
| `seed64` | BIP-39 PBKDF2-HMAC-SHA512, 2048 iters (64B) | `5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4` |
| `sk₀` | `m/1798'/0'/0'/0'` | `4a8e3a83404f1aa99e89af57179dcf033820b816c0d78ac94fcb322d6ee85649` |
| `Pk₀` | x-only(`sk₀·G`) | `7c9cdde9b8cb1e33a48a5c2b6ab1fa6fd753fa1762f56c0b3e8169e4f2d54630` |
| `sk₁` | `m/1798'/0'/0'/1'` | `c09b2a6301bdc0fef9adb1bd9de4ff77e5a30a28fb11a0dd7a76831708cea7ee` |
| `Pk₁` | x-only(`sk₁·G`) | `3b471e208d280506b20476e64c1478741bc3a71244d4a3099501f639d54afa6c` |
| `ivk` | `m/1798'/0'/1'/0'` | `ae3da9f4b07a7b6af81b549011126c39f0070a58fdedf60c5bd9591d096ba1f0` |
| `ovk` | `m/1798'/0'/1'/1'` | `f5d3205dcb3ec239f396dd120f0c71d6551465b33f5cbdb92b1946c415665d5d` |
| `op` | `m/1798'/0'/2'` | `6516c985b442d51f1e91760c9327a593ddcb7fe06b363aa5b2b8547cc61d7395` |
| `nk` | `m/1798'/0'/3'` | `4b75d4ded533cdee8d4757811bd3de1f3400008dd22b0e541cbca81423fd9f74` |
| `op_secret` | `m/1798'/0'/4'` | `4d00fd0017fe8b9741eb194b1ed393b6d5120de12ce11035f695705a9c06cd1e` |
| `nav_rand@0` | `HKDF("zkCoins/v1/NavRand", op_secret ‖ u64-be(0))` ([§1.4](#14-identifiers-and-hashes) mapping) | `a6f0057caecb75293d7c40781e244576df63fbc0ddf553897775fd4d1a6de2e8` |
| `nav_rand@1` | same, counter `1` | `93a8e7860a8b77c4b03d4b1c734489f7cf88b0ab62f26c7039d9b1f87748756d` |

(BIP-32 hardened-only derivation: `I = HMAC-SHA512(c_par, 0x00 ‖ ser256(k_par) ‖ ser32(i + 2³¹))`, child `k = (int(I[:32]) + k_par) mod n`, chain `c = I[32:]`; the `nk_commit`, `address`, and every other Poseidon-dependent continuation of this chain are listed in V.4 as values produced by the reference implementation.)

### V.2-passkey — Passkey PRF → seed fixture (pinned; v2 feature — NOT a v1 conformance target) {#v2-passkey--passkey-prf--seed-fixture-pinned}

This vector is a **conformance target only from protocol v2 onward**; it is **not a v1 conformance target**. A **v1** wallet **MUST NOT** offer, select, or use the passkey-derived-seed path for a v1 account ([§1.2](#12-key-hierarchy)), so a v1 implementation is **exempt** from this fixture. Deterministic exercise of [§1.2](#12-key-hierarchy) WebAuthn-PRF → seed — **SHA-256 / HKDF only**, no Poseidon, no live authenticator. The free fixture `prf_output` stands in for a 32-byte `eval.first` result; a conforming (v2) implementation **MUST** reproduce every derived row bit-for-bit (node + SDK byte-equal per the V.7 parity matrix).

| Symbol | Formula | Hex (32B) |
|---|---|---|
| `prf_output` | free fixture IKM (simulates WebAuthn PRF `eval.first` output; **not** from a live authenticator) | `00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff` |
| `prf_salt` | `SHA-256(UTF8("zkCoins/v1/PasskeyPRF"))` — the fixed WebAuthn `eval.first` salt of §1.2 | `642862fba8a827e8ff7cab12e3e216e19d018bf4d8150ab1ffbb640f3b607003` |
| `seed` | `HKDF-SHA256(IKM = prf_output, salt = 0x00×32, info = "zkCoins/v1/PasskeySeed", L = 32)` — i.e. `HKDF("zkCoins/v1/PasskeySeed", prf_output)` under the [§1.1](#11-cryptographic-primitives) mapping | `f5116e98e94562766e63d2813060d8615b7b94d9e27b385c6e692fd64db3b88f` |

**Negative (fail-closed — each MUST refuse Passkey seed derivation):** `prf_output` of length ≠ 32; missing PRF extension / missing `eval.first`; any fallback that substitutes credential id, signature bytes, `clientDataJSON`, or a password for `prf_output`.

**Acceptance:** from the pinned `prf_output`, recompute `prf_salt` and `seed` by the formulas above and match bit-for-bit; reject every negative case.

### V.3 `serialize(AccountState)` byte layout (pinned for the SHA-256 parts)

A worked example: an account holding 1 000 000 000 base units of `USD-Demo` after its first transition (the V.1 mint) — its coin-history SMT now holds `coin.identifier@0` at state `1`.

```
Fixed fields  (pinned bytes):
   owner               (32B): e38121742a22e04e51175eb3e38a66df7e7e691c0041c169bc3a2592696f803d
   nk_commit           (32B): 444981ebd6edc1116dc1a13d51e7ed2c47988cc66ad5fb95c12de4f2efa4456e
   current_pubkey      (32B): fba3ea150382de6f39a07348d327b1efa8c120da1ee599148ff6fed7803465fb
   send_counter        ( 8B): 0000000000000001
   coin_history_root   (32B): f5c33d0522df857744c548ca3ba539f6f9409870b2779b63e483cbd45c3e4b4b
   balances_count      ( 4B): 00000001   ← ≤ MAX_ACCOUNT_ASSETS = 32 (§2.5); one active entry here
   [balances entry, sorted ascending by asset_id]:
       asset_id        (32B): da7deb2e2d8ad91a2ec9e2aafc6756b2b11f092c79650ce313658f3a9b2ab7cf
       amount          (16B): 0000000000000000000000003b9aca00   ← u128 big-endian, 1 000 000 000

Sizes:
   prefix (without asset_id+amount): 140 bytes
   with one balance entry:           188 bytes
```

The conformance harness MUST construct the byte string in exactly this order and re-derive `ash = Hc("AccountState", <these bytes as a byte-string input>)` per [§1.7.2](#172-field-encoding-e-of-hc-inputs) and [§1.7.4](#174-serializeaccountstate).

`coin_history_root` for an empty account equals **`E'₂₅₆`**, the empty-tree root of the per-account coin-history SMT (distinct from the nullifier-accumulator log's empty root `nflog_empty = Hc("NfLog/Empty", 0)` (§1.7.6) because the coin-history SMT uses different domain tags `CoinHist/Leaf`, `CoinHist/Node`; see [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)). Both values are Poseidon-dependent and listed in V.4 (produced by the reference implementation).

### V.4 Poseidon-derived values

For each value below, the formula is fixed; the bytes were produced by the reference implementation conforming to [§1.7.1](#171-poseidon-instance-and-digest-encoding) and [§1.7.2](#172-field-encoding-e-of-hc-inputs) and are pinned in the rightmost column. Implementations MUST reproduce them bit-for-bit.

| Symbol | Formula | Bytes |
|---|---|---|
| `nflog_empty` (nullifier-accumulator empty-log root) | `Hc("NfLog/Empty", 0)` — the empty append-only Merkle log ([§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)); the retired 256-bit-SMT empty root `E₂₅₆` no longer exists | `f7599780b12dc6120b6e305e77feb04d1db533fbeb19f3fd25ca22b5b222c2bc` |
| `E'₂₅₆` (coin-history-SMT empty root) | same structure with the per-account tags: `E'₀ = Hc("CoinHist/Leaf", 0)` and `E'ᵢ = Hc("CoinHist/Node", i, E'_{i-1}, E'_{i-1})`; empty root `E'₂₅₆ = Hc("CoinHist/Node", 256, E'₂₅₅, E'₂₅₅)` — [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log) | `7d558733b6f685d85aff62341e3d017234056105bced89ce0319166dc90a6dcf` |
| `asset_id` | `Hc("AssetId", "zkCoins/v1/genesis" ‖ Pk₀_sample ‖ H("USD-Demo") ‖ decimals=0x02 ‖ issuance_version=0x01)` | `da7deb2e2d8ad91a2ec9e2aafc6756b2b11f092c79650ce313658f3a9b2ab7cf` |
| `nk_commit_sample` | `Hc("NkCommit", nk_sample)` — the account nullifier-key commitment ([§2.1 clause 4](#21-the-compliance-predicate)), a fixed field of `serialize(AccountState)` (V.3) | `444981ebd6edc1116dc1a13d51e7ed2c47988cc66ad5fb95c12de4f2efa4456e` |
| `ash_empty` | `Hc("AccountState", serialize(canonical_empty_account_for(address)))` per [§2.2](#22-proof-types) — the InitialProof's `prev_account_state` digest; uses `nk_commit = nk_commit_sample` and `coin_history_root = E'₂₅₆` | `ef56b9ac8dc7a119c9d2679164b91f341d785e9649470158c2661cfd4f71b61b` |
| `coin.identifier@0` | a coin minted to `address`, first output of the InitialProof: `Hc("Coin", ash_empty ‖ recipient=address ‖ asset_id ‖ amount=1000000000 ‖ coin_index=0)` (the mint's `recipient` is the issuing `address`, V.2, and `amount` is the V.3 supply, 1 000 000 000) | `a1cc00c5a5c0fa499664ca891690c3bde52a4c9326f6794659f8ad1926288790` |
| `coin_history_root@0` | the per-account coin-history SMT root after admitting `coin.identifier@0` as leaf state `1` (received-unspent), starting from `E'₂₅₆`; the result is a single populated path through 256 levels | `f5c33d0522df857744c548ca3ba539f6f9409870b2779b63e483cbd45c3e4b4b` |
| `ash@0` | `Hc("AccountState", serialize(<V.3 byte string with the regenerated nk_commit_sample, asset_id, coin_history_root@0, and owner (= H(Pk₀_sample ‖ nk_commit_sample), §1.4) substituted>))` | `a6591d3c3810ffdd8c0b7ff496e10521d36d76c8dc78a1726cb023efdaed2b43` |
| `nf_sample` | `Hc("Nullifier", nk_sample ‖ coin.identifier@0)` | `9cc178b183bb3c266f6638c5d5fc1b965f5b296822f4c6655a7634f438ce38d2` |
| `ocr@0` | Poseidon Merkle root over `[coin.identifier@0]`, tag `CoinsRoot` (one leaf, padded to one) per [§1.7.5](#175-poseidon-merkle-tree-used-for-ocr-and-inr) | `5961dbe2cdb0380b21034619eff89fec37ad5e99c0dfa7ca7b47a4e35d8fd3e8` |
| `inr@0` | Poseidon Merkle root over the empty list of nullifiers (a mint), tag `NullifiersRoot` — equals the `L_⊥` leaf-hash | `1de3b164f2c7e8eebad7e30e14a971e0380451c5763ebe4a79825fe29a228575` |
| `nav_empty` | the empty accumulator log value `(size = 0, mth = nflog_empty)`; `nav_root(nav_empty) = Hc("NfLog/Root", 0 ‖ nflog_empty)`, `nflog_empty = Hc("NfLog/Empty", 0)` (§1.7.6) | `cf2717e42bab4463cde1b657f010e65fd2940d459a2af8ea862dbf22702c14d0` |
| `nav_rand_sample@0` | `H("zkCoins/v1/test-vector/nav_rand")` = `e3b0e624bff8dbe486dd0761c14dcb84b4ccaf026fc60c58b69d653e6f656560` — a fixed illustrative commitment blind (real wallets derive it as `HKDF("zkCoins/v1/NavRand", op_secret ‖ u64-be(send_counter))`, §1.4) | fixed |
| `nav_commitment@0` | `Hc("NavCommit", nav_root(nav_empty) ‖ nav_rand_sample@0)` (a fresh-network **genesis** mint, where `size_final = 0`, commits the empty conditional NAV `nav_empty`; a mint on an already-active network uses `nav = size_final`, §2.3.1) | `eec40cabb6cece9f2c76cd3fde2f55c2bf193def66c4482bd94f1cb44acbe34d` |
| `H(ProofData@0)` | `SHA-256(serialize(ProofData@0))` = `SHA-256(ash@0 ‖ ocr@0 ‖ inr@0 ‖ coin_history_root@0 ‖ nav_commitment@0 ‖ npk_commit@0)`, `npk_commit@0 = H("zkCoins/v1/NpkCommit" ‖ Pk₁_sample ‖ npk_rand@0)` (canonical 192-byte `serialize(ProofData)`, [§1.4](#14-identifiers-and-hashes)) | derived from the six above — `db8c60533ba19eba14958f6ce44fd8df2e784d17dac28d8532e66fa938308de4` |
| `circuit_digest(C)` | the `verifier_only.circuit_digest` of the per-account circuit `C` built per [§1.7.9](#179-proof-system-parameters-normative) (`standard_recursion_zk_config`, one per network tag (`zkCoins/v1/mainnet`, `zkCoins/v1/testnet`, `zkCoins/v1/regtest`)), encoded per [§1.7.1](#171-poseidon-instance-and-digest-encoding). A pinned protocol constant ([§1.7.9](#179-proof-system-parameters-normative)) | mainnet `14a3adaf256b5f129d07079c29ccc35a713ecd55ea41a2e93b09925cc88c60aa`<br/>testnet `10d38c9ee6322ae6a50aa9908918d03dcedbcf984f023c3fab549eb8bce83c5c`<br/>regtest `9d256e8c828f531fc6cf9ffd4fa1ca9480473d00a99f92ea535912daa34e8352` |
| `circuit_digest(C_balance)` | the [§2.2](#22-proof-types) balance-attestation circuit's `verifier_only.circuit_digest`, one per network tag (`zkCoins/v1/mainnet`, `zkCoins/v1/testnet`, `zkCoins/v1/regtest`), produced by the same deterministic §1.7.9 build discipline as `C` | mainnet `0a4202fc772295d6db4eb9c5bd2bbb7a59d45cff1653648dff4681f4ba55d606`<br/>testnet `cbb8f284fab6f81aa3616f55da76942c1259845e0b9135f9c8fe9385d3f7fe87`<br/>regtest `bd696087e0e0f47b556a6803ef4fb5b9ebae2327e0438dd405f33752dc90772d` |
| `network_id` | `Hc("Network", network_tag_bytes)` for each network tag (`zkCoins/v1/mainnet`, `zkCoins/v1/testnet`, `zkCoins/v1/regtest`) — the public-input Poseidon `HashOut` ([§1.4](#14-identifiers-and-hashes), [§2.5](#25-circuit-dimensioning-normative)); not part of `serialize(ProofData)` | mainnet `fb5080433fbd3d5c9ed7aad0e1feced2954859c4492ecb0880b0713f6b09ec8c`<br/>testnet `edd03cfdd9de40d33160fac02396576b5bcf94f94c568bbcef291a49f61b5e28`<br/>regtest `f26dcd6b70992a28ef809001793c1e9a3c0aa68c3a7dcc9b43b1ca0e919467de` |
| `detect_tag@fixture` | `Hc("zkCoins/v1/DetectTag", ss ‖ epk)` over the pinned V.10 `ss`/`epk` | `52f38f5972d4b44ef361fadfd8e5f927f3ec9ed8d34c888435fe91d0ff76ea4c` |
| `asset_id_v2` | `Hc("AssetIdV2", genesis_tag ‖ Pk₀_sample ‖ H("EUR-Demo") ‖ decimals=0x02 ‖ issuance_version=0x02 ‖ cap_total=500000000 (16B be) ‖ terms_salt_fixture)` — `terms_salt_fixture = H("zkCoins/v1/test-vector/terms_salt")` (SHA-256, pinned: compute and inline it at the vectors PR) | `299c74853e87d0a617b8631285752d90362481e7ff06f940c6f219545c4194ab` |
| `terms_hash_v1` / `terms_hash_v2` | `Hc("IssuanceTerms", asset_id ‖ issuance_version)` and the token standard 2 analogue per [§6.5](#65-issuance--token-standards) | v1 `aa80213d58ea4fc9990f5425f71afd56f5117841ab7a3e52f46beb46330fbbf4`<br/>v2 `305bb19e79746450253d3eb2a4c1f68c4727d5792c019fe3b734e8720fbb3c2f` |

### V.5 `SpendRecord` byte layout (pinned for the SHA-256 / structural parts)

The `SpendRecord` is an **off-chain** object: the account's transition authorization (see [§1.4](#14-identifiers-and-hashes), [§3.4](#34-the-publisher)). It is **96 bytes** — its `(Pkᵢ, Rᵢ)` pair is what a publisher half-aggregates and inscribes on Bitcoin as the on-chain nullifier.

The `SpendRecord` byte layout is:

```
Pkᵢ          (32B): <Pkᵢ — spender's current per-transition signing pubkey, x-only>
signature    (64B): mainnet  7db327f8ff4bb148f051a038d370c4213149fe3affeff5b7fb7e9f8e3cc4438532168b5fca622ba2fad6d72ed201e71cef1003df880d345ddbe2b89f1ce3d4e5
                     testnet  c62142c2448e098e5f8f4ec306b8a922be44226ae754e7b515178485d2da2286c52881936dd64a1dc3b9756c4a7a033e76ca4ad778624acbf580c041be6f7bf0
                     regtest  8945e81ed57b06222bd86b957f6800fc5569014b295c40c0b7a501787edca2c916b9c2f693f5e43c030bfc4fa0f210b9e96d45b06e943e652c8edb3b4a06d7fc
                     BIP-340(sk, m_state) with S2C tweak t = H(bytes(R') ‖ H(ProofData@0)); V.2-ext keys; m_state = "zkCoins/v1/StateUpdate/{mainnet|testnet|regtest}"; H(ProofData) = H(ProofData@0) from V.4

Record size: 96 bytes (32 + 64) — the same for a send, a mint, or a pure receive; there is no
message, k, or nullifier list. The on-chain nullifier keeps only (Pkᵢ, Rᵢ), where Rᵢ is the
signature's sign-to-contract nonce (§3.5).
```

`R'` (32B, pre-tweak S2C nonce — **not** part of the 96-byte `SpendRecord`; required to recompute the §3.2 opening `R = R' + t·G` with `t = H(bytes(R') ‖ H(ProofData@0))`):

```
R'           (32B): mainnet  fafd5229e657311d934989a4bc8bdfc8f033b4d640d2eb27b9fdda316f5c9601
                     testnet  8c5b9be1e267c2f40ead298fb6fd8f98c0bc3efb862fce6ef7fa98b5691b3c6e
                     regtest  7f415c530cd07713998ae0467e2c18fce210a7818ec7ad26a7b419009d6598f1
```

A send, a mint, and a pure receive all produce the identical 96-byte `SpendRecord` authorization, and **every** one publishes its `(Pkᵢ, Rᵢ)` on Bitcoin: each is a state-advancing transition arbitrated by first-occurrence ([§2.1 clause 1](#21-the-compliance-predicate), [§3.10](#310-transaction-states)). A mint's receiver additionally re-verifies the mint's recursive proof — an `InitialProof`, or an `AccountUpdateProof` carrying `asset_issuance` for a follow-up mint ([§2.3.1](#231-mint--issuance)) — on top of the first-occurrence check on that on-chain nullifier.

### V.6 Nullifier inscription byte layout (pinned for the structural parts)

A nullifier inscription carries a fixed 42-byte header plus one body per format ([§3.5](#35-inscription-format)). Sample nullifier values are illustrative; the signatures are produced by the signers and `<REGEN>`. The half-aggregated form (`format 0x01`, shown here for `m = 2`) drops each per-nullifier `s` and shares one `s_agg`:

```
Payload header (42 bytes):
   marker                    ( 2B): 4242                              ← zkCoins prefix
   version                   ( 1B): 03                                ← half-aggregated nullifier payload
   format                    ( 1B): 01                                ← 0x00 = raw single, 0x01 = half-aggregated
   count m                   ( 2B): 0002                              ← big-endian u16, here m = 2
   block_anchor.block_hash   (32B): <REGEN — Bitcoin chain-specific; pinned per deployment, not by this spec>
   block_anchor.height       ( 4B): <REGEN — illustrative u32 big-endian Bitcoin block height>

Body (format 0x01 — m pairs then one shared scalar):
   Pk₁                       (32B): <Pkᵢ of transition 1, x-only>
   R₁                        (32B): <R₁ — its sign-to-contract nonce, §3.2>
   Pk₂                       (32B): <Pkⱼ of transition 2, x-only>
   R₂                        (32B): <R₂ — its sign-to-contract nonce, §3.2>
   s_agg                     (32B): cfb0c36a8399589b5580ba41cafaf66b7d707443a202e4113f3635872ca58b78

Payload size: 42 (header) + 2·64 (pairs) + 32 (s_agg) = 202 bytes for m = 2, ENTIRELY in witness data;
the marginal cost of one more transition is 64 bytes (Pkⱼ ‖ Rⱼ) — ~16 vBytes by Bitcoin's 1/4
witness-weighting. A raw single nullifier (format 0x00) instead carries Pkᵢ ‖ Rᵢ ‖ sᵢ = 96 body bytes.
```

Every constituent signature covers the **per-network fixed** message `m_state = "zkCoins/v1/StateUpdate/{mainnet|testnet|regtest}"` (§3.2), so a scanner recomputes every challenge `eⱼ = H_BIP340(Rⱼ ‖ Pkⱼ ‖ m_state)` from on-chain data alone (using the per-network fixed constant `m_state` for the network the scanner operates on) and checks the single aggregate relation `s_agg·G == Σⱼ aⱼ·(Rⱼ + eⱼ·Pkⱼ)` (§3.3). Each `Rⱼ` remains the sign-to-contract commitment to transition `j`'s `H(ProofData)`. This matches the size note in [§3.5](#35-inscription-format).

### V.7 How to use these vectors

1. Implement [§1.7.1](#171-poseidon-instance-and-digest-encoding) (Poseidon over Goldilocks, Plonky2 `PoseidonGoldilocksConfig`) and [§1.7.2](#172-field-encoding-e-of-hc-inputs) (`E(·)` byte-to-field encoding).
2. Reproduce each V.4 row, in order (later rows depend on earlier).
3. Substitute the regenerated values into V.3 (`asset_id`, `coin_history_root@0`, `nk_commit`, and `owner` — never `E'₂₅₆`) and V.4's `H(ProofData@0)` (which the V.5 signature commits via sign-to-contract); `ash@0` is built from that substituted V.3 byte string and therefore uses `coin_history_root@0`, never the empty-tree constant `E'₂₅₆`.
4. Compute `ash@0` from the resulting `serialize(AccountState)` per [§1.7.4](#174-serializeaccountstate) and verify it matches the V.4 entry.
5. Compute the BIP-340 signature over the **per-network fixed** message `m_state = "zkCoins/v1/StateUpdate/{mainnet|testnet|regtest}"` with the sign-to-contract tweak `t = H(bytes(R') ‖ H(ProofData@0))` (per [§3.2](#32-transition-signing-bip-340--sign-to-contract)) and fill in V.5's `signature`; the on-chain nullifier is then `(Pk₀_ext, R)` — `Pk₀_ext` being the V.2-ext `Pk₀` actually signing — with `R = R' + t·G`. Use the **V.2-ext** keys (curve-valid by construction) for the signature vectors (V.8 is a separate, fully pinned fixture that pins testnet's `m_state`); the V.1 samples are NOT curve-valid and MUST NOT be used for signing. The rotated `next_pubkey@0 = Pk₁_sample` (V.1) is **not** in the message — it is folded into `new_account_state_hash` (hence `ash@0`, hence `H(ProofData@0)`), so the sign-to-contract tweak is what authorises the rotation (clause-2/clause-7 invariant).
6. Submit the completed vectors back to the spec as a PR; the reference is locked once the SDK's independent primitive-level re-implementation reproduces the hash- and derivation-level values bit-for-bit — the `circuit_digest(C)` is locked by the node's deterministic §1.7.9 build alone, and the `signature` (V.5) and `s_agg` (V.6) values are locked by BIP-340 / half-aggregate verification including the sign-to-contract tweak check (per [§3.2](#32-transition-signing-bip-340--sign-to-contract), [§3.3](#33-half-aggregation)), not byte equality.

The V.4 bytes are authoritative only as produced by the reference implementation. **Do not invent Poseidon digests.** A wrong vector is worse than no vector: it would lead two implementations to validate against each other's mistakes.

**Parity matrix (normative).** Who must produce which vector, and the acceptance criterion:

| Vector group | node (Rust) | SDK (TypeScript) | Criterion |
|---|---|---|---|
| V.2 address / Bech32m, V.2-ext key chain & `nav_rand` | MUST produce | MUST reproduce | **byte-equal** |
| V.2-passkey Passkey PRF → seed | MUST produce **(v2 only)** | MUST reproduce **(v2 only)** | **byte-equal** (SHA-256/HKDF only) — **v2 only; not a v1 conformance target** |
| V.3 `serialize(AccountState)` byte layout (SHA-256 parts) | MUST produce | MUST reproduce | **byte-equal** |
| V.4 Poseidon values (`E'₂₅₆`, `nflog_empty`, `nk_commit`, `asset_id`, `ash`, `coin.identifier`, `nf`, roots, …) | MUST produce | MUST reproduce | **byte-equal** (SDK implements the §1.7.1 Poseidon primitive) |
| V.1 `npk_commit@0` / V.4 `H(ProofData@0)` (wallet-native SHA-256 surfaces, §7.5 N-16/N-17) | MUST produce | MUST reproduce | **byte-equal** |
| `circuit_digest(C)` / `circuit_digest(C_balance)` | MUST produce (deterministic §1.7.9 build) | consumes only | node-only pin |
| V.5 / V.6 structural layouts (protocol objects, Poseidon fields `<REGEN>`) | MUST produce | MUST **verify** (BIP-340 + S2C opening + `AggregateVerify`) | verification, not byte equality (production nonces are random) |
| V.8 synthetic signing fixture | MUST recompute & produce | MUST recompute & reproduce | **byte-equal** after recompute against fixture `m_state = "zkCoins/v1/StateUpdate/testnet"` (nonce rule deterministic; all signature/aggregate rows are **pinned for testnet** in V.8) |
| V.11 nullifier-accumulator log vectors (`nflog_empty`, hand-listed smoke set over the pinned sample-leaf sequence for small `n ≤ 9`, **and** the **generated log-boundary suite** for every `k = 0…63` as symbolic subtree-root fixtures) | MUST produce | MUST reproduce | **hand-listed:** **byte-equal** (reference-implementation bytes); **boundary suite:** Accept\|Reject on split/peak-bagging with given O(log n) subtree roots (`<REGEN>` Poseidon nodes, harness-generated) — **no** Θ(n) materialisation. Structure / sizes / Accept\|Reject normative. Feeds the D-05 release gate ([§1.7.8](#178-reference-instantiation-status-final-for-v1)) |
| V.10 note-encryption fixture (keys + `NIP44Binary` envelope preimages) | MUST reproduce | MUST reproduce | **byte-equal** on keys/`out_plain`; NIP-44 AEAD via NIP-44 vectors; envelope negatives reject |
| V.12 profile + NIP-17 wire vectors (incl. the name-loss, name-consent, and publisher-profile controls) | MUST produce/accept every positive fixture and reject every negative | MUST reproduce the profile checks and the wire construction within its scope | three-check payment binding, `name_sig` on a name-resolved profile, independent-seal construction; the live client matrix is an `app`-layer release check, not a wire vector |
| V.9 negative controls | MUST reject every case | MUST reject every case within its scope (signing/encoding cases) | each case rejects with the named reason |

### V.8 Signing & half-aggregation fixture (synthetic, fully pinned)

This fixture pins the **signing and aggregation layer in isolation** — [§3.2](#32-transition-signing-bip-340--sign-to-contract) transition signing (including the steps 1b/3b even-y rules), the sign-to-contract opening, and the [§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative) NISSHAC half-aggregation — using **synthetic** `ProofData` whose six fields are SHA-256 digests of fixed labels. The values are deliberately **not protocol-consistent** (no Poseidon value exists for them); they exercise only the SHA-256/secp256k1 layer. The fixture pins **testnet** `m_state = "zkCoins/v1/StateUpdate/testnet"`; the network-independent keys and synthetic `ProofData` tables are byte-pinned below, while the signature/aggregate values that depend on that per-network `m_state` are **pinned for the testnet fixture**. A conforming implementation **MUST** recompute those values and reproduce them bit-for-bit (node + SDK byte-equal, V.7 parity matrix).

**Fixture nonce rule (test-vector only, not normative for production).** Production nonce choice is signer-private ([§3.2](#32-transition-signing-bip-340--sign-to-contract)); this fixture pins one deterministic rule so the vector is reproducible: `masked = d XOR int(tagged_hash("BIP0340/aux", 0x00×32))`, `rand_ctr = tagged_hash("BIP0340/nonce", masked ‖ Pk ‖ m_state ‖ u32-be(ctr))`, `k' = int(rand_ctr) mod n`, starting at `ctr = 0` and incrementing `ctr` on every [§3.2](#32-transition-signing-bip-340--sign-to-contract) step-3b redraw (and on `k' = 0`). The message is the fixture's per-network fixed `m_state = "zkCoins/v1/StateUpdate/testnet"` (this fixture pins **testnet**).

**Signer 1.** `sk_sig_1 = int(H("zkCoins/v1/test-vector/sk_sig1")) mod n` = `22f508c0a93b29fa87ca8d9abcec996f01620656cd7a7e4ab5418b2e76beccf4`; BIP-340-normalised key `d_1` = `22f508c0a93b29fa87ca8d9abcec996f01620656cd7a7e4ab5418b2e76beccf4`; `Pk_1` = `e7f2a98e7b45e9424e3e0cb1d937a1698ebd339c6d8344906db979642cf20474`.

Synthetic `ProofData_1` — the six fields are `H` of the six **short labels** `zkCoins/v1/test-vector/pd1/ash`, `…/pd1/ocr`, `…/pd1/inr`, `…/pd1/chr`, `…/pd1/navc`, `…/pd1/npkc`, mapping in that order to the §1.4 `ProofData` fields:

| Field | Hex |
|---|---|
| `new_account_state_hash` | `f882df3ef57d11032e01c2214525060766250b110b09586cd6cecbed8e3ed4f7` |
| `output_coins_root` | `0852ae9e41b56cb6320977d06df0b11463919fda0364a5b1cfd3d22358211f24` |
| `input_nullifiers_root` | `25af2581385ea1e3688958c7e915c2b46b426daf62536945caaeecc8e3c3a6c6` |
| `coin_history_root` | `7014c090cbf7eeb37519e4ff815a747384f46943a2b0cc3f4a0094e62cdfaaba` |
| `nav_commitment` | `4dcf2ab90710006a8fe0c9fb0363e5465100858fc0d69155f69db53468e6af7c` |
| `npk_commit` | `23461051f1c23cf0660eab775049d51ea90bd08c31dabe5cc3d1a0e4767fe259` |
| `m_SC = H(serialize(ProofData_1))` | `bf50cc59a665bcdc2b5f0754dd754a73e37552a6b1b69eb9e42c07ddd1ae73e2` |

Signature per [§3.2](#32-transition-signing-bip-340--sign-to-contract) (deterministic fixture nonce, `ctr = 0`; values depend on the testnet `m_state`):

| Value | Hex |
|---|---|
| `R'_1` (pre-tweak nonce, x-only) | `5657f2e91dc3a2d248501a37dbe674d2cf8ed1a13c89b7710ca89aad3b9fe050` |
| `t_1` (tweak, `< n`) | `423984fa39ce7b1a4d8eb164ab2a300d56b9de4f4ed3134339db5ead7ccc17c2` |
| `R_1` (committed nonce, x-only) | `c41ff1a78f2006e5f5aa800efa84b2d2046d108dfa968909974ec37fcb87f6c4` |
| `e_1` (BIP-340 challenge) | `88aa41dbac65bb97f235c7fe064ebd5b8882d2bc04f8792aebec2c8c4df7fd4f` |
| `s_1` | `748ae8e2fded9df9830cbaa8893484e753fdfd141cccc8b35a27ab5a870a83d2` |

**Signer 2.** `sk_sig_2 = int(H("zkCoins/v1/test-vector/sk_sig2")) mod n` = `86b75c297fd9a0af472d06fbf889f7e4667c9e42b7d7efc8b1ca7e66b95462c0`; BIP-340-normalised key `d_2` = `7948a3d680265f50b8d2f9040776081a54323ea3f770b0730e07e02616e1de81` (negated — odd-y key, exercising the normalisation branch); `Pk_2` = `21799353e64a65ee4b1f414998c44878c56270cf8a81046cb3636e5ec31a3341`.

Synthetic `ProofData_2` — the six fields are `H` of the six **short labels** `zkCoins/v1/test-vector/pd2/ash`, `…/pd2/ocr`, `…/pd2/inr`, `…/pd2/chr`, `…/pd2/navc`, `…/pd2/npkc`, mapping in that order to the §1.4 `ProofData` fields:

| Field | Hex |
|---|---|
| `new_account_state_hash` | `1713c51edabaa2a6e64ef24d084d4f88e776e135514ae04ad3780c5cd154f660` |
| `output_coins_root` | `7791a68e5387e0a22f90bc7c7347a5712fe42bc82f7559333d7c578b79fd0022` |
| `input_nullifiers_root` | `8fa4a67faf24c981a64328ec227207a06a066e9ac0444621f5d3066b8f405bca` |
| `coin_history_root` | `23027099bb0e04dadb0ae9cb76208e377270c6d4dd761962b98c9db793e109be` |
| `nav_commitment` | `69266372d1705851901e48dd1e40e6cde4bda048fb04e622b97cf4346f90632f` |
| `npk_commit` | `bdae5bcf45668f6f6b2670bdce70882c3211334c78248cdf9d4aa5639074d154` |
| `m_SC = H(serialize(ProofData_2))` | `85d06ebe2f0f5173af9ff8bdd2d4d594303a640d7b2f1c8819d5a48abfa4773d` |

Signature per [§3.2](#32-transition-signing-bip-340--sign-to-contract) (deterministic fixture nonce, `ctr = 2`; values depend on the testnet `m_state`):

| Value | Hex |
|---|---|
| `R'_2` (pre-tweak nonce, x-only) | `9c18a07c07be5225b688895f73daaffefdd62cbb49e1b854dd47f5aee1484193` |
| `t_2` (tweak, `< n`) | `e21ed3e78e2d5abf9e227e8f0e3ba079010400c5103bd8a41187394b2e43527b` |
| `R_2` (committed nonce, x-only) | `bd22b77069c75431ee3676bea7324a59e9b6466a62a9a3021f831e6ccf5d3220` |
| `e_2` (BIP-340 challenge) | `3d57531ad9f5f4df812184559e0bda68c8695e2ba673546c1976732602d016b3` |
| `s_2` | `caa0374d3cf77e1874298c98d3d3fe8b416f89d51823d6909c3e1cdbf91d3002` |

**Half-aggregation (`k = 2`,** [§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative)**):**

| Value | Hex |
|---|---|
| `z = H("zkCoins/v1/HalfAgg" ‖ R₁ ‖ Pk₁ ‖ R₂ ‖ Pk₂)` | `5aca3de396d19dc1e0e2d69b4aed8816d1de535e3c180819f32037beeb49049a` |
| `a₁ = int(H(z ‖ u32-be(1))) mod n` | `ebc0ffd7fabac87c4114b82c11031482af6210be3cbdfd224a3152a41ef8f738` |
| `a₂ = int(H(z ‖ u32-be(2))) mod n` | `d37756039310968a42ab8c386a6bbdcf4211d02b8a8f7bc91257c0aa7f2d70a0` |
| `s_agg = (a₁·s₁ + a₂·s₂) mod n` | `cfb0c36a8399589b5580ba41cafaf66b7d707443a202e4113f3635872ca58b78` |

**Acceptance:** an implementation passes V.8 iff it recomputes every signature/aggregate value above (pinned for the testnet fixture) against `m_state = "zkCoins/v1/StateUpdate/testnet"` bit-for-bit **and** its own `Verify`, `CommVerify` (both signers), and `AggregateVerify` ([§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative)) accept those values; the network-independent `sk_sig_j`/`d_j`/`Pk_j` and synthetic `ProofData` tables remain pinned.

### V.9 Negative controls (normative)

A conforming implementation **MUST** reject every case below with the named outcome; a single accept is a conformance failure. Cases N-01–N-07 are executable immediately against the pinned V.8 values; N-08–N-10 become executable at the runbook steps that pin digests and stand up regtest ([Implementation Mandate](/implementation-mandate)); N-20–N-28 exercise the closed [§7.8](#78-kernel-rpc--the-internal-interface-normative) kernel→REST error mapping (API layer + kernel); N-29 exercises the [§7.5](#75-node-rest-api-normative) `awaiting_signature` signing-key echo; N-30 exercises the [§4.2](#42-bundle-delivery) SDR-Replay consumed-key binding; N-31 exercises the [§4.5](#45-recovery) gapless full-scan against a same-second NIP-01 tie flood.

| # | Mutation | Expected outcome |
|---|---|---|
| N-01 | Flip byte 0 (the first byte of `ash₁`) — the canonical case; implementations SHOULD additionally fuzz all 192 positions of signer 1's 192-byte synthetic `serialize(ProofData)` and re-run the opening | `CommVerify` returns false ([§1.7.10](#1710-half-aggregation-with-commitments-nisshac-normative)) |
| N-02 | Swap `R₁` and `R₂` inside the V.8 aggregate (keys unchanged) | `AggregateVerify` returns false |
| N-03 | Add `1` to `s_agg` (mod `n`) | `AggregateVerify` returns false |
| N-04 | Present `(Pk₁, R₁)` twice in one scan sequence | second occurrence is the double-spend loser: **not** inserted, classified `failed` ([§3.6](#36-chain-scanning), [§3.10](#310-transaction-states)) |
| N-05 | A `CoinProof` whose `asset_terms.issuance_version` byte is `0x03` | bundle malformed, rejected ([§7.1](#71-serialization-conventions-normative), [§2.3.3 step 6](#233-receive)) |
| N-06 | A `CoinProof` whose `asset_terms` presence byte is `0x02` | bundle malformed, rejected ([§7.1](#71-serialization-conventions-normative)) |
| N-07 | Truncate any fixed-width `CoinProof` field by one byte / leave one trailing byte | bundle malformed, rejected ([§7.1](#71-serialization-conventions-normative)) |
| N-08 | Verify a proof built for network tag `zkCoins/v1/testnet` (with testnet `network_id` and testnet digests) against the `zkCoins/v1/mainnet` pinned digests | rejected — `circuit_digest` mismatch ([§1.7.9](#179-proof-system-parameters-normative), [§2.5](#25-circuit-dimensioning-normative)) |
| N-09 | Force a ≤5-block regtest reorg across a `pending` nullifier | canonical replay converges: the accumulator value `(size, mth)` and `nav_root = Hc("NfLog/Root", size ‖ mth)` equal a fresh full rescan's ([§3.9](#39-finality-and-reorg-handling)) |
| N-10 | Force a ≥6-block regtest reorg displacing a `completed` nullifier | the node **detects** the displacement, its `/health/ready` stops reporting ready, and it does not credit against the broken state (the suite asserts detection and fail-stop, not recovery — [§3.9](#39-finality-and-reorg-handling)) |
| N-11 | A payload with `version = 0x04` or `format = 0x02` | malformed header — zero valid nullifiers ([§3.5](#35-inscription-format)) |
| N-12 | Substitute a different (valid) proof's `H(ProofData)` into a CommVerify opening | `CommVerify` returns false (executable against V.8) |
| N-13 | A transition whose per-asset outputs exceed inputs+mint only modulo 2¹²⁸ (conservation wrap) | proof unsatisfiable — wide-integer comparison ([§2.1 clause 3](#21-the-compliance-predicate)); executable at runbook step ≥ 5 |
| N-14 | A second token-standard-2 genesis mint consuming the same `Pk₀` | second occurrence loses first-occurrence — asset supply cap holds ([§6.5](#65-issuance--token-standards)); executable at runbook step ≥ 6 |
| N-15 | A successor whose witnessed `Pk_prev` ≠ the predecessor's exposed `consumed_pubkey` | proof unsatisfiable (clause 1 key binding (iii)); executable at runbook step ≥ 5 |
| N-16 | The node surfaces (in `awaiting_signature`) an `npk_commit` computed over a `next_pubkey` **different** from the wallet's own choice — a hosted-prover rotation-capture attempt — or any otherwise-mutated `npk_commit`; the wallet recomputes `npk_commit = H("zkCoins/v1/NpkCommit" ‖ next_pubkey ‖ npk_rand)` from **its own** `next_pubkey` and the fresh `npk_rand` it supplied and finds a mismatch | wallet **MUST refuse to sign** (never calls `/sign`); the job stays in `awaiting_signature` ([§7.5](#75-node-rest-api-normative) (a), fail-closed — this is what makes key rotation wallet-verifiable, [Requirement 5](/requirements)) |
| N-17 | The node surfaces a `proof_data_hash` that is **not** `SHA-256(serialize(ProofData))` over the six surfaced fields in the [§1.4](#14-identifiers-and-hashes) order | wallet recomputes `H(ProofData)` itself and **MUST refuse to sign** ([§7.5](#75-node-rest-api-normative) (b), fail-closed) |
| N-18 | A proof built for `testnet` verified against `mainnet` pinned digests / verifier data | rejected — `circuit_digest` mismatch; the public-input `network_id` cannot salvage a foreign-network proof ([§1.7.9](#179-proof-system-parameters-normative), [§2.2](#22-proof-types), [§2.5](#25-circuit-dimensioning-normative)) |
| N-19 | A raw `(Pk, R, s)` signed under `m_state = "zkCoins/v1/StateUpdate/testnet"` verified against mainnet's `m_state = "zkCoins/v1/StateUpdate/mainnet"` (or the reverse) | rejected — BIP-340 / `AggregateVerify` fails; **cross-network on-chain replay closed** by the per-network `m_state` ([§3.2](#32-transition-signing-bip-340--sign-to-contract), [§3.6](#36-chain-scanning); **executable immediately** against the pinned V.8 testnet fixture) |
| N-20 | Kernel returns `UNAUTHENTICATED` with `ErrorInfo.reason = "session_expired"` and `ErrorInfo.metadata.http_status = "410"` (e.g. on `GetCoinProof` / `GetAccountState` / `SubscribeReceipts`) | independent API layer **MUST** emit HTTP **410** with `{ "error": "session_expired", … }` — **never** 401 ([§7.8](#78-kernel-rpc--the-internal-interface-normative) error contract; 410 special case) |
| N-21 | Kernel returns `UNAUTHENTICATED` with `ErrorInfo.reason = "unauthorized"` and `http_status = "401"` (missing/malformed bearer, or a **grant** session on `GetAccountState`) | API layer **MUST** emit HTTP **401** with `{ "error": "unauthorized", … }` |
| N-22 | Kernel returns `FAILED_PRECONDITION` with `ErrorInfo.reason = "wrong_phase"` and `http_status = "409"` on `SignTransition` | API layer **MUST** emit HTTP **409** with `{ "error": "wrong_phase", … }` |
| N-23 | Kernel returns `NOT_FOUND` with `ErrorInfo.reason = "job_not_found"` and `http_status = "404"` on `GetJob` | API layer **MUST** emit HTTP **404** with `{ "error": "job_not_found", … }` |
| N-24 | Kernel returns `INVALID_ARGUMENT` with `ErrorInfo.reason = "bounds_exceeded"` and `http_status = "400"` on `SubmitTransition` | API layer **MUST** emit HTTP **400** with `{ "error": "bounds_exceeded", … }` |
| N-25 | Kernel returns `PERMISSION_DENIED` with `ErrorInfo.reason = "scope_exceeded"` and `http_status = "403"` on `GetRecord` / `Pull` | API layer **MUST** emit HTTP **403** with `{ "error": "scope_exceeded", … }` |
| N-26 | Kernel returns `RESOURCE_EXHAUSTED` with `ErrorInfo.reason = "rate_limited"` and `http_status = "429"` | API layer **MUST** emit HTTP **429** with `{ "error": "rate_limited", … }` |
| N-27 | Kernel returns `UNAVAILABLE` with `ErrorInfo.reason = "circuit_digest_mismatch"` and `http_status = "503"` | API layer **MUST** emit HTTP **503** with `{ "error": "circuit_digest_mismatch", … }` |
| N-28 | Same `(Status.code, ErrorInfo.reason, metadata.http_status)` emitted twice by any two procedures (or by a server-stream terminal status) | API layer **MUST** produce **byte-identical** HTTP status and `error` machine_code both times — mapping is total and deterministic ([§7.8](#78-kernel-rpc--the-internal-interface-normative)); a free-text-only `Status.message` **MUST NOT** change the mapping |
| N-29 | `awaiting_signature` omits `txn_pubkey` or `send_counter`, or surfaces `txn_pubkey ≠ current_pubkey` / `derive(A / 0' / send_counter).pubkey ≠ txn_pubkey` relative to a prior `GetAccountState` | wallet **MUST refuse to sign** ([§7.5](#75-node-rest-api-normative) wallet-side recomputation (c); K-B04 handshake) |
| N-30 | An SDR whose `own_nullifier.Pk ≠ recursive_proof.consumed_pubkey` (Fresh-Key-Substitution at replay) | reject — [§4.2](#42-bundle-delivery) Replay (iv) consumed-key binding; executable at runbook step ≥ 5 |
| N-31 | Recovery full scan under a same-second **tie flood**: more than `L` kind-`1059` events share one identical `created_at = t`, and a target `SelfDeliveryRecordV1` delivery sits among them beyond the first page of `limit = L`; **and** the case where every reachable relay **caps** the limit-free `since = t, until = t` drain and returns only a repeating subset at `t` | (a) when full drain succeeds: Recovery **MUST** still discover and process that target (no skip); (b) when no relay can fully drain `t`: Recovery **MUST** report **incomplete** (fail-closed) and **MUST NOT** advance to `until = t − 1` — [§4.5](#45-recovery) step 3 gapless scan |

### V.10 Note-encryption fixture (SHA-256/HKDF/secp256k1, fully pinned)

This fixture pins the [§1.3](#13-per-coin-keys-note-encryption--detection) note-key derivations end to end — ECDH under the [§1.1](#11-cryptographic-primitives) x-only lift convention, the §1.1 HKDF mapping, and the **`NIP44Binary` envelope framing** — reusing the V.2-ext recipient keys (`ivk`, `ovk`). All SHA-256/HKDF/secp256k1 values below are pinned (computed twice independently, byte-identical; node + SDK byte-equal per the V.7 parity matrix). `detect_tag = Hc("zkCoins/v1/DetectTag", ss ‖ epk)` and any field that absorbs a Poseidon digest (e.g. `serialize(Coin)` via `identifier` / `asset_id`) are Poseidon-dependent and pinned from the reference implementation (V.4 discipline). The **NIP-44 AEAD / Base64 payload layer itself** is covered by NIP-44's own published test vectors and is **not** re-pinned here — this fixture pins the **zkCoins envelope preimage** that becomes NIP-44's UTF-8 plaintext, plus the stored-field discipline (UTF-8 of the Base64 payload, not decoded AEAD bytes).

| Symbol | Formula | Hex (32B) |
|---|---|---|
| `esk` | `int(H("zkCoins/v1/test-vector/esk")) mod n` | `e577ff9c7f7bda9d942561e81df3ccb1dc7b9b2f354ccf82a9352eb5f7beb889` |
| `epk` | x-only(`esk·G`) | `e15129c95c4e7528810d91bdc9312389a1c6466bee0237147540c426926af154` |
| `IVPK` | x-only(`ivk·G`) (V.2-ext `ivk`) | `cf8c205c48c67816489375cb1c03f09cee718999b4a97a90e8aef80c72fb6c17` |
| `ss` | `ECDH(esk, IVPK) = x(esk·lift_x(IVPK))` ([§1.1](#11-cryptographic-primitives)) | `842f5821fa577c0374ae48e4c5afa887e3e0900df7245370e5675d88466fa05f` |
| `K_tx` | `HKDF("zkCoins/v1/NoteKey", ss ‖ epk)` | `8a8874f758261a3f48cff62810e5dd4941d3252f44873313bc3f235e73ba8c48` |
| `K_out` | `HKDF("zkCoins/v1/OutKey", ovk ‖ epk)` (V.2-ext `ovk`) | `f18500b7726bcbce23959db535de50a6c742a74f4a04397add7371e19e0426ef` |
| `kb` | `HKDF("zkCoins/v1/BlobKey", K_tx)` ([§4.2.1](#421-bundle-blob-encryption-zbe-normative)) | `fe0533b9cf0eb97a5aa20b080bf70b9be33bed4cb4bf11f58d96718ed659cd86` |

**Envelope preimages (`NIP44Binary`, normative structure — pin the UTF-8 plaintext; NIP-44 ciphertext via NIP-44 vectors).**

| Symbol | Formula | Value |
|---|---|---|
| `out_plain` | `UTF8("zkcoins-bin-v1:K_tx:" ‖ base64url_no_pad(K_tx))` — NIP-44 plaintext under conversation key `K_out` | `zkcoins-bin-v1:K_tx:ioh091gmGj9Iz_YoEOXdSUHTJS9EhzMTvD8jXnO6jEg` |
| `out_ciphertext` | `NIP44Binary(K_out, "K_tx", K_tx)` = UTF-8 of NIP-44 Base64 payload encrypting `out_plain` under `K_out` | **not re-pinned** — covered by NIP-44 v2's own vectors applied to `out_plain`; field stores UTF-8 of Base64, never decoded AEAD raw bytes |
| `coin_bytes` | `serialize(Coin)` for a fixture coin (112 B: `identifier ‖ recipient ‖ amount ‖ asset_id`) | `a1cc00c5a5c0fa499664ca891690c3bde52a4c9326f6794659f8ad1926288790e38121742a22e04e51175eb3e38a66df7e7e691c0041c169bc3a2592696f803d0000000000000000000000003b9aca00da7deb2e2d8ad91a2ec9e2aafc6756b2b11f092c79650ce313658f3a9b2ab7cf` |
| `coin_plain` | `UTF8("zkcoins-bin-v1:coin:" ‖ base64url_no_pad(coin_bytes))` — NIP-44 plaintext under conversation key `K_tx` | `zkcoins-bin-v1:coin:ocwAxaXA-kmWZMqJFpDDveUqTJMm9nlGWfitGSYoh5DjgSF0KiLgTlEXXrPjimbffn5pHABBwWm8OiWSaW-APQAAAAAAAAAAAAAAADuaygDafesuLYrZGi7J4qr8Z1aysR8JLHllDOMTZY86myq3zw` |
| `ciphertext` | `NIP44Binary(K_tx, "coin", coin_bytes)` = UTF-8 of NIP-44 Base64 payload encrypting `coin_plain` under `K_tx` | **not re-pinned** — NIP-44 layer as above; field stores UTF-8 of Base64 |

**Envelope open negatives (fail-closed — each MUST reject):** wrong prefix (not `zkcoins-bin-v1:`); wrong `label` (`"coin"` vs `"K_tx"` swapped or altered); non-canonical `base64url` (padding `=`, standard Base64 alphabet `+/`, whitespace); decoded binary length ≠ expected `L` (not 32 for `out_ciphertext`, not 112 for `ciphertext`); treating stored field bytes as raw AEAD ciphertext instead of UTF-8 of the Base64 payload.

**Acceptance:** reproduce every key-derivation row bit-for-bit, **and** confirm the receiver side derives the identical `ss` from (`ivk`, `epk`) — `x(ivk·lift_x(epk))` equals the pinned `ss` (the x-only lift's sign ambiguity cancels, §1.1); reconstruct `out_plain` from the pinned `K_tx`; open a valid `out_ciphertext` under (`K_out`, `"K_tx"`, `L = 32`) to recover `K_tx`; reject every envelope negative.

### V.11 Nullifier-accumulator log vectors

Conformance vectors for the [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log) append-only Merkle log and the [§3.7](#37-the-nullifier-accumulator) inclusion / consistency proofs. Poseidon-over-Goldilocks digests for the hand-listed smoke set below were produced by the reference implementation (never hand-authored) and are pinned here; boundary-suite fixture digests remain harness-generated at runtime (`<REGEN>` outside this page). The **construction structure** (split point = largest power of two strictly less than the run length, the `MTH` / `PATH` / `SUBPROOF` recursions of [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log) / [§3.7](#37-the-nullifier-accumulator)) is fixed here. The suite has **two layers**: (1) a **hand-listed smoke set** over fully materialised small logs (`n ≤ 9`); (2) a **generated log-boundary suite** for every size-bit `k = 0…63` that tests **split-/peak-bagging LOGIC** against **given/symbolic O(log n) subtree-root fixtures** — **not** by materialising `Θ(n)` leaves (which for `n ≈ 2⁶³` would contradict the O(log n) claim). Layer (2) **feeds the D-05 release gate** ([§1.7.8](#178-reference-instantiation-status-final-for-v1), [Paper-Deviation Analysis D-05](/paper-conformance-analysis)).

**Sample leaf sequence (normative, pinned) — hand-listed smoke set only.** `mth@n`, `inclusion@(p,n)`, and `consistency@(m,n)` in the hand-listed positive table below are computed over a pinned sequence of `(Pkₚ, Rₚ)` leaves: reuse the V.8 fixture's `(Pk_j, R_j)` as the first two leaves, and for positions `p ≥ 2` define `Pkₚ = H("zkCoins/v1/test-vector/nflog/pk" ‖ u8(p))` and `Rₚ = H("zkCoins/v1/test-vector/nflog/r" ‖ u8(p))` (SHA-256, so the sample leaves are pinnable). The leaf hash is `Hc("NfLog/Leaf", p ‖ Pkₚ ‖ Rₚ)` (Poseidon; the roots below were produced by the reference implementation). The reference implementation **MUST** use exactly this sample sequence when producing the hand-listed bytes. This hand-listed set **MAY** fully materialise leaves; it covers only small `n ≤ 9` and does **not** exercise the high size-bits of the gadgets.

**Positive — hand-listed smoke set (formulas pinned; bytes produced by the reference implementation; full materialisation permitted).**

| Value | Formula | Bytes |
|---|---|---|
| `nflog_empty` | `Hc("NfLog/Empty", 0)` | `f7599780b12dc6120b6e305e77feb04d1db533fbeb19f3fd25ca22b5b222c2bc` |
| `mth@n` for `n ∈ {1,2,3,4,5,7,8,9}` | the [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log) `MTH(D[0:n])` over the pinned sample-leaf sequence above (leaf `Hc("NfLog/Leaf", p ‖ Pkₚ ‖ Rₚ)`) | n=1 `f93137ec4a1b7e5cee06e9f82018bb77a07ffe54b51a1f684f001b2ec31629b6`<br/>n=2 `781523c7eef6bb32b4a93501f0312455e1f60a8e4ae27b9650b37e6e14845e99`<br/>n=3 `895bd18668d1d6f69e5c63f29a2ec71750540b2ae9e91a863bc2d1d790178b14`<br/>n=4 `6e223c78305f2aa63bc2b59f645f595767dd08adfa263a65fd956f072461bad3`<br/>n=5 `06cc2c84c4c72559f1f63c9ef920260e1961d87bc608fb16ccd864067d6ac845`<br/>n=7 `ba0f01b37308f7a360f851d4a67f88a63e26479e1527698591e2da398b164f10`<br/>n=8 `c3326a12b33a1c39191d27890b495f9fa77276052346e1e2a9b547e9c6b64e6d`<br/>n=9 `3ff9e35c9b06729a6867fc8ae7889ea7f2db00115070e09eeeb68b0575981ff8` |
| `nav_root@n` for the same `n` | `Hc("NfLog/Root", n ‖ mth@n)` (`n` as an 8-byte big-endian byte string, §1.7.6) | n=1 `c3b08e877ef1a527ffa95bdfca5f10f4873cd64fe3386054366799c89942ef77`<br/>n=2 `c6fd29296967409a97032133ad5f70d512c297f6cbcb4de54e783952b8c67b39`<br/>n=3 `29b58d3b4484e8d277bd0143a16d0c7e44d5ff3ccc071dc1b0f3db600b8bf538`<br/>n=4 `8f72865adf62b586e8222f4eb91cf66d0a1b9dd79038cc7b68dd28d209166921`<br/>n=5 `9119cddbad699a46d73a8dd5e6aa270d3540188539e5a7cfab783c1ef0630c48`<br/>n=7 `174c085eee8398caf1687148d4f75bb6d2bd99e427454dfa8109ccdb0478f75f`<br/>n=8 `f5c3ffe58466affc44e443d7f58aa1d12ad30686632ef52f622a9fbe8e282f92`<br/>n=9 `02e8ab8dbf3ee0f87dbf757eb7bbd989139427b415100b4a456336614ab4dca3` |
| `inclusion@(p,n)` | the RFC-6962 audit path `PATH(p, D[0:n])` recomputing `mth@n`, for exactly the closed finite set `(p, n) ∈ {(0,3),(1,3),(2,3),(0,4),(1,4),(3,4),(0,5),(2,5),(4,5),(0,8),(3,8),(7,8)}` (positions `p` encoded as 8-byte big-endian, [§1.7.6](#176-nullifier-accumulator-append-only-merkle-log)); the reference implementation MUST emit an inclusion vector for exactly these pairs | (0,3) `6dbfaac4a4e0f0ee13d112990117a3aa9d92682d43dd14a80d04e15517904be7`, `b8622bca769fe9e7e34b3435a5ccb662f5c8d323095266a0831c7279ab89f6ea`<br/>(1,3) `f93137ec4a1b7e5cee06e9f82018bb77a07ffe54b51a1f684f001b2ec31629b6`, `b8622bca769fe9e7e34b3435a5ccb662f5c8d323095266a0831c7279ab89f6ea`<br/>(2,3) `781523c7eef6bb32b4a93501f0312455e1f60a8e4ae27b9650b37e6e14845e99`<br/>(0,4) `6dbfaac4a4e0f0ee13d112990117a3aa9d92682d43dd14a80d04e15517904be7`, `deb92380fe477108e2d52da016af8c3aa4be8082a2995f82158e0990468e3a1c`<br/>(1,4) `f93137ec4a1b7e5cee06e9f82018bb77a07ffe54b51a1f684f001b2ec31629b6`, `deb92380fe477108e2d52da016af8c3aa4be8082a2995f82158e0990468e3a1c`<br/>(3,4) `b8622bca769fe9e7e34b3435a5ccb662f5c8d323095266a0831c7279ab89f6ea`, `781523c7eef6bb32b4a93501f0312455e1f60a8e4ae27b9650b37e6e14845e99`<br/>(0,5) `6dbfaac4a4e0f0ee13d112990117a3aa9d92682d43dd14a80d04e15517904be7`, `deb92380fe477108e2d52da016af8c3aa4be8082a2995f82158e0990468e3a1c`, `04dedc84f08fcc8fa0590c3f73da1c2508a18beca1ba6bb2a1dd4952c0651611`<br/>(2,5) `ca343e33072c93be82cf22efea8ee2b24be1148b64a7e4868fda4053d2ffc883`, `781523c7eef6bb32b4a93501f0312455e1f60a8e4ae27b9650b37e6e14845e99`, `04dedc84f08fcc8fa0590c3f73da1c2508a18beca1ba6bb2a1dd4952c0651611`<br/>(4,5) `6e223c78305f2aa63bc2b59f645f595767dd08adfa263a65fd956f072461bad3`<br/>(0,8) `6dbfaac4a4e0f0ee13d112990117a3aa9d92682d43dd14a80d04e15517904be7`, `deb92380fe477108e2d52da016af8c3aa4be8082a2995f82158e0990468e3a1c`, `30a878fb87d3bfb5b9dde282459cfbe95d62065acc8f324640f7583d7d9ff469`<br/>(3,8) `b8622bca769fe9e7e34b3435a5ccb662f5c8d323095266a0831c7279ab89f6ea`, `781523c7eef6bb32b4a93501f0312455e1f60a8e4ae27b9650b37e6e14845e99`, `30a878fb87d3bfb5b9dde282459cfbe95d62065acc8f324640f7583d7d9ff469`<br/>(7,8) `a8c07f1809b531ef558023f260529df2c1ea1b081c2dd9dcde679e85f0e25403`, `e7b262beb1d085e7e098a5113bcefb18984d0a5f10ec5fab7fe703357e9d8f38`, `6e223c78305f2aa63bc2b59f645f595767dd08adfa263a65fd956f072461bad3` |
| `consistency@(m,n)` for `(m,n) ∈ {(1,2),(3,4),(5,8),(7,8),(8,9)}` | the RFC-6962 `PROOF(m, D[0:n])` recomputing both `mth@m` and `mth@n` | (1,2) `6dbfaac4a4e0f0ee13d112990117a3aa9d92682d43dd14a80d04e15517904be7`<br/>(3,4) `b8622bca769fe9e7e34b3435a5ccb662f5c8d323095266a0831c7279ab89f6ea`, `ca343e33072c93be82cf22efea8ee2b24be1148b64a7e4868fda4053d2ffc883`, `781523c7eef6bb32b4a93501f0312455e1f60a8e4ae27b9650b37e6e14845e99`<br/>(5,8) `04dedc84f08fcc8fa0590c3f73da1c2508a18beca1ba6bb2a1dd4952c0651611`, `95de696c30fa370019f764a73be549c27072d7ac8a544fc4cf31b37729c897c1`, `d993b5b7af65b72fecab240a7ce110534e4fba3eaa741d9b2e71a637993594bc`, `6e223c78305f2aa63bc2b59f645f595767dd08adfa263a65fd956f072461bad3`<br/>(7,8) `a8c07f1809b531ef558023f260529df2c1ea1b081c2dd9dcde679e85f0e25403`, `6f47eeefe4ed6f140b0bc291c85d50664f81cffffe8c60a344a2438ce04d1f68`, `e7b262beb1d085e7e098a5113bcefb18984d0a5f10ec5fab7fe703357e9d8f38`, `6e223c78305f2aa63bc2b59f645f595767dd08adfa263a65fd956f072461bad3`<br/>(8,9) `0da207c4228e161d9e0af8fa0722b9e812db48c14170659a7a168dbd3405c218` |

**Generated log-boundary suite (normative — every `k = 0…63`; symbolic subtree roots, no full leaf materialisation).** A conforming reference implementation **MUST** generate and differential-test this suite against an independent RFC-6962 reference of the **same split-/peak-bagging interface**; the SDK **MUST** reproduce the same Accept/Reject structure (V.7 parity matrix). The suite **does not** materialise all leaves of a size-`n` log. For each case it supplies the **O(log n) boundary subtree roots** that the gadget's top-run (and interior-run) splits consume — as **fixture inputs** (Poseidon `HashOut` digests, hence `<REGEN>`) — together with the claimed sizes and the expected Accept/Reject. Evaluating `MTH(D[0:n])` from scratch over `n ≈ 2⁶³` independent leaves is **out of scope** and **MUST NOT** be required of the harness.

- **Capacity filter.** A boundary size `n` is in scope **iff** `0 ≤ n ≤ 2^{H_MAX} − 1` with `H_MAX = 64` ([§2.5](#25-circuit-dimensioning-normative)) — i.e. `n ≤ 2⁶⁴ − 1`. For every integer `k ∈ {0,…,63}` the three critical sizes `n ∈ {2ᵏ−1, 2ᵏ, 2ᵏ+1}` that satisfy the filter are in scope (all three for every such `k`).
- **Fixture shape per case (normative).** Each boundary case is a tuple `(size, subtree_roots[])` where `subtree_roots` is the ordered list of the **O(log n)** RFC-6962 peak / boundary subtree digests the honest split decomposition of a log of that `size` would bag into `mth` (exactly the nodes a consistency or inclusion witness consumes at that size — never the full leaf array). Concrete digest bytes are `<REGEN>` (Poseidon-dependent). The independent reference and the in-circuit gadget are fed the **same** fixture roots.
- **Per `k` — Accept cases.** For each `k ∈ {0,…,63}` and each in-scope boundary size among `{2ᵏ−1, 2ᵏ, 2ᵏ+1}`:
  - **honest inclusion split** at representative positions when `n ≥ 1` (first `p = 0`, last `p = n − 1`, and when `n ≥ 2` the power-of-two boundary `p = 2^{⌊log₂(n − 1)⌋}`): given the fixture subtree roots for size `n`, the gadget **MUST Accept** an honest PATH decomposition (correct pivot at every run, correct left/right bagging order).
  - **honest consistency** for adjacent pairs `(m, n) ∈ {(2ᵏ−1, 2ᵏ), (2ᵏ, 2ᵏ+1)}` when both sizes are in scope: given the fixture subtree-root lists for `m` and `n`, the gadget **MUST Accept** an honest `PROOF(m, ·)` / `SUBPROOF` decomposition recomputing both heads. (`m = 0` remains the trivial empty-log prefix witness of [§3.7](#37-the-nullifier-accumulator).)
- **O(log n) cost (normative claim, adjusted).** Because high-`k` cases consume only the fixture's O(log n) subtree roots — not Θ(n) leaf hashes — each Accept/Reject check is **O(log n)** field operations (bounded by `≤ 2·H_MAX` / `≤ H_MAX` slots of the unrolled gadgets, [§2.5](#25-circuit-dimensioning-normative)). The hand-listed smoke set remains the only place that fully materialises a small log.
- **Boundary-suite negatives (normative — each MUST be rejected).** For **every** in-scope boundary size `n ≥ 2` (and, where a pair is required, every adjacent consistency pair above), each of the following mutations of the **fixture-fed** witness **MUST** be rejected by both the independent RFC-6962 reference and the in-circuit gadget:

| # | Case | Expected |
|---|---|---|
| NL-B1 | **faulty split / wrong pivot** — a consistency or inclusion witness whose top-run (or an interior-run) split uses a **wrong pivot** `k' ≠` the largest power of two strictly less than the run length (false tree decomposition), with fixture roots otherwise held fixed | **reject** |
| NL-B2 | **faulty peak-/subtree-bagging / wrong order** — a consistency witness that reorders, drops, duplicates, or wrongly summarises the fixture's subtree roots that bag into `mth_a` / `mth_b` (wrong order or wrong combination of the O(log n) peaks) | **reject** |

**Negative controls — general (normative — each MUST be rejected; hand-listed materialised logs suffice).**

| # | Case | Expected |
|---|---|---|
| NL-1 | a consistency proof between `(m, mth_a)` and `(n, mth_b)` where `mth_a` is **not** the head of the first `m` leaves of the canonical `mth_b` (one interior node flipped) | consistency **fails** |
| NL-2 | an inclusion proof for `(Pk, R')` at position `p` whose canonical content at position `p` is `(Pk, R)` with `R' ≠ R` | inclusion **fails** (the audit path recomputes a different `mth`) |
| NL-3 | an inclusion proof replayed at a position `p' ≠ p` | fails (position is bound in the leaf) |
| NL-4 | a claimed `size' > size` with a fabricated tail | consistency to the canonical root fails |
| NL-5 | an inclusion at `p ≥ size` | rejected |
| NL-6 | a fork-loser `(Pk, R_loser)` (`Pk` first-occurs at position `q` with winner `R_winner ≠ R_loser`) authenticated at any position + lifted to canonical | unsatisfiable (no canonical position holds `(Pk, R_loser)`) |
| NL-7 | a `nav` authenticating a position `≥ size_final` (not-yet-final) presented for crediting | **rejected** — no valid `nav` exceeds `size_final` (§2.3.2 step 5, §3.9); the credit MUST be refused |

**Acceptance (V.11).** Pass iff: (i) every hand-listed positive vector matches the pinned bytes; (ii) the generated log-boundary suite covers every in-scope `(k, n)` / inclusion / adjacent consistency case above, Accepts every honest fixture-fed witness, and never requires Θ(n) leaf materialisation for high `k`; (iii) every NL-1–NL-7 and every NL-B1–NL-B2 case Rejects; (iv) node and SDK agree on Accept/Reject (and on hand-listed pinned paths) per the V.7 parity matrix. This acceptance is the executable form of the [§1.7.8](#178-reference-instantiation-status-final-for-v1) freeze differential-test and the D-05 release gate.

### V.12 Kind-0 zkCoins profile and NIP-17 interoperability

This group tests the [§7.3](#73-nostr-event-kinds-normative) standard kind-0 profile, the §4.3 three-check payment binding, DNS-resistant known-contact behavior, and real NIP-17 interoperability. Structural and SHA-256 parts are pinnable; Poseidon-dependent `nk_commit` and `address` are those of V.4 / V.2 (produced by the reference implementation).

**Positive profile (accept).** The fixture consists of:

- a NIP-05 response whose `names.alice` is the lowercase-hex `op_pubkey` and whose `relays[op_pubkey]` is a non-empty relay array;
- a valid kind-0 event authored and signed by that `op_pubkey`, with `content.nip05 = "alice@example.com"`;
- a valid kind-10050 event authored and signed by that `op_pubkey`, with empty `content` and at least one valid `relay` tag;
- successful original-hostname-authenticated TLS connections and successful WebSocket relay upgrades on the original URL paths for every profile/discovery and kind-10050 relay endpoint the fixture retains;
- `content.zkcoins` = exactly `{version, network, address, pk0, nk_commit, ivpk, relays, addr_sig, name_sig}`, with `version = 1`, the harness network, valid Bech32m `address`, 32-byte lowercase-hex `pk0`/`nk_commit`/`ivpk`, a non-empty relay array, and 64-byte lowercase-hex `addr_sig` and `name_sig`;
- `H(pk0 ‖ nk_commit) == address`;
- `addr_sig` valid under `pk0` over the profile-fixed `invoice_message` (`amount = 0`, all-zero `asset_id`, empty `memo`, kind-0 author as `op_pubkey`);
- `name_sig` valid under `pk0` over `name_message` for the fixture's resolved name ([§4.3](#43-addressing-for-delivery) *Name consent*).

A conforming consumer **MUST** accept the profile after the NIP-05 match and checks (i)–(iv), construct an `nprofile` from the author and only the union relays that returned valid relevant events, and retain the §4.3 minimum contact information. A profile without a valid `zkcoins` object — an ordinary Nostr peer rather than a zkCoins wallet — **MUST** still be a fully valid NIP-17 correspondent; only zkCoins payment through that profile is unavailable.

**Standard NIP-05 without `relays` (accept).** A second positive fixture omits the optional `relays` attribute entirely (an empty attribute exercises the same path). The harness configures ordinary Nostr profile/discovery relays, including at least one Bootstrap Manifest seed relay. Using only standard NIP-01 filters for `authors: [op_pubkey]` and kinds `0` and `10050`, the consumer **MUST** find a valid reverse-matching kind 0 and a valid kind 10050 on those relays, complete original-hostname-authenticated TLS and the relay WebSocket upgrade on the relevant original paths, construct an `nprofile` with at least one hint from the relays that delivered those valid events, retain the successful endpoints, and enable NIP-17. It **MUST NOT** require NIP-65, a custom endpoint, kind, tag, or zkCoins metadata. Failure to find either required event leaves the identity not ready and **MUST NOT** trigger SMTP or NIP-04 fallback.

**Hint/discovery union (accept).** A third positive fixture includes a non-empty `relays[op_pubkey]` hint that returns the valid reverse-matching kind 0 but no kind 10050; a configured profile/discovery relay outside the NIP-05 hint list returns the valid kind 10050. The consumer **MUST** query the union, accept the identity, and construct its `nprofile` only from the relays that returned either valid relevant event. A hinted relay that returns no valid kind-0 or kind-10050 event is excluded from the constructed `nprofile`.

**Name loss survivability (accept).** A fourth fixture starts from an established contact — name resolved, kind-0 and kind-10050 verified, `op_pubkey` and payment identity pinned, endpoints retained — then makes that name permanently unresolvable: the NIP-05 response 404s and DNS for the domain fails. The consumer **MUST** keep the contact, its conversation, its pinned payment identity, and its retained transport; **MUST** stop presenting that name — a 404 from the provider is a completed lookup that answers *no*, which is evidence, unlike a DNS or network failure that answers nothing (`M-16b`); and **MUST** still complete NIP-17 in both directions and a payment against the pinned identity, with **zero** successful NIP-05 requests. It **MUST NOT** delete, merge, re-pin, or re-verify the contact.

**Name consent (accept + reject).** A fifth fixture resolves a name whose kind-0 carries a `name_sig` valid under `pk0` over `name_message`; the consumer **MUST** accept the name for that identity. Three variants **MUST** be rejected as unattested, leaving any previously stored name in force: `name_sig` absent; `name_sig` valid but over a *different* name than the one resolved; and `name_sig` verifying under `op_pubkey` rather than `pk0` — the case a node-held key could produce on its own.

**Name-consent framing vector (pinned).** The semantic fixture above passes even when signer and verifier share the *same wrong* encoding, so the byte layout is fixed separately here. The inputs are the [V.2-ext](#v2-address-derivation-sha-256--bech32m--pinned) chain (`sk₀`, `pk0`, `op_pubkey`), `network = "regtest"`, and the normalized name `alice@example.com`. The preimage and digest below are produced by the reference implementation, not hand-computed.

| Value | Definition | Pinned |
|---|---|---|
| `name_len` | canonical **UTF-8 byte length** of the normalized name, not its character count | `17` (`0x00000011` big-endian) |
| `name_message` preimage | `"zkCoins/v1/NameConsent"` ‖ `network` ‖ `u32-be name_len` ‖ UTF-8 name ‖ `op_pubkey`, raw bytes in that order | 82 bytes: `7a6b436f696e732f76312f4e616d65436f6e73656e74` (`"zkCoins/v1/NameConsent"`, 22 B)<br/>‖ `72656774657374` (`"regtest"`, 7 B)<br/>‖ `00000011` (`name_len = 17`, 4 B)<br/>‖ `616c696365406578616d706c652e636f6d` (`"alice@example.com"`, 17 B)<br/>‖ `6424b41eea59c6a3aa6169b802c96ff5194962d3bf5f941130e4ebc86de3b485` (`op_pubkey` = x-only(`op`·G) for the V.2-ext `op`, 32 B) |
| `name_message` | `SHA-256(preimage)` | `54f9b1c65b6ca9065c758591a3ba50316229fa2b7a81a20dc2c52824b80cc497` |
| `name_sig` | `BIP-340(sk₀, name_message)` | `<REGEN — verified, not byte-compared: BIP-340 nonce derivation includes auxiliary randomness>` |

A harness **MUST** reproduce the preimage and its digest **byte-for-byte** against the pinned values, and **MUST** verify `name_sig` under `pk0` rather than comparing its bytes — the same rule the V.5/V.6 signature vectors use. `name_sig` therefore stays `<REGEN>` by construction and **MUST NOT** be pinned. The name fed to the framing **MUST** first be lowercased and then validated against the *Identifier syntax* of [§4.3](#43-addressing-for-delivery); framing a name that fails that grammar is an error, not a value to be sanitized ([Implementation Mandate](/implementation-mandate) §4).

Four mutations **MUST** each fail verification and **MUST** be tested individually: a different `network` string; `name_len` serialized little-endian; `name_len` off by one in either direction; and `op_pubkey` replaced by another valid key. A fifth control feeds the **un-normalized** input `Alice@Example.COM`: normalization per [§4.3](#43-addressing-for-delivery) **MUST** produce the identical preimage and digest as the normalized name above, so a producer that skips normalization fails. A character-count mutation is deliberately absent: the [§4.3](#43-addressing-for-delivery) identifier grammar admits only ASCII, so byte count and character count coincide for every conforming name and the case is unreachable.

**Producer-side name obligation (accept + reject).** An app or API layer that serves an account **MUST NOT** report setup complete, or the account ready, until it has published a kind-0 event carrying both the account's `nip05` and a `zkcoins` object whose `name_sig` verifies under that account's own `pk0` ([§4.3](#43-addressing-for-delivery), [Implementation Mandate](/implementation-mandate#app-layer-identity-and-contacts-normative)). A harness **MUST** drive setup to completion and assert the published event; and **MUST** assert that a build which completes setup with no name, with no `zkcoins` object, or with an unverifiable `name_sig` **fails** this vector. Every other V.12 fixture is consumer-side; this is the only one that tests what a conforming producer emits.

**Publisher profile (accept + reject).** A sixth fixture is a kind-30421 event whose `content` is exactly `{version: 1, relays: […]}` with a non-empty relay array, carrying a `d` tag equal to the hex `op_pubkey`, and signed by an `op` key equal to both that tag and the event `pubkey`. Paired with a kind-30422 `OperatorEndpointV1` under the same key, a spender **MUST** accept it, resolve the hand-off base URL from that endpoint event, and hand off fee-lessly over REST **without** fetching any kind-0 event, resolving any name, or making any DNS request — the control that publishing needs an `op` key, a relay presence, and an HTTP endpoint — and no zkCoins account, payment address, or wallet. Six variants **MUST** be rejected: an invalid event signature; a `pubkey` differing from the signing key; an absent `d` tag; a `d` tag differing from the author; an empty or absent `relays` array; and a kind-30422 endpoint event whose author differs from the profile's author, which **MUST** yield `unknown_publisher` rather than a hand-off to the substituted endpoint. A seventh variant carries any of the deferred fee fields (`fee_address`, `fee_asset_id`, `fee`, `pk0`, `nk_commit`, `ivpk`, `addr_sig`) and **MUST** be rejected as not-v1 under the closed field list of [§7.3](#73-nostr-event-kinds-normative), never silently ignored.

**Payment negatives (P-01–P-07 each MUST disable payment for the profile; P-08–P-09 MUST block the silent change or use of a pinned payment identity; P-10 MUST treat absence of a pin despite prior evidence as first use with a warning).**

| # | Case | Expected |
|---|---|---|
| P-01 | `zkcoins` omits `nk_commit`, `address`, or another required object field | payment profile rejected — required binding input missing |
| P-02 | `H(pk0 ‖ nk_commit) ≠ address` | payment profile rejected — check (i) fails |
| P-03 | `addr_sig` verifies under another key or over a non-profile-fixed `invoice_message` | payment profile rejected — check (ii) fails |
| P-04 | kind-0 signature is invalid or the event author differs from the NIP-05-mapped `op_pubkey` | profile rejected — check (iii) / NIP-05 binding fails |
| P-05 | empty `relays`, wrong hex widths/case, invalid Bech32m, or `addr_sig` is not 64 decoded bytes | payment profile rejected — malformed object |
| P-06 | kind-0 `nip05` does not equal the normalized identifier | identity/profile rejected — reverse NIP-05 check fails |
| P-07 | `version != 1` or `network` differs from the active network | payment profile rejected — unsupported or wrong network |
| P-08 | kind-0 verifies (signature valid, checks (i)–(iii) pass) under a contact's already-pinned `op_pubkey`, but `zkcoins.address` (or `pk0`/`nk_commit`/`ivpk`) differs from the pinned values for that already-pinned contact | payment update rejected — warn, do not adopt silently; the pinned payment identity remains in force ([§4.3](#43-addressing-for-delivery) *Payment-identity pinning*) |
| P-09 | `Invoice.sig` verifies (checks (i)–(iii) pass) under a contact's already-pinned `op_pubkey`, but `recipient` (or `pk0`/`nk_commit`/`ivpk`) differs from the pinned values for that already-pinned contact | payment rejected — warn, do not pay silently; the pinned payment identity remains in force ([§4.3](#43-addressing-for-delivery) *Payment-identity pinning*) |
| P-10 | client holds prior evidence of an earlier relationship with a NIP-05 identifier (a retained contact entry or its own payment history) but holds no payment-identity pin for that identifier; a payment to that identifier is initiated | treated as first use — warn before payment; **MUST NOT** present the contact as previously verified ([§4.3](#43-addressing-for-delivery) *Payment-identity pinning*) |

| P-11 | a profile passes checks (i)–(iii) and the field-shape rules, but the account has published **no** valid kind-10050 event | **payment succeeds** — payment resolution is not gated on messaging readiness; only NIP-17 fails closed ([§4.3](#43-addressing-for-delivery) *Payment readiness and messaging readiness are separate*) |

Rejecting only the `zkcoins` object in P-01–P-03/P-05/P-07 **MUST NOT** turn off standard NIP-17 messaging when the Nostr identity and kind-10050 event remain valid. Symmetrically, P-11 **MUST NOT** turn off payment because messaging is not ready.

**NIP-05/NIP-17 negative controls (each MUST reject exactly as stated).**

| # | Case | Expected |
|---|---|---|
| M-01 | outer kind-1059 `id` does not equal its recomputed event hash, or its signature is invalid | discard before decryption; no display, notification, state mutation, reply, or fallback |
| M-02 | outer kind-1059 has no recipient `p`, its sole recipient `p` names another key, or it contains any additional recipient `p` | discard before decryption with the same no-side-effect behavior; sender-copy validation applies the same rule with the local sender as receiver |
| M-03 | decrypted kind-13 seal has a wrong recomputed `id` or invalid signature | discard before rumor decryption; no side effect or fallback |
| M-04 | kind-13 seal `tags` is not exactly empty | discard before rumor acceptance; no side effect or fallback |
| M-05 | rumor contains any `sig` field | discard as a signed, non-NIP-17 rumor; no side effect or fallback |
| M-06 | rumor `id` differs from the ordinary Nostr hash recomputed from its fields | discard; no side effect or fallback |
| M-07 | kind-13 seal `pubkey` differs from rumor `pubkey` | discard as an impersonation attempt; no side effect or fallback |
| M-08 | one-to-one rumor lacks its required recipient `p`, names the wrong recipient/counterparty, or contains any additional recipient `p`; or a retained sender copy has `seal.pubkey = rumor.pubkey` but that author is not the local `op_pubkey` | discard; no conversation creation/update, display, notification, reply, or fallback |
| M-09 | a send plan includes any relay outside the latest valid kind-10050 set for that receiver copy | abort that publish attempt before every network write to the invalid destination; do not guess another relay or protocol |
| M-10 | the NIP-05 `/.well-known/nostr.json` response is an HTTP redirect | do not follow it; reject first discovery/revalidation and leave all existing pins unchanged |
| M-11 | outer `content` is malformed NIP-44 ciphertext or outer decryption fails | discard before seal parsing; no side effect or fallback |
| M-12 | outer kind is not 1059; or decrypted outer plaintext cannot be parsed as an event or has a kind other than 13 | discard at the failing layer; do not attempt the next decrypt or mutate state |
| M-13 | seal `content` is malformed NIP-44 ciphertext, seal decryption fails, or decrypted rumor plaintext cannot be parsed as an event | discard before rumor validation; no side effect or fallback |
| M-14 | parsed rumor kind is not 14, `created_at` is missing, or `content` is not a non-empty plain-text UTF-8 string | discard before display/storage; no side effect or fallback. A conforming consumer **MUST** accept ordinary human text here and **MUST NOT** require JSON-shaped content or apply `JSON.parse` to it — a control case carries the plain text `hello 👋` and **MUST** be accepted |
| M-15 | the two published copies of one message share a seal ciphertext, or the sender copy's seal is encrypted to the recipient rather than to the sender | reject the construction — each copy **MUST** be an independent seal-and-wrap to its own outer `p` ([§7.3](#73-nostr-event-kinds-normative)); a producer that emits this fails V.12 |
| M-16 | a verified kind-0 under an already-pinned `op_pubkey` carries a **different** `nip05` value | **not** a security event — adopt the new name **only** once **both** the event's `name_sig` verifies under the pinned `pk0` over that name **and** a forward NIP-05 resolution of it returns the pinned `op_pubkey`. A profile whose `name_sig` fails keeps the stored name in force. A `name_sig` that verifies while the forward check is unavailable retires the old label and shows the contact **unresolved**, presenting neither name. In every outcome the pinned key, payment identity, conversation, and retained transport are untouched; the client **MUST NOT** unpin, duplicate, delete, or re-verify the contact ([§4.3](#43-addressing-for-delivery) *Name changes*) |
| M-16b | a name lookup **cannot complete** — DNS failure, timeout, TLS failure — with no newer profile superseding the name | **not** a security event and **not** evidence of a change: an answer was never received, so the client keeps that last confirmed name in force and continues presenting it ([§4.3](#43-addressing-for-delivery)). This is distinct from a lookup that **completes and disagrees** — a 404, or a mapping to a different key — which stops presentation per the reverse-check outcomes of [§4.3](#43-addressing-for-delivery) and `M-17`. Messaging, payment, and retained transport continue against the pinned identity throughout, and the client **MUST NOT** unpin, duplicate, delete, or re-verify the contact |
| M-17 | the same name now resolves to a **different** public key | treat as a different contact; **MUST NOT** replace or re-point the pinned contact, and **MUST NOT** attach the name to the pinned record |

**Live interoperability matrix (evaluated at the `app`/SDK layer).** Everything above is a protocol **wire** vector, reproducible offline by node and SDK. The matrix below is different in kind: it exercises third-party software this project does not control, so it is an application-layer release check ([Implementation Mandate](/implementation-mandate#app-layer-identity-and-contacts-normative)), not a protocol conformance vector.

Before every release, bidirectional one-to-one text messaging is exercised against the then-current stable versions of all four clients, and the tested version and pass/fail result of each **MUST** be recorded:

| Client | Required platform |
|---|---|
| Primal | stable web or mobile build |
| Amethyst | stable Android build |
| Damus | stable iOS build |
| 0xchat | stable mobile build |

A failure **blocks the release when it is attributable to zkCoins** — that is, when the same exchange also fails between two zkCoins endpoints, or when the captured events deviate from the wire vectors above. A failure that reproduces against a **non-zkCoins** Nostr counterpart is an external client defect: it **MUST** be recorded and reported upstream, and **MUST NOT** block the release. For each client, verify all of the following:

1. The external client discovers the zkCoins identity through its email-style NIP-05 identifier.
2. The external client obtains kind 10050 and sends a NIP-17 message that the zkCoins stack receives.
3. The zkCoins stack discovers the external identity through NIP-05, obtains kind 10050, and sends a message that the external client receives.
4. Both sides can reply in the same one-to-one conversation.
5. Captured events show a kind-14 rumor with plain-text `content` and exactly one recipient `p`, NIP-44 v2, kind-13 seal, kind-1059 gift wrap, kind-10050 relay selection, and separate sender/recipient copies that are independently sealed — distinct seal ciphertexts and distinct fresh one-time outer `pubkey` values.
6. The external client uses no zkCoins endpoint, event kind, tag, profile field, or bridge.
7. No kind-4/NIP-04 event or unnoticed NIP-04 fallback occurs.
**DNS-free cold start (property test, not a release gate).** Independently of any external client, a conforming stack **SHOULD** demonstrate the [§4.3](#43-addressing-for-delivery) retained-endpoint behavior: after a contact and its successful relay endpoints are retained, close every WebSocket, terminate and restart the process, empty or block resolver and application DNS caches, and load only the persistent §4.3 contact/transport state. Sending then succeeds by dialing an endpoint retained only after original-hostname-authenticated TLS **and** a successful relay WebSocket upgrade, preserving the original scheme, hostname, port, and path for TLS SNI, certificate verification, WebSocket `Host`, and the upgrade request, with zero DNS and zero NIP-05 requests and TLS verification neither disabled nor replaced by IP-certificate validation. This exercises a deployment-level continuity property ([§6.3](#63-node-portability-and-multi-node-operation) residual), not a protocol guarantee: a stack whose retained endpoints have all expired is degraded, not non-conforming. The **name-loss survivability** fixture above is the mandatory control for the same property, and it does depend on the retained, original-hostname-authenticated endpoints it starts from — that dependency is the §4.3 boundary, not an omission.

**Acceptance (protocol wire vectors — mandatory):** accept all three positive NIP-05 variants, the **name-loss survivability** fixture, the **name-consent** fixture, its **framing vector** with all four mutations rejected and the normalization control accepted, the **producer-side name obligation**, and the **publisher-profile** fixture; reject P-01–P-07 with the named scope; block the silent change or use of a pinned payment identity in P-08–P-09; treat P-10 as first use with a warning; complete payment in P-11; reject M-01–M-15 with the named scope and handle M-16, M-16b, and M-17 exactly as stated; pass the independent-seal and distinct-wrapper-key assertions.

**Acceptance (application interop — release check):** every live test passes in both directions with Primal, Amethyst, Damus, and 0xchat, or each failure is recorded and shown to reproduce against a non-zkCoins counterpart. A failure attributable to zkCoins blocks the release; an external client defect does not.
