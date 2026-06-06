---
sidebar_position: 1
title: Backend
---

# Backend

The zkCoins backend is a Rust/Axum REST API server that manages account state, generates ZK proofs, scans the Bitcoin blockchain, and publishes commitments.

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
│  │ Plonky2      │  │ Scanner       │  │
│  │ prover       │  │               │  │
│  │ (in-process) │  │ Esplora WS    │  │
│  │ ZK proofs    │  │ (event-driven)│  │
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
| `/health` | GET | Health check (returns `ok`) |
| `/api/info` | GET | Network name (Mainnet/Mutinynet) |
| `/api/balance` | GET | Query account balance by address |
| `/api/address` | GET | List all known account addresses |
| `/api/mint` | POST | Mint coins from the minting account |
| `/api/send` | POST | Transfer coins (with optional Schnorr signature auth) |
| `/api/receive` | POST | Submit a received coin proof (binary) |
| `/api/proof/{id}` | GET | Download a coin proof (binary) |

## Bitcoin Node Requirement

:::warning Bitcoin node required
The zkCoins server **requires a Bitcoin node** to operate. The server continuously scans the blockchain for Taproot Inscriptions containing zkCoins commitments. Without a node, no transactions can be verified or published.
:::

### What the server needs from the node

- **RPC access** — to query blocks, transactions, and broadcast inscriptions
- **`txindex=1`** — full transaction indexing must be enabled
- **`rest=1`** — REST API for health checks and block queries
- **`server=1`** — RPC server must be active

### Node options

| Option | Use case | Setup |
|---|---|---|
| **Local Bitcoin Core** (recommended) | Production, self-hosting | Run `bitcoind` with `txindex=1`, expose RPC on port 8332 |
| **Docker Bitcoin Core** | Containerized deployment | Use `lightninglabs/bitcoin-core` image in shared Docker network |
| **Public Esplora API** | Development, quick start | Point to `https://mutinynet.com/api` or `https://mempool.space/api` |

### Docker setup (recommended for production)

The server connects to the Bitcoin node via a shared Docker network. Both containers join the same network, and the server reaches the node by hostname:

```
┌──────────────────────────────────────┐
│         Docker Network: bitcoin      │
│                                      │
│  ┌──────────────┐  ┌─────────────┐  │
│  │ bitcoind     │  │ zkcoins     │  │
│  │ Port 8332    │◀─│ server      │  │
│  │ txindex=1    │  │ Port 4242   │  │
│  └──────────────┘  └─────────────┘  │
└──────────────────────────────────────┘
```

The server connects to `http://bitcoind:8332/` within the Docker network — no port forwarding needed.

### Bitcoin Core configuration

Minimum `bitcoin.conf` for zkCoins:

```ini
server=1
rest=1
txindex=1
rpcallowip=0.0.0.0/0
rpcbind=0.0.0.0
rpcport=8332
rpcuser=<your-rpc-user>
rpcpassword=<your-rpc-password>
```

### Network choice

| Network | Port | Data size | Use case |
|---|---|---|---|
| **Mainnet** | 8332 | ~850+ GB | Production |
| **Testnet4** | 18443 | ~14 GB | Integration testing |
| **Signet** | 38332 | ~83 MB | Fast development |

For development, **Signet** is recommended — it's small, fast to sync, and has predictable block times.

## Running locally

```bash
# Start the server (requires Bitcoin node access)
ESPLORA_URL=http://localhost:8332 \
RUST_LOG=info \
cargo run -p server
```

The server starts on `http://127.0.0.1:4242`.

### Environment variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | yes | Postgres connection string for account and proof state |
| `PUBLISHER_KEY` | yes | Hex private key used to sign Taproot inscription (commit/reveal) transactions |
| `USERNAME_DOMAIN` | yes | Domain used for account usernames (returned by `/api/info`) |
| `IS_MAINNET` | yes | `true` for Bitcoin mainnet, `false` for the test network |
| `NETWORK_NAME` | no | Display name for the network (e.g. `Mainnet`, `Mutinynet`); cosmetic only |
| `PROOFS_DIR` | no | Directory where serialized proofs are stored (default `./proofs`) |
| `ZKCOINS_SKIP_BOOTSTRAP_WARMUP` | no | Skip the Plonky2 prover warmup at startup (faster boot for local development) |

## Key components

### Account Server

Manages accounts as a hashmap of `Address → Account`:

```rust
struct Account {
    proof: Option<Proof>,           // Latest Plonky2 proof
    coin_queue: Vec<CoinProof>,     // Received but unspent coins
    coin_history: SparseMerkleTree, // SMT of received coin identifiers
    balance: u64,                   // Liquid balance
}
```

### Scanner

Subscribes to an Esplora WebSocket and processes blocks as they arrive (event-driven, no polling):

1. Receives new tip events from the Esplora WebSocket as blocks are announced
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

### Prerequisites

1. **Bitcoin Core node** with `txindex=1` and `rest=1` (see above)
2. **Rust 1.81+** toolchain
3. ~2 GB RAM for the server + Plonky2 prover

### From source

```bash
# Build
cargo build --release -p server

# Run (connect to local Bitcoin node)
ESPLORA_URL=http://localhost:8332 \
BITCOIN_RPC_USER=myuser \
BITCOIN_RPC_PASSWORD=mypassword \
RUST_LOG=info \
./target/release/server
```

### With Docker

```bash
# Run server container, join Bitcoin node's Docker network
docker run -p 4242:4242 \
  --network bitcoin \
  -e ESPLORA_URL=http://bitcoind:8332 \
  -e BITCOIN_RPC_USER=myuser \
  -e BITCOIN_RPC_PASSWORD=mypassword \
  -v server-data:/data \
  zkcoins-server:latest
```

The `--network bitcoin` flag connects the server to the same Docker network as the Bitcoin node, allowing access via hostname `bitcoind`.
