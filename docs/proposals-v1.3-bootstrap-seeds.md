---
title: "Proposal (v1.3): Bootstrap seed plurality"
---

# Proposal (v1.3): Bootstrap seed plurality

:::warning Not part of v1 — proposed for the next protocol version (v1.3)
This page is a **design proposal for a future protocol version (v1.3)**. It is **not** part of the
frozen v1 specification: v1 is final for v1 ([spec §1.7.8](/specification#178-reference-instantiation-status-final-for-v1))
and keeps the single pinned `bootstrap_pubkey` per network exactly as specified today
([spec §3.6](/specification#36-chain-scanning), [§4.3](/specification#43-addressing-for-delivery)).
Nothing here changes v1. The page records the intended direction so it can be reviewed *before* it
is written into the normative spec. When adopted it becomes a v1.3 change to the spec, carrying its
own security argument and a trust-boundary register entry (per `CONTRIBUTING.md`).
:::

## Problem

v1 pins **one** `bootstrap_pubkey` per network — "the only authority permitted to sign
`BootstrapManifestV1` … there is no other trust root for bootstrap"
([spec §4.3](/specification#43-addressing-for-delivery)). That key is a member of the pinned
`network-params.json` tuple ([spec §3.6](/specification#36-chain-scanning)); unlike the network tag
and `circuit_digest`, it is **not** cryptographically bound into the verifier data, and it has **no
rotation procedure**. It shares the character of the `activation_height` parameter — enforced only by
each node loading the same `network-params.json`, a parameter-agreement assumption rather than a
chain binding — but note the distinction: only `activation_height` is registered as a D-05 residual
([Paper-Deviation Analysis](/paper-conformance-analysis)); the same non-binding property of the
`bootstrap_pubkey` is an analogous gap that is **not** itself a registered residual today.

At launch the network's discovery/recovery entry points are operated by the founding team alone
(`api.zkcoins.com` and `api.zkcoins.app`, both under `api.`). Two domains, but a **single operator**
— i.e. a single point of control for the bootstrap layer. For the discovery/liveness/recovery plane
this stands in tension with the specification's own goal of "no central element anywhere in the
system" ([specification, introductory overview](/specification)).

## What is — and is not — at stake

The bootstrap layer is relied on **only for discovery and liveness, never for correctness.** Any node
rebuilds the nullifier accumulator from Bitcoin alone ([spec §3.6](/specification#36-chain-scanning))
and re-verifies every coin against Bitcoin before crediting it. A thin wallet does not do this
itself: it relies on its **own** node for it ([Requirement 4](/requirements)), and a receiver that
instead delegates to a **selected foreign** node trusts that node for correctness as a deliberate,
documented non-trustless trade-off ([spec §6.6](/specification#66-threat-model-and-trust-configurations)).
A relay or blob store a client is steered to "can withhold a bundle but can neither forge nor alter
one" ([spec §4.1](/specification#41-roles-and-transport)).

Consequently a compromised or lost bootstrap authority can:

- **block or degrade** onboarding and emergency recovery (liveness), and
- **redirect** a fresh client's metadata to chosen infrastructure, and — the sharper case — steer a
  new user toward a hostile **operator** it might then entrust with its operational bundle. That
  bundle is `{ivk, ovk, op, nk, op_secret}` ([spec §1.2](/specification#12-key-hierarchy)) — more
  than viewing keys: `nk` links the account's own spends and `op` is its Nostr signing key. An
  operator a user delegates witness-building to also holds the D-17 send-intent power — it can
  redirect or burn a send's outputs, or freeze the account, an effect "the same as theft" on that
  one transition ([spec §6.6](/specification#66-threat-model-and-trust-configurations),
  [Paper-Deviation Analysis](/paper-conformance-analysis)),

but it can **never** forge, steal, or double-spend across the protocol as a whole: custody (the SPEND
key) never leaves the wallet in any configuration. The fix therefore targets liveness,
censorship-resistance, and metadata exposure — plus the *steering-into-a-bad-operator* risk above,
which the client rule below bounds but does not fully remove.

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
   cross-checks it, and **TOFU-pins** the keys it learns. It **MUST NOT** auto-entrust its
   operational bundle `{ivk, ovk, op, nk, op_secret}`, or delegate witness-building, to an operator
   merely because that operator appears on the list — that delegation is a separate, deliberate trust
   decision the user makes under the [spec §6.6](/specification#66-threat-model-and-trust-configurations)
   model (self-host, or vet the operator). This extends the union + trust-on-first-use
   contact-discovery pattern the spec already defines (register entry D-15,
   [Paper-Deviation Analysis](/paper-conformance-analysis)) from contact lookup to the network
   bootstrap.
4. **Acceptance criterion for a PR (normative for this mechanism).** The endpoint MUST return the
   correct pinned `network-params` from `GET /v1/info` for the network. Note this is a **necessary,
   not sufficient** check: `/v1/info` is a self-declared response that a non-conforming server can
   mirror, so v1.3 will define a stronger behavioural/liveness check (e.g. serving a known
   inscription or bundle on request). A PR SHOULD also carry an operator identity/contact for
   accountability. A listing conveys *discoverability*, never endorsement.

### Operator incentives and trade-offs

Reasons an independent operator would list itself:

- It **removes dependence on the founding endpoints**: the network keeps bootstrapping even if
  `api.zkcoins.com` / `api.zkcoins.app` are censored, fail, or are compelled offline.
- It **diversifies discovery** across independent operators and jurisdictions, which is the property
  a censored cold-start needs.
- It makes the operator's **own users and infrastructure directly discoverable** at first contact
  and during recovery.

What listing does **not** do: it does not make the operator trusted. Because correctness is enforced
by nodes re-deriving state from Bitcoin and re-verifying every coin, a listed seed cannot forge,
steal, or double-spend. It **can**, however, present a hostile operator as a candidate; a user who
then deliberately entrusts that operator with its operational bundle or its witness-building is
exposed to the D-17 boundary (send-output redirection or account freeze, an effect equivalent to
theft on that transition). The union + cross-check + TOFU-pin + never-auto-entrust rule of point 3
bounds automatic exposure; the deliberate-delegation exposure is addressed only by self-hosting or
independently vetting the operator.

## Residual trust

This makes bootstrap **robust, not trustless.** At launch both listed endpoints share one operator,
so the list provides endpoint redundancy, not operator independence; the single point of control is
only reduced as independently operated seeds join. Even then, trust does not disappear — it moves to
(a) the software-distribution / release process that curates the seed list and (b) the set of seed
operators. Two residuals remain and are the reason point 3 is normative rather than advisory:

- **Cold-start eclipse and metadata** are *reduced* by plurality, not eliminated: a client whose
  seeds all collude, or which is fully eclipsed, still gets a false view (Bitcoin's DNS seeds carry
  the same residual).
- **Trust-delegation steering:** a malicious seed can still present a hostile operator as a
  candidate. The union + cross-check + TOFU-pin + never-auto-entrust rule bounds this, so a client
  that follows it is not exposed beyond metadata unless it goes on to delegate deliberately.

## Spec impact when adopted (v1.3)

A v1.3 change would specify: the seed-list format and its in-code location; the client resolution
algorithm (query N seeds, union, cross-check, TOFU-pin, no auto-entrust); the PR acceptance
criterion; and — because this moves a trust/availability boundary — its **own security argument** and
register entries in the [Paper-Deviation Analysis](/paper-conformance-analysis) and
[Paper-Conformance Remediation](/paper-conformance-remediation), as `CONTRIBUTING.md` requires for any
change to a load-bearing trust boundary (with a [Risks](/risks) entry and a tracking issue for any
open contradiction). Until then, **v1 keeps the single `bootstrap_pubkey` unchanged.**
