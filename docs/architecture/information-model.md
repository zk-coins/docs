---
title: Information Model
---

# Information Model

At its core, zkCoins is an **information system**: a small set of pieces of data, each created at a specific point, held by a specific party, and either kept private or published. This page is the complete catalog. For every piece of information it answers four questions:

1. **What is it?**
2. **How does it come into existence?** (its genesis / derivation)
3. **Who holds it?**
4. **How — and whether — may it be shared?**

It complements two neighbouring pages: the [Privacy Model](privacy-model) (what an _on-chain observer_ can see) and the [Trust Model](trust-model) (what your _node operator_ can see). Read this one first — it is the map.

> Notation: `H(...)` denotes a domain-separated hash. In-circuit commitments use **Poseidon over Goldilocks**; the on-chain signature message uses **SHA-256** per BIP-340. The exact functions live in [Proof System](proof-system) and [Key Management](key-management); this page focuses on _what is hashed and why_, not the primitive.

:::info Protocol vs. the zkcoins.app service
This page describes the **zkCoins protocol**. The protocol's only notion of identity is the 32-byte **address** = `SHA-256(initial public key)`.

Human-readable handles such as `name@zkcoins.app`, username registration, and LNURL / Lightning-Address resolution are features of **zkcoins.app — one specific, centralized service provider** built on top of the protocol. They are **not part of the protocol**: it neither stores nor needs an `@` handle, and a different operator may offer different naming, or none at all. Wherever an `@` handle appears below, treat it as a service-layer convenience, not a protocol fact.
:::

## The four sensitivity classes

Every piece of information falls into exactly one class. The class answers "who may hold it and who may see it" in one move:

| Class | Meaning | Lives where |
|---|---|---|
| 🔴 **Secret** | Never leaves the wallet. Disclosure = total loss of funds. | The user's device only |
| 🟠 **Private** | Plaintext bookkeeping. Disclosure = loss of _privacy_ (never theft). | Wallet + the node that hosts the account |
| 🟡 **Shareable** | Handed out on purpose. | User + the payment counterparty |
| 🟢 **Public** | Written to Bitcoin, world-readable — but only hashes. | Bitcoin L1 |

The whole privacy story is the gap between **Private** (off-chain plaintext) and **Public** (on-chain hashes), and the whole trust story is the question _whose node holds the Private data_.

## The information catalog

| Information | Class | How it comes into existence (genesis) | Held by | Shared with | May it be shared? |
|---|---|---|---|---|---|
| **Seed** | 🔴 Secret | 256-bit entropy (BIP-39 mnemonic, or Passkey PRF → HKDF) generated in the wallet | User only | nobody | **Never** |
| **Master private key (Xpriv)** | 🔴 Secret | BIP-32 derivation from the seed | User only | nobody | **Never** |
| **Per-transaction private key** | 🔴 Secret | BIP-32 child derivation; a fresh key per send (forward secrecy) | User only | nobody | **Never** |
| **Public key** (33 bytes) | 🟢 Public | secp256k1 from the current private key; rotates each send | User → embedded in the on-chain commitment | Bitcoin | Yes (it is published on-chain) |
| **Address** | 🟡 Shareable | `SHA-256(initial public key)` — fixed once at account creation; the protocol's _only_ identity (see [Key Management](key-management)) | User | the payer (inside an invoice) | Yes — but it is stable, so reusing it links payments |
| **Invoice** `{amount, recipient, asset_id}` | 🟡 Shareable | Created by the recipient when requesting a payment (`recipient` is the 32-byte address) | Recipient | the chosen payer | Yes, with the payer |
| **AccountState** `{owner, balance, public_key}` | 🟠 Private | Created when the account is created; mutates on every send | User + the hosting node | only **your** node | No — the balance is private |
| **account_state_hash** | 🟢 Public | `H(AccountState)` | User → commitment | Bitcoin | Yes — a hash; hides the balance |
| **Coin** `{identifier, recipient, amount, asset_id}` | 🟠 Private | Built during a send from a `CoinTemplate` | Sender → recipient | the recipient (via the coin proof) | Recipient only (today more is visible than ideal — see [Privacy Model](privacy-model)) |
| **Coin identifier** | 🟡 Shareable | `H(account_state_hash ‖ asset_id ‖ coin_index)` | inside the coin proof | recipient + the coins tree | Yes |
| **AssetId** | 🟡 Shareable | `H(genesis_tag ‖ creator_pubkey ‖ name ‖ decimals)` at asset creation | Creator → every user of that asset | public | Yes (everyone using the token needs it) |
| **Account / coins / history trees** (Sparse Merkle Tree, Merkle Mountain Range) | 🟢 Public (roots) / 🟠 Private (leaves) | The node builds them incrementally from accounts and coins | The node | roots go on-chain; plaintext leaves stay private | Roots yes; plaintext leaves no |
| **Validity proof** (Plonky2, recursive) | 🟢 Public | The node's prover produces one per state transition | The node | the recipient (inside the coin proof) | Yes — zero-knowledge, it reveals nothing beyond validity |
| **ProofData** (public inputs) `{account_state_hash, output_coins_root, commitment_history_root, coin_history_root, asset_id}` | 🟢 Public | The public outputs of the proof | public | bound on-chain | Yes — only hashes and roots |
| **CoinProof** = `coin + proof + inclusion_proof` | 🟠 Private | The sender bundles it for delivery | Sender → recipient | the recipient | Recipient only (it contains the plaintext coin) |
| **Commitment** `{public_key, signature, message}` | 🟢 Public | The owner signs `message = SHA-256(account_state_hash ‖ output_coins_root)` with a Schnorr/BIP-340 signature | first the owner, then Bitcoin | **Bitcoin** | Yes — this is the **only object that goes on-chain** |
| **Inscription / nullifier** | 🟢 Public | The commitment is written to Bitcoin as a 64-byte Taproot inscription at broadcast | Bitcoin (permanently) | the whole world | Yes (it is what prevents double-spends) |

## How information comes into existence

This is the heart of the model. Everything is **born in the wallet, top-down from the seed**, and only a **minimal hash fingerprint** is ever written to Bitcoin:

```
Seed (entropy)
  └─BIP32─▶ Master Xpriv
              └─child(i)─▶ Private key_i ──secp256k1──▶ Public key_i
                                                          ├─ H ─▶ Address  (identity, fixed once)
                                                          └─ rotates each send

Address + AccountState{balance} ─── H ───▶ account_state_hash

Send: CoinTemplate{recipient, amount, asset_id}
        └─ + coin_index + account_state_hash ─ H ─▶ Coin.identifier
                                                      └──▶ output_coins_root (tree)

(account_state_hash ‖ output_coins_root) ── SHA-256 ──▶ message
   message ── Schnorr(Private key_i) ──▶ Commitment{public_key, signature, message}
                                            └── Taproot inscription ──▶ BITCOIN L1   ◀── the only on-chain step

Node prover: (previous state, coins, trees) ── Plonky2 ──▶ Validity proof (+ ProofData)
Delivery to recipient: Coin + proof + inclusion_proof  =  CoinProof
```

Reading it as layers:

- **Key layer (Secret → one Public key).** The seed deterministically produces every key. Only the _public_ key of each transaction ever leaves the device, and it does so inside the on-chain commitment.
- **Identity layer (Shareable).** The address is a one-time hash of the first public key; it is the stable handle a payer needs. An [invoice](addressing) wraps it together with an amount and asset.
- **State & coins layer (Private).** Balances and coins are plaintext bookkeeping. They live off-chain. They are computed by the owner and held by whichever node hosts the account.
- **Asset layer (Shareable).** An asset is defined the moment someone hashes their creator key together with a name and decimals. The resulting `AssetId` is public — every holder of the token references it.
- **Tree layer (Public roots / Private leaves).** The node folds accounts and coins into Merkle structures. The _roots_ are committed on-chain; the _leaves_ (plaintext) are not.
- **Proof layer (Public).** A recursive zero-knowledge proof attests the whole state transition is valid without revealing any Private data. Its public inputs (`ProofData`) carry only hashes.
- **On-chain layer (Public).** A single signed `Commitment` — a public key, a Schnorr signature, and the hash `SHA-256(account_state_hash ‖ output_coins_root)` — is inscribed on Bitcoin. Nothing else.

## Two invariants

These are the load-bearing truths of the whole design:

1. **On-chain there are only hashes.** Amounts, recipients, and balances are **never** written to Bitcoin — only the `Commitment` (a public key, a signature, and one hash). No bookkeeping can be reconstructed from the chain. See [Privacy Model](privacy-model).
2. **Privacy is decided by _whose node_ holds the Private data.** Your own node ⇒ no leak. Someone else's node ⇒ that operator sees your Private (plaintext) data — a privacy trade-off — but can **never** steal, forge, or double-spend, because that is enforced by the Public layer plus cryptography. This is exactly the [Trust Model](trust-model): run your own node and you are trustless and private at once.

## Naming is a service-layer feature, not protocol

To the protocol, identity is the 32-byte address (`SHA-256(initial public key)`) and nothing else. The friendly `name@zkcoins.app` form is provided by the **zkcoins.app service**, in two variants:

- **Default handle** — the first 8 hex characters of the address, derived on the fly and resolved on request. It is **not stored anywhere**; it exists for every account automatically. Example: address `e660e4ea…` ⇒ `e660e4ea@zkcoins.app`.
- **Custom username** — an optional override (e.g. `alice@zkcoins.app`) that the user claims with a Schnorr signature over the identity key. Only custom claims are persisted (in the service's own table); a service with no claims still serves every default handle.

Because naming lives entirely in the service, it sits **outside the four protocol classes above**. A self-hosted node may implement naming differently, or not at all — the protocol is unaffected. See [Addressing](addressing) for the service's endpoints.

## A worked example (live)

A single real account from a Mutinynet deployment, shown across the classes. Hashes are full and unabridged; the values are a point-in-time snapshot.

**🔴 Secret** — never present on the node at all. The seed and private keys stay in the wallet; the node only ever sees the public key below.

**🟠 Private** (off-chain, in the node's database) — the account's full state:

```
address (identity) : e660e4ea3ce6c92c1e27ecb6cad611236d96a412cbc51d28eeba45fa86903825
state blob size    : 181,967 bytes   (balance + rotating key + coin queue & history)
```

This blob lives only on the node. It is never published.

**🟢 Public** (on-chain, on Mutinynet) — the account's _entire_ Bitcoin footprint is one 177-byte commitment:

```
commit txid : 3cf5f3159c5035b3c84ca8f591ec1741d7a2556e0b67779df184225b5567b2a5

public_key (33 B) : 0363c9346024c5dcd393bb7577fd3f8d045c68ad297d7b90a454d8e2ec388ed8c7
signature  (64 B) : b50b629ea32dadf453561c763e3567869b1e326777459ca7d8f7fe71462b2506
                    9addc28c08b80ddb66a11830aa95e57a7b5ec24414486102c54695fc4ea1a4e2
message    (64 B) = account_state_hash ‖ output_coins_root
  account_state_hash : a791849cffb631de85d299074d150f1410c1c0e6edf66ffa42246bde64334fbc
  output_coins_root  : be900b25dad0c79b981741d7f37e3a3b635cf51cc7c4af2d1b428baa565134dc
```

What is **not** here: no balance, no amount, no recipient — only a public key, a Schnorr signature, and two hashes. And the address is exactly the SHA-256 of that public key:

```
SHA-256(0363c934…388ed8c7) = e660e4ea3ce6c92c1e27ecb6cad611236d96a412cbc51d28eeba45fa86903825
```

So this account is **181,967 bytes** of private plaintext off-chain, but only **177 bytes** of hashes and a signature on-chain. The `account_state_hash` (`a791849c…`) is the public fingerprint of that private blob: an observer sees the hash and learns nothing; the owner can open it to the full balance.

**🟢 Public** (global tree roots) — every account folds into shared roots; the latest values:

```
smt_root      : aee03c2d44273005cc1fb5d999a564231784044a3a3e5a39d2f7a173448140b6
prev_mmr_root : da929cb09a4f034b4e30a2d74afc0e2db862d523c321af8d29e1358bca9bb3fd
```

**Service layer** (zkcoins.app — _not_ protocol) — the friendly handle resolves live:

```
GET /api/username/resolve/e660e4ea
→ {"username":"e660e4ea","address":"0xe660e4ea3ce6c92c1e27ecb6cad611236d96a412cbc51d28eeba45fa86903825"}
```

The protocol neither knows nor needs this handle; it only ever uses the 32-byte address.

## Related pages

- [Trust Model](trust-model) — who you trust, and why running your own node removes it
- [Privacy Model](privacy-model) — what an on-chain observer can and cannot see
- [Key Management](key-management) — seed, BIP-32 derivation, Schnorr signing
- [Addressing](addressing) — addresses, invoices, and LNURL compatibility
- [Nullifier Design](nullifier-design) — the 64-byte on-chain marker
- [Proof System](proof-system) — the recursive Plonky2 circuit
- [Transaction Flow](transaction-flow) — how a send moves through the system end-to-end
