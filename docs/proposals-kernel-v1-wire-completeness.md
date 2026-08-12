---
title: "Proposal: kernel.v1 wire-contract completeness"
---

# Proposal: kernel.v1 wire-contract completeness

:::warning Decision record — not yet normative
This page records **two places where the normative `kernel.v1` Protocol-Buffers contract
([spec §7.8](/specification#78-kernel-rpc--the-internal-interface-normative)) is not by itself
sufficient to drive its own procedures**, and proposes how to resolve them. It is a decision record for
review *before* the spec text changes — it does not itself change the normative contract. The node
implementation already carries a working answer to both (noted per item below); this page exists so the
answer is written into `kernel.v1` deliberately rather than left as an implementation divergence. When a
direction is chosen it becomes an additive amendment to
[spec §7.8](/specification#78-kernel-rpc--the-internal-interface-normative) under the
[§1.7.8](/specification#178-reference-instantiation-status-final-for-v1) between-step-3-and-step-7 rule
(see *Why amend v1* below).
:::

## Why this is raised now

`kernel.v1` declares itself "the complete, normative `kernel.v1` contract"
([spec §7.8](/specification#78-kernel-rpc--the-internal-interface-normative)). Two of the kernel's own
procedures cannot be driven from that published `.proto` alone. Because the API layer, the SDK, and any
third-party client all build against that contract, an under-specified contract propagates downward into
every one of them — so it is resolved here, at the source, before the `node → sdk → api` chain builds
any more code against a work-around.

## Gap 1 — `Pull` carries no ownership-vs-grant discriminator

A pull session is created by `Pull(PullRequest)` and later presented, by opaque `session` handle, to
the follow-up reads. The contract draws a sharp line between two session kinds: `GetRecord`,
`GetCoinProof` and `SubscribeReceipts` admit **either** an ownership **or** a grant session, but
`GetAccountState` — which discloses the full account head — admits an **ownership session only** and
**must reject a grant session** with `unauthorized` / `401` (the `GetAccountState` row of the
[§7.8](/specification#78-kernel-rpc--the-internal-interface-normative) per-procedure error table maps a
grant session to `unauthorized` / `401`; [§5.1](/specification#51-capability-gated-pull) states the
reason: "no full-state disclosure under a scoped grant").

For the kernel to enforce that at `GetAccountState` time — which carries only `{ session, chan_bind }` —
the session must have been **recorded as ownership or grant when it was created**, at `Pull`. But the
normative `PullRequest { nonce, subject, resolved_scope, chan_bind }` has **no field that tells the
kernel which kind to record.** The two cases are wire-identical: an ownership pull and a grant pull can
both arrive with `resolved_scope` = `*` over the same `subject`. The distinction lives entirely in
*which capability the client proved to the API layer* — an `OwnershipProof` versus a `GrantProof`
([spec §5.1](/specification#51-capability-gated-pull)) — and the API layer performs that entire
capability gate; the kernel is told only the already-resolved scope and "trusts the API layer for
ACCESS, never widens".

- **How the node bridges it today.** The kernel reads the session kind from an out-of-contract gRPC
  metadata key, `x-zkcoins-session-authority` (values `ownership` | `grant`), supplied by the API
  layer alongside the `PullRequest`, and records it on the session (the source carries a matching
  "Proto GAP" note). It is enforced, but it is **not** in the `.proto`, so a client generated purely
  from the published contract cannot open a session the kernel will accept at `GetAccountState`, and a
  reviewer reading only the contract cannot see that `GetAccountState`'s "ownership only" rule is even
  satisfiable.

### Proposed resolution

Add the discriminator to the contract so `Pull` is drivable from the `.proto` alone. To match the
proto's stated house style — "Closed string value sets stay as strings here … not as enums"
(`node/proto/kernel/v1/kernel.proto`), as `TransitionRequest.kind`, `Job.status`, and
`PullChallengeRequest.action` already are — it is a closed string, not an enum:

```proto
message PullRequest {
  bytes nonce = 1;
  string subject = 2;
  Scope resolved_scope = 3;
  bytes chan_bind = 4;
  string authority = 5;   // closed set "ownership" | "grant": which capability the API layer
                          //   verified (§5.1). The kernel records it on the session and enforces
                          //   "ownership only" on GetAccountState. Empty/other ⇒ INVALID_ARGUMENT.
}
```

The kernel still performs no capability check — it records `authority` exactly as the API layer, which
*did* verify the proof, asserts it: identical in trust terms to how it already trusts `resolved_scope`.
This retires the `x-zkcoins-session-authority` metadata key. The lighter alternative — declaring that
metadata key a **normative** part of the `kernel.v1` transport — is possible but leaves the `.proto`
non-self-sufficient, and is weaker for exactly the third-party-client reason above.

## Gap 2 — the creator / genesis base pubkey is a needed input with no field

Minting binds an asset to its creator's base pubkey Pk₀: the creator pubkey is a domain-separated hash
input to the on-chain asset identity `asset_id`
([spec §6.5](/specification#token-standard-2--auditable-capped-supply)), and `GetTokenProvenance` must
later return that same `creator_pubkey`. Symmetrically, a **genesis receive** credits a not-yet-existing
account whose Pk₀ the kernel has never seen.

Whether either value is derivable from the rest of the request depends on the case:

- **`Issuance.creator_pubkey`.** The compliance circuit binds `creator_pubkey` to the minting account
  via `address(creator_pubkey, nk_commit) == owner` (all mints), and — **only for token-standard-2** —
  additionally to `current_pubkey`. For token-standard-1, and whenever the minting account has already
  advanced (`send_counter > 0`, where `current_pubkey ≠ Pk₀`), Pk₀ is not recoverable from the account
  head via the wire contract: the non-invertible address hash means `owner` alone does not yield it.
  (The reference node happens to persist Pk₀ per account, so it *can* look it up for an
  already-registered account; the point is that the **contract** does not guarantee derivability, so a
  conforming client/kernel cannot rely on it.)
- **`TransitionRequest.genesis_pubkey`.** The receiver of a genesis transition has **no** prior state
  on the node, so its Pk₀ genuinely cannot be looked up and must be supplied.

Meanwhile the normative `Issuance` and `TransitionRequest` messages carry **neither** field.

- **How the node bridges it today.** The node's own `proto/kernel/v1/kernel.proto` already carries
  `Issuance.creator_pubkey = 7` and `TransitionRequest.genesis_pubkey = 12` (both 32-byte x-only), and
  the gRPC ingress reads them (it rejects a non-empty `genesis_pubkey` on mint/send; the genesis-receive
  presence rule — required for a fresh account, forbidden for an existing one — is enforced deeper in
  the dispatcher and currently surfaces as `internal_error` rather than `INVALID_ARGUMENT`). This is an
  **additive divergence** from the published contract: the node compiles and enforces two fields the
  normative spec does not list.

### Proposed resolution

Bring the normative spec up to the fields the node already carries — add to
[spec §7.8](/specification#78-kernel-rpc--the-internal-interface-normative):

```proto
message Issuance {
  string name = 1; uint32 decimals = 2; uint32 issuance_version = 3;
  string amount = 4; string cap_total = 5; bytes terms_salt = 6;
  bytes creator_pubkey = 7;   // Pk₀ (32B x-only); required for a mint. Bound in-circuit to the
                              //   minting account (address(creator_pubkey, nk_commit) == owner;
                              //   == current_pubkey for token-standard-2).
}
message TransitionRequest {
  // … fields 1–11 unchanged …
  bytes genesis_pubkey = 12;  // recipient's Pk₀ (32B x-only); required for a genesis receive,
                              //   MUST be empty otherwise (INVALID_ARGUMENT on mint / send).
}
```

Adopting the field additions requires no node change. Separately, this amendment should also require the
node to map the genesis-receive presence-rule violation to `INVALID_ARGUMENT` instead of today's
`internal_error` — a small, additional node fix tracked with the amendment.

## Why amend `kernel.v1` rather than defer to `kernel.v2`

Both gaps are **genuine contract needs** (shown above), so "just remove the input" is not open. And the
spec already provides the exact mechanism — this is not a freeze violation:

[§1.7.8](/specification#178-reference-instantiation-status-final-for-v1) freezes the wire formats only
**from runbook step 7 (public testnet)**. **Between step 3 and step 7**, it states verbatim, "an
addition to the §7 wire formats that touches **neither** a circuit element **nor** a pinned vector
**nor** a digest is **not** a new protocol version; it **MUST** be introduced by a specification PR that
states why the addition is required" — and it names the additive `GET /v1/token/<asset_id>/provenance`
read as "exactly such an addition". Both changes here are that kind:

- **Additive, and touching no circuit element, vector, or digest.** They add proto3 fields and one
  closed-string value; existing fields are unchanged. `creator_pubkey` is *already* a circuit input
  (`asset_id` hashes it) — the new wire field only transports a value the circuit consumes, so the
  circuit shape, the pinned vectors, and the digests are untouched. `authority` is a pull-session
  access field with no circuit involvement at all.
- **No trust boundary moves.** The API layer still performs the entire §5.1 capability gate; the kernel
  still trusts the API layer for access and never widens scope. `authority` and the two pubkeys are
  inputs the API layer already supplies out-of-band today — the amendment only moves them into the
  typed contract.

The one precondition is that the network is **still before runbook step 7**; after that point a §7 wire
change is a new protocol version and this must instead be `kernel.v2`. Given a pre-step-7, green-field
v1, deferring to v2 anyway keeps the freeze pristine on paper but ships a v1 whose published contract
cannot drive its own procedures — the worse outcome for everyone downstream. The recommendation is
therefore a single, additive, pre-step-7 amendment to `kernel.v1` covering both gaps, introduced by this
spec PR per §1.7.8.

## Spec impact when adopted

A change to [spec §7.8](/specification#78-kernel-rpc--the-internal-interface-normative) would: add
`PullRequest.authority` (closed string `ownership` | `grant`) with its `INVALID_ARGUMENT` rule and note
that it retires the `x-zkcoins-session-authority` metadata key; add `Issuance.creator_pubkey` and
`TransitionRequest.genesis_pubkey` with their presence rules (including the genesis-receive
`INVALID_ARGUMENT`); and state, per the §1.7.8 between-steps rule, why each addition is required (this
page). It touches no circuit element, pinned vector, or digest, so no lineage is rebuilt. Until a
direction is chosen the spec text is unchanged and the node keeps its current bridge.
