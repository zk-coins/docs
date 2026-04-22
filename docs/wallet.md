---
sidebar_position: 4
title: Wallet
---

# Wallet Guide

The zkCoins wallet is a web application at [zkcoins.app](https://zkcoins.app) for sending and receiving private Bitcoin transactions.

## Getting started

1. Open [zkcoins.app](https://zkcoins.app)
2. Click **Create Account** — this generates a BIP32 HD wallet in your browser
3. Use the **Faucet** button to mint testnet coins
4. Enter a recipient address and amount, then click **Send Coins**

Your keys are generated locally and stored in the browser. They are never sent to any server.

## Features

| Feature | Status | Description |
|---|---|---|
| Account creation | ✅ Live | BIP32 HD wallet generation via WASM |
| Balance display | ✅ Live | Auto-refreshing balance with 5s polling |
| Send coins | ✅ Live | Transfer to any zkCoins address |
| Faucet | ✅ Live | Mint testnet coins (testnet only) |
| Transaction log | ✅ Live | Local history of all transactions |
| WASM crypto | ✅ Live | Schnorr signing and key derivation in browser |
| Encrypted storage | 🔜 Planned | IndexedDB with Web Crypto API |
| Account backup | 🔜 Planned | Export/import wallet state |
| Multi-coin TX | 🔜 Planned | Send to multiple recipients |
| Mobile PWA | 🔜 Planned | Progressive Web App for mobile |

## Tech stack

| Layer | Technology |
|---|---|
| Framework | Next.js 14 (App Router) |
| Language | TypeScript |
| Styling | Tailwind CSS (dark theme, Bitcoin orange) |
| State | Zustand with localStorage persistence |
| Crypto | Rust → WebAssembly (secp256k1, BIP32) |
| API | REST client to Rust/Axum backend |

## Self-hosting

The wallet is fully open-source and can be self-hosted:

```bash
# Clone the monorepo
git clone https://github.com/zk-coins/zkcoins-app.git
cd zkcoins-app

# Install dependencies
yarn install

# Start the wallet in development mode
yarn dev

# The wallet is available at http://localhost:3090
```

To connect to your own backend, set the environment variable:

```bash
NEXT_PUBLIC_API_URL=http://localhost:4242
```

## API endpoints

The wallet communicates with the Rust backend via REST:

| Endpoint | Method | Description |
|---|---|---|
| `/api/mint` | POST | Mint new coins (testnet faucet) |
| `/api/send` | POST | Send coins to a recipient |
| `/api/balance` | GET | Query account balance |
| `/api/proof/:id` | GET | Download a coin proof |
