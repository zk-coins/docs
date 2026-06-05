---
title: Learnings — Bitcoin Asset Overlays
---

# Learnings — Bitcoin Asset Overlays

The "issue assets on Bitcoin" lineage — Colored Coins / Open Assets, Counterparty, Omni Layer, and the modern Ordinals / Runes / BRC-20 family — solved problems zkCoins still faces: how to mark protocol data on Bitcoin so a scanner can find it cheaply, how to register and mint asset types without a new chain, and how to run a public indexer/explorer over purely on-chain commitments. Their issuance schemes are directly relevant to the **S5 trustless emission** gap, their indexer designs to the **public explorer** gap, and their marker/encoding conventions to **on-chain footprint + scanning**.

The hard caveat up front: **every one of these overlays is fully transparent.** Amounts, asset IDs, sender/recipient outputs, and full provenance are published in the clear and reconstructed by any indexer. That is the *opposite* of what zkCoins is. So we mine these protocols for *mechanism* — marker bytes, varint packing, mint-terms grammar, reorg-aware indexing — and explicitly reject anything that assumes the ledger is public. Nothing about their balance models, edict/transfer semantics, or explorer "show me account X's holdings" UX transfers, because in zkCoins coin data lives off-chain behind ZK proofs and the only public artifact is an opaque commitment with the `4242` marker.

## Omni Layer (ex-Mastercoin)

**How it works** — Omni is a metadata layer on Bitcoin: token instructions ("Simple Send", `CREATE_PROPERTY`, DEx orders) are embedded in Bitcoin transactions, most commonly as a Class C OP_RETURN payload that Omni-aware software parses while plain Bitcoin nodes ignore it ([cryptoapis.io](https://cryptoapis.io/blog/89-what-is-omni-layer-and-how-does-it-work), [OmniLayer/spec](https://github.com/OmniLayer/spec)). Each asset ("property") gets a unique integer Property ID (e.g. USDT-Omni = 31) and can be issued with **fixed supply** or **managed supply** (issuer can mint/burn), with configurable decimal precision; creating a property is intentionally free of protocol fees to lower the barrier to entry ([cryptoapis.io](https://cryptoapis.io/blog/89-what-is-omni-layer-and-how-does-it-work)). The OP_RETURN budget is tight — ~80 bytes total, of which a few are the Omni marker, leaving roughly 76 for the payload ([cryptoapis.io](https://cryptoapis.io/blog/89-what-is-omni-layer-and-how-does-it-work)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Integer Property ID registry | Each asset type is a compact monotonic integer with a registration tx, queryable on explorers | zkCoins is going multi-asset and needs a stable, compact `asset_id` namespace; an integer minted by a registration transaction is the cheapest possible identifier to carry in proofs/commitments | S5 | High | Med |
| Fixed vs. managed supply flag at issuance | One bit/field at creation decides whether supply is capped forever or issuer-mintable | Gives S5 a clean policy axis (cap-once vs. ongoing emission) decided *at issuance time* and bound into the asset's genesis commitment | S5 | High | Med |
| Marker-aware passive scanning | Omni-aware parsers scan every block for the Omni marker; non-aware nodes treat the tx as ordinary | Validates zkCoins' `4242`-marker scan model and the "ignored by Bitcoin, meaningful to the node" pattern | Scanning | High | Low (already aligned) |

**Doesn't transfer**
- Omni balances are a **public ledger** keyed by Bitcoin address; the entire point of zkCoins is that no such ledger exists on-chain. Do not import its balance-tracking model.
- "Managed supply" in Omni means the issuer **publicly** mints/burns visible amounts. For zkCoins, any emission must be a value-hiding mint *inside* a proof, not a transparent supply-change transaction.
- USDT-on-Omni style centrally-issued, issuer-controlled tokens are a trust model zkCoins explicitly rejects for S5 (the goal is trustless emission, not a node/issuer signing mints off-circuit).

## Counterparty (XCP)

**How it works** — Counterparty embeds messages into Bitcoin transactions behind an eight-byte ASCII marker **`CNTRPRTY`** (hex `434e545250525459`), historically via 1-of-3 bare multisig, later OP_RETURN, with payloads **RC4-scrambled** by a key derived from the first input txid ([jpjanssen.com](https://jpjanssen.com/compressed-xcp-transactions/)). It pioneered an **on-chain DEX**, **broadcasts/feeds** (an oracle primitive: a signed feed can later resolve escrowed bets/CFDs), and bets, all encoded as typed messages ([Counterparty docs](https://docs.counterparty.io/docs/basics/what-is-xcp/), [counterparty-lib #272](https://github.com/CounterpartyXCP/counterparty-lib/issues/272)). Asset issuance distinguishes **numeric assets** (format `A` + a large number, free, no XCP) from **named assets** (human-readable, require burning XCP to register the name); the native XCP itself was created by **proof-of-burn** of BTC in early 2014, giving founders no premine ([Counterparty docs](https://docs.counterparty.io/docs/basics/what-is-xcp/)). A "compressed" variant uses a 3-byte `XCP` prefix and run-length encoding to squeeze repeated zero-bytes, saving 6–67% depending on message type ([jpjanssen.com](https://jpjanssen.com/compressed-xcp-transactions/)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Free numeric / costly named asset tiers | Numeric IDs are free; reserving a human-readable name costs a burn | A Sybil/spam control for S5 issuance: anyone can mint a *numeric* asset cheaply, but a scarce human-readable namespace is rate-limited by a provable cost | S5 | Med | Med |
| Proof-of-burn genesis (no premine) | XCP came into existence only by destroying BTC, with no founder allocation | A credibly-neutral, founder-free emission anchor for an asset's genesis — the *fairness* property S5 wants, achievable on Bitcoin with no new chain | S5 | Med | Research |
| Compact run-length / zero-byte compression | RLE over the structurally-zero regions of the message before inscribing | zkCoins inscribes ~177 B today; structured commitment fields likely have low-entropy regions that compress, shrinking on-chain footprint toward the paper's ~64 B target | On-chain-encoding | Med | Med |
| Distinct, namespaced ASCII marker | A fixed protocol marker (`CNTRPRTY`) makes scanning unambiguous and collision-resistant | Reinforces choosing a marker wide enough to avoid cross-protocol collisions; note Counterparty/Omni collision risk is cited as ~1-in-16M — argues for a longer marker than 2 bytes | Scanning | Med | Low |

**Doesn't transfer**
- The **on-chain DEX, feeds/oracles, and bets** all publish prices, amounts, and counterparties in the clear. None of this transfers — an oracle/feed that resolves a public condition is fundamentally incompatible with a shielded design.
- RC4 "scrambling" is **obfuscation, not encryption** — it provides zero privacy and exists only to avoid accidental parsing. Do not mistake it for a confidentiality mechanism.
- Counterparty's asset balances and issuance events are a public ledger; only the *gating mechanism* (cost to register, proof-of-burn genesis) is interesting, not the transparent accounting.

## Colored Coins / Open Assets

**How it works** — The earliest issuance schemes "colored" specific satoshis to represent assets. The dominant standardized form, **Open Assets (OAP/1.0)**, replaced literal satoshi-coloring with an OP_RETURN **marker output** tagged `0x4f 0x41` ("OA"), a 2-byte version, then a LEB128-encoded asset-quantity list and a metadata field ([Open Assets spec](https://github.com/OpenAssets/open-assets-protocol/blob/master/specification.mediawiki)). Positional semantics carry the meaning: **outputs *before* the marker are issuance outputs, outputs *after* are transfer outputs**, and the marker output is always uncolored ([Open Assets spec](https://github.com/OpenAssets/open-assets-protocol/blob/master/specification.mediawiki)). Asset IDs are derived deterministically as `RIPEMD160(SHA256(first_input_script))`, and a coloring algorithm flows asset units positionally from the input sequence to the output sequence ([Open Assets spec](https://github.com/OpenAssets/open-assets-protocol/blob/master/specification.mediawiki)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| LEB128 quantity packing | Variable-length integers (1–9 bytes) for amounts, identical to Protobuf varints | A well-specified, byte-minimal way to pack the integer fields zkCoins must encode (e.g. asset IDs, counts) inside a constrained inscription budget | On-chain-encoding | Med | Low |
| Deterministic asset ID from genesis tx | `asset_id = hash(first_input_script)` — no registry server, the ID *is* the issuance | A trustless, server-free way to derive a globally-unique `asset_id` purely from the issuing transaction; no central allocator needed for S5 | S5 | High | Med |
| OP_RETURN marker that doesn't bloat the UTXO set | Open Assets deliberately moved off literal satoshi-coloring to OP_RETURN so as not to pollute UTXOs | Reinforces the design choice between provably-unspendable OP_RETURN (no UTXO bloat, prunable) vs. witness/inscription for zkCoins commitments | On-chain-encoding | Med | Research |

**Doesn't transfer**
- **Positional coloring semantics** (input/output ordering encodes who gets what) leak the entire transfer structure — exactly the transaction graph zkCoins hides. Reject wholesale.
- Deriving `asset_id` from the *first input script* ties the asset to a **publicly visible** Bitcoin output and its spend history. For zkCoins the genesis must be commitment-based, not output-linked, or it leaks issuance lineage.
- "Metadata linked from the blockchain and stored on the web" is a data-availability anti-pattern (link rot, centralized hosting) — zkCoins' off-chain bundle + node/relay model is already better.

## Ordinals / Runes / BRC-20

**How it works** — Two opposite design philosophies. **BRC-20** writes JSON inscriptions (`text/plain`/`application/json`) into Taproot witnesses and relies entirely on **off-chain indexers** (the `ord` software and successors like OPI) to parse, validate, and maintain balances — transfers are an awkward two-step inscribe-then-send ([best-in-slot indexer rules](https://docs.bestinslot.xyz/brc-20-indexer-rules), [OPI / DeepWiki](https://deepwiki.com/bestinslot-xyz/OPI/3-protocol-indexers)). **Runes** instead encodes everything in a single OP_RETURN **runestone** marked by `OP_RETURN OP_13`, decoded as a sequence of 128-bit integers via **LEB128 varints** parsed into **tag/value pairs**, with a tag of 0 switching to edict data ([Runes spec](https://docs.ordinals.com/runes/specification.html), [Ordinal Theory Handbook](https://docs.ordinals.com/runes.html)). Runes is **UTXO-native** (balances ride on outputs, no mandatory central indexer), and issuance ("**etching**") sets divisibility, symbol, optional **premine**, and **open-mint terms**: `Amount` per mint, `Cap` (max number of mints), and `HeightStart/End` or `OffsetStart/End` minting windows ([Runes spec](https://docs.ordinals.com/runes/specification.html)). Malformed runestones become **cenotaphs** and burn their runes — an explicit, deterministic invalid-message rule ([Runes spec](https://docs.ordinals.com/runes/specification.html)). Premine fairness is a live debate: >10% premine is widely seen as "greedy," and Rodarmor hard-coded the first runes as mint-only to prevent a VC land-grab ([ordinals.com](https://docs.ordinals.com/runes.html), [gate.com](https://www.gate.com/learn/articles/what-are-the-controversies-and-hype-behind-runes-which-is-not-ideal-for-launch/3154)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Open-mint terms grammar (`Cap` + `Amount` + height window) | Issuance declares a per-mint amount, a max mint count, and a block-height start/end window — anyone may mint within terms | A ready-made **trustless emission** schedule for S5: emission is governed by *protocol rules fixed at etch time*, not by a node signing each mint. The richest single import in this cluster | S5 | High | Research |
| `OP_RETURN OP_13` marker + tag/value LEB128 body | Single, self-describing message: marker, then varint tag/value pairs, then edicts | A clean, extensible alternative to a fixed 2-byte `4242`: tag/value lets fields be added without versioning breaks, and LEB128 minimizes bytes | On-chain-encoding | High | Med |
| Cenotaph rule (deterministic invalid-message handling) | Any malformed message is unambiguously invalid and burns its assets | zkCoins needs a crisp "this commitment is malformed → reject/ignore" rule so every honest node agrees on validity without a coordinator | Scanning | Med | Low |
| UTXO-native, indexer-optional balances | Because state rides on Bitcoin's UTXO model, many wallets can compute state without one canonical indexer | The aspiration behind "run your own node": no single privileged indexer. zkCoins' SMT+MMR node already targets this — Runes confirms the value | Explorer | Med | Research |
| Reorg-aware indexer pattern | OPI/`ord`-class indexers monitor chaintips and auto-roll-back on reorg | Directly maps to zkCoins' public-explorer/indexer mode and its existing Conditional NAV reorg handling | Explorer | High | Med |
| Premine-fairness norms | Community converged on ≤5–10% premine, "no premine" as a credibility signal, protocol-enforced fair first-mints | Gives S5 a *social/policy* template for credibly-neutral issuance, and a warning that opaque/large allocations destroy trust | S5 | Med | Low |

**Doesn't transfer**
- Runes/BRC-20 **publish every amount, ticker, mint, and transfer in the clear** and balances are reconstructed by public indexers. The entire ledger is the antithesis of shielding. Only the *encoding grammar, issuance terms, and indexer engineering* transfer.
- The **edict transfer model** (rune ID, amount, output index) encodes recipient and amount on-chain — reject; zkCoins transfers must stay inside proofs.
- A Runes/ord-style explorer that answers "what does address X hold?" cannot exist over shielded commitments. A zkCoins "explorer" can only show **opaque** per-commitment facts (marker present, inscription size, block height, count), never balances or linkage — design the explorer to that hard ceiling.
- BRC-20's reliance on a *de facto canonical* off-chain indexer to define consensus is a centralization smell; prefer the Runes lesson (push validity into rules every node can check) over the BRC-20 lesson.

## Top candidates from this cluster

1. **Open-mint terms grammar (Cap + Amount + height window) — Runes — S5 — Fit High / Effort Research.** A protocol-fixed emission schedule that lets anyone mint within rules replaces the current node-signed/off-circuit mint; the single most relevant import for trustless issuance. The open research question is binding these terms into a ZK circuit while keeping minted amounts hidden.
2. **Deterministic asset ID from genesis (no registry) — Open Assets / Omni Property IDs — S5 — Fit High / Effort Med.** Derive a compact, globally-unique `asset_id` from the issuance commitment itself (commitment-based, *not* Open Assets' output-linked hash) so multi-asset needs no central allocator.
3. **`OP_RETURN OP_13`-style tag/value + LEB128 encoding & cenotaph rule — Runes — On-chain-encoding/Scanning — Fit High / Effort Med.** A self-describing, extensible, byte-minimal message format with a deterministic invalid-message rule — a strong successor to a bare 2-byte `4242` marker; pairs with Counterparty-style zero-byte compression to push toward the ~64 B paper target.
4. **Reorg-aware indexer architecture — Runes/OPI/`ord` — Explorer — Fit High / Effort Med.** Battle-tested chaintip-monitoring + auto-rollback engineering for the public explorer/indexer mode, but scoped to *opaque* commitment facts only (no balances, no linkage).
