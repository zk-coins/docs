---
sidebar_position: 2
title: Deployment
---

# Deployment

zkCoins is deployed as Docker containers behind Cloudflare Tunnel, following the same patterns used in production DeFi infrastructure.

## Domain mapping

| Domain | Service | Environment |
|---|---|---|
| `zkcoins.app` | Wallet (Next.js) | Production |
| `docs.zkcoins.app` | Documentation (Docusaurus) | Production |
| `explorer.zkcoins.app` | Explorer (Next.js) | Production (planned) |
| `api.zkcoins.app` | Backend (Rust/Axum) | Production |
| `dev.zkcoins.app` | Wallet | Development |
| `dev-docs.zkcoins.app` | Documentation | Development |
| `dev-api.zkcoins.app` | Backend | Development |

## Docker images

| Image | Description | Tag pattern |
|---|---|---|
| `zkcoins-wallet` | Next.js wallet app | `beta` (develop), `latest` (main) |
| `zkcoins-docs` | Docusaurus documentation | `beta` (develop), `latest` (main) |
| `zkcoins-server` | Rust/Axum backend | `beta` (develop), `latest` (main) |

## Port allocation

| Port | Service |
|---|---|
| 6090 | Wallet |
| 6091 | Explorer |
| 6092 | Documentation |
| 6093 | Backend API |

## Running with Docker

```bash
# Wallet
docker run -p 3090:3090 \
  -e NEXT_PUBLIC_API_URL=https://api.zkcoins.app \
  zkcoins-wallet:latest

# Backend
docker run -p 4242:4242 \
  -e SP1_PROVER=mock \
  -e ESPLORA_URL=https://mutinynet.com/api \
  -v server-data:/data \
  zkcoins-server:latest

# Docs
docker run -p 3092:3092 zkcoins-docs:latest
```

## Source code

All services are part of the [zkcoins-app monorepo](https://github.com/zk-coins/zkcoins-app):

| Component | Path |
|---|---|
| Wallet | `apps/wallet/` |
| Documentation | `apps/docs/` |
| Backend | `rust/server/` |
| WASM Crypto | `rust/client/` + `packages/zkcoins-wasm/` |
| SP1 Circuit | `rust/program/` |
