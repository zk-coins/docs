---
sidebar_position: 1
title: Specification
---

# zkCoins Protocol Specification

This document is **a possible** technical specification of the **zkCoins protocol** — one concrete, buildable realization of the zkCoins concept (Robin Linus) and the **Shielded CSV** construction (Jonas Nick, Liam Eagen, Robin Linus), designed around a single principle: **the full self-sovereignty of every participant, with no central element anywhere in the system.**

> Private payments on Bitcoin — no new chain, no token, no consensus change, no trusted operator. Only Bitcoin, zero-knowledge proofs, and the user's own keys.

:::tip In one paragraph (plain language)
zkCoins lets you send value on Bitcoin without anyone seeing the amount, the asset, who paid, or who received. Bitcoin stores only **opaque markers** that a spend happened — *not* the coin's contents, which travel privately between sender and receiver as a small encrypted bundle. **Double-spend protection** is the chain's job: each spent coin publishes a one-time random-looking *nullifier* on Bitcoin, and any second appearance is rejected. Your **seed phrase** derives every key, your **wallet** is the only thing that can spend, **any node** can serve you, and you check every figure against Bitcoin yourself.
:::

:::info What this is — and what it isn't
This is **one** concrete realization, not the only one possible: wherever the source papers leave a choice open, this specification takes the established, Bitcoin-consistent option and defines it exactly. It builds faithfully on the whitepapers' core and carries their philosophy into every layer they did not formalize — delivery, recovery, access, and operation. It describes the **target design** and is intentionally independent of any current implementation.
:::

## One principle, carried all the way

Every decision below follows from one idea — **complete self-sovereignty, zero central elements** — applied without exception:

| Design decision | follows from the principle |
|---|---|
| Settles only on Bitcoin L1 — no own chain, token, or consensus | inherit the most decentralized base; build no new one |
| Client-side validation; constant-size ZK proofs | each participant verifies for themselves, trusting no one |
| Spend key lives only in the wallet | the participant alone holds custody |
| Off-chain delivery over a node-as-relay mesh | no central delivery service |
| Recovery from seed + Bitcoin + the network | no central backup custodian |
| Capability-gated disclosure; self-hostable, verifiable explorer | the owner alone decides who sees what; no trusted authority |
| Any node — switchable, several at once | no lock-in to any operator |
| Permissionless asset creation | anyone can create their own asset; each asset's minter is its creator |

These are not features bolted on. They are the same principle, followed to its conclusion.

## The triad it guarantees

- **Bitcoin-anchored** — settled on Bitcoin L1, exactly as it exists today.
- **Shielded** — amounts, sender, receiver, and the transaction graph are hidden, behind a global anonymity set.
- **Trustless** — correctness is enforced by cryptography and Bitcoin alone.

Each is rare on its own elsewhere; here they hold **together** — see [Comparisons](/comparisons).

## How the data moves

**What lives where.** Bitcoin holds only opaque markers; everything that says *which coin, how much, between whom* lives off-chain and is encrypted to the recipient:

```
    BITCOIN L1 (Public)                  OFF-CHAIN (Private — wallet + node)
    ────────────────────                 ───────────────────────────────────

    ┌──────────────────┐                 ┌───────────────────────────────┐
    │   SpendRecord    │   sign-to-      │  AccountState                 │
    │   ────────────   │   contract      │   balances · keys · counters  │
    │   Pkᵢ            │   binds         │   coin_history_root           │
    │   nullifiers     │ ◀ H(ProofData)─ ├───────────────────────────────┤
    │   signature      │                 │  Recursive validity proof     │
    │   inr ‖ ocr      │ ◀── attests ─── │   (constant-size · ZK)        │
    └──────────────────┘                 ├───────────────────────────────┤
            ▲                            │  Coin plaintext               │
            │ inscribed in a             │   amount · asset · recipient  │
            │ Taproot reveal-tx          ├───────────────────────────────┤
            │ envelope                   │  CoinProof bundle  ──▶ to B   │
            │                            │   (coin + proof + envelope)   │
            └────────────────────────────┴───────────────────────────────┘
```

**A payment, end to end.** A pays B; both run their own wallet+node; only Bitcoin is shared:

```
    Alice                 Nostr relay         Bitcoin              Bob
      │                       │                  │                  │
      │ 1. build SpendRecord  │                  │                  │
      │    + recursive proof  │                  │                  │
      │                       │                  │                  │
      │ 2. publish encrypted CoinProof bundle (NIP-44 / NIP-59)     │
      ├──────────────────────▶│                  │                  │
      │                       │                  │                  │
      │ 3. inscribe SpendRecord (nullifiers in the clear)           │
      ├──────────────────────────────────────────▶                  │
      │                       │                  │                  │
      │                       │  every node folds the new nfs into  │
      │                       │  its nullifier accumulator          │
      │                       │                  │                  │
      │                       │ 4. scan candidates · match          │
      │                       │    detect_tag (1 Poseidon hash/evt) │
      │                       ◀───────────────────────────────────┤
      │                       │                  │                  │
      │                       │ 5. gift-wrapped bundle blob         │
      │                       ├──────────────────────────────────▶│
      │                       │                  │                  │
      │                       │            6. decrypt with K_tx     │
      │                       │               verify recursive proof│
      │                       │               check nf non-member.  │
      │                       │               of accumulator at tip │
      │                       │                  │                  │
      │                       │            7. credit coin (trustless)
      │                       │                  │                  │
      │ 8. encrypted ACK · A may now drop her retained copy         │
      ◀──────────────────────────────────────────────────────────┤
      │                       │                  │                  │
```

## Scope

The specification covers every component that will exist: the **node** (validator · prover · relay · data store), the **wallet** (thin key-holder), and the **explorer** (public and authorised views) — together with the cryptography that binds them. For every key, hash, and identifier it states exactly **how it is derived**; for every requirement, **how it is met**.

## The ten requirements

The whole specification exists to satisfy these (in full on the [Requirements](/requirements) page):

1. Bitcoin L1 as the only base · 2. Private · 3. Trustless · 4. Client-side validation · 5. Custody only in the wallet · 6. Recovery · 7. Self-hostable · 8. Multi-asset · 9. Selective disclosure · 10. Node portability.

## Reading guide

| # | Page | What it gives you |
|---|---|---|
| 1 | [Foundations](foundations) | The single source of truth: primitives, the full key hierarchy and exact derivations, every identifier, the data structures and the global nullifier accumulator |
| 2 | [Proofs & State Transitions](proofs) | The compliance predicate, recursion, and the mint / send / receive algorithms |
| 3 | [On-chain Layer](onchain) | The `SpendRecord`, signing, half-aggregation, the publisher, and the nullifier accumulator |
| 4 | [Transport & Recovery](transport-recovery) | Off-chain delivery, note discovery, seed recovery, data availability |
| 5 | [Access & Explorer](access-explorer) | Capability-gated pull, view grants, and the disclosure spectrum: per-transaction links, balance attestations, full-account views |
| 6 | [System Architecture](architecture) | Node, wallet, explorer; portability, multi-node, issuance, threat model |
| — | [Glossary](glossary) | Every term, identifier, and notation, alphabetical, one line each |
| — | [Test vectors](test-vectors) | Worked-example values and a conformance harness for implementations |

New here? Read **Foundations** first — everything else builds on it. Stuck on a term? Jump to the **Glossary**.

## Requirements traceability

Where each requirement is satisfied:

| Requirement | Satisfied by |
|---|---|
| **1 · Bitcoin-only base** | §1 (no native token; secp256k1/BIP-340), §3 (a single `SpendRecord` inscribed; no chain/consensus change) |
| **2 · Private** | §1.3 (per-coin encryption), §1.4 (opaque `SpendRecord` carries only hashes and unlinkable nullifiers), §2 (ZK proof hides amounts/parties/graph) |
| **3 · Trustless** | §2 (proof soundness ⇒ no forgery), §3 (nullifier accumulator ⇒ no double-spend), §1.2 (no key a node holds can spend), §6 (threat model) |
| **4 · Client-side validation** | §2 (receiver re-verifies the full recursive proof), §4 (receive flow) |
| **5 · Custody only in wallet** | §1.2 (SPEND branch is wallet-only; hardened separation) |
| **6 · Recovery** | §1.3 (seed-derived detection/scan keys), §4 (seed reconstruction, replication, data availability) |
| **7 · Self-hostable** | §6 (node ships self-contained, no operator-specific dependencies), §4 (node-as-relay) |
| **8 · Multi-asset** | §1.4 (`asset_id`), §1.5 (per-asset balances), §2 (per-asset conservation), §6 (issuance) |
| **9 · Explorer** | §5 (capability-gated authorised view; per-coin view capability; verifiable confirmation links) |
| **10 · Node portability** | §1.2 (everything derives from the seed ⇒ no node-specific state), §6 (switch / multi-node) |

## Conventions

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) follow RFC 2119. All notation, primitives, and domain-separation tags are defined once in [Foundations](foundations) and used unchanged throughout; sizes, encodings, and input orderings are exact.
