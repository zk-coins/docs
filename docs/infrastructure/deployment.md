---
sidebar_position: 2
title: Deployment
---

# Deployment

zkCoins runs as Docker containers exposed via HTTPS. Documentation is deployed as a static site.

## Architecture

```
GitHub (push)
  │
  ├── develop → GitHub Actions → Docker build (ARM64)
  │                              → push zkcoin/*:beta
  │                              → SSH deploy to DEV server
  │
  └── main → GitHub Actions → Docker build (ARM64)
                              → push zkcoin/*:latest
                              → SSH deploy to PRD server

Static docs
  └── docs.zkcoins.app → Cloudflare Pages (auto-build on push)
```

## URLs

| URL | Service | Environment |
|---|---|---|
| `zkcoins.com` | Whitepaper / Shielded CSV Landing | PRD |
| `dev.zkcoins.com` | Whitepaper Landing (preview) | DEV |
| `zkcoins.info` | Brand-Hub / Landing (planned) | PRD |
| `zkcoins.app` | Wallet App | PRD |
| `api.zkcoins.app` | Backend API | PRD |
| `docs.zkcoins.app` | Documentation | PRD |
| `status.zkcoins.app` | Status Page | PRD |
| `dev.zkcoins.app` | Wallet App | DEV |
| `dev-api.zkcoins.app` | Backend API | DEV |
| `dev-docs.zkcoins.app` | Documentation | DEV |
| `dev-status.zkcoins.app` | Status Page | DEV |
| `zkcoins.exchange` | Trading Venue (planned) | PRD |
| `dev.zkcoins.exchange` | Trading Venue (planned) | DEV |
| `zkcoins.space` | Explorer (planned) | PRD |
| `dev.zkcoins.space` | Explorer (planned) | DEV |

## Docker Images

| Image | DEV tag | PRD tag | Registry |
|---|---|---|---|
| `zkcoin/app` | `:beta` | `:latest` | [Docker Hub](https://hub.docker.com/u/zkcoin) |
| `zkcoin/server` | `:beta` | `:latest` | [Docker Hub](https://hub.docker.com/u/zkcoin) |

Docs are not containerized — deployed as static files via Cloudflare Pages.

## Repositories

| Repo | Purpose | Deploy method |
|---|---|---|
| [zk-coins/app](https://github.com/zk-coins/app) | Wallet frontend (Next.js, PWA) | Docker container |
| [zk-coins/server](https://github.com/zk-coins/server) | Backend API (Rust/Axum) | Docker container |
| [zk-coins/docs](https://github.com/zk-coins/docs) | Documentation (Docusaurus) | Cloudflare Pages |
| [zk-coins/research](https://github.com/zk-coins/research) | Protocol research, upstream repos | Not deployed |

## Git Workflow

| Branch | Purpose | Deploy target | Protection |
|---|---|---|---|
| `develop` | Default branch, active development | DEV | Ruleset (PR required) |
| `main` | Production releases | PRD | Branch protection (PR required) |
| Feature branches | Individual changes | — | Merged to develop via PR |

Workflow: `feature branch → PR to develop → auto Release PR to main → merge to main`

## CI/CD Workflows

Every repo has 3-4 workflows:

| Workflow | Trigger | Action |
|---|---|---|
| `ci.yaml` | Push develop, PR | Lint + Build check |
| `deploy-dev.yaml` | Push develop | Docker build (ARM64) → push `:beta` → deploy DEV |
| `deploy-prd.yaml` | Push main | Docker build (ARM64) → push `:latest` → deploy PRD |
| `auto-release-pr.yaml` | Push develop | Creates Release PR (develop → main) |

## GitHub Secrets

Secrets are set at the **org level** (`zk-coins`) and available to all repos:

| Secret | Purpose |
|---|---|
| `DEPLOY_DEV_SSH_KEY` | SSH private key for DEV server |
| `DEPLOY_DEV_SSH_KNOWN_HOSTS` | Host key for DEV server |
| `DEPLOY_DEV_HOST` | DEV server SSH hostname |
| `DEPLOY_DEV_USER` | DEV server SSH username |
| `DEPLOY_PRD_SSH_KEY` | SSH private key for PRD server |
| `DEPLOY_PRD_SSH_KNOWN_HOSTS` | Host key for PRD server |
| `DEPLOY_PRD_HOST` | PRD server SSH hostname |
| `DEPLOY_PRD_USER` | PRD server SSH username |
| `DOCKER_USERNAME` | Docker Hub username (`zkcoin`) |
| `DOCKER_PASSWORD` | Docker Hub access token |

## Running with Docker

### Wallet App

```bash
docker run -p 3090:3090 \
  -e NEXT_PUBLIC_API_URL=https://api.zkcoins.app \
  -e NEXT_PUBLIC_NETWORK=mainnet \
  zkcoin/app:latest
```

Runtime env var injection via `entrypoint.sh` — same image for DEV and PRD.

### Backend Server

```bash
docker run -p 4242:4242 \
  --network bitcoin \
  -e ESPLORA_URL=http://bitcoind:8332 \
  -e BITCOIN_RPC_USER=myuser \
  -e BITCOIN_RPC_PASSWORD=mypassword \
  zkcoin/server:latest
```

Requires a Bitcoin node. See [Backend documentation](/infrastructure/backend).

## Health Checks

| Container | Health check | Healthy response |
|---|---|---|
| `zkcoins-app` | `curl -f http://localhost:3090/` | HTTP 200 |
| `zkcoins-server` | `wget http://localhost:4242/health` | HTTP 200 (`ok`) |

## Monitoring

- 6 Uptime Kuma monitors (app + api + docs, for both DEV and PRD)
- Public status pages: [status.zkcoins.app](https://status.zkcoins.app) (PRD), [dev-status.zkcoins.app](https://dev-status.zkcoins.app) (DEV)

## Port Allocation

| Port | Service |
|---|---|
| 6090 | Wallet App (host-side) |
| 6091 | Explorer (planned) |
| 6093 | Backend API (host-side) |
| 3090 | App internal (inside container) |
| 4242 | Server internal (inside container) |
