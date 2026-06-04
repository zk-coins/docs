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
- a reference to **A's on-chain commitment** (the Bitcoin inscription / nullifier).

B verifies all of it **against B's own node and B's own view of Bitcoin**:

1. the ZK proof is valid,
2. the coin is included in the committed root,
3. that root is anchored in a real Bitcoin commitment,
4. the coin's nullifier has not already been spent.

If all four hold, B is convinced — **without trusting A or A's node**. That is client-side validation. What B learns: "I received 20 valid TFREAK." Not A's balance, not A's other coins, not A's history.

## What B needs to spend the coins onward

- **B's own private key** (B has it) to sign the new commitment.
- **The received bundle** — it is simultaneously B's receipt _and_ B's spend credential. B's new proof recursively references A's proof to carry the coin's provenance forward, while staying constant-size.
- **B's node** to build the new state transition, proof, and on-chain commitment.
- the **recipient's address**.

Consequence: **the bundle is custody.** A seed phrase alone cannot restore spendable coins — lose the bundle and the coins cannot be spent. (See [Key Management](key-management).)

## What C receives

C is uninvolved but runs a node and scans Bitcoin. C receives **only the public skeleton**:

- the **opaque commitments / nullifiers** of A's mint and A's send (a public key, a Schnorr signature, one hash each), with their block and time,
- folded into C's own copy of the **roots and the nullifier set**.

C does **not** receive: the amount, the recipient, the fact that Tapfreak was involved, that it was 20, or that B took part. Only if B later pays C does C receive a bundle — until then, C learns nothing about A → B.

## What an explorer and a Bitcoin-only observer receive

- An **explorer** is a public, read-only view of the **same Bitcoin data C sees**: the stream of commitments, the roots history, aggregate counts, and signature/anchoring checks. It **cannot** show amounts, the asset name "Tapfreak", balances, sender or recipient, or the graph. (One honest nuance: a commitment's _shape_ — a shorter message for an issuance vs a longer one for a transfer — may hint at the transaction _type_, never its content.)
- A **Bitcoin-only observer** (no zkCoins node) sees the least: **opaque 64-byte Taproot inscriptions** (identifiable as zkCoins by their marker, countable, timestamped) and nothing interpretable — the same raw data the explorer decodes, just undecoded.

## Who sees what

| Information | A | B | C | Nostr relay | Explorer | BTC-only |
|---|---|---|---|---|---|---|
| A's private key | yes | – | – | – | – | – |
| A's balance & full history | yes | – | – | – | – | – |
| The coin's content (amount, asset, recipient) | yes | yes | – | – | – | – |
| Proof the coin is valid | yes | yes | – | – | – | – |
| The delivery itself | yes | yes | opaque¹ | opaque¹ | – | – |
| A commitment was anchored on Bitcoin | yes | yes | yes | – | yes | yes² |
| Global roots + nullifier set | yes | yes | yes | – | yes | raw only |

¹ Only an encrypted, gift-wrapped blob — no sender, recipient, amount, or asset (see below). ² As opaque inscription bytes.

## The transport layer: delivering the bundle over Nostr

The scenario exposes the missing piece. On-chain carries only the commitment hash; the **CoinProof bundle must travel off-chain from A to B**. On a single shared service this happens implicitly today (sender and recipient share a node, which hands the coin over internally). For independent, equal nodes, zkCoins needs a **defined delivery protocol**.

### What it must guarantee

1. **Confidentiality** — the bundle contains plaintext (amount, recipient, asset); it must be **encrypted to B**, so any relay sees only ciphertext.
2. **Safety without transport trust** — B verifies cryptographically (ZK proof + Bitcoin anchoring), so a malicious or failed courier can **withhold but never forge or alter**. The transport is trusted only for _availability and metadata_, never for correctness — the same logic as the node trust model.
3. **Asynchrony** — B may be offline; delivery must **store-and-forward**, not require a live connection.
4. **Addressing** — A must derive a delivery route from B's identity.
5. **Metadata minimisation** — a courier should learn as little as possible (ideally not even who sent to whom).
6. **Decentralisation** — no mandatory single courier; B can self-host its delivery endpoint.

### Design: delivery over Nostr

zkCoins identities are **secp256k1 / BIP-340** keys — the same family Nostr uses — so an account's identity key is directly usable as a Nostr key, with **no separate keypair**. That makes Nostr a natural fit:

1. **Addressing.** B's receive identity is B's stable identity key (the one its address derives from), which is also B's Nostr public key. B's invoice/address advertises its relay set.
2. **Encrypt.** A encrypts the CoinProof bundle to B's key (NIP-44).
3. **Gift-wrap.** A wraps it (NIP-59) under an ephemeral key, so relays see neither sender nor recipient — only an opaque event.
4. **Publish.** A posts the gift-wrapped event to B's relays (and/or shared relays).
5. **Receive & verify.** B subscribes, unwraps, and verifies the bundle against its own node and Bitcoin. On success, B may return an encrypted **acknowledgement** so A can drop its copy.

### Why Nostr fits

- **Same keys** — identity = Nostr key; no new identity layer.
- **Decentralised & censorship-resistant** — many relays, self-hostable; matches zkCoins' ethos.
- **Async by design** — relays store-and-forward; B fetches when online.
- **Metadata-minimal** — gift-wrapping hides sender and recipient; the relay sees only ciphertext addressed to an ephemeral key — privacy that matches the on-chain layer.
- **Safe without trusting the relay** — a relay can neither read nor forge a bundle; B verifies cryptographically. A relay affects only availability — the same trust spectrum as the node model.

### What the relay sees

A Nostr relay carrying the delivery sees an **opaque, gift-wrapped, encrypted event addressed to an ephemeral key** — not the sender, not the recipient, not the amount, not the asset, not the proof. It learns only that _some_ event was stored at _some_ time.

### Tradeoffs & open points

- **Relay availability is custody-adjacent.** The bundle is the spend credential; if every relay drops the event before B fetches it and A has discarded its copy, the coin is unrecoverable. Mitigations: multiple relays (including one B self-hosts), and the sender retaining the bundle until B acknowledges.
- **Proof size.** A CoinProof carries a zero-knowledge proof. If it exceeds practical relay event sizes, the design splits into a small Nostr control message plus the encrypted proof blob in content-addressed storage (e.g. a Blossom-style store), with the Nostr event carrying the pointer and decryption key.
- **Acknowledgement & retries** must be specified so delivery is reliable, not best-effort.

## Status / caveats

- **Trustless receive (S1).** "B verifies without trusting A" requires B to re-verify the full recursive proof on receipt — the keystone of the decentralisation roadmap.
- **This delivery layer is proposed**, not yet implemented; today delivery is implicit same-node.
- **Trustless emission (S5).** Permissionless, un-privileged minting ("A mints") is the emission roadmap item.
- **Asset names are never on-chain.** "Tapfreak" lives only in the peer-to-peer coin data and the `asset_id`.

## Related pages

- [Information Model](information-model)
- [Trust Model](trust-model)
- [Privacy Model](privacy-model)
