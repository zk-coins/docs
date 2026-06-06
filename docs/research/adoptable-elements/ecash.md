---
title: Learnings — Ecash & Off-chain Bitcoin
---

# Learnings — Off-chain Bitcoin Value & Chaumian Ecash

This cluster carries Bitcoin-pegged value *off-chain* as bearer instruments, and it has shipped — in production — exactly the layers zkCoins still has on its roadmap: a pasteable bearer-token format, offline/async receive, seed-based recovery, and an anti-double-spend ledger. The mechanisms are directly relevant. **The trust models are not.** Cashu is custodial (the mint holds the funds), Fedimint is federated custody (a quorum of guardians holds them), Ark depends on a liquidity-providing server, and Statechains/Mercury rely on a blind-signing entity. zkCoins is Bitcoin-anchored and trustless with a ZK anonymity set — so for each project the rule is: extract the *plumbing* (token format, deterministic recovery, offline transfer, spent-secret ledger), never the *custody*.

## Cashu

**How it works** — Cashu is Chaumian blind-signature ecash. A wallet picks a random `secret x`, blinds it (`B_ = hash_to_curve(x) + rG`), and the mint blind-signs it (`C_ = kB_`); the wallet unblinds to a token `(x, C)` it can later present to the mint, which verifies `k·hash_to_curve(x) == C` without ever having seen `x` at signing time ([NUT-00](https://github.com/cashubtc/nuts/blob/main/00.md)). A token is a set of such **Proofs** (`amount`, `secret`, `C`, keyset `id`) serialized to a single pasteable string (`cashuB...`, CBOR/base64-url) — a true bearer credential: possession is ownership ([NUT-00](https://github.com/cashubtc/nuts/blob/main/00.md)). The mint prevents double-spend by keeping a database of seen secrets and refusing any secret it has already redeemed; a token-state endpoint reports `UNSPENT/PENDING/SPENT` ([NUT-07](https://cashubtc.github.io/nuts/07/)). Crucially for zkCoins, the secret and blinding factor can be derived deterministically from a BIP-39 seed so a wallet can rebuild its tokens after data loss ([NUT-13](https://cashubtc.github.io/nuts/13/)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Deterministic secrets from seed (NUT-13) | Secret + blinding factor derived from a BIP-32 path `m/129372'/0'/keyset'/counter'/{0,1}` (ratified NUT-13; an `HMAC-SHA256(seed, keyset‖counter‖type)` variant is proposed but not yet ratified); wallet keeps a per-keyset counter and walks it forward on recovery, stopping after 3 empty batches of 100 ([NUT-13](https://cashubtc.github.io/nuts/13/)) | Directly models zkCoins' recovery target — *seed* re-derives the deterministic part (all keys + the seed-bound pull-tags) so the wallet can *enumerate and request* what is owed without trusting the source; mirrors the "deterministic pull-tags" already named in the [Information Flow](../../architecture/information-flow#recovery-seed--bitcoin--an-honest-network) recovery design | Recovery | High | Med |
| Counter-walk + batch-scan recovery loop | Recover in batches of 100, increment counter, stop after 3 consecutive empty batches | A concrete, finite algorithm for "enumerate everything mine" against the node/relay mesh — turns zkCoins' recovery-pull from a vague pull into a bounded, terminating scan | Recovery | High | Low |
| Bearer-token serialization (`cashuB`) | A self-contained, copy-paste/QR/URI string that *is* the value; no account, no liveness | Validates the zkCoins CoinProof-bundle-as-bearer model and argues for a single canonical, channel-agnostic bundle encoding (URI/QR fallback when no relay is reachable) | Delivery | High | Low |
| Spent-secret ledger as the double-spend oracle | Mint refuses any secret it has seen; state endpoint returns SPENT/PENDING/UNSPENT | The *shape* of zkCoins' **S2** (queryable global spent-coin accumulator): a verifier-queryable "has this nullifier been seen" service — except zkCoins makes it a Bitcoin-anchored accumulator, not a mint's private DB | S2 | High | Research |
| P2PK / HTLC-locked tokens (NUT-11/14) | A token locked to a pubkey (Schnorr sig to spend), with optional locktime + n-of-m refund keys; or locked to a hash preimage | A template for **capability-gated pull** and conditional/escrowed delivery: lock a bundle so only the intended operational key can redeem it, with a timelock refund to the sender if the receiver never claims | Delivery / Two-key / Anti-spam | Med | Med |

**Doesn't transfer**

- **Custody.** The mint *holds the Bitcoin*; a Cashu token is an IOU against a custodian who can rug, censor, or vanish. zkCoins coins are non-custodial — the bundle is the spend credential, no operator holds funds. This is the single hardest line in the cluster: copy the token *format* and *recovery*, never the issuer-holds-the-money model.
- **Mint-assisted recovery (NUT-09 restore).** NUT-13 recovery still *asks the mint to reissue signatures*; the mint is the availability authority. zkCoins replaces that authority with Bitcoin (authenticates every returned bundle) + an honest, replicated relay mesh (serves blobs) — the seed-derivation idea transfers, the "ask the mint" step does not.
- **Mint as double-spend authority.** The spent-secret DB is the mint's private ledger and the sole arbiter of validity. zkCoins must anchor the equivalent in a public, Bitcoin-verifiable accumulator (S2), not a trusted operator's database.
- **Blind signatures themselves.** Cashu's unlinkability comes from BDHKE blinding against one mint; zkCoins' unlinkability comes from a ZK anonymity set over all coins. They are different privacy primitives — don't graft blind-signing onto a system that already has a stronger anon-set.

## Fedimint

**How it works** — Fedimint runs a Chaumian mint as a **federation of guardians** under a Byzantine-fault-tolerant consensus and a threshold (t-of-n) signature scheme over the custodied Bitcoin — e.g. 3-of-4 or 5-of-7, tolerating up to ~1/3 of guardians being offline or malicious ([Spark research](https://www.spark.money/research/fedimint-federated-ecash), [Bitcoin Magazine](https://bitcoinmagazine.com/business/from-stealth-to-scale-fedi-unveils-multi-sig-guardians-for-federated-bitcoin-e-cash-mints)). Users hold blinded ecash notes as bearer instruments; **Lightning gateways** are non-guardian participants that bridge to/from Lightning without joining consensus or holding custody ([Spark research](https://www.spark.money/research/fedimint-federated-ecash)). Backup is an optional client feature: the client encrypts a snapshot of its notes and stores it with the federation, and recovery re-fetches it — but the mint "has no record of which notes belong to which user," so *unbacked* lost notes are simply gone ([Spark research](https://www.spark.money/research/fedimint-federated-ecash), [fedimint-clientd](https://github.com/fedimint/fedimint-clientd)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Threshold availability for the bundle store | t-of-n guardians: data stays available as long as a quorum is up; BFT tolerates ~1/3 offline/malicious | A design quantifier for zkCoins' "honest + replicated" recovery precondition: replicate each bundle to k relays so any t can serve it — sizing the relay mesh as a t-of-n availability set, not custody | Recovery | High | Med |
| Encrypted client-state snapshot to the network | Client encrypts its own note set and parks it with the federation; only the client can decrypt | A pattern for an *encrypted* recovery blob beyond per-coin pull: the node could hold a wallet's gift-wrapped state snapshot it cannot read, restoring fast after a crash without leaking content | Recovery | Med | Med |
| Gateway as a swappable bridge role | LN bridge run by a non-custodial, non-consensus participant, cleanly separated from the core | Validates separating zkCoins' Lightning/on-chain bridging into a swappable role outside the trust core (relay/validator), keeping the bridge from becoming a trust dependency | Delivery / Economics | Med | Med |

**Doesn't transfer**

- **Federated custody.** The guardians *collectively hold the Bitcoin*; "self-custodial" here means t-of-n custody, and users cannot exit unilaterally ([Spark research](https://www.spark.money/research/fedimint-federated-ecash)). zkCoins has no quorum holding funds — take the *availability* math (t-of-n replication), never the *custody* quorum.
- **Guardian-assisted / social recovery.** Recovery leans on cooperating guardians (and sometimes a personal-knowledge proof to the federation). zkCoins' recovery must stay *trustless*: cooperation is needed only for availability, correctness is enforced by Bitcoin — guardians are not an identity or custody authority.
- **Consensus over user state.** Fedimint runs a live BFT consensus; zkCoins deliberately has *no* own consensus — Bitcoin is the ordering/anchor. Don't import a guardian consensus layer.

## Ark

**How it works** — Ark moves Bitcoin off-chain via **VTXOs** (virtual TXOs) that live inside a shared on-chain UTXO. An **Ark server (ASP)** periodically runs **rounds** that batch-settle refreshes into a new shared output ([Bitcoin Optech](https://bitcoinops.org/en/topics/ark), [Ark Protocol](https://ark-protocol.org/intro/vtxos/index.html)). Between rounds, **out-of-round ("arkoor") payments** are pre-signed by the sender and co-signed by the server, so a receiver gets a spendable VTXO *without being online and without the server fronting liquidity* — enabling true async/offline receive; a brand-new wallet can receive immediately with no boarding ([second.tech](https://second.tech/docs/learn/intro)). Users keep a fallback: a **unilateral exit** broadcasts the pre-signed branch/leaf transactions to claim their Bitcoin on-chain with no third party ([second.tech](https://second.tech/docs/learn/intro)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Offline/async receive via pre-signed transfer | Sender fully pre-signs the transfer; receiver (even brand-new, even offline) obtains a spendable instrument and verifies later | The clearest model for zkCoins' **offline-receive** gap: a sender pushes a complete, self-verifying CoinProof bundle to a store-and-forward layer; the receiver claims and verifies against Bitcoin whenever it comes online | Offline-receive | High | Med |
| Batched settlement in rounds | Many off-chain transfers collapse into one periodic on-chain footprint | Conceptual cover for **economics/anti-spam**: batch many commitments per Bitcoin anchor to amortize on-chain cost — relevant when zkCoins moves from full-commitment inscriptions toward compressed nullifier batches | Economics | Med | High |
| Unilateral-exit guarantee | The holder can always reclaim funds on Bitcoin with no third party | Reinforces zkCoins' core invariant restated for transport: availability failure must never become loss — the bundle (the spend credential) plus Bitcoin must always suffice, no server permission needed | Recovery / Delivery | High | Low |

**Doesn't transfer**

- **Liquidity-provider dependency.** Ark's server must front on-chain liquidity for refreshes/offboarding and co-signs transfers; it is a semi-trusted, liveness-critical party. zkCoins has no liquidity provider — value isn't pooled in a server's shared UTXO. Take the *async-receive flow*, not the LP.
- **Server co-signing / collusion window.** Arkoor security assumes "sender and server don't collude to double-spend" until the next refresh ([second.tech](https://second.tech/docs/learn/intro)). zkCoins' validity is enforced by ZK proof + Bitcoin anchoring, not by a co-signer's honesty — don't introduce a co-signing server into the spend path.
- **VTXO expiry / refresh treadmill.** VTXOs decay and must be periodically refreshed in rounds. zkCoins coins don't expire; importing round-based expiry would add a liveness burden the model doesn't need.

## Statechains / Mercury

**How it works** — A Mercury statechain transfers *ownership of a real Bitcoin UTXO* off-chain. The UTXO is locked to an aggregate key split between the owner and a **blind server**; to transfer, the old owner, new owner, and server collaboratively *update* the key shares so the new owner + server hold shares of the *same* aggregate key, and a fresh backup transaction is signed ([Mercury Layer](https://mercurylayer.com/), [Bitcoin Magazine](https://bitcoinmagazine.com/technical/mercury-layer-a-massive-improvement-on-statechains)). The server is kept **blind** — the transfer data is blinded so it never learns the aggregate key, the TXIDs, or even the signatures it helps produce; it only counts how many times it has signed for a given statechain ([Bitcoin Magazine](https://bitcoinmagazine.com/technical/mercury-layer-a-massive-improvement-on-statechains)). The receiver verifies **client-side**: it checks the server-reported signature count matches the handed-over transfer history, that every signature is valid, and that each backup transaction's timelock decrements correctly so the current owner can always claim first ([Bitcoin Magazine](https://bitcoinmagazine.com/technical/mercury-layer-a-massive-improvement-on-statechains)).

**Adoptable for zkCoins**

| Element | What it is | Why it fits zkCoins | Gap addressed | Fit | Effort |
|---|---|---|---|---|---|
| Blind server (counts, never sees content) | A server assists transfers while learning nothing — not the keys, TXIDs, signatures, only an opaque per-statechain signature count | The exact privacy posture zkCoins wants for its node/relay: it can *count and serve* opaque events but cannot read amounts/recipients/graph — already the zkCoins relay model; Mercury is independent validation that "assist-blind" is buildable | Delivery / S1 | Med | Research |
| Client-side count-vs-history verification | Receiver cross-checks a server-claimed monotonic counter against the full handed-over history to detect a hidden second transfer | A double-spend *detection* primitive that needs no global state: bind a monotonic counter into the handed-over CoinProof history so a receiver can spot an equivocating sender/relay — a cheap complement to the S2 accumulator | S2 / S1 | Med | Research |
| Decrementing-timelock backup transactions | Each transfer's fallback tx has a shorter timelock than the prior owner's, so the latest owner always wins a unilateral claim race | A pattern for ordering claim priority among successive holders of a bearer instrument when a dispute reaches Bitcoin — relevant if zkCoins ever needs an on-chain tiebreaker for contested bundles | S2 | Low | Research |

**Doesn't transfer**

- **Reliance on the statechain entity.** Even blinded, the server must co-sign every transfer and not collude with a prior owner; the receiver trusts it won't double-sign undetected. zkCoins' validity is cryptographic + Bitcoin-anchored, not entity-gated — keep the blind-assist and client-side-verify *ideas*, not the must-sign entity.
- **Whole-UTXO granularity.** A statechain transfers a fixed UTXO; no native splitting/merging of value mid-flight. zkCoins coins carry arbitrary amounts and recursive provenance — don't inherit UTXO-grain rigidity.
- **Weak/no anonymity set.** Statechains offer transfer unlinkability against the server but no global shielded set; amounts and the coin's on-chain UTXO are visible. zkCoins' ZK anon-set is strictly stronger — this is a borrow-the-blinding, not the privacy-model situation.

## Top candidates from this cluster

1. **Deterministic secrets from seed (NUT-13) — Cashu — Recovery — Fit High / Effort Med.** A proven seed→secret derivation + bounded counter-walk scan that maps almost 1:1 onto zkCoins' "seed re-derives keys and pull-tags" recovery; adopt the derivation discipline and batch-scan termination, drop the "ask the mint" step.
2. **Offline/async receive via pre-signed transfer — Ark — Offline-receive — Fit High / Effort Med.** The cleanest blueprint for zkCoins' biggest UX gap: a fully pre-signed, self-verifying bundle pushed to store-and-forward, claimed and Bitcoin-verified by an offline receiver — minus Ark's liquidity provider and co-signing server.
3. **t-of-n replication for the bundle store — Fedimint — Recovery — Fit High / Effort Med.** Quantifies the "honest + replicated" precondition: replicate each bundle to k relays so any t can serve it, sizing the relay mesh as an availability quorum (not a custody quorum).
4. **Spent-secret ledger as the double-spend oracle — Cashu — S2 — Fit High / Effort Research.** The functional shape of S2's queryable spent-coin accumulator — adopt the "verifier asks: has this nullifier been seen?" interface, but anchor it in Bitcoin instead of a mint's private DB.
