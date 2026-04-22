---
sidebar_position: 5
title: Key Management
---

# Key Management

zkCoins uses BIP32 Hierarchical Deterministic (HD) wallets for key derivation. All keys are generated and stored locally in the browser — they never touch the server.

## Key derivation

```
Random 256-bit seed (from browser crypto.getRandomValues)
  └── BIP32 Master Key (Xpriv)
        │
        ├── Public Key [0]  →  blinded with random bytes  →  Account Address
        ├── Public Key [1]  →  used as sender_next_public_key in TX 1
        ├── Public Key [2]  →  used as sender_next_public_key in TX 2
        └── ...
```

Each transaction uses the current public key and derives the next one. This provides:

- **Forward secrecy** — each transaction uses a fresh key
- **Deterministic derivation** — all keys can be re-derived from the master key
- **Stealth-like addresses** — the blinded address is unlinkable to the public keys

## Key storage

Currently, keys are stored in the browser's `localStorage`:

```json
{
  "address": "a1b2c3...",
  "numPubkeys": 3,
  "xpriv": "xprv9s21ZrQH..."
}
```

:::warning MVP limitation
localStorage is not encrypted. The master private key is stored in plaintext. This is acceptable for testnet but must be addressed before mainnet:

- **Phase 2**: IndexedDB with Web Crypto API encryption
- **Phase 3**: Hardware wallet integration or WebAuthn
:::

## Schnorr signatures

Transaction commitments are signed with Schnorr signatures over the secp256k1 curve — the same cryptography that powers Bitcoin's Taproot. The signing happens in WebAssembly, compiled from the Rust `bitcoin` crate:

```typescript
// In the browser via WASM
const signature = wasm.signSchnorr(privateKeyHex, messageHashHex);
```

## Account address

The account address is derived from the first public key, blinded with random bytes:

```
Address = hash(blind(PublicKey[0]))
```

This ensures that the on-chain commitment (which contains the public key hash) cannot be linked back to the account address without knowledge of the blinding factor.

## Backup and recovery

:::danger Seed phrase recovery is NOT sufficient
Unlike regular Bitcoin wallets, recovering a seed phrase alone does not restore a zkCoins wallet. The **coin proofs** — the Zero-Knowledge proofs of each coin's validity — must also be preserved. Without them, the coins cannot be spent.

This is a fundamental property of Client-Side Validation: the blockchain only stores nullifiers, not transaction data. The wallet must keep its own records.
:::

Planned backup approach:

1. Export wallet state as encrypted file (master key + coin proofs)
2. Import on another device
3. Re-scan blockchain for nullifiers to rebuild accumulator state
