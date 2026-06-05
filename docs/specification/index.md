---
sidebar_position: 1
title: Specification
---

# zkCoins Protocol Specification

This is the complete, normative specification of the zkCoins protocol. It is written against the **target design** — the [Requirements](/requirements) — and is deliberately **decoupled from the current implementation**: where today's code differs, the specification, not the code, describes the goal. Open design choices are resolved here in favour of the established, Bitcoin-consistent option; nothing is left undefined.

## Scope

The specification covers **every** component that will exist:

- the **node** (validator, prover, relay, data store);
- the **wallet** (thin key-holder);
- the **explorer** (public and authorised views);
- the cryptography binding them (keys, hashes, identifiers, proofs, on-chain commitments, off-chain transport, recovery).

It defines, for every key / hash / identifier, exactly **how it is derived**; for every requirement, **how it is met**; and for the system, **how the parts fit together**.

## Conventions

- Normative keywords **MUST**, **MUST NOT**, **SHOULD**, **MAY** follow RFC 2119.
- All notation, primitives, and domain-separation tags are defined once in [Foundations](foundations) and used unchanged throughout.
- Sizes, encodings, and input orderings are exact; reordering hashed inputs yields a different, invalid value.

## The requirements (normative)

The specification exists to satisfy these ten requirements. Each is restated in full on the [Requirements](/requirements) page; in brief:

1. Bitcoin L1 as the only base · 2. Private · 3. Trustless · 4. Client-side validation · 5. Custody only in the wallet · 6. Recovery · 7. Self-hostable · 8. Multi-asset · 9. Explorer (shareable confirmation) · 10. Node portability.

## Reading guide

| # | Page | Defines |
|---|---|---|
| 1 | [Foundations](foundations) | Primitives, key hierarchy, identifiers, data structures, trees — the single source of truth |
| 2 | [Proofs & State Transitions](proofs) | The compliance predicate, recursion, and the mint / send / receive algorithms |
| 3 | [On-chain Layer](onchain) | Commitment construction, signing, aggregation, publishing, scanning, the nullifier accumulator |
| 4 | [Transport & Recovery](transport-recovery) | Off-chain bundle delivery, node-as-relay, note discovery, recovery, data availability |
| 5 | [Access & Explorer](access-explorer) | Capability-gated pull, viewing keys / view grants, and the explorer (public + authorised, shareable links) |
| 6 | [System Architecture](architecture) | Node, wallet, explorer components; portability & multi-node; issuance; threat model |

## Requirements traceability

Where each requirement is satisfied:

| Requirement | Satisfied by |
|---|---|
| **1 · Bitcoin-only base** | §1 (no native token; secp256k1/BIP-340), §3 (a single commitment inscribed; no chain/consensus change) |
| **2 · Private** | §1.3 (per-coin encryption), §1.4 (opaque commitment carries only hashes), §2 (ZK proof hides amounts/parties/graph) |
| **3 · Trustless** | §2 (proof soundness ⇒ no forgery), §3 (nullifier accumulator ⇒ no double-spend), §1.2 (no key a node holds can spend), §6 (threat model) |
| **4 · Client-side validation** | §2 (receiver re-verifies the full recursive proof), §4 (receive flow) |
| **5 · Custody only in wallet** | §1.2 (SPEND branch is wallet-only; hardened separation) |
| **6 · Recovery** | §1.3 (seed-derived detection/scan keys), §4 (seed reconstruction, replication, data availability) |
| **7 · Self-hostable** | §6 (node ships self-contained, no operator-specific dependencies), §4 (node-as-relay) |
| **8 · Multi-asset** | §1.4 (`asset_id`), §1.5 (per-asset balances), §2 (per-asset conservation), §6 (issuance) |
| **9 · Explorer** | §5 (capability-gated authorised view; per-coin view capability; verifiable confirmation links) |
| **10 · Node portability** | §1.2 (everything derives from the seed ⇒ no node-specific state), §6 (switch / multi-node) |
