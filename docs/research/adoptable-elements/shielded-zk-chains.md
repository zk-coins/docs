---
title: Learnings — Shielded ZK Chains
---

# Learnings — Shielded ZK Chains

These protocols are private *and* decentralized, but each runs on its own chain, token, and security budget — so none of them transfers wholesale to zkCoins (we inherit Bitcoin's security and ship no chain or token). What *does* transfer is their cryptographic plumbing: key hierarchies that split *seeing* from *spending*, schemes for a recipient to *detect* incoming notes over an untrusted relay, and light-client constructions for trustless restore. Those three areas map almost one-to-one onto zkCoins' open gaps (two-key / view-grant model, Nostr delivery, and recovery), and are the highest-value finds in this cluster.

A standing caveat for the whole cluster: every "viewing key" or "detection key" here is derived inside that chain's own circuit and works because the chain itself is the authoritative ledger of notes. zkCoins has no such ledger — the value-bearing data lives in off-chain bundles and only opaque commitments hit Bitcoin. So these are *design patterns to re-instantiate over the zkCoins data model*, not drop-in code.

## Zcash

**How it works** — A shielded note is a commitment in a global Merkle tree; spending it publishes a nullifier (preventing double-spend) without revealing which note. Receivers find their notes by **trial-decrypting** every output's ciphertext with their incoming viewing key — shielded outputs are key-private, so a ciphertext reveals nothing about its recipient except to the holder of the right key ([zfnd scanning](https://zfnd.org/introducing-blockchain-scanning-with-zebra/), [ZIP-307](https://zips.z.cash/zip-0307)). The Sapling/Orchard **key hierarchy** derives, from one spending key, a full viewing key, separate incoming and outgoing viewing keys, and diversified addresses ([ECC viewing keys](https://electriccoin.co/blog/explaining-viewing-keys-2/), [ZIP-316](https://zips.z.cash/zip-0316)). Orchard (Halo2) removed Zcash's trusted setup.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Layered viewing-key hierarchy (spend → FVK → incoming VK / outgoing VK) derived from one seed | One spend key yields several read-only keys, each scoped to *incoming-only*, *outgoing-only*, or *both* ([ECC](https://electriccoin.co/blog/explaining-viewing-keys-2/)) | Directly models zkCoins' spend-vs-operational split and the view-grant. Today's "view grant" is a single coarse capability; Zcash shows how to scope *direction* (a node that decrypts incoming bundles needs only incoming-view authority, never outgoing) | View-keys / S1 | High | Med |
| Trial decryption of key-private ciphertexts for note discovery | Recipient scans all outputs, trial-decrypts with incoming VK; AEAD failure ⇒ "not mine" | This is exactly the "detect incoming payment over an untrusted relay" problem. A zkCoins node receiving gift-wrapped Nostr bundles can trial-decrypt with the operational key — no sender metadata needed | Note-discovery / Delivery | High | Med |
| Diversified addresses | Many unlinkable receive addresses from one key, all scanned in a single pass | Solves reusable-address linkability (today reusing the stable zkCoins address links payments) without multiplying scan cost | Addressing | High | Med |
| ZIP-321 payment-request URIs | Standard `zcash:addr?amount=&memo=` request format, parser rules, `req-` required-params ([ZIP-321](https://zips.z.cash/zip-0321)) | A ready template for zkCoins' invoice object (`{amount, recipient, asset_id}`) as a shareable URI; the `req-` convention gives forward-compatible extensibility for relay sets / asset names | UX / Addressing | Med | Low |
| ZIP-307 light-client protocol (CompactBlock + client-side trial decryption) | Server streams compact data (commitment, ephemeral pubkey, truncated ciphertext); client does all decryption/witnessing so the server never learns ownership ([ZIP-307](https://zips.z.cash/zip-0307)) | A model for the recovery/pull endpoint: serve compact candidate data, keep all matching client-side, so a cooperating-but-untrusted node learns nothing about which items are yours | Recovery / Light-client | High | High |
| Orchard / Halo2 no-trusted-setup | Recursion-friendly proofs with no ceremony | Reinforces zkCoins' existing choice (Plonky2/FRI, transparent) — a precedent, not a change | — | — | — |

**Doesn't transfer**
- Note/nullifier scheme assumes a single global ledger of all notes; zkCoins' double-spend is enforced in-circuit (per-account history SMT non-inclusion), so Zcash's nullifier *set* is not a drop-in for the S2 accumulator — only the *concept* (publish a spent-marker queryable by verifiers) transfers.
- Trial decryption scans the *whole chain*; zkCoins bundles arrive addressed (gift-wrapped to the operational key), so the cost profile differs — discovery is over a relay inbox, not an L1 scan.
- Outgoing viewing keys decrypt *your own* sends from the chain; zkCoins already re-derives its own activity from seed + the on-chain signing pubkey, so the OVK need is weaker.

## Monero

**How it works** — Every wallet has a **private view key** and a **private spend key**. The view key alone scans the chain for incoming outputs (it can prove receipts to an auditor) but cannot spend; spending needs the spend key ([monero.how](https://www.monero.how/tutorial-monero-privacy-ring-signatures-stealth-addresses-ringct)). **Stealth addresses** make the sender derive a fresh one-time output address per payment, so a published address never appears on-chain. **Subaddresses** give unlimited unlinkable receive addresses from one key set. **Dandelion++** obscures the originating IP by relaying a tx through a random "stem" of peers before broadcast. Privacy of *amounts/senders* comes from RingCT + ring signatures — a decoy set, **not** a ZK anonymity set.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| View key vs spend key split | A read-only key that scans + audits but cannot move funds | The canonical precedent for zkCoins' operational-key (read/decrypt/audit) vs spend-key (custody) two-key model — same "can see, cannot steal" property the trust model already asserts | View-keys / S1 | High | Med |
| Stealth (one-time) addresses | Sender derives a fresh per-payment output address from the recipient's static address | A way to give zkCoins reusable receiver addressing without on-chain linkage; complements diversified-address ideas | Addressing | Med | Research |
| Subaddresses | Many unlinkable labels from one key, scanned together | Per-counterparty / per-purpose receive identities without extra scanning — useful UX for the invoice layer | Addressing / UX | Med | Med |
| Dandelion++ origin hiding | Random stem relay before broadcast hides the originating peer/IP | The transport-layer caveat in zkCoins' Nostr design ("a relay exposes IP") maps to this: a stem-style or Tor-fronted publish path before a bundle reaches the wider relay mesh | Delivery / Anti-spam | Med | Med |

**Doesn't transfer**
- Ring-signature / RingCT privacy is a *decoy ring of 16*, statistically attackable — strictly weaker than zkCoins' ZK anonymity set; nothing to adopt there, and it would be a regression.
- Output scanning is an on-chain trial-computation (`K'_s = K^o - H(k_v·rG)·G`); zkCoins has no per-output public scalars on Bitcoin, so the *mechanism* doesn't port, only the *role separation* of the two keys.
- Monero's mandatory chain-wide scan assumes the chain holds the outputs; zkCoins value data is off-chain.

## Namada (MASP)

**How it works** — The **Multi-Asset Shielded Pool** extends Zcash's Sapling circuit so *all* assets share one unified anonymity set instead of one pool per asset ([masp repo](https://github.com/namada-net/masp)). A **convert circuit** lets shielded balances be converted/rewarded *without unshielding* — enabling **shielded-set incentives**: a PD-controller pays up to ~10%/yr inflation, per-asset, to users who keep assets shielded, claimable in-pool via the convert circuit ([Namada specs](https://specs.namada.net/modules/masp/shielded-pool-incentives)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Unified multi-asset anonymity set | One shielded set across all assets, not per-asset | zkCoins already supports custom assets (`asset_id`); MASP's lesson is to keep *one* anonymity set across them so small assets borrow the big set's privacy rather than fragmenting it | Economics / privacy | High | Med |
| Convert-circuit pattern (transform a note in-circuit without revealing) | A circuit operation that rewrites a note's asset/value while staying shielded | Conceptual template if zkCoins ever needs in-circuit asset transforms (e.g. fee abstraction, issuance accounting) without exposing the note | S5 / Economics | Low | Research |
| Shielded-set incentive (controller-tuned reward for staying shielded) | Economic nudge to keep value in the anonymity set | A possible answer to zkCoins' "anti-spam / data-availability durability / economics" open areas — reward nodes/users who replicate and hold bundles | Economics / Recovery | Low | Research |

**Doesn't transfer**
- The incentive is funded by **chain inflation / a native token** — zkCoins has no token and no inflation, so the funding mechanism cannot port; only the *idea* of incentivizing shielded behavior (which would need a Bitcoin-native fee/economic model) survives.
- MASP is a Sapling-derived Groth16 circuit with a trusted setup; zkCoins' Plonky2 stack is transparent and recursive — different circuit family.

## Penumbra

**How it works** — Penumbra is a shielded Cosmos zone whose standout primitive is **Fuzzy Message Detection (FMD)**: a recipient publishes a compact **detection (clue) key** that a third-party server uses to filter the chain for that recipient's transactions *probabilistically* — **no false negatives, a tunable false-positive rate**, so the server cannot tell true matches from chaff ([Penumbra FMD](https://protocol.penumbra.zone/main/crypto/fmd.html), [Beck et al.](https://www.cs.umd.edu/~imiers/pdf/fuzzy.pdf)). Crucially, detection ≠ viewing: the clue key only yields a *probabilistic association*, never transaction contents. Penumbra's **S-FMD** variant lets the *sender* set the false-positive rate; one clue per recipient per tx, padded with dummy clues so observers can't count recipients ([sender/receiver FMD](https://protocol.penumbra.zone/main/crypto/fmd/sender-receiver.html)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Fuzzy Message Detection (detection key, tunable false-positive rate) | An untrusted server filters "messages possibly for you" without learning which are real ([FMD](https://protocol.penumbra.zone/main/crypto/fmd.html)) | The strongest fit for zkCoins' delivery/recovery problem: a Nostr relay (or recovery-pull node) could return your bundles via a detection key, learning only a fuzzy set — strictly better metadata than tagging events with your pubkey | Note-discovery / Delivery / Recovery | High | High |
| Detection ≠ viewing separation | A capability that *locates* without *decrypting* — strictly weaker than a viewing key | Adds a third tier below zkCoins' view-grant: hand a relay a *detect-only* clue key (find my bundles) while a view-grant (read) and spend key stay separate — finer-grained capability gating | View-keys / Anti-spam | High | Med |
| Per-tx clue padding (dummy clues = #outputs) | Pad clues so recipient count doesn't leak | Maps to zkCoins' gift-wrap goal of hiding recipient cardinality on a relay; a padding discipline for delivery events | Delivery (metadata) | Med | Med |
| Sender-set precision (S-FMD) | Sender, not receiver, fixes the false-positive rate | Lets a zkCoins sender tune the privacy/bandwidth tradeoff of a delivered bundle's detectability without recipient round-trips | Delivery | Med | Research |

**Doesn't transfer**
- FMD's privacy guarantees are *probabilistic and contested* — analyses show real-world false-positive tuning leaks more than hoped over time ([arxiv 2109.06576](https://arxiv.org/pdf/2109.06576)). Adopt as a *bandwidth optimization with caveats*, not a privacy guarantee on its own; gift-wrap (NIP-59) remains the baseline.
- Penumbra's FMD scans *its own chain's* clue stream; zkCoins would run FMD over a relay inbox, so the deployment surface differs.
- Flow encryption (threshold-encrypted batched flows for its DEX) is tied to Penumbra's validator set and on-chain batching — no analog in a Bitcoin-anchored, no-validator design.

## Aleo

**How it works** — Aleo extends Zcash's UTXO model into a **records** model: a record is an encrypted, owner-addressed container of arbitrary state, not just a coin value ([Aleo record model](https://aleo.org/post/aleo-record-model-secure-efficient-blockchain/)). Programs execute **off-chain in snarkVM**, producing a ZK proof; on-chain validators see only commitments and ciphertexts, and users decrypt with their view keys. Spending reveals a **serial number** (a PRF of the owner's secret key and the record nonce) to prevent double-spend.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Off-chain execution → on-chain commitment, decrypt-with-view-key | Compute privately, publish only commitment + ciphertext; owner decrypts with a view key | Validates zkCoins' "private bundle off-chain, opaque commitment on-chain" model from a programmable angle; the view-key-decrypts-record pattern reinforces the operational-key-decrypts-bundle design | View-keys / S1 | Med | Med |
| Serial-number double-spend marker (PRF of secret key + nonce) | A deterministic, owner-derived spent-marker revealed at spend | A concrete shape for the S2 accumulator: a per-coin nullifier derived in-circuit and made *verifier-queryable*, deterministic from the owner's key so recovery can recompute it | S2 | Med | High |

**Doesn't transfer**
- Aleo is a general-purpose execution L1 with its own consensus/token; the records *programmability* is far beyond zkCoins' payment scope and brings its own chain — only the privacy-of-execution and serial-number ideas port.
- snarkVM's record encryption is to Aleo addresses on its curve (BLS12-377); zkCoins uses secp256k1/BIP-340 — different primitives.

## Iron Fish

**How it works** — An account-based shielded L1 (Sapling-style notes/nullifiers) aimed at usability; accounts have view keys that expose incoming/outgoing history without spend authority.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Account-based shielded model with per-account view keys | Shielding organized around accounts rather than pure UTXO notes | zkCoins is *already* account-based (AccountState, per-account coin-history SMT) — Iron Fish is corroboration that account-scoped view keys are workable, reinforcing the view-grant design | View-keys | Low | Low |

**Doesn't transfer**
- Own chain, own token, Groth16/Sapling lineage — no Bitcoin anchoring, nothing structurally new beyond what Zcash already provides.

## Firo (Lelantus Spark)

**How it works** — Spark addresses support **incoming view keys** and **full view keys**, **diversified addressing** (unlimited addresses from one seed, each coin scanned once), and non-interactive one-time addressing ([Spark paper](https://eprint.iacr.org/2021/1173.pdf)). Incoming view keys let a third party identify incoming outputs *with value and memo* but no spend authority; full view keys cover all transactions — explicitly designed to *offload chain scanning and balance computation without delegating spend authority*.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Incoming vs full view keys + scan-offload framing | Tiered read keys whose explicit purpose is delegating scanning/balance to a server without spend power | This *is* zkCoins' operational-key thesis (always-on node scans/decrypts; wallet only spends), independently arrived at — strong external validation and a clean tiering to copy | View-keys / S1 | High | Med |
| Diversified addressing, scan-once | Many addresses from one seed, identified in a single scan pass | Same payoff as Zcash diversified addresses; Spark's "scan each coin once" is a useful efficiency constraint for zkCoins' discovery | Addressing | Med | Med |

**Doesn't transfer**
- Own chain; Spark's one-out-of-many proofs and the Firo anonymity set are chain-resident, not Bitcoin-anchored.

## Zano

**How it works** — **Auditable wallets**: the owner shares a *tracking seed* (auditable address + secret view key + timestamp) so an auditor can verify **all** incoming and outgoing transactions and balances, while the owner keeps sole spend authority ([Zano docs](https://docs.zano.org/docs/use/auditable-wallets/)). To make outgoing transfers auditable, auditable outputs are excluded from the mixing process. Also offers **confidential assets** (hidden amounts/addresses) with the same auditability.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Full-audit view capability (see *both* directions + balance) bound to a shareable tracking secret | One shareable secret yields complete, spend-less auditability | A concrete shape for a *full* (vs incoming-only) zkCoins view-grant — e.g. for an accountant/tax tool/explorer — matching the capability-gated authorized-explorer goal | View-keys | Med | Med |
| Scoped auditability with a creation timestamp | Tracking secret carries a start time, bounding what's disclosed | zkCoins view-grants want scoping (date range, asset, expiry); the timestamp-in-the-grant pattern is a simple, copyable scoping primitive | View-keys | Med | Low |

**Doesn't transfer**
- Privacy is CryptoNote ring-mixing (decoys), not a ZK anonymity set; the trade Zano makes (exclude auditable outputs from mixing ⇒ weaker privacy for auditability) is an artifact of decoy mixing and does **not** apply to zkCoins' ZK shield — a zkCoins view-grant need not weaken the anonymity set.

## Top candidates from this cluster

1. **View-key hierarchy / spend-vs-view split** — Zcash (FVK/IVK/OVK), Monero, Firo, Zano — gap: View-keys + S1 (operational-key model, scoped view-grants) — **Fit High / Effort Med**. The single richest, best-corroborated transfer; four protocols independently validate it.
2. **Fuzzy Message Detection (detection key, no false negatives)** — Penumbra — gap: Note-discovery + Delivery + Recovery (untrusted relay returns your bundles without learning which) — **Fit High / Effort High**. Adopt as a bandwidth/metadata optimization layered on gift-wrap, not a standalone privacy guarantee.
3. **Trial decryption of key-private ciphertexts** — Zcash — gap: Note-discovery / Delivery (detect incoming bundles addressed to the operational key over Nostr) — **Fit High / Effort Med**.
4. **ZIP-307-style light-client / compact pull + client-side decryption** — Zcash — gap: Recovery / Light-client (serve compact candidates, keep matching client-side, cooperating node stays blind) — **Fit High / Effort High**.
5. **Diversified / stealth / sub-addressing** — Zcash, Firo, Monero — gap: Addressing (reusable receiver addresses without on-chain linkage) — **Fit Med-High / Effort Med**.
6. **ZIP-321 payment-request URIs** — Zcash — gap: UX / Addressing (a proven invoice-URI format with forward-compatible required-params) — **Fit Med / Effort Low**.
