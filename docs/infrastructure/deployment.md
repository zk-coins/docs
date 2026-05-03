---
sidebar_position: 2
title: Deployment
---

# Deployment

zkCoins runs as Docker containers behind Cloudflare Tunnel on dedicated Mac Studio servers (Apple Silicon, ARM64).

## Architecture

```
GitHub (push)
  │
  ├── develop → GitHub Actions → Docker build (ARM64)
  │                              → push zkcoin/*:beta
  │                              → SSH deploy to dfxdev (DEV)
  │
  └── main → GitHub Actions → Docker build (ARM64)
                              → push zkcoin/*:latest
                              → SSH deploy to dfxprd (PRD)

Cloudflare Tunnel
  │
  ├── *.zkcoins.app → dfxprd (PRD containers)
  └── dev*.zkcoins.app → dfxdev (DEV containers)

Cloudflare Pages
  └── docs.zkcoins.app → zk-coins/docs repo (static build)
```

## URLs

| URL | Service | Host | Environment |
|---|---|---|---|
| `zkcoins.app` | Wallet App | dfxprd | PRD |
| `api.zkcoins.app` | Backend API | dfxprd | PRD |
| `docs.zkcoins.app` | Documentation | Cloudflare Pages | PRD |
| `status.zkcoins.app` | Status Page | Uptime Kuma | PRD |
| `dev.zkcoins.app` | Wallet App | dfxdev | DEV |
| `dev-api.zkcoins.app` | Backend API | dfxdev | DEV |
| `dev-docs.zkcoins.app` | Documentation | Cloudflare Pages | DEV |
| `dev-status.zkcoins.app` | Status Page | Uptime Kuma | DEV |
| `explorer.zkcoins.app` | Explorer | dfxprd | PRD (planned) |
| `dev-explorer.zkcoins.app` | Explorer | dfxdev | DEV (planned) |

## Docker Images

| Image | DEV tag | PRD tag | Registry |
|---|---|---|---|
| `zkcoin/app` | `:beta` | `:latest` | [Docker Hub](https://hub.docker.com/u/zkcoin) |
| `zkcoin/server` | `:beta` | `:latest` | [Docker Hub](https://hub.docker.com/u/zkcoin) |

Docs are not containerized — they deploy as static files via Cloudflare Pages.

## Port Allocation

| Port | Service | Used on |
|---|---|---|
| 6090 | Wallet App | dfxdev + dfxprd |
| 6091 | Explorer (planned) | dfxdev + dfxprd |
| 6093 | Backend API | dfxdev + dfxprd |
| 4242 | Server internal port | Inside container only |
| 3090 | App internal port | Inside container only |

## Repositories

| Repo | Purpose | Deploy |
|---|---|---|
| [zk-coins/app](https://github.com/zk-coins/app) | Wallet frontend (Next.js, PWA) | Docker → Tunnel |
| [zk-coins/server](https://github.com/zk-coins/server) | Backend API (Rust/Axum) | Docker → Tunnel |
| [zk-coins/docs](https://github.com/zk-coins/docs) | Documentation (Docusaurus) | Cloudflare Pages |
| [zk-coins/research](https://github.com/zk-coins/research) | Protocol research, upstream repos, paper | Not deployed |

## Git Workflow

All repos follow the same pattern:

| Branch | Purpose | Deploy target | Protection |
|---|---|---|---|
| `develop` | Default branch, active development | dfxdev (DEV) | Ruleset (PR required) |
| `main` | Production releases | dfxprd (PRD) | Branch protection (PR required, enforce admins) |
| Feature branches | Individual changes | — | Merged to develop via PR |

Workflow: `feature branch → PR to develop → auto Release PR to main → merge to main`

## CI/CD Workflows

Every repo has 3-4 workflows:

| Workflow | Trigger | Action |
|---|---|---|
| `ci.yaml` | Push develop, PR | Lint + Build check |
| `deploy-dev.yaml` | Push develop | Docker build (ARM64) → push `:beta` → SSH deploy dfxdev |
| `deploy-prd.yaml` | Push main | Docker build (ARM64) → push `:latest` → SSH deploy dfxprd |
| `auto-release-pr.yaml` | Push develop | Creates Release PR (develop → main) |

### Deploy Mechanism

1. GitHub Actions builds Docker image on `ubuntu-24.04-arm` runner
2. Pushes to Docker Hub (`zkcoin/app:beta` or `zkcoin/server:latest`)
3. Installs `cloudflared` for SSH tunnel
4. SSHs to target server via Cloudflare Tunnel (`ssh-dfxdev.dfxserve.com` / `ssh-dfxprd.dfxserve.com`)
5. Runs `deploy.sh zkcoins-app` or `deploy.sh zkcoins-server`
6. `deploy.sh` does `docker compose pull + up -d` for the specific service

## GitHub Secrets

Secrets are set at the **org level** (`zk-coins`) and available to all repos:

| Secret | Purpose |
|---|---|
| `DEPLOY_DEV_SSH_KEY` | SSH private key for dfxdev |
| `DEPLOY_DEV_SSH_KNOWN_HOSTS` | Host key for dfxdev tunnel |
| `DEPLOY_DEV_HOST` | SSH hostname (Cloudflare Tunnel) |
| `DEPLOY_DEV_USER` | SSH username on dfxdev |
| `DEPLOY_PRD_SSH_KEY` | SSH private key for dfxprd |
| `DEPLOY_PRD_SSH_KNOWN_HOSTS` | Host key for dfxprd tunnel |
| `DEPLOY_PRD_HOST` | SSH hostname (Cloudflare Tunnel) |
| `DEPLOY_PRD_USER` | SSH username on dfxprd |
| `DOCKER_USERNAME` | Docker Hub username (`zkcoin`) |
| `DOCKER_PASSWORD` | Docker Hub access token |

## Infrastructure as Code

All infrastructure is managed in the [DFXswiss/server](https://github.com/DFXswiss/server) repo:

| File | Purpose |
|---|---|
| `infrastructure/cloudflare/zkcoins.tf` | DNS records, Cloudflare Pages project, tunnel ingress |
| `infrastructure/cloudflare/tunnels.tf` | Tunnel routing rules (dfxdev + dfxprd) |
| `infrastructure/cloudflare/locals.tf` | Zone ID for zkcoins.app |
| `infrastructure/dfxdev/zkcoins/docker-compose.yaml` | DEV container configuration |
| `infrastructure/dfxprd/zkcoins/docker-compose.yaml` | PRD container configuration |
| `infrastructure/dfxdev/bin/deploy.sh` | Deploy script (DEV) |
| `infrastructure/dfxprd/bin/deploy.sh` | Deploy script (PRD) |

Changes to DNS/tunnels go through Terraform (CI/CD on DFXswiss/server). Changes to compose files are synced via the `deploy-infrastructure` workflow.

## Monitoring

| Component | Tool | URL |
|---|---|---|
| Uptime monitoring | Uptime Kuma | [kuma.dfxserve.com](https://kuma.dfxserve.com) |
| PRD status page | Uptime Kuma | [status.zkcoins.app](https://status.zkcoins.app) |
| DEV status page | Uptime Kuma | [dev-status.zkcoins.app](https://dev-status.zkcoins.app) |

6 monitors total: app + api + docs for both PRD and DEV.

## Health Checks

| Container | Health check | Healthy response |
|---|---|---|
| `zkcoins-app` | `curl -f http://localhost:3090/` | HTTP 200 |
| `zkcoins-server` | `wget http://localhost:4242/health` | HTTP 200 (`ok`) |

## Secrets Management

All secrets are stored in Vaultwarden (`dfxvault.com`):

| Vault Entry | Server | Content |
|---|---|---|
| Docker Hub - zkcoin | — | Docker Hub PAT |
| zkCoins DEV - dfxdev | dfxdev | Bitcoin Mainnet RPC credentials |
| zkCoins PRD - dfxprd | dfxprd | Bitcoin Mainnet RPC credentials |

## Bitcoin Node

The server connects to a local Bitcoin Core node via shared Docker network:

```
Network: bitcoin (external, created by nodes stack)
Hostname: bitcoind-mainnet
Port: 8332
Config: txindex=1, rest=1, server=1
```

See [Backend documentation](/infrastructure/backend) for full Bitcoin node setup.
