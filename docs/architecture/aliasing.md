---
sidebar_position: 9
title: Aliasing (Design)
---

# Aliasing

:::info Design document
This page describes a **proposed design**, not the current implementation. Today's behaviour is documented in [Addressing](./addressing.md). The properties described below depend on protocol-level work that is tracked separately (see [SPEC.md §15 D2/D10](https://github.com/zk-coins/node/blob/develop/SPEC.md) and [zk-coins/node#170](https://github.com/zk-coins/node/issues/170)).
:::

## Guiding principle

**Aliases are the identity. Everything else is cryptographic plumbing.** Users only ever see, share, or type `name@zkcoins.app`. Raw hex strings, public keys, and commitments exist — but only inside the protocol and wallet, never in the UI.

The current implementation collapses several distinct concepts into a single 64-hex string: the user-facing identifier, the on-chain coin recipient field, and the server-side state lookup key. Aliasing separates these into independent layers.

## Layer model

| Layer | Visibility | Contents |
| --- | --- | --- |
| **1. Alias** | user-facing, public | `bob@zkcoins.app` |
| **2. Directory** | sender wallet | alias → scan material |
| **3. Payment derivation** | per send | one-time commitment inside the coin |
| **4. State** | account owner only (authenticated) | balance, history, send counter |
| **5. On-chain** | anyone | 64-byte opaque nullifier (unchanged) |

A clean separation of these five layers is the architectural change. The cryptographic primitives required (ECDH derivation, view-key separation) are standard.

## Layer 1 — Alias

| Property | Definition |
| --- | --- |
| Form | `name@<directory-host>`, e.g. `bob@zkcoins.app` |
| Lifetime | permanent, no rotation |
| Uniqueness | within one directory host |
| Reservation | signed claim using the wallet's master key |
| Recovery | deterministic from the seed (claim signature reproducible) |
| Raw hex in UI | **never** — not in settings, export, or QR captions |
| QR encoding | the alias string itself, not the underlying bytes |

Self-hosting means running an own directory host, e.g. `bob@bob.eu`. The alias scheme is host-transparent — wallets only need to resolve the host suffix.

## Layer 2 — Directory

A single public operation:

```
GET https://<host>/.well-known/zkcoins/resolve/<name>
→   { "scan_pub": "<bytes>", "spend_pub": "<bytes>", "version": 1 }
```

- **Unauthenticated.** The response carries no state — only the routing material needed to address the account. Knowing it lets you pay; it does not let you read.
- Cache-friendly. The value is stable for the wallet's lifetime.
- Does **not** return balance, activity flags, history existence, send counter, or pending status. Nothing about the account's state.
- The host suffix in the alias determines which directory to query. Aliases are bound to a host; cross-host migration is out of scope for this design.

## Layer 3 — Payment derivation

For each send, the sender wallet derives a one-time commitment so that two payments to the same alias are not linkable on chain or between senders.

```
1. Resolve scan_pub from the recipient's directory (cached after first lookup).
2. Generate an ephemeral keypair (e_priv, e_pub).
3. shared       = ECDH(e_priv, scan_pub)        // known only to sender + recipient
4. payment_tag  = H(shared, send_index)         // goes into the coin
5. scan_hint    = e_pub                          // goes into the coin
```

The coin recipient field, currently a plaintext address (see SPEC §15 D2), becomes:

```
Coin.recipient_commit = payment_tag
Coin.scan_hint        = scan_hint
```

Properties:

- Two sends to the same alias produce two unrelated `payment_tag` values. Not linkable on chain.
- Different senders paying the same recipient cannot detect each other's payments by comparing notes: `payment_tag` is a hash over the ECDH `shared` secret, which only the sender and recipient can compute.
- The recipient's alias stays the same. No rotation, no sub-addresses required for unlinkability.

This is a direct extension of the D2/D10 commitment work tracked in SPEC §15, with the additional per-send randomization that makes recipient values structurally unlinkable.

## Layer 4 — State (server-side, authenticated reads)

All read endpoints require a Schnorr-signed request, using the same signature scheme already used for `/api/send`. The server keys reads on the account hash internally, never on the alias.

```
GET /api/balance     → signature with spend_priv
GET /api/history     → signature with spend_priv
GET /api/scan        → signature with scan_priv  (lighter capability)
```

Three capability levels, cleanly separated:

| Capability | Private key | What it grants |
| --- | --- | --- |
| **Receive** | none | sending coins to the alias |
| **View** | `scan_priv` | recognising incoming coins, reading balance and history |
| **Spend** | `spend_priv` | spending coins |

`scan_priv` and `spend_priv` are both derived from the wallet seed via BIP-32 branching and normally live in the wallet together. The separation enables view-only export — for example, sharing `scan_priv` with an accountant without granting send rights.

This closes the unauthenticated-read leaks discussed in [zk-coins/node#170 P10](https://github.com/zk-coins/node/issues/170) without removing the lookup endpoints themselves.

## Layer 5 — On-chain

Unchanged from the existing protocol: 64-byte half-aggregate Schnorr nullifier, Taproot inscription, `4242` marker prefix. Only the *contents* committed inside the coin change (from plaintext address to `payment_tag` with `scan_hint`).

## User-level operations

| User action | What happens internally |
| --- | --- |
| **Create wallet** | Seed → master key → derive `spend_priv` + `scan_priv` → publish `(scan_pub, spend_pub)` to the directory with a desired alias → directory stores the claim |
| **Receive** | The user shares `bob@zkcoins.app`. Nothing else. |
| **Send** | User types `alice@zkcoins.app`; wallet resolves the alias once, derives a fresh `payment_tag`, builds the send request |
| **Restore** | Seed entered → `scan_priv` / `spend_priv` reproduced → signed `/api/scan` returns all coins whose `scan_hint` matches the recovered `scan_priv` → balance hydrated |

## Protocol operations

| Operation | Endpoint | Authentication |
| --- | --- | --- |
| **Claim alias** | `POST /api/alias/claim` | Schnorr signature with `spend_priv` over `(name, scan_pub, spend_pub)` |
| **Resolve alias** | `GET /.well-known/zkcoins/resolve/:name` | none — pure routing |
| **Pay** | `POST /api/send` | sender Schnorr signature; the coin carries `payment_tag` + `scan_hint` |
| **Scan / read** | `GET /api/{balance,history,scan}` | recipient Schnorr signature (view or spend, depending on endpoint) |

## What this addresses

| Problem (current state) | After aliasing |
| --- | --- |
| Hex strings visible in the UI | Solved — only aliases appear in the UI |
| Username-resolve → address → balance / history lookup | Solved — resolve returns routing material only; reads are authenticated |
| Cross-sender linkability of payments to the same recipient | Solved — each send derives an independent `payment_tag` |
| On-chain coin linkability (SPEC §15 D2) | Solved — coin carries a commitment, not a plaintext address |
| `num_sends` as a public activity counter | Solved — behind authentication |
| Address rotation as a privacy workaround | Not required — the alias is permanently stable |
| View-only sharing | Newly possible via the dedicated `scan_priv` capability |

## What this does **not** address

| Problem | Why it remains |
| --- | --- |
| Operator visibility into `/api/send` plaintext | Server-side prover still observes `(sender, payment_tag, amount)`. This is [zk-coins/node#170 P3/P9](https://github.com/zk-coins/node/issues/170) and is orthogonal to aliasing. |
| Operator linkability of `payment_tag` to a recipient when scanning is server-side | Only mitigable via client-side scanning, which is a bandwidth/UX trade-off discussed below. |
| Alias squatting | A UX/policy concern (first-come, reservation window, fee, …), not a privacy property. |
| Migration between directory hosts | Intentionally out of scope. Aliases are host-bound. |

## Default choices for the three open design questions

| Question | Default | Rationale |
| --- | --- | --- |
| Scan: server-side with auth, or client-side? | **Server-side with auth as MVP; client-side as opt-in v2** | Fits the thin-client architecture; the operator already sees plaintext via the send path, so server-side scan does not regress privacy further. |
| Alias format | **`name@host`** (RFC 5321-compatible) | Universally shareable, copy/paste-friendly, double-click-selectable in any browser. |
| Aliases per wallet | **One primary alias + optional unnamed sub-aliases** | Avoids multi-alias UI complexity for typical users while leaving room for power-user flows. |

## Open items before implementation

1. How `payment_tag` slots into the Plonky2 circuit. The change is adjacent to SPEC §15 D2/D10, which already plans to replace plaintext recipients with commitments inside the `apply_coin` gadget.
2. Server-side scan: index design for `scan_hint` in Postgres so lookups by recipient scan key remain efficient at scale.
3. Alias squatting policy: first-come, reservation window, burn-fee, or subdomain-style namespacing.
4. View-only export format: the canonical encoding for a shareable `scan_priv` blob.

## Relationship to existing documents

- [Addressing](./addressing.md) — describes the **current** three-phase address scheme. This document supersedes it once implemented.
- [Privacy Model](./privacy-model.md) — describes what is and is not private today. Aliasing changes both the "what is hidden" and "what is visible" tables.
- [Nullifier Design](./nullifier-design.md) — unchanged. Aliasing operates on the coin contents, not the nullifier itself.
- [SPEC.md §15](https://github.com/zk-coins/node/blob/develop/SPEC.md) — circuit-level divergences D2 and D10 are the cryptographic prerequisites for aliasing.
- [zk-coins/node#170](https://github.com/zk-coins/node/issues/170) — network-layer decentralization problems. Aliasing closes the read-side privacy gap (P10) but does not address the prover-locality issues (P3, P9).
