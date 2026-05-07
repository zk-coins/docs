---
sidebar_position: 8
title: Addressing
---

# Addressing

zkCoins uses human-readable addresses in the format `user@zkcoins.app` instead of raw cryptographic hashes. The addressing system is designed in three phases, each building on the previous one.

## Phase 1 — Auto-derived address with LNURL-pay endpoint

Every account automatically gets a human-readable address derived from its cryptographic identity. No manual registration is needed. The server implements the LNURL-pay endpoint structure (LUD-16) from day one so the format is forward-compatible with Lightning wallets.

### Default address

The first 8 hex characters of the account's SHA-256 hash become the address:

```
sha256(pubkey_0) = 553c0958e85e016b...
                   ^^^^^^^^
                   └── 553c0958@zkcoins.app
```

This happens automatically — users see their address immediately after creating a wallet.

### Custom usernames

Users can optionally claim a human-readable username to replace the hash-based default:

```
553c0958@zkcoins.app  →  alice@zkcoins.app
```

Claiming requires a Schnorr signature with the account's identity key (pubkey at index 0), proving ownership. Usernames are unique and immutable once claimed. One username per account.

- Lowercase alphanumeric, plus `-`, `_`, `.`
- Max 64 characters

### Server endpoints

**Address resolution:**

```
GET https://api.zkcoins.app/api/username/resolve/{identifier}
```

The server resolves identifiers in two ways:
1. Custom username lookup (exact match)
2. Hex prefix lookup against known account addresses (fallback)

Response:

```json
{
  "username": "553c0958",
  "address": "0x553c0958e85e016b131d214b96ce7dc28b0aa89a2d0675c13ef610b86b31312a"
}
```

**LNURL-pay discovery (LUD-16 compatible):**

```
GET https://api.zkcoins.app/.well-known/lnurlp/{identifier}
```

Response:

```json
{
  "tag": "payRequest",
  "callback": "https://api.zkcoins.app/lnurl/pay/{identifier}",
  "minSendable": 1000,
  "maxSendable": 1000000000000,
  "metadata": "[[\"text/plain\",\"Pay 553c0958 on zkCoins\"],[\"text/identifier\",\"553c0958@zkcoins.app\"]]"
}
```

**Username claim:**

```
POST https://api.zkcoins.app/api/username/claim
```

Body (JSON):

```json
{
  "username": "alice",
  "address": "0x553c0958...",
  "public_key": "02abc...",
  "signature": "hex...",
  "timestamp": 1715100000
}
```

The signature covers `sha256("zkcoins:claim_username" || address || username || timestamp)` using the identity key at HD index 0.

### How the wallet uses addresses

- **Display**: always shows `{username}@zkcoins.app` or `{8-hex}@zkcoins.app`
- **Copy**: copies the zkcoins address, not the raw hash
- **QR code**: encodes the zkcoins address
- **Send**: accepts `alice@zkcoins.app`, `alice`, or raw `0x...` hex — resolves via API before sending

## Phase 2 — Lightning Address compatibility

The `user@zkcoins.app` address becomes a fully functional Lightning Address (LUD-16). Any Lightning wallet worldwide can send sats to a zkCoins user.

### Flow

```
Sender (any Lightning wallet)          zkCoins Server              Recipient
         │                                   │                        │
         │  GET /.well-known/lnurlp/alice    │                        │
         │──────────────────────────────────▶│                        │
         │                                   │                        │
         │  payRequest response              │                        │
         │◀──────────────────────────────────│                        │
         │                                   │                        │
         │  GET callback?amount=10000        │                        │
         │──────────────────────────────────▶│                        │
         │                                   │  generate Lightning    │
         │  BOLT11 invoice (pr)              │  invoice via LN node   │
         │◀──────────────────────────────────│                        │
         │                                   │                        │
         │  pay invoice via Lightning        │                        │
         │──────────────────────────────────▶│                        │
         │                                   │  credit zkCoins sats   │
         │                                   │──────────────────────▶│
         │                                   │                        │
```

### What the server does

1. Receives Lightning payment (BTC sats)
2. Credits the recipient's zkCoins account with the equivalent amount
3. The recipient sees the balance in their zkCoins wallet

### Requirements

- zkCoins server operates a Lightning node (or connects to one via LND/CLN)
- BOLT11 invoices are generated with `description_hash = sha256(metadata)`
- Full LUD-06 compliance: amount validation, metadata hash verification
- Optional: LUD-09 successAction, LUD-12 comments

## Phase 3 — UMA compatibility (USDT → WUSDT)

The address becomes compatible with UMA (Universal Money Address). This enables cross-currency payments including stablecoins from wallets like Tether Wallet.

### Address format

UMA uses a `$` prefix. Both formats work:

```
alice@zkcoins.app     (Lightning Address — Phase 2+)
$alice@zkcoins.app    (UMA address — Phase 3)
```

### Flow

```
Sender (Tether Wallet / UMA wallet)    zkCoins Server              Recipient
         │                                   │                        │
         │  GET /.well-known/lnurlp/$alice   │                        │
         │  + UMA params (version, sig...)   │                        │
         │──────────────────────────────────▶│                        │
         │                                   │                        │
         │  payRequest + currencies[]        │                        │
         │  + settlementOptions              │                        │
         │◀──────────────────────────────────│                        │
         │                                   │                        │
         │  POST payreq (amount=100.USD)     │                        │
         │  + compliance data                │                        │
         │──────────────────────────────────▶│                        │
         │                                   │                        │
         │  settlement instructions          │                        │
         │  (Ethereum USDT transfer addr)    │                        │
         │◀──────────────────────────────────│                        │
         │                                   │                        │
         │  send USDT on Ethereum            │                        │
         │──────────────────────────────────▶│                        │
         │                                   │  lock USDT, mint WUSDT │
         │                                   │──────────────────────▶│
         │                                   │                        │
```

### What the server does

1. Receives USDT on Ethereum (or other supported chain)
2. Locks the USDT in a bridge contract
3. Mints equivalent WUSDT (Wrapped USDT) on the zkCoins Shielded CSV protocol
4. Credits the recipient's zkCoins account with WUSDT

### Additional UMA endpoints

```
GET  /.well-known/lnurlpubkey          → signing + encryption certificates
GET  /.well-known/uma-configuration    → VASP capabilities
POST /api/lnurlp/payreq/{username}     → payment request with compliance data
POST /api/lnurlp/utxocallback          → post-transaction compliance hook
```

## Backward compatibility

All three phases are backward-compatible:

| Sender wallet | Address used | Settlement | Recipient gets |
|---|---|---|---|
| zkCoins | alice@zkcoins.app | Internal transfer | zkCoins sats |
| Lightning wallet | alice@zkcoins.app | Lightning (BTC) | zkCoins sats (Phase 2+) |
| UMA / Tether wallet | $alice@zkcoins.app | Ethereum (USDT) | WUSDT on zkCoins (Phase 3) |

## References

- [LUD-01: Base LNURL encoding](https://github.com/lnurl/luds/blob/main/01.md)
- [LUD-06: LNURL-pay](https://github.com/lnurl/luds/blob/main/06.md)
- [LUD-16: Lightning Address](https://github.com/lnurl/luds/blob/main/16.md)
- [UMA Protocol](https://github.com/uma-universal-money-address/protocol)
- [OpenCryptoPay](https://opencryptopay.io)
