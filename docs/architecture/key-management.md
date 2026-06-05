---
sidebar_position: 5
title: Key Management
---

# Key Management

zkCoins uses BIP32 Hierarchical Deterministic (HD) wallets for key derivation. All keys are generated and stored locally in the browser — they never touch the server.

## Key derivation

```
Seed (BIP-39 mnemonic or Passkey PRF → HKDF)
  └── BIP32 Master Key (Xpriv)
        │
        ├── Public Key [0]  →  SHA-256  →  Account Address
        ├── Public Key [1]  →  used as sender_next_public_key in TX 1
        ├── Public Key [2]  →  used as sender_next_public_key in TX 2
        └── ...
```

Two ways to create a wallet (both produce the same BIP32 key structure):

- **Seed Phrase (BIP-39):** 12-word mnemonic → PBKDF2 → 64-byte seed → Xpriv
- **Passkey (WebAuthn PRF):** biometric auth → PRF output → HKDF → 16-byte entropy → BIP-39 mnemonic → seed → Xpriv

Each transaction uses the current public key and derives the next one. This provides:

- **Forward secrecy** — each transaction uses a fresh key
- **Deterministic derivation** — all keys can be re-derived from the seed
- **Deterministic address** — same seed always produces the same account address

## Key storage

Keys are stored encrypted in the browser's IndexedDB using AES-256-GCM via the Web Crypto API:

- **Seed phrase wallets:** encryption key derived from user password (PBKDF2, 100k iterations)
- **Passkey wallets:** encryption key derived from WebAuthn PRF output (HKDF-SHA256)

The master private key is never stored in plaintext. Decryption requires user authentication on each session.

## Schnorr signatures

Transaction commitments are signed with Schnorr signatures over the secp256k1 curve — the same cryptography that powers Bitcoin's Taproot. The signing happens in WebAssembly, compiled from the Rust `bitcoin` crate:

```typescript
// In the browser via WASM
const signature = wasm.signSchnorr(privateKeyHex, messageHashHex);
```

## Account address

The account address is derived deterministically from the first public key:

```
Address = SHA-256(PublicKey[0])
```

This ensures the same seed always produces the same address, enabling wallet recovery. The address is an internal identifier — on-chain privacy is provided by the ZK proofs, not by address blinding.

## Backup and recovery

:::danger Seed phrase recovery is NOT sufficient
Unlike regular Bitcoin wallets, recovering a seed phrase alone does not restore a zkCoins wallet. The **coin proofs** — the Zero-Knowledge proofs of each coin's validity — must also be preserved. Without them, the coins cannot be spent.

This is a fundamental property of Client-Side Validation: the blockchain only stores opaque commitments, not transaction data. The wallet must keep its own records.
:::

Planned backup approach:

1. Export wallet state as encrypted file (master key + coin proofs)
2. Import on another device
3. Re-scan the blockchain for commitments to rebuild local state
