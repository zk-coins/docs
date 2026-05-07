---
sidebar_position: 7
title: Tech Decisions
---

# Technology Decisions

Every technology choice has trade-offs. This page documents what we chose, why, and what alternatives were considered.

---

## Frontend: Next.js 14

**Chosen:** Next.js 14 with App Router, TypeScript, standalone output

**Why:**
- Server-side rendering for initial page load and SEO
- App Router provides modern React patterns (Server Components, streaming)
- `output: 'standalone'` produces a minimal Docker image (~90 MB)
- Largest ecosystem for React-based web apps
- Runtime environment variable injection via `entrypoint.sh` — same image for DEV and PRD

**Considered:**
- **Vite + React** — lighter, faster dev server, but no SSR without additional setup. Good for SPAs, but we want the option for server-rendered pages (e.g. public wallet views, SEO)
- **SvelteKit** — excellent DX, but smaller ecosystem. Team familiarity with React was decisive
- **Plain HTML/JS** — the ZeroSync prototype uses this. Too limited for a production app with state management, routing, and component reuse

---

## Styling: Tailwind CSS

**Chosen:** Tailwind CSS with custom dark theme and Bitcoin orange accent (#f7931a)

**Why:**
- Utility-first — no context switching between CSS files and components
- Consistent design system through `tailwind.config.ts` (colors, fonts)
- Tiny production CSS — only used classes are bundled
- Dark theme by default — matches the crypto/privacy aesthetic

**Considered:**
- **Flowbite** — used in other DFX projects (dEURO, JuiceDollar). Skipped here because zkCoins has a distinct brand identity that doesn't fit Flowbite's component style
- **shadcn/ui** — excellent components but adds complexity. May adopt later for complex UI elements
- **CSS Modules** — more isolation but slower development velocity

---

## State Management: Zustand

**Chosen:** Zustand with localStorage persistence

**Why:**
- Minimal boilerplate — no providers, no reducers, no actions
- Direct store access from any component via hooks
- Built-in persistence middleware for localStorage
- ~1 KB bundle size vs Redux (~7 KB) or MobX (~15 KB)
- Perfect fit for a wallet app with simple state (account, balance, transactions)

**Considered:**
- **Redux Toolkit** — used in DFX projects. Overkill for a wallet with 3 state slices
- **React Context** — no persistence, re-renders entire tree on state change
- **Jotai/Recoil** — atomic state model is elegant but less established

---

## Cryptography: Rust → WebAssembly

**Chosen:** Rust compiled to WASM via `wasm-pack`, with JS fallback

**Why:**
- **secp256k1 in Rust** — battle-tested, same implementation as Bitcoin Core
- **BIP32 HD wallets** — deterministic key derivation in the browser
- **Schnorr signatures** — required by the Shielded CSV protocol
- **Performance** — WASM is 10-100x faster than pure JS for cryptographic operations
- **Security** — compiled from audited Rust crates, not hand-written JS crypto

**Why JS fallback:**
- WASM requires LLVM with wasm32 target for compilation (secp256k1 C library)
- CI environments may not have the full Rust+LLVM toolchain
- Fallback allows the app to function (with limited features) when WASM is unavailable

**Considered:**
- **noble-secp256k1 (JS)** — pure JavaScript, no WASM needed. But: not the same implementation as Bitcoin Core, less confidence in edge cases
- **WebCrypto API** — browser-native but doesn't support secp256k1 or Schnorr
- **libsodium.js** — excellent for general crypto but doesn't support Bitcoin's specific curves

---

## Backend: Rust / Axum

**Chosen:** Rust with Axum (async web framework)

**Why:**
- **Same language as the ZK circuits** — shared types between server and SP1 program
- **Performance** — Rust handles concurrent blockchain scanning and proof generation efficiently
- **Memory safety** — critical for a system that manages cryptographic state
- **Axum** — built on Tokio, idiomatic Rust, excellent middleware ecosystem
- **Direct port of ZeroSync prototype** — minimal rewrite needed

**Considered:**
- **Node.js/TypeScript** — used in DFX projects (indexer, prover). Would require rewriting all Rust types and Merkle tree logic. The shared Rust workspace between server and SP1 program is a significant advantage
- **Go** — good for concurrent servers but no SP1 zkVM support, would need FFI bridge
- **Python/FastAPI** — too slow for proof generation and blockchain scanning

---

## ZK Proofs: SP1 zkVM (Succinct)

**Chosen:** SP1 with CPU prover (production)

**Why:**
- **Write proofs in standard Rust** — no DSL, no Circom, no custom language
- **Recursive proofs** — essential for Proof-Carrying Data (PCD)
- **Succinct Prover Network** — outsource proving to decentralized network (future)
- **Active development** — Succinct is well-funded, rapid iteration
- **Used by ZeroSync prototype** — proven to work for this use case

**Prover modes:**
- **CPU** (current production) — runs on ARM64 (Apple Silicon M3 Ultra), generates real compressed STARK proofs
- **Mock** (development only) — dummy proofs for local testing via `SP1_PROVER=mock`
- **GPU / Network** (future scaling) — CUDA or Succinct Prover Network for lower latency

**Considered:**
- **Circom + Groth16** — used in Shade Protocol. Excellent for EVM verification but poor fit for Bitcoin (no on-chain verifier). Also requires a trusted setup
- **Halo2** — used by Zcash. Mature but complex DSL, steep learning curve
- **RISC Zero** — similar to SP1 but less ecosystem support for Bitcoin

---

## Data Structures: Sparse Merkle Tree + Merkle Mountain Range

**Chosen:** SMT for state, MMR for history

**Why:**
- **SMT** — supports both inclusion and non-inclusion proofs. Essential for proving a nullifier has NOT been published (double-spend prevention)
- **MMR** — append-only, efficient for accumulating block-by-block commitment history
- **Both defined in the Shielded CSV paper** — following the protocol specification
- **256-bit key space** — matches Bitcoin's hash output size

**Considered:**
- **Binary Merkle Tree** — simpler but doesn't support non-inclusion proofs efficiently
- **Verkle Trees** — more space-efficient but newer, less battle-tested, not specified by the protocol

---

## Bitcoin Integration: Taproot Inscriptions via Esplora API

**Chosen:** Publish nullifiers as Taproot Inscriptions, scan via Esplora REST API

**Why:**
- **Taproot Inscriptions** — arbitrary data in witness, minimal on-chain footprint
- **Esplora API** — RESTful, well-documented, compatible with Bitcoin Core's REST interface
- **Prefix marker (4242)** — simple filter for identifying zkCoins inscriptions among all Bitcoin transactions
- **No consensus changes** — works with Bitcoin as it exists today

**Considered:**
- **OP_RETURN** — simpler but limited to 80 bytes. Nullifiers fit, but Taproot Inscriptions are more future-proof for larger payloads
- **Bitcoin Core RPC directly** — possible, but Esplora provides a cleaner REST interface for block scanning
- **Electrum protocol** — efficient for UTXO queries but not designed for inscription scanning

---

## Documentation: Docusaurus 3.9

**Chosen:** Docusaurus with dark mode default, deployed via Cloudflare Pages

**Why:**
- **Markdown-based** — fast to write, version-controlled, diff-friendly
- **Used by Shade Protocol** — consistent pattern across our projects
- **Built-in search, versioning, i18n** — features we'll need as the project grows
- **Cloudflare Pages** — zero-infrastructure hosting, automatic deploys on push
- **Separate repo** — docs deploy independently from app/server

**Considered:**
- **Nextra** — originally planned, but Docusaurus was chosen for consistency with Shade Protocol
- **GitBook** — SaaS dependency, less control
- **VitePress** — excellent for Vue projects, less established for React-adjacent teams

---

## Hosting: Cloudflare Tunnel + Docker

**Chosen:** Docker containers on Mac Studio servers, exposed via Cloudflare Tunnel

**Why:**
- **No public IP needed** — servers are LAN-only, Cloudflare Tunnel provides secure ingress
- **Existing infrastructure** — dedicated servers already run 20+ containers
- **ARM64 native** — Apple Silicon, no emulation overhead
- **Consistent deploy pattern** — same Traefik setup, same monitoring across all services
- **Bitcoin node co-location** — server connects to Bitcoin node via shared Docker network, no network latency

**Considered:**
- **Cloudflare Workers** — serverless, but can't run Rust/Axum natively or maintain state (SMT/MMR)
- **AWS/GCP** — would work but adds cost and complexity vs. existing on-prem infrastructure
- **Vercel** — excellent for Next.js but can't host the Rust backend

---

## CI/CD: GitHub Actions with SSH Deploy

**Chosen:** GitHub Actions (ARM64 runners) → Docker build → push to Docker Hub → SSH deploy via Cloudflare Tunnel

**Why:**
- **ARM64 runners** — native builds for Apple Silicon, no cross-compilation
- **Docker Hub** — simple, reliable image registry
- **SSH through Cloudflare Tunnel** — secure deploy without exposing server ports
- **Command-restricted SSH key** — `deploy.sh` limits what CI can execute on the server
- **Consistent with DFX deploy pattern** — same workflow structure across all projects

**Deploy flow:**
```
Push to develop → GitHub Actions → Docker build (ARM64) → Push zkcoin/app:beta
                                                        → SSH to DEV server → deploy.sh zkcoins-app
                                                        → docker compose pull + up -d
```

---

## Monitoring: Uptime Kuma

**Chosen:** Uptime Kuma (self-hosted), 6 monitors, 2 status pages

**Why:**
- **Already running** — central monitoring for all DFX projects
- **Public status pages** — status.zkcoins.app and dev-status.zkcoins.app
- **Simple** — HTTP health checks, no agent installation needed
- **Self-hosted** — no SaaS dependency

---

## PWA: Service Worker + Web App Manifest

**Chosen:** Standalone PWA with cache-first strategy

**Why:**
- **Installable** — users add to home screen on iOS/Android
- **Standalone mode** — no browser chrome, native app feel
- **Offline capable** — static assets cached, API calls network-first with fallback
- **No app store** — instant updates, no review process
- **Bitcoin orange theme** — status bar matches brand

**Considered:**
- **React Native** — true native app, but doubles development effort. PWA is sufficient for MVP
- **Capacitor/Ionic** — wraps web app in native shell. Adds complexity without significant benefit over PWA
- **Electron** — desktop only, not mobile
