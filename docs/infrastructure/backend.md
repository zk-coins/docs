---
sidebar_position: 1
title: Backend
---

# Backend

The zkCoins backend is a Rust/Axum REST API server that manages account state, generates ZK proofs, scans the Bitcoin blockchain, and publishes nullifiers.

## Architecture

```
┌─────────────────────────────────────────┐
│            Rust/Axum Server             │
│            Port 4242                    │
│                                         │
│  ┌──────────────┐  ┌────────────────┐  │
│  │ Account      │  │ State          │  │
│  │ Server       │  │                │  │
│  │              │  │ Sparse Merkle  │  │
│  │ - Accounts   │  │ Tree (SMT)    │  │
│  │ - Coin Queue │  │               │  │
│  │ - Proofs     │  │ Merkle Mt.    │  │
│  └──────┬───────┘  │ Range (MMR)   │  │
│         │          └───────┬────────┘  │
│         │                  │           │
│  ┌──────▼───────┐  ┌──────▼────────┐  │
│  │ SP1 Prover   │  │ Scanner       │  │
│  │              │  │               │  │
│  │ ZK proof     │  │ Poll Bitcoin  │  │
│  │ generation   │  │ every 30s     │  │
│  └──────────────┘  └──────┬────────┘  │
│                           │           │
│  ┌────────────────────────▼────────┐  │
│  │ Publisher                       │  │
│  │                                 │  │
│  │ Taproot Inscriptions            │  │
│  │ Commit/Reveal, prefix "4242"    │  │
│  └─────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## REST API

| Endpoint | Method | Description |
|---|---|---|
| `/api/mint` | POST | Mint coins from the minting account |
| `/api/send` | POST | Transfer coins between accounts |
| `/api/balance` | GET | Query account balance |
| `/api/proof/:id` | GET | Download a coin proof (binary) |

## Running locally

```bash
cd rust
SP1_PROVER=mock cargo run -p server
```

The server starts on `http://127.0.0.1:4242`.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `SP1_PROVER` | `mock` | Prover mode: `mock` (dummy proofs) or `local` (real proofs) |
| `ESPLORA_URL` | `https://mutinynet.com/api` | Bitcoin node API endpoint |
| `PUBLISHER_KEY` | Hardcoded | Private key for inscription publishing |
| `RUST_LOG` | `info` | Log level |

## Key components

### Account Server

Manages accounts as a hashmap of `Address → Account`:

```rust
struct Account {
    proof: Option<Proof>,           // Latest SP1 proof
    coin_queue: Vec<CoinProof>,     // Received but unspent coins
    coin_history: SparseMerkleTree, // SMT of received coin identifiers
    balance: u64,                   // Liquid balance
}
```

### Scanner

Continuously polls the Bitcoin blockchain via Esplora API:

1. Fetches new blocks every 30 seconds
2. Filters transactions by prefix `4242`
3. Extracts Taproot Inscription data from witness
4. Deserializes and verifies Schnorr signatures
5. Updates the global SMT and MMR

### Publisher

Creates Bitcoin Taproot Inscriptions:

1. Splits commitment data into 520-byte chunks (max push size)
2. Creates a commit transaction (key-path spend)
3. Creates a reveal transaction (script-path spend with inscription data)
4. Broadcasts via Esplora API

### State

Thread-safe shared state (`Arc<Mutex<State>>`):

- **Sparse Merkle Tree** — stores all commitments indexed by public key hash
- **Merkle Mountain Range** — append-only history of SMT roots
- **Root indices** — maps previous MMR root to (SMT root, index) for proof lookups

## Self-hosting

```bash
# Build the server
cd rust
cargo build --release -p server

# Run with real Bitcoin testnet
SP1_PROVER=mock \
ESPLORA_URL=https://mutinynet.com/api \
RUST_LOG=info \
./target/release/server
```
