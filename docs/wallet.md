---
sidebar_position: 4
title: Wallet
---

# Wallet Guide

The zkCoins wallet is a web application at [zkcoins.app](https://zkcoins.app) for sending and receiving private Bitcoin transactions.

## Getting started

1. Open [zkcoins.app](https://zkcoins.app)
2. Choose **Create with Passkey** (biometric) or **Create with Seed Phrase** (12 words)
3. For seed phrase: write down the 12 words, confirm them, set an unlock password
4. Use the **Faucet** button to mint testnet coins
5. Enter a recipient address and amount, then click **Send Coins**

Your keys are generated locally, encrypted with AES-256-GCM, and stored in IndexedDB. They are never sent to any server.

## Features

| Feature | Status | Description |
|---|---|---|
| Seed phrase (BIP-39) | ✅ Live | 12-word recovery phrase, create + restore |
| Passkey (WebAuthn) | ✅ Live | Biometric auth via PRF extension |
| Encrypted storage | ✅ Live | AES-256-GCM in IndexedDB via Web Crypto API |
| Balance display | ✅ Live | Auto-refreshing balance with 5s polling |
| Send coins | ✅ Live | Schnorr-signed transfers to any zkCoins address |
| Faucet | ✅ Live | Mint testnet coins (testnet only) |
| Transaction log | ✅ Live | Local history of all transactions |
| WASM crypto | ✅ Live | BIP-39, BIP-32, Schnorr signing in browser |
| Account backup | 🔜 Planned | Export/import wallet state |
| Mobile PWA | 🔜 Planned | Progressive Web App for mobile |

## Tech stack

| Layer | Technology |
|---|---|
| Framework | Next.js 14 (App Router) |
| Language | TypeScript |
| Styling | Tailwind CSS (dark theme, Bitcoin orange) |
| State | Zustand with encrypted IndexedDB persistence |
| Crypto | Rust → WebAssembly (secp256k1, BIP32) |
| API | REST client to Rust/Axum backend |

## Self-hosting

The wallet is fully open-source and can be self-hosted:

```bash
# Clone the monorepo
git clone https://github.com/zk-coins/app.git
cd app

# Install dependencies
npm install

# Start the wallet in development mode
npm run dev

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
| `/api/info` | GET | Network info (mainnet/testnet) |
| `/api/balance` | GET | Query account balance |
| `/api/address` | GET | List all known addresses |
| `/api/mint` | POST | Mint new coins (testnet faucet) |
| `/api/send` | POST | Send coins (with optional Schnorr signature) |
| `/api/receive` | POST | Submit a received coin proof |
| `/api/proof/{id}` | GET | Download a coin proof (binary) |
