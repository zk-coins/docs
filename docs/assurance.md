---
title: Assurance Roadmap
---

# Assurance Roadmap

> *[Risks](/risks) documents what can go wrong. This page defines how the project earns confidence that the design and the implementation are sound — two workstreams, and the hard gates they impose before the protocol carries real value.*

## Two failure classes, two instruments

Two distinct failure classes threaten the protocol, and they need different instruments:

- **Incentive failures.** Every role behaves as specified only if behaving as specified is that actor's best strategy. Cryptographic proofs do not cover this: a protocol can be mathematically sound and still fail in production because rational operators act differently than the design assumes. Incentive failures surface only once the network is live and someone exploits them — and a live decentralized system cannot simply be patched. They must be found **before** launch, by analysis.
- **Implementation failures.** The specification can be right and the code wrong. zkCoins deliberately runs a **single protocol implementation** (the Rust node; the TypeScript SDK independently re-implements only the client-side primitives — derivation, hashing, and signing). There is no second full implementation to cross-check against, so the independent view a second client would provide must come from elsewhere: the conformance harness and an external audit.

Both workstreams follow the project's standing rule: whatever they change flows through this repository as a spec PR first ([Implementation Mandate](/implementation-mandate)).

## Workstream 1 — Incentive analysis

Scope: every mechanism whose correctness depends on actor behaviour rather than cryptography. [Risks](/risks) names the open ones: publisher economics under the serial accumulator ([spec §3.4](/specification#34-the-publisher), [§3.8](/specification#38-fees-and-economics)), griefing via conflicting `SpendRecord`s, and the `BatchBundle` retention free-rider structure ([spec §4.6](/specification#46-data-availability--replication-factor-k), [§4.8](/specification#48-durability--the-store-everything-invariant)).

Method — for each mechanism:

1. **Actor model.** Who participates, what they can do, what it costs them, what they earn.
2. **Adversary budget.** What a rational attacker spends versus what the attack yields — including griefing, where the attacker pays to impose losses on others.
3. **Equilibrium argument.** Show in writing, with assumptions stated, that following the protocol is each actor's best strategy. Where a closed-form argument is not available, simulate.
4. **Verdict.** Each mechanism ends in exactly one of: **holds**, **holds under stated assumptions**, or **broken → spec change**.

Output: one analysis document per mechanism, linked from [Risks](/risks). Resulting protocol changes go into the [Specification](/specification) as PRs. No mechanism ships to mainnet with an open verdict.

## Workstream 2 — Verification staircase

The path to "demonstrably secure", in order — each step builds on the previous one:

1. **Security definitions.** Precise statements of what *secure* means for zkCoins: no forgery, no double-spend, and privacy of amounts, assets, and participants expressed as indistinguishability properties. The definitions become part of the [Specification](/specification).
2. **Paper proofs.** Reductions showing the protocol meets those definitions under standard assumptions (hash security, discrete log/Schnorr, the proof system's soundness and zero-knowledge). Written up, published, and reviewable.
3. **Machine-checked and external verification.** Machine-checked proofs or model checking for the protocol state machine where feasible, and an **external audit** of both the specification and the node implementation. With a single implementation, the audit carries the weight that a second independent implementation would otherwise carry.

:::info Proofs cover the model, not the code
A security proof establishes that the *specified* protocol is sound. That the *running* code implements the specified protocol is established separately — by the pinned conformance vectors and the end-to-end suite the [Implementation Mandate](/implementation-mandate) requires. Only both halves together justify the claim "demonstrably secure".
:::

## Gates

| Gate | What must hold |
|---|---|
| **Public testnet** | Specification deep-review complete; conformance vectors generated and pinned; the A-to-Z suite passes across node, SDK, and app. |
| **Real value (mainnet)** | Every incentive verdict is **holds** or **holds under stated assumptions** — no open and no **broken** verdicts (Workstream 1); security definitions and paper proofs are published (Workstream 2, steps 1–2); an external audit is completed with findings resolved (step 3); a vulnerability disclosure process is live ([SECURITY.md](https://github.com/zk-coins/docs/blob/develop/SECURITY.md)). |

These gates are ordered stations, not aspirations: a release that has not passed its gate does not ship.
