---
sidebar_position: 6
title: 5 · Access & Explorer
---

# 5 · Access & Explorer

This page specifies how Private data ([Foundations §1.6](foundations)) is released by a node, the structure of viewing capabilities, and the explorer that renders them. All primitives, keys, identifiers, and tags are defined in [Foundations](foundations) and used here unchanged. Normative keywords follow RFC 2119.

Recall the relevant key material from [Foundations §1.2](foundations): a subject's identity is its `address = H(Pk₀)` ([§1.4](foundations)); the **operational key** `op` is the node-held Nostr/identity key that signs grants and acknowledgements but cannot spend; `ivk`/`ovk` are the viewing keys; and `K_tx` ([§1.3](foundations)) is the per-coin note key that decrypts exactly one coin. The on-chain `Commitment` ([§1.4](foundations)) is the only object written to Bitcoin and the integrity anchor for everything below.

## 5.1 Capability-gated pull

Every node exposes exactly one endpoint for Private data — the **pull endpoint** — and it serves a record only after the requester demonstrates a cryptographic capability. The endpoint **MUST NOT** release any Private payload (coin plaintext, amounts, parties, balances, proofs, ciphertext) on an unauthenticated request, and **MUST** restrict the response to the data covered by the presented capability. There are exactly two capabilities, and **no others**.

The endpoint **MUST** be unauthenticated only for the Public projection of [§5.5](#55-two-explorer-modes) (on-chain commitments and roots), which carry no Private data by construction.

A request proceeds as a challenge–response so that captured transcripts cannot be replayed:

```
1. Requester → Node :  PullRequest { subject: address, scope }
2. Node → Requester :  Challenge   { nonce: 32 random bytes,
                                     server_id,            // this node's op pubkey (x-only)
                                     expiry: unix_seconds, // node MUST reject after expiry
                                     domain: "zkCoins/v1/PullChallenge" }
3. Requester → Node :  PullProof   { one of (a) OwnershipProof | (b) GrantProof }
4. Node → Requester :  the Private records matching `subject` within `scope`,
                       or an error (capability invalid / scope exceeded / challenge expired).
```

The signed challenge message is fixed as `chal = H(domain ‖ nonce ‖ server_id ‖ subject ‖ expiry)`, using `H` and input ordering per [Foundations §1.4, §1.7](foundations). A node **MUST** reject a `PullProof` whose `chal` it did not issue, whose `nonce` it has already consumed, or whose `expiry` has passed.

### (a) Ownership proof

The requester proves it controls the subject's identity by signing the challenge with the subject's **initial spend key** `sk₀` (the key that fixes `address`, [Foundations §1.4](foundations)):

```
OwnershipProof = {
  subject    : address,
  public_key : Pk₀,                          // x-only, 32B
  signature  : BIP-340(sk₀, chal)            // 64B
}
```

The node **MUST** verify both `H(Pk₀) == subject` and the BIP-340 signature over `chal`, and only then release every Private record whose recipient is `subject`. This is also the **recovery** path; the requester **MAY** instead present its seed-derived `detect_tag` set ([Foundations §1.3](foundations)) to enumerate its own coins without revealing `Pk₀` (see [Transport & Recovery](transport-recovery)). Ownership grants the **subject's full** Private view; it is the one self-disclosure that requires the spend branch.

### (b) Delegated view grant

The requester presents an `op`-signed grant (the **view grant** of [§5.2](#52-view-grant)) authorising some grantee key `D`, and signs the challenge with `D`:

```
GrantProof = {
  grant      : ViewGrant,                     // Bech32m `zkgrant`, see §5.2
  grantee_pk : D,                             // x-only, 32B; equals grant.grantee
  signature  : BIP-340(d, chal)              // proves possession of D's secret d
}
```

The node **MUST** (1) verify the grant's `op` signature against the subject's published `op` pubkey, (2) verify `grantee_pk == grant.grantee` and the BIP-340 signature over `chal`, (3) confirm the grant has not expired and is not revoked, and (4) release **only** records inside the grant's scope. The node makes **no** policy decision: it enforces the subject's signed grant, which it verifies cryptographically, and **MUST NOT** broaden the disclosure beyond `scope`.

## 5.2 View grant

A view grant is a **delegated viewing key**: it permits *seeing, not spending*. It binds a grantee key to a scope and is signed by the subject's operational key `op`. The grant **MUST NOT** contain, and a node **MUST NOT** accept it as authority over, any spend key.

```
ViewGrant = {
  version    : 1,
  subject    : address,                       // whose data is disclosed
  grantee    : D,                             // x-only pubkey authorised to view (32B)
  scope      : {
    asset_ids  : [asset_id] | "*",            // exact AssetId set ([Foundations §1.4]); "*" = all assets
    not_before : unix_seconds,                // 0 = no lower bound
    not_after  : unix_seconds,                // inclusive upper bound on the data window
    expiry     : unix_seconds                 // grant unusable after this instant
  },
  nonce      : 16 random bytes,               // makes grant_id unique
  signature  : BIP-340(op, grant_message)     // 64B; binds all fields above
}

grant_message = H( "zkCoins/v1/Grant" ‖ version ‖ subject ‖ grantee
                 ‖ asset_ids ‖ not_before ‖ not_after ‖ expiry ‖ nonce )
grant_id      = H( grant_message )            // stable handle for revocation
```

The signing tag `"zkCoins/v1/Grant"` is the reserved `Grant` context from [Foundations §1.1](foundations); `H` and the input ordering are per [Foundations §1.4, §1.7](foundations).

**Encoding.** A `ViewGrant` is serialised in the field order above and encoded as **Bech32m** with HRP **`zkgrant`** ([Foundations §1.7](foundations)), so it is never confused with an `address` (`zk`) or a per-coin capability (`zkview`). A node **MUST** reject a grant under any other HRP.

**Revocation is forward-only.** A subject revokes a grant by instructing the node(s) it controls to refuse any `GrantProof` carrying that `grant_id`. Each node **MUST** maintain a revocation set and **MUST** reject a revoked grant at step (3) of [§5.1(b)](#b-delegated-view-grant). Revocation **MUST NOT** be claimed to undo prior disclosure: data already released under the grant, and any independent copy the grantee retained, is permanently outside the subject's control — **already-disclosed data cannot be un-seen**. A node a subject does not control cannot be compelled to honour a revocation; therefore grants **SHOULD** carry a short `expiry` rather than relying on revocation.

## 5.3 Per-coin view capability

The narrowest capability discloses a single coin. It is the per-coin note key `K_tx` from [Foundations §1.3](foundations), scoped to exactly one coin: it decrypts that coin's `ciphertext` and **nothing else**, and confers no spend authority and no view of any other coin, balance, or transaction.

A per-coin view capability is encoded as **Bech32m** with HRP **`zkview`** ([Foundations §1.7](foundations)):

```
zkview = Bech32m( HRP = "zkview", data = K_tx )      // 32-byte symmetric note key
```

Unlike a `ViewGrant`, a `zkview` carries no signature: it is a **bearer** secret whose mere possession authorises decryption of its one coin. It is the capability embedded in a shareable confirmation link ([§5.6](#56-shareable-confirmation-links)).

## 5.4 Capabilities at a glance

| Capability | Encoding (HRP) | Authorises | Scope | Bearer? | Revocable |
|---|---|---|---|---|---|
| Ownership proof | — (signed challenge) | full Private view of the subject | whole account | no — needs `sk₀` | n/a |
| View grant | Bech32m `zkgrant` | delegated viewing | `asset_ids` × time window | no — needs grantee key `D` | forward-only |
| Per-coin capability | Bech32m `zkview` | decrypt one coin | exactly one coin | **yes** — `K_tx` is the secret | no (forward-only by nature) |

## 5.5 Two explorer modes

The same node data ([Foundations §1.6](foundations): plaintext leaves Private, roots Public) is presented in two modes that differ **only** in the capability supplied.

**Public mode.** No capability is presented. The explorer renders **only** Public on-chain data: the stream of `Commitment`s, the global roots and commitment history ([Foundations §1.6](foundations)), and aggregate counts, with signature- and anchoring-checks against Bitcoin. It **MUST NOT** display amounts, `asset_id`s or asset names, balances, addresses, senders, or recipients — none of which are derivable from Public data. (A commitment's byte length **MAY** hint at the transaction *type*; never its content.)

**Authorised mode.** The viewer supplies the subject's signed **view grant** ([§5.2](#52-view-grant)) (or, for self-view, an ownership proof). The explorer then drives the pull endpoint of [§5.1](#51-capability-gated-pull) on the viewer's behalf and renders that subject's real transactions **within the grant's scope** — and nothing beyond it. Disclosure stays under the subject's control: the subject chooses the grantee, the asset set, and the time window. The explorer is a client of the capability model; it gains **no** privilege the presented capability does not already confer.

## 5.6 Shareable confirmation links

This is the case of [Requirement 9](/requirements): a sender (A) who paid a recipient (B) hands B — or a third party — a link that confirms exactly that one payment, *"here is verifiable proof I sent it."* The link is a bearer of a **per-coin view capability** ([§5.3](#53-per-coin-view-capability)) plus the locators needed to fetch and anchor the transaction.

**Link grammar.** A confirmation link carries exactly three parts: a handle to the on-chain `Commitment`, a **holder locator**, and a `zkview` per-coin capability. The reference URL form (one self-hostable explorer instance shown; any instance is equivalent):

```
https://<explorer-host>/tx/<commitment>:<holder>:<view-cap>

  <explorer-host> = explorer.zkcoins.com         ; one instance among many; self-hostable
  <commitment>    = <txid> "i" <vout> ":" <j>     ; a reveal tx batches MANY commitments, so
                                                 ; txid:vout alone is insufficient; <j> is the
                                                 ; in-payload commitment index (onchain.md §3.5/§3.6
                                                 ; ordering) and resolves to exactly one Commitment
                                                 ; e.g. <txid>i0:7 — anchors to Bitcoin ([Foundations §1.4])
  <holder>        = a node locator that holds the bundle:
                      "op:" <op-pubkey-bech32>     ; a specific holder (e.g. A's node), or
                      "@"  <relay-url>             ; an explicit relay, or
                      "*"                          ; empty/omitted — resolve via the relay mesh
  <view-cap>      = <zkview>                       ; Bech32m per-coin capability ([§5.3])
```

The `<txid>i<vout>:<j>` handle resolves to **exactly one** `Commitment` within the batched reveal transaction; the per-coin `K_tx` (`<view-cap>`) then selects the one coin inside that commitment's transaction.

A canonical, host-independent form `zkcoins:tx/<commitment>:<holder>:<view-cap>` **MAY** be used so the link is portable across explorer instances; an explorer **MUST** treat the `<commitment>`/`<holder>`/`<view-cap>` triple, not the host, as authoritative.

**Flow.**

1. Any holder of the link opens it on an explorer — e.g. `explorer.zkcoins.com`, a **neutral node that is neither A nor B**, or one the viewer self-hosts.
2. The explorer resolves `<holder>` (or, when `*`, queries the relay mesh, [Transport & Recovery](transport-recovery)) and **pulls the bundle** for `<commitment>` — the `CoinProof` ([Foundations §1.5](foundations): coin + proof + inclusion proof + encryption envelope).
3. The explorer decrypts the coin with `<view-cap>` (`K_tx`) and renders the full single transaction: **amount, asset, time, status**.
4. The explorer surfaces **verifiable evidence**: it checks the coin's inclusion in `output_coins_root`, that root's `Commitment` anchored on Bitcoin, and the recursive validity proof ([Foundations §1.4, §1.5](foundations)). The viewer therefore trusts **Bitcoin and the proof — never the explorer's assertion**.

**Properties.**

- **Bearer.** Whoever holds the link can view that one transaction; the `zkview` is the secret. The link **MUST** travel over a channel the sender trusts.
- **Scoped.** It discloses that single transaction in full and **nothing else** — no other transactions, no balances, no counterparties beyond that payment, and no spend authority.
- **Privacy cost.** A third-party explorer operator (and anyone given the link) learns that one transaction. Self-hosting the explorer removes the operator from the trust and disclosure surface.
- **Availability.** Any node holding the replicated bundle (A, B, or another, [Transport & Recovery](transport-recovery)) can serve it; confirmation does not hinge on A being online.

The explorer is a **self-hostable presentation layer** and **MUST NOT** be a trusted authority: every figure it shows is independently verifiable against Bitcoin and the proof by the viewer.
