---
sidebar_position: 2
title: 1 · Foundations
---

# 1 · Foundations (normative)

This page is the **single source of truth** for the zkCoins specification. Every other spec page builds on the primitives, keys, identifiers, and structures defined here. It is written against the **target design** (the [Requirements](/requirements)), not against any current implementation.

Normative keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) are used per RFC 2119.

## 1.1 Cryptographic primitives

The protocol fixes one concrete instantiation. Where a choice was open, the established, Bitcoin-consistent option is taken.

| Role | Primitive |
|---|---|
| Signature curve & scheme | **secp256k1**, **BIP-340 Schnorr** (x-only public keys, 32-byte) |
| On-chain / signature hash | **SHA-256** (BIP-340 uses tagged SHA-256 internally) |
| In-circuit hash | **Poseidon** over the proof field `𝔽` (Goldilocks, `p = 2^64 − 2^32 + 1`) |
| General hash (addresses, off-circuit ids) | **SHA-256** |
| Recursive proof system | A **proof-carrying-data (PCD)** scheme via **cyclic recursion**; reference instantiation: a FRI-based recursive proof (Plonky-style) over Goldilocks with Poseidon |
| Key derivation | **BIP-32** (secp256k1) for the key tree; **HKDF-SHA256** for symmetric/derived secrets |
| Transport encryption | **NIP-44 v2** (ECDH-secp256k1 → HKDF-SHA256 → ChaCha20 + HMAC-SHA256) |
| Metadata privacy | **NIP-59** gift-wrap |
| Text encoding | **Bech32m** for the address (HRP `zk`); transport identifiers as `bech32m` with role HRPs |

Notation:

- `H(x)` — SHA-256 of byte string `x`.
- `Hc(tag, a, b, …)` — Poseidon over `𝔽`, **domain-separated** by `tag`, applied to the field-encoded inputs.
- `P = k·G` — secp256k1 scalar multiplication; `G` the generator.
- `ECDH(k, P) = x(k·P)` — the x-coordinate of the shared point.
- `a ‖ b` — byte concatenation.

**Domain separation.** Every `Hc` / `HKDF` call **MUST** be tagged with a context string of the form `"zkCoins/v1/<context>"`. The contexts used in this spec are: `Address`, `AssetId`, `Coin`, `AccountState`, `CoinsRoot`, `Nullifier`, `NoteKey`, `DetectTag`, `Grant`. Reusing a tag for two purposes is forbidden.

## 1.2 Key hierarchy

All key material descends deterministically from a single 256-bit **seed**. The seed is the only thing a user backs up ([Requirement 6](/requirements)).

```
seed  (256-bit; BIP-39 mnemonic, or Passkey PRF → HKDF)
  └─ BIP-32 ─▶ m  (master)
        └─ m / 1798' / account'                              = A   (per-account root; 1798' = zkCoins purpose)
              ├─ A / 0'        = SPEND branch   (wallet only)
              │     ├─ A/0'/0'            = sk₀   → Pk₀   (initial spend key; fixes the address)
              │     ├─ A/0'/i'            = skᵢ   → Pkᵢ   (rotating per-send spend key)
              │     └─ A/0'/n'            = nk            (nullifier key)
              ├─ A / 1'        = VIEW branch    (delegable to a node)
              │     ├─ A/1'/0'            = ivk           (incoming viewing key)
              │     └─ A/1'/1'            = ovk           (outgoing viewing key)
              └─ A / 2'        = op            (operational / Nostr identity key)
```

`1798'` is the chosen BIP-43 purpose index for zkCoins (hardened). All branch separations are **hardened**: the VIEW and `op` branches are hardened children of `A`, so a party holding them **cannot** derive the SPEND branch.

**Who holds what** (this table is the cryptographic basis of the [Trust Model](/architecture/trust-model)):

| Key | Held by | Can do | Cannot do |
|---|---|---|---|
| `skᵢ`, `nk` (SPEND branch) | wallet only | authorise spends, compute nullifiers | — |
| `ivk` | wallet, and any node the wallet delegates to | detect & decrypt **incoming** coins | spend |
| `ovk` | same | recover **outgoing** coin plaintext | spend |
| `op` | the node | publish/receive on Nostr, sign view grants & acknowledgements | spend, decrypt others' coins |
| `K_tx` (per-coin note key, §1.3) | derived per coin; shareable | decrypt **exactly one** coin | spend, see any other coin |

The **operational bundle** `{ivk, ovk, op}` is what a wallet entrusts to a node so the node can receive and serve on its behalf 24/7. None of it can spend. A *foreign* node never receives these directly; the wallet instead issues that node a scoped, `op`-signed **view grant** (§ Access model).

## 1.3 Per-coin keys (note encryption & detection)

Each output coin carries an ephemeral key and is individually encrypted, so that a single per-coin capability discloses one coin and nothing else.

```
Per output coin:
  esk           = random scalar                          (sender, fresh per coin)
  epk           = esk·G                                   (published with the coin)
  IVPK          = ivk·G                                   (recipient incoming-view pubkey)
  ss            = ECDH(esk, IVPK)  = ECDH(ivk, epk)       (shared secret; both sides derive it)
  K_tx          = HKDF("zkCoins/v1/NoteKey",  ss ‖ epk)   (per-coin symmetric note key)
  detect_tag    = Hc("zkCoins/v1/DetectTag",  dk ‖ epk)   (per-coin detection tag)
      where dk  = HKDF("zkCoins/v1/DetectTag", ivk)       (detection key, from ivk)
```

- The coin plaintext is encrypted under `K_tx` (NIP-44 v2). Only a holder of `ivk` (the recipient, or its node) can re-derive `K_tx` and decrypt.
- `detect_tag` lets a recipient/node find its own coins on relays **without** trial-decrypting everything, and is **seed-derivable** (so it doubles as the recovery scan key, [Requirement 6](/requirements)). Deterministic tags are linkable by a relay that stores them; a fuzzy-message-detection layer is an **OPTIONAL** privacy upgrade and does not change the interfaces.
- The **per-coin view capability** placed in an explorer link (§ Explorer) is `K_tx` for that one coin. It decrypts that coin only.

## 1.4 Identifiers and hashes

Exact derivations. Every value here is reproducible from its inputs.

| Identifier | Definition | Size / type |
|---|---|---|
| **Address** | `address = H(Pk₀)` — SHA-256 of the **initial** spend public key; fixed at account creation; the protocol's only identity | 32 bytes (Bech32m, HRP `zk`) |
| **AssetId** | `asset_id = Hc("AssetId", genesis_tag ‖ creator_pubkey ‖ H(name) ‖ decimals)` at asset creation; the human-readable `name` is **never** on-chain | field element / 32-byte canonical |
| **Coin identifier** | `coin.identifier = Hc("Coin", account_state_hash ‖ asset_id ‖ coin_index)` | field element |
| **account_state_hash** (`ash`) | `ash = Hc("AccountState", serialize(AccountState))` | 32-byte canonical |
| **output_coins_root** (`ocr`) | Poseidon Merkle root over the transaction's output `coin.identifier`s, tag `CoinsRoot` | 32-byte canonical |
| **Commitment message** | `message = ash ‖ ocr` | 64 bytes |
| **Commitment** | `{ public_key: Pkᵢ (32B x-only), signature: BIP-340(skᵢ, message) (64B), message (64B) }` — the **only** object written to Bitcoin | ~177 bytes inscribed |
| **Nullifier** | `nf = Hc("Nullifier", nk ‖ coin.identifier)` — revealed when a coin is spent; unlinkable to the coin without `nk` | field element |
| **ProofData** (public inputs) | `{ prev_commitment_history_root, new_account_state_hash, output_coins_root, input_nullifiers_root, nullifier_acc_root, coin_history_root }` | hashes/roots only |

The BIP-340 signature over `message` additionally uses **sign-to-contract**: the transaction commitment is embedded in the nonce, so no extra bytes are needed on-chain (see On-chain layer).

## 1.5 Core data structures

```
AccountState = {
  owner          : address,                 // fixed identity
  balances       : map<asset_id, amount>,   // private bookkeeping, multi-asset
  current_pubkey : Pkᵢ,                      // rotates each send
  send_counter   : i                         // monotonic
}

Coin         = { identifier, recipient: address, amount, asset_id }
CoinTemplate = { recipient: address, amount, asset_id }

CoinProof    = {                            // the value-bearing off-chain bundle (bearer)
  coin,                                      // plaintext coin
  proof,                                     // recursive validity proof
  inclusion_proof,                           // membership of coin in output_coins_root
  epk, ciphertext, detect_tag                // encryption envelope (§1.3)
}

Invoice      = { amount, recipient: address, asset_id, memo? }     // shareable, off-chain
```

## 1.6 Global and per-account trees

| Structure | Scope | Contents | Root goes |
|---|---|---|---|
| **Coin-history SMT** | per account | coins the account has received/spent (for in-circuit non-inclusion) | into `ash` lineage |
| **Commitment SMT** | global | latest committed state per account, keyed by `address` | on-chain (root) |
| **Commitment MMR** | global | one Commitment-SMT root per Bitcoin block (append-only history) | on-chain (root) |
| **Nullifier accumulator** | global | every published `nf` (sorted Merkle / SMT, supports membership + non-membership) | on-chain (root) |

Tree leaves that contain plaintext (coins, balances) are **Private**; only **roots** are **Public**. The global structures are rebuilt by any node from the public chain plus the bundles it holds, and are verifiable against Bitcoin — they require no trust in the node that serves them.

## 1.7 Encoding rules

- Field elements are canonically encoded as 32-byte big-endian (Goldilocks elements zero-padded); SHA-256 outputs are 32 bytes as-is.
- Bitcoin txids are stored internal-order and **displayed** byte-reversed (canonical Bitcoin convention).
- Addresses, view grants, and explorer view capabilities are Bech32m with distinct HRPs (`zk`, `zkgrant`, `zkview`) so they are never confused.
- All multi-input hashes fix input order exactly as written in §1.4; reordering changes the digest and is invalid.
