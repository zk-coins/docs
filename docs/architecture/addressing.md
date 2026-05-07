---
sidebar_position: 8
title: Addressing
---

# Addressing

zkCoins uses human-readable addresses in the format `user@zkcoins.app` instead of raw cryptographic hashes. The addressing system is designed in three phases, each building on the previous one.

## Current state

Today, the wallet displays a raw 32-byte SHA-256 hash as the account address:

```
Address: a7f3b2c1d4e5f6...28 bytes more...9a0b1c2d
```

This is unfriendly, error-prone, and impossible to remember. The addressing system replaces this with human-readable identifiers while maintaining full protocol compatibility.

## Phase 1 — Human-readable alias with LNURL-pay endpoint

The primary goal is replacing cryptographic hashes with readable names. Even though Phase 1 does not yet handle Lightning payments, the server already implements the LNURL-pay endpoint structure (LUD-16) so the address format is forward-compatible.

### Address format

```
alice@zkcoins.app
```

- Lowercase alphanumeric, plus `-`, `_`, `.`
- Max 64 characters
- Case-insensitive (normalized to lowercase)
- Unique per user

### Server endpoint

```
GET https://api.zkcoins.app/.well-known/lnurlp/{username}
```

Phase 1 response (LNURL-pay compatible structure, Lightning not yet functional):

```json
{
  "tag": "payRequest",
  "callback": "https://api.zkcoins.app/v1/lnurlp/callback/{username}",
  "minSendable": 1000,
  "maxSendable": 100000000,
  "metadata": "[[\"text/plain\",\"Pay {username} on zkCoins\"],[\"text/identifier\",\"{username}@zkcoins.app\"]]"
}
```

### Address resolution

```
alice@zkcoins.app
       │
       ▼
GET /.well-known/lnurlp/alice
       │
       ▼
Server looks up username "alice"
       │
       ▼
Returns internal address: sha256(pubkey_0) = a7f3b2c1d4e5f6...
```

The wallet UI displays only the human-readable alias. The cryptographic address is used internally for protocol operations but never shown to users.

### Registration

Users claim a username during or after signup. The server stores a mapping:

```
username  →  account_address (32-byte hash)
```

Usernames are immutable once claimed. One username per account.

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

The address gains a `$` prefix and becomes a valid UMA address (Universal Money Address). This enables cross-currency payments including stablecoins.

### Address format

```
$alice@zkcoins.app    (UMA address)
 alice@zkcoins.app    (Lightning Address — still works)
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
POST /v1/lnurlp/payreq/{username}      → payment request with compliance data
POST /v1/lnurlp/utxocallback           → post-transaction compliance hook
```

### Currencies advertised

```json
{
  "currencies": [
    {
      "code": "SAT",
      "name": "Satoshis",
      "symbol": "₿",
      "multiplier": 1000,
      "decimals": 0,
      "convertible": { "min": 1, "max": 10000000 }
    },
    {
      "code": "USDT",
      "name": "Tether USD",
      "symbol": "$",
      "multiplier": 23400,
      "decimals": 6,
      "convertible": { "min": 1000000, "max": 1000000000000 }
    }
  ]
}
```

### Settlement options

```json
{
  "settlementOptions": [
    { "settlementLayer": "ln", "assets": [{ "identifier": "BTC" }] },
    { "settlementLayer": "ethereum", "assets": [{ "identifier": "USDT" }] }
  ]
}
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
