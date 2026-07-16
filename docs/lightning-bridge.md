---
title: Lightning Bridge
---

# Lightning Bridge

:::info Optional operator role
The Lightning bridge is an **optional operator role of the API layer**, **off by default**, and **never part of the trustless core**. It layers on top of the node's core surface at the kernel/API seam ([spec §6.1](/specification#61-components-and-responsibilities)); a node **MUST** advertise it so a client treats an unadvertised bridge as absent and fails closed. The operator running it never holds a user's keys and can never touch settled balances.
:::

## What the bridge is

The Lightning bridge is an operator-run swap service that sits at the edge between the Lightning Network and zkCoins. It exists so that one `user@domain` handle ([spec §4.3](/specification#43-addressing-for-delivery)) is payable **from any Lightning wallet** and can **pay any Lightning invoice** — the two rails meet at the operator, not in the protocol.

The operator **MAY** delegate the Lightning side to an external Lightning service provider. From the user's view this delegation is invisible: the operator remains the **sole counterparty** for every swap, and the user relates only to the operator that fronts their handle.

The bridge adds no new wire protocol to the core. On the zkCoins side it acts as an ordinary sender or recipient; on the Lightning side it acts as an ordinary Lightning node. Everything below is the operator wiring those two ordinary roles together.

## Discovery and gating

A client learns whether an operator runs the bridge from the node's advertised role set ([spec §6.4](/specification#64-external-interfaces-abstract), *Core surface vs optional roles*): the bridge is a **separately-gated endpoint** layered on the core surface, not a new part of it. Because optional roles gate **fail-closed** ([spec §6.1](/specification#61-components-and-responsibilities)), a client that sees no advertised bridge treats it as **absent** — it never assumes a swap endpoint that was not offered, and it never falls back to an unadvertised one. An operator that offers the bridge advertises its **fee schedule** and its **per-swap and aggregate caps** alongside the role, so a wallet can quote and bound a swap before the user commits to it.

## Receive path — Lightning into zkCoins

The handle's domain serves LNURL-pay (LUD-16) at `https://<domain>/.well-known/lnurlp/<user>`. This is the **Lightning rail** of the dual-rail handle design ([spec §4.3](/specification#43-addressing-for-delivery), *One handle for Lightning and zkCoins*): the same handle resolves for Lightning here and for zkCoins at `/.well-known/zkcoins/<user>`, so a payer picks the rail their wallet speaks.

An inbound payment on this rail flows in two independent settlements:

1. A Lightning payment settles at the **operator's Lightning node**. From the payer's perspective this is a normal LNURL-pay to a Lightning address.
2. The operator then delivers the **equivalent zkCoins payment** to the handle's resolved `address` as an ordinary bundle delivery ([spec §4.2](/specification#42-bundle-delivery)). Here the operator is simply a **normal zkCoins sender**: it constructs the delivery event and blob like any other payer, and the recipient's node credits the coin **only after the standard verification** against Bitcoin (§4.2, §4.5). The bridge earns no special trust on this leg — a bridged receive is indistinguishable, at the recipient, from any other incoming coin.

Because the delivered payment is an ordinary bundle, it reaches the recipient through the **ordinary path**: the recipient's node discovers it, verifies it, and surfaces it exactly as it would any other incoming coin. The recipient's wallet needs no bridge-specific handling and does not have to know the coin arrived over Lightning — from its side it received zkCoins, full stop.

The two settlements are not simultaneous. The window between them is the operator's exposure, discussed under *Trust model* below. Because the recipient credits only on its own verification against Bitcoin, a bridge that takes the Lightning payment and then fails to deliver the zkCoins side has **defaulted on an owed delivery** — it has not, and cannot, forge a credited coin at the recipient.

## Send path — zkCoins out to Lightning

To pay a Lightning invoice (or a Lightning address) from a zkCoins balance, the user's wallet sends zkCoins to the **bridge operator's address** as an ordinary transfer, and the operator pays the invoice over Lightning. The exchange runs through a normative state machine:

| State | Entered when | Operator obligation in this state |
|---|---|---|
| `quoted` | the user requests a swap for a given invoice or amount | disclose the **amount and the fee/spread**, and the **per-swap and aggregate in-flight caps** the bridge advertises, **before** the user commits |
| `funded` | the user's zkCoins transfer to the operator verifies (§4.2, §4.5) | attempt the Lightning payment for the quoted invoice |
| `settled` | the Lightning payment confirms | the swap is complete; nothing further is owed |
| `refunded` | the Lightning payment **fails definitively** | return the zkCoins amount **minus the disclosed fee** to the user |

The obligations are hard requirements on the operator:

- The operator **MUST** disclose the fee and spread in the `quoted` state, before the user transfers anything. A swap the user has not seen priced **MUST NOT** execute.
- The operator **MUST** refund the zkCoins amount, minus the disclosed fee, whenever the Lightning payment fails definitively (no route, expiry, or a permanent failure returned by Lightning). A definitively failed swap ends in `refunded`, never in the operator silently keeping the funds.
- The operator **MUST** apply the **per-swap** and **aggregate in-flight** caps it advertises. The aggregate cap bounds the total value the operator can owe across all open swap windows at once — the ceiling on the exposure described next.

The distinction between a **definitive** and a **transient** Lightning failure governs which state a swap ends in. A transient failure (a route that timed out, a temporarily-unavailable peer) keeps the swap in `funded` while the operator retries within the quote's validity; only a **definitive** failure moves it to `refunded`. A single funded swap resolves to exactly one terminal state — `settled` or `refunded` — so a user never both receives the Lightning payment and keeps the zkCoins.

## Trust model

Each swap is **custodial within its window**. Lightning settlement and zkCoins settlement are **not atomic**: between the two legs the operator — **not the protocol** — owes one side until the swap completes. On a receive, the operator owes the zkCoins delivery after the Lightning payment lands; on a send, the operator owes the Lightning payment (or the refund) after the zkCoins transfer verifies. A dishonest or insolvent operator can default on that in-flight obligation, and the honest bound on the damage is the **advertised aggregate in-flight cap** plus the per-swap cap — no user is exposed beyond what the operator advertised it could owe at once.

What the bridge **cannot** do is as important as what it can:

- It **never holds user keys** — not the seed, not the SPEND branch, not the operational bundle. A user swaps by making an ordinary transfer, exactly as they would to any other address.
- It **never sees SPEND material** and **cannot spend, forge, or double-spend** a user's coins ([spec §6.1](/specification#61-components-and-responsibilities)).
- It **cannot affect settled balances**. Once a bridged coin is verified and credited, it is an ordinary zkCoins coin under the user's own custody; the bridge has no further reach into it.
- It **cannot touch non-bridged traffic** at all. Coins that never transit the bridge are entirely outside its view and its control.

This shape is a **deliberate trade-off the swapping user accepts**, in the same spirit as the wallet–node trust configurations of the specification: a sovereign user who wants no in-flight custody simply does not run and does not use a bridge, and pays or receives Lightning by other means. A user who does use one exchanges the atomicity of a pure on-chain transfer for the reach of the Lightning Network, with the operator's advertised caps as the honest bound on what that reach can cost them.

The swap is custodial because it is a swap, not because zkCoins delegates anything to it. An **atomic** construction — one where the Lightning leg and the zkCoins leg either both complete or both revert with no in-flight custody — would require a **hash-time-locked transition in the core protocol**, binding a Lightning HTLC preimage to a zkCoins state transition. That construction is **out of scope for this extension**: the bridge specified here is a swap service at the edge, and its honest description is a bounded-custody one.

## Privacy

The operator learns the **Lightning counterpart, the amounts, and the timing** of the payments it bridges — this is inherent to standing between the two rails. It learns nothing about **non-bridged traffic** beyond what the aliasing role that fronts the handle already sees ([spec §4.3](/specification#43-addressing-for-delivery)): a coin the user sends or receives without going through the bridge is invisible to it. Running the bridge therefore widens the operator's view only over the swaps that pass through it, not over the account as a whole.

## Regulatory note

Operating a Lightning bridge is a **custodial financial service** — the operator holds value in flight across each swap window — and obtaining any licensing that service requires is the **operator's own responsibility**.

## See also

- [Mail bridge](/mail-bridge) — the sibling optional operator role that makes a handle a working email address.
