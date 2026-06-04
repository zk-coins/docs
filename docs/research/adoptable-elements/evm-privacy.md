---
title: Learnings — EVM Privacy
---

# Learnings — Privacy on Smart-Contract Chains

Railgun, Aztec, and Tornado Cash are the most battle-tested shielded systems outside Bitcoin. They are account/contract-model Ethereum-class systems, so much of their machinery (on-chain state, smart-contract execution, sequencers) does **not** transfer to a Bitcoin-anchored, client-side-validation design. But each has solved one operational problem zkCoins still has open — **fee/gasless delivery (Railgun), note discovery (Aztec), and a public spent-set + compliance story (Tornado Cash / Privacy Pools)** — and those mechanisms are concept-portable even when the substrate is not. This page extracts only those transferable ideas and is honest about the rest.

## Railgun

**How it works** — Railgun is a shielded pool implemented as an EVM smart contract. Funds are *shielded* (deposited, ~0.25% treasury fee) into a private UTXO set held as a commitment Merkle tree; spends reveal nullifiers and a ZK proof, and *unshielding* exits back to a public `0x` address ([Railgun privacy system](https://docs.railgun.org/wiki/learn/privacy-system)). Private balances live under a `0zk` address distinct from the user's public `0x` address. Crucially, once funds are shielded a user holds no native gas token, so a **Broadcaster** (relayer) submits the transaction on-chain and is paid its fee *out of the shielded funds in the same token*, taking a premium (~10% over gas) — the user never touches ETH and the on-chain tx appears to originate from the Broadcaster, not the user ([costs & fees](https://docs.railgun.org/community-faqs/readme/costs-and-fees), [Bitfinex overview](https://blog.bitfinex.com/education/what-is-railgun-rail/)). For compliance, **Private Proofs of Innocence** auto-generates, on shield, a recursive-SNARK *non-membership* proof that the funds are NOT in any of several independent List-Provider blocklists, verifiable by an exchange without revealing the user's address, balance, or history ([PPOI wiki](https://docs.railgun.org/wiki/assurance/private-proofs-of-innocence)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Broadcaster / relayer paid from shielded funds | A third party publishes your tx and deducts its fee *from the value being moved*, in the same asset; user needs no separate gas balance | zkCoins must inscribe a Bitcoin commitment (real sats fee) without the *spender* doxxing a funding UTXO. A publisher that anchors the commitment and is reimbursed from the transferred coin (or a fee coin in the bundle) breaks the link between spender identity and the on-chain fee-paying input | Economics / Anti-spam | High | Med |
| Broadcaster competition / fee market | Anyone can run a broadcaster; cheaper ones get more flow | Matches the "run your own node / node-as-relay" mesh: any node can offer paid publishing, no privileged operator | Economics | High | Low |
| Private Proofs of Innocence (non-membership proof) | Recursive ZK proof that a coin's provenance avoids a chosen public blocklist, checkable by a receiver/exchange with zero other disclosure | Same recursive-proof substrate zkCoins already uses (Plonky2 PCD). A *receiver-side* "this coin avoids list X" predicate folds naturally into the per-coin proof and gives the authorized-explorer/compliance story without a global de-anonymization | Compliance / Explorer | Med | Research |
| `0zk` vs `0x` address separation | A distinct shielded-address namespace separate from the base-layer address | Mirrors the proposed spend-vs-operational two-key split and the "receive identity = operational/Nostr key" addressing change | View-keys / UX | Med | Low |

**Doesn't transfer**
- The shield/unshield boundary assumes a *public* on-chain balance to enter/exit from; zkCoins has no public per-account balance to shield from — value is born inside the CSV layer.
- Broadcaster pays gas in the *transferred ERC-20*; on Bitcoin the publishing fee is in sats, not in the (arbitrary, off-chain) asset, so a sat-denominated fee/coin or a publisher-side sat float is required — not a 1:1 lift.
- Smart-contract enforcement of the pool and the on-chain encrypted commitment tree are EVM-native; zkCoins keeps coin data off-chain entirely.

## Aztec

**How it works** — Aztec is a privacy-first ZK L2 where private state is a set of encrypted *notes* (UTXOs) with a global nullifier tree. The hard problem is **note discovery**: how a recipient finds which encrypted logs are theirs without trial-decrypting the entire chain. Aztec's default answer is **note tagging**: sender and recipient derive a shared secret (Diffie-Hellman on Grumpkin, from incoming-viewing keys), hash it with the contract address and recipient address to get a *directional* secret, then hash that with an *incrementing per-recipient counter* to produce a tag per note. The recipient (in its Private Execution Environment) recomputes the next expected tags, queries the node for just those logs, strips the tag, and trial-decrypts only that small set; non-matching logs are silently discarded ([Aztec note discovery](https://docs.aztec.network/developers/docs/concepts/advanced/storage/note_discovery)). Variants include **delegated trial decryption** (hand a tagging key to a service that scans for you) and **tag hopping**; a sliding window bounds the index scan. The standing limitation: you cannot receive a tag from an *unknown* sender without first knowing their key to derive the shared secret.

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Deterministic note tags (shared-secret + counter) | A per-note label only sender & recipient can compute, so the store can be queried by tag instead of brute-force scanned | Directly answers zkCoins' open "pullability vs recipient privacy": the recovery doc already wants *deterministic, seed-bound tags that look random to the store*. Aztec's DH+counter construction is a concrete, proven recipe for exactly that tag — for both Nostr delivery filtering and recovery-pull | Note-discovery / Delivery / Recovery | High | Med |
| Delegated trial decryption | Recipient shares a *view/tagging* key with a service that scans on their behalf, never gaining spend power | Maps onto the operational-key + node-as-relay model: the always-on node holds the operational key and scans/decrypts incoming bundles while the wallet is offline — exactly Aztec's delegation, same trust boundary | Note-discovery / View-keys | High | Low |
| Sliding-window index scan | Bound the tag counter range you check using finalized/aged block indices | A cheap, ready optimization for how a recovering node enumerates "everything for me" without unbounded scanning | Recovery / Note-discovery | Med | Low |
| Unknown-sender handshake (open problem) | Tagging needs a prior shared secret; first contact needs a handshake or brute-force fallback | zkCoins inherits the *same* gap (you can't tag from a stranger). Worth tracking Aztec's handshake research rather than re-deriving it | Note-discovery / Addressing | Med | Research |

**Doesn't transfer**
- Aztec's tags label *on-chain encrypted logs*; zkCoins puts no encrypted payload on Bitcoin, so the tag indexes a *Nostr/off-chain blob store*, not chain logs — same idea, different carrier.
- Grumpkin-curve key derivation is Aztec-specific; zkCoins uses secp256k1/BIP-340, so the DH and tag-hash must be re-instantiated on its own curve/hash (Poseidon-Goldilocks), not copied.
- The PXE / contract-side decryption assumes an L2 execution environment; zkCoins does tag matching in the node, outside any contract.

## Tornado Cash

**How it works** — Tornado Cash is a fixed-denomination mixer. A deposit inserts a commitment (a hash of a secret nullifier + secret) as a leaf into an **on-chain incremental Merkle tree** (depth ~20–32, last ~30 roots retained). To withdraw, the user submits a ZK proof of (a) knowledge of a secret whose commitment is in the tree and (b) a freshly revealed **nullifier hash**, which the contract records in a public **nullifier set** to prevent a second withdrawal — the nullifier reveals nothing about *which* leaf it came from ([Liam Z. explainer](https://liamz.co/tech-blog/2024/09/06/how-do-privacy-pools-tornadocash-work.html), [tornadocash docs](https://github.com/tornadocash/docs/blob/en/general/how-does-tornado.cash-work.md)). Because every deposit in a pool is the same amount, deposits are indistinguishable; the anonymity set is just the count of commitments. The compliance evolution is **Privacy Pools** (Buterin, Illum, Nadler, Schär, Soleimani): users additionally prove membership in a chosen **association set** — a subset of deposits curated to include only "honest" funds or exclude flagged ones — creating a "separating equilibrium" where honest users can dissociate from illicit deposits without revealing their specific deposit ([Privacy Pools paper, SSRN](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4563364), [The Block on 0xbow](https://www.theblock.co/post/348959/0xbow-privacy-pools-new-cypherpunk-tool-inspired-research-ethereum-founder-vitalik-buterin)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Public, verifier-queryable nullifier set | Spent-coin markers published so *any* verifier checks "not already spent" without learning the coin | This is essentially the **S2** target. zkCoins enforces no-double-spend in-circuit (per-account SMT non-inclusion) but has no global spent-set a receiver can query; Tornado's revealed-nullifier-in-a-public-accumulator is the canonical pattern to copy, anchored as a Bitcoin-committed accumulator | S2 | High | Research |
| Commitment Merkle tree + nullifier separation | One accumulator for "exists", a separate revealed value for "spent", unlinkable to each other | Validates zkCoins' existing SMT/MMR + nullifier direction and gives a reference for the *global* spent layer it still lacks (vs today's per-account check) | S2 / S1 | High | Med |
| Association sets / Privacy Pools "separating equilibrium" | Prove your funds belong to a chosen honest subset (or avoid a flagged one) without revealing which note is yours | Cleaner, less centralized framing than Railgun's provider blocklists for the same compliance need; the membership predicate folds into zkCoins' recursive per-coin proof and pairs with the capability-gated authorized explorer | Compliance / Explorer | Med | Research |
| Fixed denominations (as a *uniformity* lesson) | Equal amounts make deposits indistinguishable, maximizing the anon set | A cautionary input for zkCoins' amount-hiding: arbitrary amounts shrink effective anonymity vs a denomination/range discipline — relevant to privacy-model tuning, not a feature to copy wholesale | UX / — | Low | Research |

**Doesn't transfer**
- Fixed-denomination pools are the *opposite* of zkCoins' arbitrary-amount, multi-asset shielded coins; the denomination scheme itself is incompatible.
- Tornado stores the whole commitment tree and nullifier set *on-chain*; zkCoins must keep the spent accumulator as a Bitcoin-*committed* structure with off-chain data, not on-chain state — the mechanism transfers, the storage location does not.
- It is a mixer (enter/exit a pool), not a payment system with sender→receiver delivery; there is no transport, recovery, or addressing story to borrow.

## Top candidates from this cluster

1. **Aztec deterministic note tags** — Aztec — Note-discovery / Delivery / Recovery — Fit High / Effort Med. A concrete shared-secret+counter recipe for the seed-bound, store-opaque tags zkCoins' recovery design already calls for.
2. **Railgun broadcaster paid from shielded funds** — Railgun — Economics / Anti-spam — Fit High / Effort Med. The cleanest pattern for paying the Bitcoin publishing fee without the spender doxxing a funding input.
3. **Tornado public nullifier set** — Tornado Cash — S2 — Fit High / Effort Research. The canonical global spent-coin accumulator zkCoins lacks; the open work is anchoring it to Bitcoin rather than an EVM contract.
4. **Privacy Pools association sets** — Tornado Cash — Compliance / Explorer — Fit Med / Effort Research. Decentralized "separating equilibrium" compliance that folds into the recursive proof and the authorized-explorer/view-grant model.
