---
sidebar_position: 9
title: Aliasing (Design)
---

# Aliasing

:::info Design document — v0.2
This page describes a **proposed design**, not the current implementation. Today's behaviour is documented in [Addressing](./addressing.md). The properties described below depend on protocol-level work that is tracked separately (see [SPEC.md §15 D2/D10](https://github.com/zk-coins/node/blob/develop/SPEC.md) and [zk-coins/node#170](https://github.com/zk-coins/node/issues/170)).

**v0.2 closes the gaps identified in v0.1:** the wallet uses a single signing key (no scan/spend split); restore, default-alias derivation, authenticated reads, send-to-unclaimed and cross-host operation are now specified concretely.
:::

## Guiding principles

Two non-negotiable constraints shape this design.

**1. Aliases are the identity. Everything else is plumbing.**
Users only ever see, share, or type `name@zkcoins.app`. Raw hex strings, public keys, BIP-32 indices and commitments exist — but only inside the protocol and the node, never in the wallet UI and never on the SDK surface.

**2. The wallet SDK looks like every other wallet SDK.**
Integrators (Cake Wallet, LayerZ, BlueWallet, …) work with **seed and address** — exactly the two concepts they already know from Bitcoin, Monero, Lightning. The SDK exposes no zk-specific concepts: no view-key / spend-key split, no ECDH, no BIP-32 index management, no scan loop, no two-phase commit, no proof IDs. Everything that is not seed-or-address is delegated to the node.

**Trust model:** the node operator sees the same plaintext as today. Users who don't want to trust the public operator run their own node. This is the deliberate trade-off that keeps the SDK trivial to integrate.

## Layer model

| Layer | Visibility | Contents | Lives in |
| --- | --- | --- | --- |
| **1. Alias** | user-facing, public | `bob@zkcoins.app` | wallet UI |
| **2. SDK surface** | wallet integrator | `seed`, `address`, `balance`, `send`, `history` | SDK |
| **3. Directory + payment derivation** | node-internal | per-recipient `account_pub` lookup; per-send `payment_tag` (ECDH) | node |
| **4. State** | account owner only (authenticated) | balance, history, send counter | node |
| **5. On-chain** | anyone | 64-byte opaque nullifier (unchanged) | Bitcoin chain |

The clean separation across these five layers is the architectural change. Layers 1, 2, and 5 are what wallets and users see. Layers 3 and 4 are entirely the node's responsibility.

## Layer 1 — Alias

| Property | Definition |
| --- | --- |
| Form | `name@<directory-host>`, e.g. `bob@zkcoins.app` |
| Lifetime | permanent, no rotation |
| Uniqueness | within one directory host |
| Reservation | signed claim using the wallet's signing key |
| Recovery | deterministic from the seed (claim signature reproducible) |
| Raw hex in UI | **never** — not in settings, export, or QR captions |
| QR encoding | the alias string itself, not the underlying bytes |

Self-hosting means running an own directory host, e.g. `bob@bob.eu`. The alias scheme is host-transparent — wallets only need to resolve the host suffix.

## Layer 2 — SDK surface

The wallet SDK presents the same shape any familiar wallet SDK does. An integrator that has wired up a Bitcoin or Monero wallet recognises every method.

```ts
class ZkCoinsWallet {
  // Construction — from a BIP-39 mnemonic, like every other wallet SDK.
  static async fromMnemonic(
    mnemonic: string,
    opts?: { nodeUrl?: string; network?: "mainnet" | "testnet" },
  ): Promise<ZkCoinsWallet>;

  // Properties — synchronous, computed once from the seed.
  readonly address: string;          // "bob@zkcoins.app"

  // State — async, served by the node.
  getBalance(): Promise<{ confirmed: bigint; pending: bigint }>;
  getHistory(opts?: { limit?: number; offset?: number }): Promise<Tx[]>;
  validateAddress(s: string): boolean;

  // Transaction — single atomic call. No two-phase commit on the SDK surface.
  send(to: string, amountSats: bigint): Promise<{ txid: string }>;

  // Optional, off the hot path — upgrade default alias to a vanity name.
  claimUsername(name: string): Promise<string>;  // returns the new address
}
```

That is the entire surface. One constructor, one property, six methods.

**What the SDK does internally:**

- BIP-39 → BIP-32 derivation of a single wallet signing key (`account_priv`).
- Schnorr signing of outgoing requests (`send`, authenticated reads, alias claim).
- HTTP transport to the node.
- Alias parsing and basic validation (format only — see Open items).

**What the SDK does NOT do:**

- No ECDH or per-send key derivation.
- No view-key / spend-key separation.
- No BIP-32 index management or `num_sends` tracking.
- No scan loop, no candidate-set processing.
- No proof generation, no proof verification, no proof IDs.
- No two-phase send/commit choreography.
- No on-chain access (no Bitcoin node connection from the wallet).

Everything in the second list happens behind `/api/send` and `/api/balance` on the node.

### Integration shape for popular wallets

| Wallet target | Mapping |
| --- | --- |
| **Cake Wallet** `WalletService` | `restore` → `fromMnemonic`, `address` getter → `wallet.address`, `balance` → `getBalance`, `createTransaction` + `commit` → `send`, `transactionHistory` → `getHistory` |
| **LayerZ** | same shape; `send` is single-step |
| **BlueWallet** | same shape |
| **Custom wallets** | depend only on `fromMnemonic`, `address`, `send`, `getBalance`, `getHistory` |

The integration effort is comparable to adding a second Bitcoin-family chain (Litecoin, Bitcoin Cash) — a fraction of the effort that Monero or Ethereum require, because the SDK does not own any on-chain scanning machinery.

## Layer 3 — Directory and payment derivation (node-internal)

This entire layer is invisible to the wallet and to the SDK. It lives inside the node.

**One key per wallet.** The recipient publishes exactly one public key, `account_pub`, derived deterministically from the wallet seed (see Wallet ↔ node protocol details below). The node uses it for two purposes simultaneously:

- as the receiver point for incoming-payment ECDH,
- as the verifier point for outgoing-payment Schnorr signatures, alias claims, and authenticated reads.

A separate "scan key" would protect against nothing the operator cannot already see at request time. In privacy coins where the scan side runs client-side (Monero), a scan/spend split prevents the watcher from spending; here, the scan side runs on the same node that already authorises spends, so the split is structurally redundant.

When a wallet calls `wallet.send("alice@zkcoins.app", amount)`, the SDK forwards the alias as an opaque string to the node. The node:

1. Resolves the alias to Alice's `account_pub`.
2. Generates an ephemeral keypair `(e_priv, e_pub)`.
3. Computes `shared = ECDH(e_priv, account_pub)`.
4. Derives `payment_tag = H(shared || send_index)` — distinct per send, even to the same recipient.
5. Writes `Coin.recipient_commit = payment_tag` and `Coin.scan_hint = e_pub` into the coin.
6. Runs the Plonky2 prover and publishes the nullifier as today.

Properties this preserves:

- **On-chain unlinkability** — two sends to the same alias produce two unrelated commitments. Outside observers cannot link them. (This is the direct fix for SPEC §15 D2.)
- **Cross-sender unlinkability against outside observers** — three different senders paying Alice produce three unlinkable on-chain artifacts.
- **No wallet complexity** — the SDK is unaware that any of this happens.

What this does **not** preserve, and accepts as the trust trade-off:

- The node operator sees plaintext at request time (sender, alias, amount). The same trust assumption that already holds today.
- A malicious operator could collapse the per-send derivation (e.g., reuse nonces) and reintroduce on-chain linkability. Mitigation: self-hosting, or third-party audits of the running operator binary.

## Layer 4 — State (node, authenticated reads)

`/api/balance`, `/api/history`, and the alias claim endpoint all require a Schnorr-signed request using the wallet's single signing key. The node keys reads on `account_pub`, never on the alias.

Two capability levels, sufficient for every wallet flow:

| Capability | Held by | What it grants |
| --- | --- | --- |
| **Receive** | anyone with the alias | sending coins to the alias |
| **Account** | wallet signing key | reading state, spending coins, claiming aliases |

There is intentionally no separate view-key. View-only flows (accountant access, watching wallets, …) are out of scope for this design — they would either complicate the SDK or require a node-side delegation mechanism, both of which conflict with the integration-simplicity constraint.

### Authenticated request format

Every authenticated request — GET or POST — carries the same triple:

| Field | Definition |
| --- | --- |
| `account_pub` | BIP-340 x-only public key, 32 bytes, hex-encoded |
| `timestamp` | Unix epoch seconds; the node accepts a ±5-minute window |
| `signature` | BIP-340 Schnorr over `H("zkcoins/v1" \|\| method \|\| path \|\| timestamp \|\| body_hash)` |

`body_hash` is `SHA-256` of the request body, or 32 zero bytes for empty bodies. The domain-separator string `"zkcoins/v1"` prevents cross-protocol replay.

For GET endpoints, the triple is sent in the `Authorization` header:

```
Authorization: ZkCoins v=1 pub=<account_pub_hex> ts=<timestamp> sig=<signature_hex>
```

For POST endpoints, the same triple lives in the request body (`auth: { account_pub, timestamp, signature }`). The node caches accepted `(account_pub, timestamp)` pairs for the validity window to prevent replay.

## Layer 5 — On-chain

Unchanged from the current protocol: 64-byte half-aggregate Schnorr nullifier, Taproot inscription, `4242` marker prefix. Only the *contents* committed inside the coin change (from plaintext address to `payment_tag` with `scan_hint`).

## Wallet ↔ node protocol details

### Wallet key derivation

A wallet derives **exactly one** signing key from the seed:

```
seed → BIP-39 entropy → BIP-32 master → m/zkcoins'/0'/0  →  account_priv
account_pub = account_priv · G   (BIP-340 x-only encoding)
```

The derivation path is intentionally short — one application-scoped hardened index plus one chain — because the node handles all per-payment freshness via ephemeral keys on its side. No per-recipient or per-send branching exists in the wallet.

### Default alias derivation

The default alias is **wallet-computed and deterministic**:

```
default_local_part = first N hex chars of SHA-256("zkcoins-alias-v1" || account_pub)
default_alias      = default_local_part + "@" + configured_host
```

This design picks `N = 16` (64 bits, ~4 billion accounts before significant birthday collisions). The domain-separator `"zkcoins-alias-v1"` is included so the prefix cannot be confused with any other hash use of `account_pub`.

Determinism matters because:

- The wallet can display the default alias immediately after creation, before any network round-trip.
- On restore, the same seed reproduces the same default local part. The host comes from configuration, not the seed.
- A user moving from `prefix@zkcoins.app` to `prefix@self.host` keeps the same local part.

On `POST /api/alias/claim` with the default local part, the node accepts unless a prior claim by a different `account_pub` exists (collision). Collisions return `409 Conflict`; the wallet retries with a longer prefix (`N + 4`, recursively) and surfaces the final claimed alias as `wallet.address`.

### Onboarding flow

```
1. SDK generates seed (or accepts a provided mnemonic).
2. SDK derives account_priv / account_pub locally.
3. SDK computes default_local_part = SHA-256(...).
4. SDK calls POST /api/alias/claim with { account_pub, default_local_part, signature }.
5. Node either accepts (creates the account, stores the claim) or returns 409.
6. SDK sets wallet.address and returns. No further calls are required for the user
   to start receiving.
```

### Restore protocol

Restore is **not** a separate endpoint. A wallet restored from seed:

1. Re-derives `account_priv` and `account_pub`.
2. Computes the default local part deterministically.
3. Calls `GET /api/balance` with an authenticated header.

The response is `{ alias, confirmed, pending }`:

- If the node knows this `account_pub`, `alias` is whatever the user has claimed (vanity name or default).
- If the node does not know this `account_pub`, it creates the account on-the-fly using the default local part as the alias, and returns the resulting state. This makes restore on a fresh node indistinguishable from initial onboarding from the SDK's perspective.

### Send to an unclaimed alias

The directory resolution for an unclaimed alias returns `404 Not Found`. The SDK surfaces this as a typed error `RecipientNotFound`, with the alias string preserved for UI presentation.

There is intentionally no auto-create path on the sender's side. The recipient must claim an alias before they can receive, because without a registered `account_pub` the sender's node has no public point against which to ECDH-derive the per-send commitment. This is the price of the per-send unlinkability mechanism.

## Cross-host operation

Self-hosting is meaningful only if a self-hosted node can transact with the public operator. This section specifies the minimal cross-host mechanism.

### Directory resolution across hosts

When the sender's node receives `POST /api/send` for `alice@bob.eu`, it parses the alias and fetches:

```
GET https://bob.eu/.well-known/zkcoins/resolve/alice
→ { "account_pub": "<hex>", "version": 1 }
```

Resolution is cached per `(host, name)` pair for the wallet session lifetime, with a TTL no longer than 24 hours. An entry is invalidated on out-of-band failure (TLS error, 4xx response) or on explicit refresh.

### Coin transport between nodes

The chain carries only the 64-byte nullifier. The `(coin, coin_proof)` payload must reach the recipient's node off-chain. The mechanism:

After publishing the nullifier, the sender's node POSTs the coin bundle directly to the recipient's node:

```
POST https://bob.eu/api/inbox
Body: {
  coin: <bytes>,
  coin_proof: <bytes>,
  nullifier_locator: { block_height, txid, vout, witness_index }
}
```

The recipient's node:

1. Verifies the proof against its local nullifier accumulator (including the nullifier at `nullifier_locator`).
2. Decrypts the recipient hint with the local `account_priv` to confirm the coin is genuinely addressed to one of its accounts.
3. Credits the recipient's account.
4. Returns `202 Accepted` (idempotent — re-delivery of the same `nullifier_locator` is a no-op).

Replay protection is structural: the nullifier is unique per send, and the recipient's node refuses to credit the same nullifier twice.

### Offline-recipient handling

If the recipient's node is unreachable at delivery time, the sender's node:

1. Retains the coin bundle in a local outbox keyed by `nullifier_locator`.
2. Retries delivery on an exponential backoff schedule, indefinitely up to a configured retention window (default 30 days).
3. Surfaces the pending delivery in the sender's `/api/history` as `status: "pending-delivery"`.

If the recipient's node loses local state (DB wipe, disk failure) and the chain still has the nullifier, the recipient can request re-delivery by issuing an authenticated `GET /api/inbox/{nullifier_locator}` to the sender's node. The sender's node honours the request for the duration of the retention window. After retention expiry, the bundle is considered lost and recovery becomes an operator-specific concern (e.g., log-based reconstruction) — there is no protocol-level recovery beyond the window.

## User-level operations

| User action | What happens internally |
| --- | --- |
| **Create wallet** | Seed generated → `account_priv` derived → SDK computes default local part → claim posted to node → `wallet.address` set |
| **Receive** | The user shares `bob@zkcoins.app`. Nothing else. |
| **Send** | User types `alice@zkcoins.app`; SDK signs and POSTs to the node; the node resolves (locally or cross-host), runs ECDH, generates proof, broadcasts the nullifier, delivers the coin bundle to the recipient's node |
| **Restore** | Seed entered → `account_priv` reproduced → authenticated `GET /api/balance` → node returns alias + balance |
| **Vanity name (optional)** | `wallet.claimUsername("bob")` → signed claim → node updates the alias for this account |

## Protocol operations

| Operation | Endpoint | Authentication |
| --- | --- | --- |
| **Resolve alias** | `GET /.well-known/zkcoins/resolve/:name` | none — pure routing, returns `account_pub` only |
| **Claim alias** | `POST /api/alias/claim` | authenticated request (see Layer 4) |
| **Pay** | `POST /api/send` | authenticated request; alias is in the body, the node does the rest |
| **Read state** | `GET /api/{balance,history}` | authenticated request |
| **Cross-host coin delivery** | `POST /api/inbox` | sender-node origin verification (TLS) plus proof validation by recipient node |
| **Cross-host re-delivery request** | `GET /api/inbox/{nullifier_locator}` | authenticated request from the recipient wallet |

The wallet SDK touches only `claim`, `send`, and `read state` directly. The `resolve` and `inbox` endpoints are consumed by the node itself.

## What this addresses

| Problem (current state) | After aliasing v0.2 |
| --- | --- |
| Hex strings visible in the UI | Solved — only aliases appear in the UI |
| Username-resolve → address → balance / history lookup | Solved — resolve returns `account_pub` only; reads are authenticated |
| Cross-sender linkability of payments to the same recipient (on-chain) | Solved — each send derives an independent `payment_tag` |
| On-chain coin linkability (SPEC §15 D2) | Solved — coin carries a commitment, not a plaintext address |
| `num_sends` as a public activity counter | Solved — behind authentication |
| Address rotation as a privacy workaround | Not required — the alias is permanently stable |
| Wallet SDK complexity blocking integrations | Solved — SDK collapses to seed + address + four methods |
| Cross-host send (#170 P1) | Specified — directory resolve + `/api/inbox` push, with offline retention |

## What this does **not** address

| Problem | Why it remains |
| --- | --- |
| Operator visibility into `/api/send` plaintext | Server-side prover still observes `(sender, alias, amount)`. This is [zk-coins/node#170 P3/P9](https://github.com/zk-coins/node/issues/170) and is the **deliberate trust trade-off** that enables the simple SDK. Users who do not want to trust the public operator self-host. |
| Operator linkability of `payment_tag` to a recipient | Implicit in operator visibility; identical mitigation (self-host). |
| Alias squatting | A UX/policy concern (first-come, reservation window, fee, …), not a privacy property. |
| Migration between directory hosts | Intentionally out of scope. Aliases are host-bound; moving means re-claiming on the new host. |
| View-only / watch-only wallet access | Intentionally out of scope. Would require either SDK complexity or a node-side delegation flow; both conflict with the integration-simplicity constraint. |

## Default choices

| Question | Default | Rationale |
| --- | --- | --- |
| Where does ECDH / payment derivation run? | **Node** | Required by the SDK-simplicity constraint. Operator-trust trade-off accepted; self-host is the escape hatch. |
| Alias format | **`name@host`** (RFC 5321-compatible) | Universally shareable, copy/paste-friendly, double-click-selectable in any browser. |
| Default alias on wallet creation | **Wallet-computed, 16 hex chars from `SHA-256("zkcoins-alias-v1" \|\| account_pub)`** | Deterministic from seed alone; safe collision margin; no hex shown to the user |
| Aliases per wallet | **One primary alias** | Matches the mental model of every other wallet SDK; reduces UI surface |
| View-key separation | **None** | Out of scope; see above |
| `validateAddress(s)` semantics | **Format-only** (regex on `name@host`) | Live directory probes are an explicit `wallet.send` precondition — no need to spend a round-trip on every keystroke |
| Cross-host coin retention by sender | **30 days** | Long enough to cover typical recipient downtime / restore; bounded so outboxes do not grow forever |
| Auth request validity window | **±5 minutes** | Matches the existing `/api/send` skew; small enough to keep the replay cache bounded |

## Open items before implementation

1. **Plonky2 circuit slot for `payment_tag` / `scan_hint`.** Adjacent to SPEC §15 D2/D10, which already plans the commitment-based recipient.
2. **`Tx` type for `getHistory`.** Concrete TypeScript shape — fields, optionality of counterparty, status enum, pagination cursor format.
3. **`counterparty` content in history rows after D2.** Once on-chain recipients are commitments, the counterparty for a `send` is naturally the alias the wallet typed; the counterparty for a `receive` has no clean attribution and is likely `null`.
4. **Alias squatting policy.** First-come, reservation window, burn-fee, or subdomain-style namespacing. Default proposed: first-come, with operator-side rate limiting on claim attempts.
5. **SDK packaging.** Does `@zkcoins/sdk` v0.2 ship the new surface as a clean replacement, or as an additive `ZkCoinsWallet` class alongside the existing lower-level `ZkCoinsClient`?
6. **Cross-host trust posture.** Authentication of the `POST /api/inbox` request beyond TLS: should the sender's node sign the bundle envelope? Should the recipient's node refuse delivery from unknown hosts?
7. **Multi-account-per-host limits.** A node serving many accounts is the assumed default; anti-squatting and fee structure may impose limits — open as policy.
8. **Migration of existing accounts.** Hex-prefix accounts on the current scheme map deterministically to default aliases (`<hex-prefix>@<host>`) without state changes; vanity names migrate via re-claim against the same `account_pub`. Concrete migration script is implementation work.

## Relationship to existing documents

- [Addressing](./addressing.md) — describes the **current** three-phase address scheme. This document supersedes it once implemented.
- [Privacy Model](./privacy-model.md) — describes what is and is not private today. Aliasing changes both the "what is hidden" and "what is visible" tables.
- [Nullifier Design](./nullifier-design.md) — unchanged. Aliasing operates on the coin contents, not the nullifier itself.
- [SPEC.md §15](https://github.com/zk-coins/node/blob/develop/SPEC.md) — circuit-level divergences D2 and D10 are the cryptographic prerequisites for aliasing.
- [zk-coins/node#170](https://github.com/zk-coins/node/issues/170) — network-layer decentralization problems. Aliasing closes the read-side privacy gap (P10) and specifies a mechanism for the cross-host transport gap (P1). Prover locality (P3, P9) remains mitigated only by self-hosting.
