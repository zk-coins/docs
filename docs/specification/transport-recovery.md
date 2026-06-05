---
sidebar_position: 5
title: 4 · Transport & Recovery
---

# 4 · Transport & Recovery

This page specifies the **off-chain layer**: how the value-bearing `CoinProof` bundle ([Foundations §1.5](foundations)) travels from sender to recipient, how a recipient discovers its own incoming bundles, how a node recovers its entire state from the **seed** plus Bitcoin, and the data-availability guarantees that make recovery possible. The on-chain layer carries only the opaque commitment ([Foundations §1.4](foundations)); the bundle — which is simultaneously the recipient's receipt and its spend credential — never touches Bitcoin and **MUST** be delivered here.

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) are used per RFC 2119. All primitives, keys, and identifiers are defined in [Foundations](foundations) and used unchanged.

## 4.1 Roles and transport

Every zkCoins **node is itself a full Nostr relay**. One process performs Bitcoin validation, proof verification, state storage, the encrypted bundle relay/store, and the capability-gated pull endpoint ([Access & Explorer](access-explorer)). There is no separate, mandatory courier.

The transport key is `op`, the operational / Nostr identity key ([Foundations §1.2](foundations)). It is a secp256k1 / BIP-340 key — the same family Nostr uses — so it doubles as the wallet's Nostr key with no separate keypair. The node holds `op` and runs the relay on the wallet's behalf; `op` **MUST NOT** be able to spend (it is a hardened sibling of the SPEND branch).

The transport is trusted only for **availability** and for **metadata minimisation** — never for correctness. A relay can **withhold** a bundle but can neither **forge** nor **alter** one, because the recipient verifies every bundle cryptographically (§4.5). This is the same trust spectrum as the node model: a compromised relay is a privacy/availability problem, never theft.

## 4.2 Bundle delivery

A bundle is delivered as a small Nostr control event that **references** the encrypted bundle, plus the bundle blob itself in content-addressed storage.

**Why split.** A recursive proof is large (on the order of 100 KB or more) — too big for an ordinary relay event. Therefore:

1. The sender encrypts the serialised `CoinProof` bundle under the per-coin note key `K_tx` ([Foundations §1.3](foundations)) using **NIP-44 v2**, producing `ciphertext`. (`K_tx` is re-derivable by the recipient from `ivk` and the coin's `epk`; no relay can derive it.)
2. The sender stores `ciphertext` in a content-addressed blob store (a Blossom-style store co-located with each node's relay). The store returns a content hash `blob_id = H(ciphertext)`.
3. The sender constructs a **delivery event**, an application-specific Nostr event whose plaintext payload is:

   ```
   DeliveryEvent.payload = {
     detect_tag,                 // per-coin detection tag (Foundations §1.3)
     epk,                        // ephemeral pubkey for the coin (Foundations §1.3)
     blob_id,                    // content hash of the encrypted bundle
     blob_locators               // ordered hints to nodes/stores holding the blob
   }
   ```

   The payload carries **no** amount, asset, recipient address, or sender — those live only inside `ciphertext`. Note that `K_tx` itself is **never** placed in the delivery event; the recipient re-derives it from `ivk` and `epk`.

4. The sender encrypts the delivery event to the recipient's **incoming-view public key** `IVPK = ivk·G` ([Foundations §1.3](foundations)) with **NIP-44 v2**, then **NIP-59** gift-wraps the result under a fresh ephemeral key. The outer wrapped event is addressed to that ephemeral key, so a relay sees neither sender nor recipient — only an opaque blob stored at some time.
5. The sender publishes the gift-wrapped event to the recipient's advertised relay set (§4.3) and replicates per §4.6.

**Store-and-forward.** The recipient **MAY** be offline. Relays **MUST** retain a delivery event and its blob until either an explicit deletion is authorised or a relay's retention policy expires it; retention **MUST** be at least long enough to satisfy the acknowledgement rule below. Receiving therefore requires only that **one** holding relay is reachable when the recipient comes online — hence the multi-relay advertisement of §4.3.

**ACK + retry (normative).** Delivery is reliable, not best-effort:

- The sender **MUST** retain its own copy of the bundle (and `K_tx`) until it receives a valid acknowledgement.
- On successful receipt and verification (§4.5), the recipient's node **MUST** return an **acknowledgement**: a NIP-44-encrypted, NIP-59 gift-wrapped event addressed back to the sender, carrying `detect_tag` and `blob_id` and signed by the recipient's `op`. The sender verifies the `op` signature against the recipient's published `op` pubkey.
- Until a valid ACK arrives, the sender **MUST** re-publish the delivery event on an exponential-backoff schedule (RECOMMENDED: initial 30 s, doubling, capped at 1 h) to every relay in the recipient's set.
- After a valid ACK the sender **MAY** drop its retained copy. The sender **MUST NOT** drop the copy before both a valid ACK and the replication target `k` (§4.6) are confirmed.

## 4.3 Addressing for delivery

A sender starts from the recipient's `address` ([Foundations §1.4](foundations)) — the protocol's only public identity — and must obtain two things: the recipient's `IVPK` and a relay set to post to.

Addresses are minimal by design and carry no network routing, so resolution is explicit. The supported source, in order of preference, is the **`Invoice`** ([Foundations §1.5](foundations)), extended for transport with the recipient-published, `op`-signed fields:

```
Invoice = {
  amount, recipient: address, asset_id, memo?,   // Foundations §1.5
  ivpk          : IVPK,                            // recipient incoming-view pubkey = ivk·G
  op_pubkey     : op·G,                            // recipient operational/Nostr identity
  relays        : [relay_url, …],                  // recipient's advertised relay set (≥ 1)
  sig           : BIP-340(op, H("zkCoins/v1/Invoice" ‖ serialize(fields)))
}
```

The sender **MUST** verify `sig` against `op_pubkey` and **MUST** check that `H(Pk₀)` published by the recipient binds to `address`; an `Invoice` whose `op`-signature or address binding fails **MUST** be rejected. When no `Invoice` is available, a recipient **MAY** publish the same `{ivpk, op_pubkey, relays}` tuple as an `op`-signed Nostr profile (a replaceable event) discoverable on well-known relays by `op_pubkey`; resolution by `address` alone, with no recipient-published record, is **not** supported — the recipient must have advertised at least one of these.

Each published delivery event carries the per-coin `detect_tag` (§4.2, [Foundations §1.3](foundations)) in its plaintext payload so the recipient can locate it by scan rather than by trial-decrypting every event.

## 4.4 Note discovery

A recipient (or its always-on node, holding `ivk`) finds its own incoming bundles as follows:

1. Derive the detection key `dk = HKDF("zkCoins/v1/DetectTag", ivk)` ([Foundations §1.3](foundations)).
2. Subscribe to / scan its relay set, **filtering by `detect_tag`**. Because the recipient cannot know the `epk` of an inbound coin in advance, discovery proceeds by retrieving candidate delivery events and recomputing, for each candidate's published `epk`, the expected tag `Hc("zkCoins/v1/DetectTag", dk ‖ epk)`; a match selects the event as a candidate for this recipient.
3. For each matched candidate, derive `K_tx = HKDF("zkCoins/v1/NoteKey", ss ‖ epk)` where `ss = ECDH(ivk, epk)` ([Foundations §1.3](foundations)), fetch the blob by `blob_id`, and **trial-decrypt** with `K_tx`. Successful NIP-44 authentication confirms the coin is the recipient's.
4. Verify the decrypted bundle against Bitcoin (§4.5) before accepting it.

**Privacy tradeoff (normative note).** `detect_tag` is deterministic and seed-derivable — the same property that makes it the recovery scan key ([Foundations §1.3](foundations)). A relay that stores tags can therefore **link** the events sharing one recipient's tag-set, even though it learns nothing of content, amount, or identity. This is an accepted, bounded leak. A **fuzzy message detection** layer (probabilistic per-coin tags with tunable false-positive rate) is an **OPTIONAL** privacy upgrade that removes the linkability; it changes only the tag computation and the scan filter and **MUST** leave every other interface in this page unchanged.

## 4.5 Recovery

The seed is the **only** required backup ([Requirement 6](/requirements)). Recovery has two paths, in strict priority order:

- **Primary — the node operator's own backup.** A node **SHOULD** maintain its own durable backup of its local state and bundle store; restoring from it is the normal path and requires no network and no re-verification beyond integrity checks.
- **Emergency fallback — network reconstruction.** After total loss of local data, the complete spendable state is rebuilt from the seed, the public Bitcoin chain, and the bundles replicated across other nodes (§4.6).

The fallback procedure is fully deterministic and trustless:

1. **Re-derive keys.** From the seed, re-derive the account root `A` and thereby `ivk`, `dk`, `ovk`, `op`, the nullifier key `nk`, and the spend keys ([Foundations §1.2](foundations)). This alone restores the address/identity, decryption ability, and the deterministic detection tags.
2. **Rebuild the public index from Bitcoin.** Scan Bitcoin for zkCoins commitments and rebuild the global trees — Commitment SMT, Commitment MMR, and the nullifier accumulator ([Foundations §1.6](foundations)). These are derived from the chain and require no trust. Because each commitment carries the signer's rotating public key, the operator can privately recognise its **own** commitments (its seed derives the keys; outsiders cannot link the rotating keys) and so reconstruct the skeleton of its own activity.
3. **Pull candidate bundles.** Query the network's capability-gated pull endpoints ([Access & Explorer](access-explorer)) by proving ownership (sign a challenge with the identity key) or by presenting the deterministic `detect_tag` set from `dk`. Cooperating nodes return every bundle matching the proof/tags. The network here is an **untrusted blob cache**.
4. **Verify each bundle against Bitcoin.** For every returned bundle, the node **MUST** independently verify the recursive proof, the coin's inclusion in the committed `output_coins_root`, that the root is anchored in a real Bitcoin commitment, and that the coin is unspent against the nullifier accumulator ([Foundations §1.4](foundations), [Foundations §1.6](foundations)). A bundle failing any check **MUST** be discarded. A node can only **withhold**, never forge — correctness is guaranteed by the chain.
5. **Rebuild `AccountState` and balances.** From the accepted incoming and outgoing coins, reconstruct the per-asset `balances`, the coin-history SMT, `current_pubkey`, and `send_counter` ([Foundations §1.5](foundations), [Foundations §1.6](foundations)).

The coin **values** of incoming coins are choices others made; they exist only in the bundles and cannot be derived from the seed or a hash. They come back solely through step 3 — which is why the data-availability guarantee of §4.6 is a precondition for the emergency path. Asset ids fall out of the coins themselves; only the human-readable asset `name` is external and never recoverable from the chain.

## 4.6 Data availability — replication factor `k`

A bundle is custody. If every holder drops it before the recipient (or a recovering owner) fetches it, the coin becomes unspendable. The protocol therefore fixes a **replication factor `k`**:

- Before a delivery is considered **complete**, its encrypted bundle blob and delivery event **MUST** be replicated to at least `k` **independent** nodes/relays. "Independent" means distinct operators/hosts; `k` copies on one operator do not count.
- The default is **`k = 3`**. Rationale: `k = 3` survives the simultaneous loss of any two replicas — covering single-disk failure plus one node being offline during recovery — without imposing the storage and bandwidth cost of higher fan-out. It mirrors the de-facto three-way replication used by durable distributed stores. Deployments **MAY** raise `k` for higher durability; `k` **MUST NOT** be less than 2.
- The recommended replica set is: the recipient's own node, the sender's own node (retained until ACK, §4.2), and at least one additional relay from the recipient's advertised set — yielding `k = 3` from parties that each have an incentive to retain.
- A sender **MUST NOT** drop its retained copy until **both** a valid ACK (§4.2) and confirmation that the blob is held by at least `k` independent replicas.

**Safety invariant (normative).** Custody safety **MUST NOT** depend on availability. Losing availability impairs **recovery** (a bundle may be unrecoverable) but can **never** cause **theft**: an unavailable bundle cannot be spent by anyone else, and a returned bundle is only accepted after verification against Bitcoin (§4.5). Availability is therefore a liveness property, never a safety property.

## 4.7 Metadata and privacy tradeoffs

- **What a relay learns.** Only that an opaque, gift-wrapped, NIP-44-encrypted event was stored at some time — not sender, recipient, amount, asset, or proof (§4.1–§4.2). Because each node is a full relay, coin-delivery events blend into ordinary Nostr traffic (cover traffic).
- **Deterministic-tag linkability.** As stated in §4.4, a tag-storing relay can link one recipient's events to each other without learning who that recipient is; the OPTIONAL fuzzy-message-detection upgrade removes this.
- **Network presence.** Operating a relay exposes the operator's network address (IP) to peers. Operators that require location privacy **SHOULD** run the relay behind an anonymity network (e.g. a Tor hidden service).
- **Recovery disclosure.** Pulling by `detect_tag` reveals the tag-set to the serving node; pulling by ownership proof reveals the requester's identity to that node. Both are consensual, scoped to the requester's own data, and never expose spend authority.

Continue to [Access & Explorer](access-explorer) for the capability-gated pull endpoint, view grants, and the shareable confirmation links that build on this transport layer.
