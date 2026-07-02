---
sidebar_position: 8
title: Addressing
---

# Addressing

zkCoins encodes its identifiers and capabilities as Bech32m strings with distinct human-readable prefixes.

## Protocol-level encodings: the five Bech32m HRPs

Each object type uses a distinct HRP, so the different objects can never be confused ([spec §1.7.7](/specification#177-bech32m-and-bitcoin-conventions)):

| HRP | Payload | Purpose |
|---|---|---|
| `zk` | 32-byte address | account address |
| `zkgrant` | full `ViewGrant` byte serialization | delegated, revocable view grant |
| `zkview` | 32-byte per-coin key `K_tx` | per-coin view capability — decrypts exactly one coin |
| `zkavk` | 64-byte `ivk ‖ ovk` | bearer account view key — full-history read, irrevocable |
| `zkbid` | 32-byte `blob_id = H(ciphertext)` | confirmation-link blob locator — content-addressed bundle fetch |

A node or explorer **must** reject a value presented under the wrong HRP.

## References

- [zkCoins specification §1.7.7 — Bech32m and Bitcoin conventions](/specification#177-bech32m-and-bitcoin-conventions)
