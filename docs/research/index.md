---
sidebar_position: 9
title: Research
---

# Research & References

This section contains the research that zkCoins is built on — primary sources, protocol analysis, community discussion, and upstream code references.

## Primary Source

The Shielded CSV protocol paper is the foundation of everything:

- **Paper:** [Shielded CSV: Private and Efficient Client-Side Validation](https://eprint.iacr.org/2025/068) (ePrint 2025/068)
- **Authors:** Jonas Nick (Blockstream), Liam Eagen (Alpen Labs), Robin Linus (ZeroSync)
- **Published:** January 2025
- **PDF:** [GitHub Release](https://github.com/ShieldedCSV/ShieldedCSV/releases/latest/download/shieldedcsv.pdf)

## Upstream Repositories

Our server code is derived from the ZeroSync prototype. These are the original repositories:

| Repository | Description | Status |
|---|---|---|
| [ShieldedCSV/ShieldedCSV](https://github.com/ShieldedCSV/ShieldedCSV) | Paper reference code (Rust). PCD Compliance Predicate, types, node logic. All crypto primitives are `unimplemented!()` — it's a specification in Rust form. | 44 stars, MIT, inactive since Sep 2024 |
| [ZeroSync/ZKCoins](https://github.com/ZeroSync/ZKCoins) | **Functional prototype** — the codebase our server is derived from. SP1 zkVM proofs, Taproot Inscriptions, WASM client, Axum server. | Active (last update Apr 2026) |
| [ZeroSync/rust-bitcoincore-rpc](https://github.com/ZeroSync/rust-bitcoincore-rpc) | Fork of rust-bitcoincore-rpc with `submitpackage` RPC updates for ZKCoins integration. | Tooling |
| [BitVM/zkCoins](https://github.com/BitVM/zkCoins) | Historical Plonky2 recursive circuit experiments. Predecessor to the ZeroSync implementation. Last commit: "Recursive proving kinda works" (Feb 2024). | Archived |

## Predecessor: zkCoins Gist

Before the formal paper, Robin Linus published the original concept as a GitHub Gist (2023):

[zkCoins — RobinLinus/d036511015caea5a28514259a1bab119](https://gist.github.com/RobinLinus/d036511015caea5a28514259a1bab119)

Jonas Nick on the difference:
> zkCoins represents "significant progress", but "the proposal does not describe the complete protocol and lacks some important details." Shielded CSV fills these gaps.

## Subpages

- [Protocol Analysis](/research/protocol-analysis) — Deep dive into the Shielded CSV protocol
- [Authors & Ecosystem](/research/authors) — Who built this, related projects
- [Community Discussion](/research/community) — Bitcoin-Dev mailing list, talks, criticism
- [Sources](/research/sources) — Complete link collection (40+ references)
- [Adoptable Elements](/research/adoptable-elements) — What zkCoins could learn from related protocols, mapped to roadmap gaps

## Primary Sources (Full Text, Archived)

These are locally archived copies of key articles, stored as static files:

- [Shielded CSV Paper (PDF)](/research/shieldedcsv-paper.pdf)
- [Blockstream Blog — "Bitcoin's Shielded CSV Protocol Explained"](/research/blockstream-blog.txt)
- [Bitcoin-Dev Mailing List — Full Thread (Nick, Riard, Chen)](/research/mailing-list.txt)
- [Eliel Blog — "My Thoughts on the Shielded CSV Protocol"](/research/eliel-blog.txt)
- [Bitcoin Optech — Client-Side Validation](/research/bitcoin-optech.txt)
- [ePrint 2025/569 — Solving Data Availability in CSV](/research/da-paper.txt)
