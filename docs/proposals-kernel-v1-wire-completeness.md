---
title: "Proposal: v1 wire-contract completeness (§7.5 REST and kernel.v1 gRPC)"
---

# Proposal: v1 wire-contract completeness (§7.5 REST and kernel.v1 gRPC)

:::warning Decision record — not yet normative
This page records places where the v1 wire contracts do not by themselves carry values the node
genuinely needs, and weighs how to resolve them. It is a decision record for review; it does **not**
change the normative spec. A follow-up specification PR — after reviewers choose a direction — makes the
actual edits to [§7.5](/specification#75-node-rest-api-normative) and
[§7.8](/specification#78-kernel-rpc--the-internal-interface-normative). The reference `api` and `node`
already carry working answers, which each item notes below — exactly why this is worth settling in the
spec rather than leaving as implementation drift.
:::

## Why raise this now

A transition value travels through two wire hops: a wallet or the SDK speaks **§7.5 REST** to the API
layer, and the API layer speaks **kernel.v1 gRPC** ([§7.8](/specification#78-kernel-rpc--the-internal-interface-normative))
to the node. The SDK and third-party clients build against the §7.5 REST surface only — they never speak
kernel.v1 gRPC, which is operator-internal. Both contracts are normative, and the same two values are
under-specified on each. Because everything downstream builds against these contracts, reviewers should
settle the gaps at the source before more code accretes around the current work-arounds.

## Gap 1 — `Pull` carries no ownership-vs-grant session discriminator (gRPC only)

`Pull(PullRequest)` creates a session that later reads present by opaque `session` handle. The contract
draws a sharp line: `GetRecord`, `GetCoinProof`, and `SubscribeReceipts` admit **either** an ownership
**or** a grant session, but `GetAccountState` — which discloses the full account head — admits an
**ownership session only** and rejects a grant session. The `GetAccountState` row of the
[§7.8](/specification#78-kernel-rpc--the-internal-interface-normative) per-procedure error table maps a
grant session to `UNAUTHENTICATED` / `unauthorized` / `401`; [§5.1](/specification#51-capability-gated-pull)
gives the reason: "no full-state disclosure under a scoped grant".

To enforce that at `GetAccountState` time — which carries only `{ session, chan_bind }` — the kernel must
already have recorded, at `Pull`, whether the session is ownership or grant. But the normative
`PullRequest { nonce, subject, resolved_scope, chan_bind }` carries no field stating which kind it is: an
ownership pull and a grant pull can arrive byte-identically, both with `resolved_scope` = `*` over the
same `subject`. The distinction lives in which capability the client proved to the API layer — an
`OwnershipProof` versus a `GrantProof` ([§5.1](/specification#51-capability-gated-pull)) — and the API
layer performs that entire gate, then tells the kernel only the resolved scope.

- **How the node bridges it today.** The API layer passes the kind in an out-of-contract gRPC metadata
  key, `x-zkcoins-session-authority` (values `ownership` | `grant`), and the kernel records it on the
  session (the source carries a matching "Proto GAP" note). This value is genuinely out-of-band — unlike
  Gap 2, it is not a proto field at all — so a client built only from the `.proto` cannot open a session
  the kernel accepts at `GetAccountState`, and a reviewer reading only the contract cannot see that
  the "ownership only" rule is satisfiable.

## Gap 2 — the creator / genesis base pubkey is missing on both wire levels

Minting binds an asset to its creator's base pubkey Pk₀ — `creator_pubkey` is a domain-separated hash
input to the on-chain `asset_id` ([§6.5](/specification#65-issuance--token-standards)), and
`GetTokenProvenance` must later return that same `creator_pubkey`. A **genesis receive** credits an
account with no prior state on the node. Both values are needed, and both wire contracts omit them:

- **§7.5 REST.** The normative `POST /v1/tx` `TransitionRequest`
  ([§7.5](/specification#75-node-rest-api-normative)) has no `genesis_pubkey`, and its `issuance` object
  has no `creator_pubkey`.
- **kernel.v1 gRPC.** The normative `Issuance` and `TransitionRequest` messages
  ([§7.8](/specification#78-kernel-rpc--the-internal-interface-normative)) omit the same two fields.

**How the implementations bridge it today.** The node's `proto/kernel/v1/kernel.proto` already carries
`Issuance.creator_pubkey = 7` and `TransitionRequest.genesis_pubkey = 12`, and the reference `api`
crate's wallet-facing JSON already carries `issuance.creator_pubkey` (required) and `genesis_pubkey`
(optional) — its source even cites "(§7.5)" for a field §7.5 does not define. So both the REST body and
the gRPC message have silently diverged from the normative text in the same two fields.

**Can the node derive the value instead of carrying it?** Partly, and unevenly — which matters for the
options below:

- The compliance circuit binds `creator_pubkey` to the minting account via
  `address(creator_pubkey, nk_commit) == owner` (all mints), and — for token-standard-2 only —
  additionally to `current_pubkey`. For token-standard-1, and whenever the minting account has advanced
  (`send_counter > 0`, so `current_pubkey ≠ Pk₀`), the wire contract does not make Pk₀ recoverable from
  the account head. The reference node does persist Pk₀ per account, so it *can* look it up for an
  already-registered account; the contract does not guarantee that.
- A genesis receive's recipient has no prior account state on the node, so no scheme that reads existing
  account state can look up its Pk₀. (The node did see that Pk₀ once, though — in the `OwnershipProof` at
  bootstrap entrust; see the derive option below.)

## Options and trade-offs

The two gaps are independent; reviewers can resolve each one differently. The options below lay out the
choice rather than foreclose it.

**Gap 1 (session discriminator).**

- *Add a typed field to `PullRequest`* — closed string `authority` (`ownership` | `grant`), matching the
  proto's own house style ("closed string value sets stay as strings … not as enums", as
  `TransitionRequest.kind` and `Job.status` already are). Makes `Pull` drivable from the `.proto`.
- *Normatively document the `x-zkcoins-session-authority` metadata key* as part of the kernel.v1
  transport. Smaller edit, but the `.proto` stays non-self-sufficient — a client built from the `.proto`
  alone still needs out-of-band knowledge.

**Gap 2 (creator / genesis pubkey).**

- *Add the fields to both §7.5 and §7.8* (the shape both implementations already use). Directly matches
  reality; the trade-off is that it edits the frozen wire text (see the freeze analysis below).
- *Derive the value node-side instead of carrying it.* The node already receives an account's Pk₀ in the
  `OwnershipProof` at `POST /v1/bootstrap/entrust`, and it requires an active operational bundle for
  **every** transition — including a genesis receive — so a genesis recipient has necessarily entrusted,
  and the node has already seen its Pk₀ once. A design that captured and persisted Pk₀ at entrust could
  make **both** `creator_pubkey` and `genesis_pubkey` derivable without a per-transition field. The
  catch: the API handler verifies the `OwnershipProof`, but the `EntrustRequest` it then builds carries
  no Pk₀ field, so the verified key never reaches the kernel. This route therefore trades two
  per-transition fields for a different additive change (Pk₀ into the entrust path) and couples issuance
  and receive to persisted bootstrap state.
- *Defer to kernel.v2 / a §7.5 `/v2/`* — keep the frozen text pristine (see below).
- *Document the current divergence as deliberate* — ratify the spec-vs-implementation drift in place
  rather than close it. This is **not** a paper-conformance deviation in the `CONTRIBUTING.md` sense
  (that rule governs departures from the two source papers — zkCoins registers each such departure, with
  its rationale and release gate, in the Paper-Deviation Analysis and Paper-Conformance Remediation, adds
  a security argument only where a load-bearing boundary moves, and opens a Risks entry and an issue only
  for an open contradiction);
  it is a text-vs-implementation gap, so it needs a spec statement making the divergence intentional, not
  a paper-deviation register entry.

**Recommendation (a preference, not a foreclosure):** a single additive amendment that adds `authority`
to `PullRequest` and the two pubkey fields to both §7.5 and §7.8 — because the values are needed, the two
pubkey fields already exist in this shape in both implementations (only `authority` is a genuine new
addition), and (below) the freeze rule permits it pre-step-7. The node-side-derive route is a real
alternative for the pubkeys, but it trades these fields for a different additive change to the entrust
path, so it does not avoid amending a wire contract.

## Why the additive amendment fits the v1 freeze

[§1.7.8](/specification#178-reference-instantiation-status-final-for-v1) freezes the wire formats only
**from runbook step 7 (public testnet)**. It states, verbatim, that **between step 3 and step 7** "an
addition to the §7 wire formats that touches **neither** a circuit element **nor** a pinned vector **nor**
a digest is **not** a new protocol version; it **MUST** be introduced by a specification PR that states
why the addition is required" — and it names the additive `GET /v1/token/<asset_id>/provenance` read as
"exactly such an addition". That rule spans all of §7, so it covers the §7.5 REST body and the §7.8 gRPC
message alike. Each field here qualifies:

- **`authority`** is a pull-session access field with no circuit involvement.
- **`creator_pubkey`** is *already* a bound circuit input (it hashes into `asset_id`); the new wire field
  only transports a value the circuit already consumes.
- **`genesis_pubkey`** supplies the genesis account's initial `txn_pubkey`, a value the account model
  already binds; the wire field transports it rather than introducing a new circuit input.

None of the three changes a circuit element, a pinned vector, or a digest, and none moves a trust
boundary — the API layer still performs the entire [§5.1](/specification#51-capability-gated-pull)
capability gate. The precondition is that the network is **still before runbook step 7**; after that
point a §7 change is a new protocol version and this must instead be a `/v2/` contract. Given a
pre-step-7, green-field v1, an additive amendment matches the spec's own mechanism; deferring to v2 keeps
the frozen text pristine but ships a v1 whose published contracts cannot carry values the node needs.

## Spec impact when adopted (v1, pre-step-7)

A follow-up specification PR would, per the §1.7.8 between-steps rule, state why each addition is required
(this page) and then:

- **[§7.8](/specification#78-kernel-rpc--the-internal-interface-normative) (kernel.v1 gRPC).** Add
  `PullRequest.authority` (closed string `ownership` | `grant`); its absence or any other value is
  `INVALID_ARGUMENT` / `malformed_request` / `400` (the mapping `Pull` already uses). **Ratify** the two
  pubkey fields already present in the node proto — `Issuance.creator_pubkey = 7`,
  `TransitionRequest.genesis_pubkey = 12` — with their presence rules (`creator_pubkey` required for a
  mint; `genesis_pubkey` required for a genesis receive, `INVALID_ARGUMENT` / `malformed_request` / `400`
  otherwise), and note that `authority` retires the `x-zkcoins-session-authority` metadata key. So this
  ratifies two existing proto fields and introduces one new one.
- **[§7.5](/specification#75-node-rest-api-normative) (REST).** Document the matching JSON fields
  (`issuance.creator_pubkey`, `TransitionRequest.genesis_pubkey`) the reference `api` already accepts,
  with the same presence rules and error mapping.
- **A small node fix** to track with the amendment: map the genesis-receive presence-rule violation to
  `INVALID_ARGUMENT` instead of today's `internal_error`.

It touches no circuit element, pinned vector, or digest, so the amendment rebuilds no lineage. Until
reviewers choose a direction, the spec text stays unchanged and the implementations keep their current
fields.
