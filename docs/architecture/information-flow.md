---
title: Information Flow
---

# Information Flow: a 3-party transfer and coin delivery

This page traces **which information goes where** when value moves between participants, and specifies the **transport layer** that carries the value-bearing data. It builds on the [Information Model](information-model) (what each piece of data is) and the [Trust Model](trust-model) (why running your own node is the trustless path).

## The scenario

Three participants — **A**, **B**, **C** — each run **their own node** (validator) and wallet. They are fully equal and trustless: nobody queries anybody else's node, and nobody trusts anybody else.

A issues a custom asset **Tapfreak (TFREAK)** and pays B:

1. **A mints 100 TFREAK** (A is the asset's creator).
2. **A sends 20 TFREAK to B.**
3. **C is uninvolved** — a third participant simply running a node.

**The one rule that explains everything:** the _only_ information that flows directly between participants is the **CoinProof bundle**, delivered peer-to-peer from sender to recipient. Everything else, every node derives independently from **Bitcoin**. A's private key never leaves A.

## What stays in A's node — 🟠 private

A's node holds A's entire bookkeeping; none of it leaves on its own:

- **A's balances** — 80 TFREAK after the transfer, A's current rotating public key, A's address.
- **A's coins** — the coin objects A still holds, with their amounts and asset ids.
- **A's full history** — the issuance of 100, the send of 20, every proof A produced.
- **The Tapfreak definition** — `asset_id = H(A's key ‖ "Tapfreak" ‖ decimals)` and its supply rules; A is the creator.
- **A's copy of the global trees** (account SMT, commitment MMR) — A has them, but they are _derived from Bitcoin_, not secret to A.

A reveals nothing except the single coin it chooses to send B.

## What must reach B — to verify receipt

For B to accept the 20 TFREAK **trustlessly**, A delivers B a **CoinProof bundle** (off-chain):

- the **coin in clear**: `{ identifier, recipient = B, amount = 20, asset = TFREAK }`
- the **zero-knowledge proof** (recursive, constant-size): attests the coin is the valid output of a valid state transition — _without_ exposing A's other balances, coins, or history. It proves only "this coin is valid."
- the **inclusion proof**: that the coin sits in the `output_coins_root` A committed.
- a reference to **A's on-chain commitment** (the Bitcoin inscription).

B verifies all of it **against B's own node and B's own view of Bitcoin**:

1. the ZK proof is valid,
2. the coin is included in the committed root,
3. that root is anchored in a real Bitcoin commitment,
4. the coin has not already been spent.

If all four hold, B is convinced — **without trusting A or A's node**. That is client-side validation. What B learns: "I received 20 valid TFREAK." Not A's balance, not A's other coins, not A's history.

> **Status:** this full, trustless check is the **target**. Today a receiving node verifies only the **inclusion proof** and trusts the source; re-verifying the recursive proof (**S1**) and a verifier-queryable global spent-coin accumulator for step 4 (**S2**) are roadmap items — see [Status](#status--caveats) below.

## What B needs to spend the coins onward

- **B's own private key** (B has it) to sign the new commitment.
- **The received bundle** — it is simultaneously B's receipt _and_ B's spend credential. B's new proof recursively references A's proof to carry the coin's provenance forward, while staying constant-size.
- **B's node** to build the new state transition, proof, and on-chain commitment.
- the **recipient's address**.

Consequence: **the bundle is custody.** A seed phrase alone cannot restore spendable coins — lose the bundle and the coins cannot be spent. (See [Key Management](key-management); [Recovery](#recovery-seed--bitcoin--an-honest-network) below shows how the network restores it.)

## What C receives

C is uninvolved but runs a node and scans Bitcoin. C receives **only the public skeleton**:

- the **opaque commitments** of A's mint and A's send (a rotating public key, a Schnorr signature, and two state hashes each), with their block and time,
- folded into C's own copy of the **global roots and commitment history**.

C does **not** receive: the amount, the recipient, the fact that Tapfreak was involved, that it was 20, or that B took part. Only if B later pays C does C receive a bundle — until then, C learns nothing about A → B.

## What an explorer and a Bitcoin-only observer receive

- An **explorer** is a public, read-only view of the **same Bitcoin data C sees**: the stream of commitments, the roots history, aggregate counts, and signature/anchoring checks. It **cannot** show amounts, the asset name "Tapfreak", balances, sender or recipient, or the graph. (One honest nuance: a commitment's _shape_ — a shorter message for an issuance vs a longer one for a transfer — may hint at the transaction _type_, never its content.)
- A **Bitcoin-only observer** (no zkCoins node) sees the least: the inscriptions are present but **opaque** — each carries a rotating public key, a signature, and two state hashes (~177 bytes), identifiable as zkCoins by their marker, countable, timestamped, but otherwise **uninterpretable** — the same raw data the explorer decodes, just undecoded.

## Who sees what

| Information | A | B | C | Nostr relay | Explorer | BTC-only |
|---|---|---|---|---|---|---|
| A's private key | yes | – | – | – | – | – |
| A's balance & full history | yes | – | – | – | – | – |
| The coin's content (amount, asset, recipient) | yes | yes | – | – | – | – |
| Proof the coin is valid | yes | yes | – | – | – | – |
| The delivery itself | yes | yes | opaque¹ | opaque¹ | – | – |
| A commitment was anchored on Bitcoin | yes | yes | yes | – | yes | yes² |
| Global roots + commitment history | yes | yes | yes | – | yes | raw only |

¹ Only an encrypted, gift-wrapped blob — no sender, recipient, amount, or asset (see below). ² As opaque inscription bytes.

## Two keys: spend vs operational

The node must never hold the key that moves funds — yet the off-chain layer (publishing to relays, decrypting incoming bundles, signing view grants) needs a key that can act while the wallet is offline. zkCoins resolves this with **two keys per wallet, split by role**:

| Key | Held by | Can | Cannot |
|---|---|---|---|
| **Spend key** | the wallet only | sign commitments — i.e. **spend** (custody) | — |
| **Operational key** (per wallet) | the node | publish/receive on Nostr, **decrypt** incoming bundles (read), sign **view grants** + acknowledgements | **never spend** |

Both come from the **same seed**, on **separate hardened BIP-32 branches**, so:

- the wallet re-derives **both** deterministically on recovery (one seed backup);
- the hardened split means the operational key **cannot be walked back** to the spend key — compromising the node leaks _read access_, never spend authority.

This makes the trust statement precise: the node never holds the **spend** key; it may hold a **spend-less operational key**. A compromised node is therefore a **privacy breach (read) — never theft**, exactly matching "a node can see but cannot steal."

Incoming bundles are addressed to the **operational key**, so the always-on node receives, decrypts and stores them without ever touching the spend key; the wallet comes online only to spend. _(This is an addressing change: today the address derives from the spend-side key, so advertising the operational key as the receive identity is part of the proposal — see [Status](#status--caveats).)_

**Own node vs foreign node.** You give _your own_ node the derived operational key. A _foreign_ node never gets your key — instead the wallet issues it a **scoped, signed delegation** to that node's own key. Same self-host-vs-foreign spectrum as everywhere.

## The node is also a Nostr relay

Every zkCoins node **is itself a full Nostr relay**. That collapses the entire off-chain layer into the node you already run:

- **Self-hosted delivery, storage and recovery** — your node is your relay is your persistent bundle store. Senders publish to it; after a crash you re-pull from it.
- **The node network _is_ the relay mesh** — nodes subscribe to and replicate each other for redundancy, with no third-party dependency.
- **Dual-use** — as a _full_ relay it also carries general Nostr traffic, so coin-delivery events **blend into ordinary traffic** (cover traffic) and the node is useful Nostr infrastructure besides.

One process does it all: Bitcoin validation, proof verification, state, the encrypted bundle relay/store, and the capability-gated pull endpoint.

**Caveats:**

- **Capability-gating is an extension, not vanilla relay behaviour.** A standard Nostr relay serves events by public filter to anyone; the gated recovery/disclosure **pull** is a zkCoins-specific endpoint layered on top of the relay, not plain Nostr semantics.
- **Durability needs replication.** Your own relay removes the _dependency_, not the single point of failure — mirror bundles to a few peer/fallback relays so one dead disk cannot lose coins.
- **Receiving needs the relay online** — advertise several relays (your own + fallbacks); store-and-forward across the mesh.
- **A full open relay invites spam/storage abuse** — needs policies (capability-gating for pulls, anti-spam / PoW / web-of-trust for posting, scope to your own wallets for delivery).
- **A relay exposes network presence (IP)** — Tor / hidden service as an option.

## The transport layer: delivering the bundle over Nostr

The scenario exposes the missing piece. On-chain carries only the opaque commitment (no amounts, no identities); the **CoinProof bundle must travel off-chain from A to B**. On a single shared service this happens implicitly today (sender and recipient share a node, which hands the coin over internally). For independent, equal nodes, zkCoins needs a **defined delivery protocol**.

**The core is deliberately small:** encrypt the bundle to the recipient's key, leave it where the recipient can fetch it, and let the recipient verify it. Everything below is either that core or a clearly-optional layer on top — start minimal, add layers only as needed.

### What it must guarantee

1. **Confidentiality** — the bundle contains plaintext (amount, recipient, asset); it must be **encrypted to B**, so any relay sees only ciphertext.
2. **Safety without transport trust** — B verifies cryptographically (ZK proof + Bitcoin anchoring), so a malicious or failed courier can **withhold but never forge or alter**. The transport is trusted only for _availability and metadata_, never for correctness — the same logic as the node trust model.
3. **Asynchrony** — B may be offline; delivery must **store-and-forward**, not require a live connection.
4. **Addressing** — A must derive a delivery route from B's identity.
5. **Metadata minimisation** — a courier should learn as little as possible (ideally not even who sent to whom).
6. **Decentralisation** — no mandatory single courier; B can self-host its delivery endpoint.

### Design: delivery over Nostr

Delivery uses the **operational key** from the two-key model above — a secp256k1 / BIP-340 key, the same family Nostr uses, so it doubles as the wallet's Nostr key with **no separate keypair**. The node holds it and runs the relay:

1. **Addressing.** B's receive identity is B's **operational (Nostr) public key**; B's invoice/address advertises its relay set.
2. **Encrypt.** A encrypts the CoinProof bundle to B's key (NIP-44).
3. **Gift-wrap.** A wraps it (NIP-59) under an ephemeral key, so relays see neither sender nor recipient — only an opaque event.
4. **Publish.** A posts the gift-wrapped event to B's relays (and/or shared relays).
5. **Receive & verify.** B subscribes, unwraps, and verifies the bundle against its own node and Bitcoin. On success, B may return an encrypted **acknowledgement** so A can drop its copy.

### Why Nostr fits

- **Same keys** — the operational key _is_ the Nostr key; no new identity layer.
- **Decentralised & censorship-resistant** — many relays, self-hostable; matches zkCoins' ethos.
- **Async by design** — relays store-and-forward; B fetches when online.
- **Metadata-minimal** — gift-wrapping hides sender and recipient; the relay sees only ciphertext addressed to an ephemeral key — privacy that matches the on-chain layer.
- **Safe without trusting the relay** — a relay can neither read nor forge a bundle; B verifies cryptographically. A relay affects only availability — the same trust spectrum as the node model.

### What the relay sees

A Nostr relay carrying the delivery sees an **opaque, gift-wrapped, encrypted event addressed to an ephemeral key** — not the sender, not the recipient, not the amount, not the asset, not the proof. It learns only that _some_ event was stored at _some_ time.

### Tradeoffs & open points

- **Relay availability is custody-adjacent.** The bundle is the spend credential; if every relay drops the event before B fetches it and A has discarded its copy, the coin is unrecoverable. Mitigations: multiple relays (including one B self-hosts), and the sender retaining the bundle until B acknowledges.
- **Proof size makes off-band storage mandatory, not optional.** A recursive Plonky2 proof is large (on the order of ~100 KB+) — too big for ordinary relay events. So delivery uses a small Nostr control message plus the **encrypted proof blob in content-addressed storage** (e.g. a Blossom-style store), with the Nostr event carrying the pointer and decryption key. (The node already treats proofs as large, disk-backed objects.)
- **Acknowledgement & retries** must be specified so delivery is reliable, not best-effort.

## Recovery: seed + Bitcoin + an honest network

Delivery (push once) is not the same as **recovery** (pull anytime). Bitcoin stores only the opaque commitments, so a node that loses its local state **cannot rebuild the spendable coins from the chain alone**. The property zkCoins targets:

> With only the **seed**, the **public Bitcoin chain**, and an **honest (cooperating) network**, a user recovers their **entire** spendable state — **trustlessly**.

**What the seed gives back (deterministic).** Every key (spend + operational + all rotating keys), the address/identity, the decryption ability, and the deterministic pull-tags — enough to prove ownership and to enumerate and decrypt everything that is yours.

**What Bitcoin gives back (the index + integrity anchor).** The full ordered set of commitments and the global roots — reconstructable by any node. It lets you **authenticate every recovered bundle** (proof valid + anchored; the global double-spend check is the **S2** roadmap item — see [Status](#status--caveats)). Because the on-chain commitment carries your signing public key, you can also **privately recognise your own commitments** — your seed derives the keys; outsiders cannot link the rotating keys, but you can — recovering the skeleton of your own activity.

**What is irreducibly external — and how it comes back.** The coin **values** (amounts, recipients), especially of **incoming** coins, are _choices others made_; they live only in the bundles and cannot be derived from a hash or your seed. Under an **honest network** these bundles are simply **returned on request**: you prove ownership (or present your tags), cooperating nodes serve every bundle addressed to you, and you **verify each one against Bitcoin**.

**Why it stays trustless.** Because Bitcoin authenticates every returned bundle, a node can only **withhold**, never forge. So:

- **cooperation is needed only for availability** — they hand back what they hold;
- **correctness is guaranteed by the chain** — you verify what they hand back.

The network is reduced to an **untrusted blob cache** checked against Bitcoin.

**The one precondition (even under cooperation).** "Cooperate" means _they serve what they have_ — you also need the network to **hold** it. So the delivery layer must **distribute/replicate** bundles across nodes, not leave them on the single node you lost. **Honest + replicated ⇒ total, trustless recovery.**

**Pullability vs recipient privacy.** To return "everything for me", the store must recognise your items —

- **Simple:** items tagged with your public key (the store learns the recipient);
- **Private:** deterministic, seed-bound tags that look random to the store (you compute your own; the store cannot link them to you).

**Asset id falls out of the bundles.** It is part of every coin (`asset_id = H(creator ‖ name ‖ decimals)`), so it is not a separate recovery input; only the human-readable **name** is external (never on-chain, not in the hash). The effective inputs reduce to **seed + Bitcoin + the (honest, replicated) network**.

This data-availability layer is the **hardest part** of any client-side-validation protocol. Solving it as a **network pull verified against Bitcoin** — rather than the manual file backups RGB / Taproot Assets rely on — is a concrete advantage.

## Access model: capability-gated pull

One primitive serves delivery, recovery, _and_ disclosure: a **pull endpoint gated by a cryptographic capability**. A node releases data only after the requester proves entitlement — in one of two ways:

1. **Ownership proof.** The requester signs a challenge with the subject's identity key. The node verifies the signature against the subject's address and returns the data whose recipient is that subject. (This is also the recovery path.)
2. **Delegated view grant.** The subject signs a grant — _"the holder of key D may view my transactions"_. The grantee presents it; the node verifies the subject's signature and releases the data. The node makes **no policy decision** — it simply **enforces the subject's signed grant**, which it can verify cryptographically.

A view grant is, in effect, a **delegated viewing key** (compare Zcash viewing keys): it permits _seeing, not spending_. So a user can consensually disclose to an accountant, a tax tool, or an explorer **without ever surrendering the spend key**. Grants can be scoped (one asset, a date range, an expiry) and revoked — but revocation is **forward-only**: already-disclosed data cannot be un-seen.

## Two explorer modes

The access model yields two distinct explorers over the **same data** — the only difference is the capability presented:

- **Public explorer** — no authorisation; shows only the on-chain public data (commitments, roots, aggregates). It cannot show amounts, assets, balances, or counterparties.
- **Authorised (view) explorer** — shows a _specific user's real transactions_, but only when presented that user's signed **view grant**. Privacy stays under the user's control: they choose who sees what, and for how long.

## Status / caveats

- **Trustless verification is the target, not today's behaviour.** "B verifies without trusting A" needs two roadmap items: re-verifying the full recursive proof on receipt (**S1**), and a verifier-queryable **global spent-coin accumulator** for the double-spend check (**S2**). Today a receiving node checks only the inclusion proof and trusts the source; double-spend is enforced _in the circuit_ (proof of non-inclusion), not via an on-chain nullifier set.
- **The whole off-chain layer is proposed** (roadmap), not yet implemented: the two-key model (today's wallet uses a single, non-hardened derivation branch and addresses by the spend-side key), node-as-relay, Nostr delivery, recovery-pull, and capability-gated access. Today delivery is implicit same-node.
- **Trustless emission (S5).** Permissionless, un-privileged minting ("A mints") is the emission roadmap item.
- **Asset names are never on-chain.** "Tapfreak" lives only in the peer-to-peer coin data and the `asset_id`.

## Related pages

- [Information Model](information-model)
- [Trust Model](trust-model)
- [Privacy Model](privacy-model)
