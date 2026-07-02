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
