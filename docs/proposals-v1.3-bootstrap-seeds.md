---
title: "Proposal (v1.3): Bootstrap seed plurality"
---

# Proposal (v1.3): Bootstrap seed plurality

:::warning Not part of v1 — proposed for the next protocol version (v1.3)
This page is a **design proposal for a future protocol version (v1.3)**. It is **not** part of the
frozen v1 specification: v1 is final for v1 (spec §1.7.8) and keeps the single pinned
`bootstrap_pubkey` per network exactly as specified today (spec §3.6, §4.3). Nothing here changes
v1. The page records the intended direction so it can be reviewed *before* it is written into the
normative spec. When adopted it becomes a v1.3 change to the spec, carrying its own security
argument and a trust-boundary register entry (per `CONTRIBUTING.md`).
:::

## Problem

v1 pins **one** `bootstrap_pubkey` per network — "the only authority permitted to sign
`BootstrapManifestV1` … there is no other trust root for bootstrap" (spec §4.3). That key is a
member of the pinned `network-params.json` tuple (spec §3.6); it is **not** cryptographically bound
into the on-chain data (unlike the network tag and `circuit_digest`), and it has **no rotation
procedure**. It rests on the parameter-agreement assumption the spec states in its own honest caveat
(a D-05 residual): every node must load the same `network-params.json`.

At launch the network's discovery/recovery entry points are operated by the founding team alone
(`api.zkcoins.com` and `api.zkcoins.app`, both under `api.`). Two domains, but a **single operator**
— i.e. a single point of control for the bootstrap layer. For the discovery/liveness/recovery plane
this contradicts the project's stated goal of "no central element anywhere in the system" (spec
Foundations).

## What is — and is not — at stake

The bootstrap layer is trusted **only for discovery and liveness, never for correctness.** Every
client re-derives the nullifier accumulator from Bitcoin alone (spec §3.6) and re-verifies every
coin against Bitcoin before crediting it (client-side validation, Requirement 4). A relay or blob
store a client is steered to "can withhold a bundle but can neither forge nor alter one" (spec §4.1).

Consequently a compromised or lost bootstrap authority can:

- **block or degrade** onboarding and emergency recovery (liveness), and
- **redirect** a fresh client's metadata to chosen infrastructure, and — the sharper case — steer a
  careless new user toward a hostile **operator** it might then entrust with its operational bundle
  (the account's viewing keys), which is a privacy and send-correctness exposure (the D-17 boundary),

but it can **never** forge, steal, or double-spend. The fix therefore targets liveness,
censorship-resistance, and metadata exposure — not custody.

## Proposal

Replace the single mandatory bootstrap trust root with a **plurality of independent seed endpoints**,
following the model Bitcoin Core uses for its DNS seeds and `chainparams`:

1. **Ship an initial seed list in code.** At launch: `api.zkcoins.com` and `api.zkcoins.app`.
2. **Open the list to independent operators by pull request.** Any operator running a conforming,
   publicly reachable node MAY add its endpoint. This is a release-governance mechanism: the trust
   becomes "who reviews and merges the PR" plus "the set of listed operators", instead of one
   unrotatable key.
3. **Clients treat seeds as discovery _candidates_, not authorities.** A client queries several
   seeds, takes the **union** of the advertised infrastructure (relays, blob stores, operators),
   cross-checks it, and **TOFU-pins** the keys it learns — it **MUST NOT** auto-delegate custody or
   hand its operational bundle to a listed operator merely because the operator appears on the list.
   This extends the union + trust-on-first-use contact-discovery pattern the spec already defines
   (register entry D-15) from contact lookup to the network bootstrap.
4. **Acceptance criterion for a PR (normative for this mechanism).** The endpoint MUST verifiably
   serve a conforming node — `GET /v1/info` returns the correct pinned `network-params` for the
   network — and SHOULD carry an operator identity/contact for accountability. A listing conveys
   *discoverability*, never endorsement.

### Why an operator should add itself (rationale to embed at the list)

- It **removes dependence on the founding endpoints**: the network keeps bootstrapping even if
  `api.zkcoins.com` / `api.zkcoins.app` are censored, fail, or are compelled offline.
- It **diversifies discovery** across independent operators and jurisdictions, which is exactly the
  property a censored cold-start needs.
- It makes the operator's **own users and infrastructure directly discoverable** at first contact
  and during recovery.
- It is **low-risk to contribute**: because correctness is enforced by client-side validation
  against Bitcoin, and because seeds are candidates that clients cross-check and TOFU-pin rather than
  trust blindly, adding a seed can only **widen reach** — it cannot forge, steal, double-spend, or,
  under the client rule in point 3, unilaterally capture a user's trust delegation.

## Residual trust (stated honestly)

This makes bootstrap **robust, not trustless.** The single-point-of-control is dissolved, but trust
does not disappear — it moves to (a) the software-distribution / release process that curates the
seed list and (b) the set of seed operators. Two residuals remain and are the reason point 3 is
normative rather than advisory:

- **Cold-start eclipse and metadata** are *reduced* by plurality, not eliminated: a client whose
  seeds all collude or who is fully eclipsed still gets a false view (Bitcoin's DNS seeds carry the
  same residual).
- **Trust-delegation steering:** a malicious seed can still present a hostile operator as a
  candidate. The union + cross-check + TOFU-pin + never-auto-entrust rule is what bounds this, so a
  client that follows it is not exposed beyond metadata.

## Spec impact when adopted (v1.3)

A v1.3 change would specify: the seed-list format and its in-code location; the client resolution
algorithm (query N seeds, union, cross-check, TOFU-pin, no auto-entrust); the PR acceptance
criterion; and — because this moves a trust/availability boundary — its **own security argument**
and a register entry in the Paper-Deviation Analysis and Risks, as `CONTRIBUTING.md` requires for any
change to a load-bearing trust boundary. Until then, **v1 keeps the single `bootstrap_pubkey`
unchanged.**
