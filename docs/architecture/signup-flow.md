---
sidebar_position: 6
title: Signup Flow
---

# Signup Flow

zkCoins supports two signup methods that both produce the same result: a BIP-32 HD wallet with secp256k1 keys. The user chooses their preferred method — the wallet is functionally identical regardless of how it was created.

## Two Paths, One Wallet

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   Option A: Seed Phrase              Option B: Passkey      │
│   ┌─────────────────┐               ┌─────────────────┐    │
│   │ 12 words        │               │ Face ID /        │    │
│   │ (BIP-39)        │               │ Touch ID /       │    │
│   │                 │               │ Windows Hello    │    │
│   └────────┬────────┘               └────────┬────────┘    │
│            │                                  │             │
│            │ BIP-39 → Seed                    │ WebAuthn    │
│            │                                  │ P-256 Sig   │
│            │                                  │ → SHA-256   │
│            │                                  │ → Seed      │
│            │                                  │             │
│            └──────────────┬───────────────────┘             │
│                           │                                 │
│                           ▼                                 │
│                 ┌─────────────────┐                         │
│                 │  BIP-32 Seed    │                         │
│                 │  (256 bit)      │                         │
│                 └────────┬────────┘                         │
│                          │                                  │
│                          ▼                                  │
│                 ┌─────────────────┐                         │
│                 │  HD Master Key  │                         │
│                 │  (Xpriv)        │                         │
│                 └────────┬────────┘                         │
│                          │                                  │
│                    ┌─────┼─────┐                            │
│                    ▼     ▼     ▼                            │
│                  Key₀  Key₁  Key₂  ...                     │
│                  (secp256k1 Schnorr)                        │
│                                                             │
│                 = zkCoins Wallet                             │
│                   (identical regardless of signup method)    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

The key insight: **both methods produce a 256-bit seed**. Everything downstream — HD key derivation, address generation, Schnorr signing — is identical.

---

## Option A: Seed Phrase (Classic)

The traditional Bitcoin wallet creation flow. Familiar to crypto users, compatible with hardware wallets, portable across any BIP-39 compatible software.

### User Flow

1. User opens zkcoins.app and taps **"Create Wallet"**
2. User selects **"Seed Phrase"**
3. App generates 128 bits of entropy via `crypto.getRandomValues()`
4. Entropy is encoded as **12 BIP-39 mnemonic words** (English wordlist)
5. User is shown the 12 words and prompted to write them down
6. User confirms by entering words in correct order (verification step)
7. BIP-39 seed is derived: `PBKDF2(mnemonic, "mnemonic" + passphrase, 2048, 64)`
8. BIP-32 master key (Xpriv) is derived from the seed
9. First public key is derived at index 0, blinded → account address
10. Wallet is ready

### Technical Details

```
Entropy:     128 bits (crypto.getRandomValues)
Mnemonic:    12 words (BIP-39 English wordlist, 2048 words)
Seed:        PBKDF2-HMAC-SHA512(mnemonic, salt="mnemonic", iterations=2048, dkLen=64)
Master Key:  HMAC-SHA512(key="Bitcoin seed", data=seed) → Xpriv
Derivation:  m/84'/0'/0'/0/N (BIP-84 for native SegWit, or custom zkCoins path)
Signing:     secp256k1 Schnorr (BIP-340)
```

### Security Properties

| Property | Status |
|---|---|
| Offline generation | Yes — entropy from browser, no network needed |
| Deterministic | Yes — same 12 words always produce same wallet |
| Portable | Yes — import into any BIP-39 wallet |
| Backup | User responsibility — must store 12 words securely |
| Phishing risk | High — attackers trick users into entering seed phrases |
| Recovery | Full — 12 words restore everything |

### Where It Runs

- **Entropy generation:** Browser (`crypto.getRandomValues`)
- **BIP-39 encoding:** WASM module (Rust `bitcoin` crate) or JS fallback
- **Key derivation:** WASM module (BIP-32, secp256k1)
- **Storage:** localStorage (MVP), IndexedDB with encryption (planned)

---

## Option B: Passkey (Modern)

Passwordless, phishing-resistant signup using the device's biometric authentication (Face ID, Touch ID, Windows Hello) or a hardware security key. No words to write down. The private key never leaves the device's Secure Enclave.

### User Flow

1. User opens zkcoins.app and taps **"Create Wallet"**
2. User selects **"Passkey"**
3. Browser triggers **WebAuthn `navigator.credentials.create()`**
4. Device shows biometric prompt (Face ID / Touch ID / fingerprint / PIN)
5. Secure Enclave generates a **P-256 key pair** (ECDSA)
6. Passkey is stored in the device's passkey manager (iCloud Keychain / Google Password Manager / Windows Hello)
7. App requests a **deterministic signature** over a canonical message: `"zkCoins Wallet Derivation v1"`
8. The signature (P-256, 64 bytes) is hashed: `SHA-256(signature)` → **256-bit seed**
9. From this seed, BIP-32 master key is derived — identical to the seed phrase path
10. Wallet is ready

### Technical Details

```
WebAuthn Create:
  rp:                  { name: "zkCoins", id: "zkcoins.app" }
  user:                { id: random, name: "zkCoins Wallet", displayName: "zkCoins" }
  pubKeyCredParams:    [{ type: "public-key", alg: -7 }]  // ES256 = ECDSA P-256
  authenticatorSelection:
    residentKey:       "required"           // Discoverable credential
    userVerification:  "required"           // Always require biometric
  attestation:         "none"               // No attestation needed

WebAuthn Sign (for seed derivation):
  challenge:           SHA-256("zkCoins Wallet Derivation v1")
  allowCredentials:    [{ id: credentialId }]
  userVerification:    "required"

Seed Derivation:
  signature:           P-256 ECDSA signature (r || s, 64 bytes)
  seed:                SHA-256(signature) → 256 bits
  master_key:          HMAC-SHA512(key="Bitcoin seed", data=seed) → Xpriv
```

:::warning Deterministic Signatures
Standard ECDSA (P-256) produces **non-deterministic signatures** — the same message signed twice yields different signatures (due to random nonce `k`). This means `SHA-256(signature)` would produce a different seed each time.

**Solution:** We sign once during wallet creation and store the resulting seed (not the signature). The passkey is then used only for **authentication** (unlocking the wallet), not for re-deriving the seed.

Alternative: Use the passkey's raw public key directly as entropy: `seed = SHA-256(publicKey.x || publicKey.y)`. This is deterministic and reproducible. Trade-off: the seed is tied to the specific passkey, and a new passkey means a new wallet.
:::

### Security Properties

| Property | Status |
|---|---|
| Offline generation | Partially — WebAuthn needs browser support, but no network |
| Phishing resistant | Yes — passkey is bound to `zkcoins.app` domain (WebAuthn RP ID) |
| Biometric | Yes — Face ID, Touch ID, fingerprint, Windows Hello |
| Cloud sync | Yes — via iCloud Keychain or Google Password Manager |
| Backup | Automatic via cloud sync; optional seed phrase export |
| Recovery | Via synced passkey on another device, or exported seed phrase |
| Portable | Limited — passkey is bound to zkcoins.app, not importable to other wallets |

### Where It Runs

- **WebAuthn ceremony:** Browser API (`navigator.credentials.create/get`)
- **P-256 key pair:** Device Secure Enclave (never leaves hardware)
- **Seed derivation:** Browser JS (SHA-256 of public key or signature)
- **BIP-32 derivation:** WASM module (identical to seed phrase path)
- **Passkey storage:** OS passkey manager (iCloud Keychain, Google PM, Windows Hello)

---

## Comparison: Seed Phrase vs. Passkey

| | Seed Phrase | Passkey |
|---|---|---|
| **Target user** | Crypto-native, self-sovereign | Mainstream, first-time crypto |
| **Setup time** | ~2 min (write down 12 words) | ~10 sec (biometric scan) |
| **Phishing risk** | High (words can be stolen) | None (domain-bound) |
| **Backup** | Manual (paper, steel plate) | Automatic (cloud sync) |
| **Recovery** | 12 words → full restore | Cloud sync or exported seed |
| **Portability** | Any BIP-39 wallet | Only zkcoins.app |
| **Hardware wallet** | Compatible | Not compatible |
| **Works offline** | Yes | Partially (needs browser) |
| **User responsibility** | High (guard 12 words) | Low (device handles it) |

---

## Reference: Coinbase Smart Wallet

Our passkey implementation is inspired by [Coinbase Smart Wallet](https://github.com/coinbase/smart-wallet), but with fundamental architectural differences:

### What Coinbase Does

Coinbase's Smart Wallet uses **ERC-4337 Account Abstraction**:

1. Passkey creates a P-256 key pair via WebAuthn
2. The P-256 **public key is registered as an owner** in a Smart Contract on-chain
3. The Smart Contract wallet (not an EOA) is the user's address
4. Transactions are `UserOperations` signed with P-256, verified on-chain
5. A Bundler submits UserOps to the EntryPoint contract
6. Gas is sponsored via Paymasters

```
Coinbase Architecture:
  Passkey (P-256) → signs UserOp → Smart Contract verifies P-256 onchain
```

### What zkCoins Does Differently

zkCoins operates on **Bitcoin L1 with Client-Side Validation** — there are no smart contracts on Bitcoin to verify P-256 signatures. Instead:

1. Passkey creates a P-256 key pair via WebAuthn
2. The P-256 key is used to **derive a secp256k1 seed** (one-time conversion)
3. From the seed, standard Bitcoin keys are derived (BIP-32, secp256k1)
4. All signing uses **secp256k1 Schnorr** (Bitcoin-native)
5. The passkey is used for **wallet unlock/authentication**, not transaction signing

```
zkCoins Architecture:
  Passkey (P-256) → derives seed (one-time) → BIP-32 (secp256k1) → Schnorr signing
```

### Why the Difference

| | Coinbase | zkCoins |
|---|---|---|
| **Blockchain** | EVM (supports P-256 verification) | Bitcoin (secp256k1 only) |
| **Wallet type** | Smart Contract (ERC-4337) | HD Wallet (BIP-32) |
| **Passkey role** | Signs every transaction (P-256) | Unlocks wallet + derives seed (one-time) |
| **Signing curve** | P-256 (secp256r1) | secp256k1 (Bitcoin/Schnorr) |
| **On-chain verification** | Smart Contract validates P-256 sig | No on-chain verification (CSV) |
| **Gas sponsorship** | Paymasters | N/A (no gas — anchoring cost is the publisher's batch inscription fee, [spec §3.8](/specification#38-fees-and-economics)) |

### What We Learn from Coinbase

1. **Default to passkey** — new users shouldn't need to understand seed phrases
2. **Biometric-first UX** — Face ID / Touch ID is the primary interaction
3. **Recovery key as backup** — prompt users to create a backup while they still have access
4. **`userVerification: "required"`** — always require biometric, never fall back to PIN-only
5. **Domain binding** — passkey bound to `zkcoins.app` prevents phishing

---

## Implementation Plan

### Phase 1: Seed Phrase (Current)

The current MVP uses a simplified version:
- Random seed generated via `crypto.getRandomValues()` (no BIP-39 mnemonic yet)
- BIP-32 HD key derivation in WASM
- Stored in localStorage (unencrypted)

**To complete:**
- [ ] BIP-39 mnemonic generation (12 words, English wordlist)
- [ ] Mnemonic verification UI (confirm words in order)
- [ ] Mnemonic import (restore existing wallet)
- [ ] WASM module: expose `generateMnemonic()`, `mnemonicToSeed()`, `validateMnemonic()`

### Phase 2: Passkey

- [ ] WebAuthn registration (`navigator.credentials.create`)
- [ ] Seed derivation from passkey public key (`SHA-256(pubKey.x || pubKey.y)`)
- [ ] Passkey authentication for wallet unlock (`navigator.credentials.get`)
- [ ] Encrypted seed storage in IndexedDB (AES-GCM via Web Crypto API)
- [ ] Seed phrase export UI (for backup)
- [ ] UI: passkey as default option, seed phrase as "Advanced"

### Phase 3: Recovery & Multi-Device

- [ ] Seed phrase export from passkey-created wallets
- [ ] Multiple passkeys per wallet (add new device)
- [ ] Wallet migration between devices
- [ ] Emergency recovery flow (passkey lost, no seed phrase → funds lost)

---

## Security Considerations

### Passkey + Seed Phrase Hybrid

Users who sign up with a passkey should be **strongly encouraged** to also export their seed phrase as a backup. The passkey provides convenience (biometric unlock, cloud sync), but the seed phrase provides **sovereignty** (works with any BIP-39 wallet, no vendor lock-in).

The app should prompt:
1. At signup: "Your wallet is secured by your passkey. For extra safety, export your recovery phrase."
2. After first transaction: "You have funds in your wallet. Back up your recovery phrase now."
3. Periodically: gentle reminder if seed phrase hasn't been exported.

### Threat Model

| Threat | Seed Phrase | Passkey |
|---|---|---|
| Phishing | User enters words on fake site | Not possible (domain-bound) |
| Device theft | Words on paper are safe | Biometric prevents unauthorized use |
| Cloud breach | N/A | Passkey encrypted in Keychain |
| Malware | Keylogger captures words | Secure Enclave protects key |
| Loss | Paper destroyed = funds lost | Cloud sync recovers; or seed export |
| Vendor lock-in | None (BIP-39 standard) | Passkey bound to zkcoins.app |

### Non-Deterministic Signature Problem

WebAuthn P-256 signatures include a random nonce, so `sign(message)` produces different output each time. This means we **cannot** re-derive the seed from the passkey alone. Two approaches:

**Approach A: Public Key as Entropy (Recommended)**
```
seed = SHA-256(credentialId || publicKey.x || publicKey.y)
```
- Deterministic: same passkey always produces same seed
- Reproducible: seed can be re-derived as long as the passkey exists
- Trade-off: if the user creates a new passkey (e.g. after device reset), it generates a new wallet

**Approach B: Store the Seed**
```
seed = random 256 bits (generated at signup)
passkey = authentication only (unlock encrypted seed)
```
- Seed is stored encrypted in IndexedDB, decrypted via passkey auth
- More flexible: seed is independent of passkey
- Trade-off: if IndexedDB is cleared and no seed backup exists, funds are lost
- This is the approach Coinbase uses (smart contract stores the public key, not the seed)

**Our choice: Approach B** — the passkey authenticates, the seed is stored encrypted. This decouples the wallet identity from the specific passkey, allowing multiple passkeys and device migration.
