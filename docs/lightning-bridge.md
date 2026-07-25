---
title: Lightning Bridge
---

# Lightning Bridge

:::info Optional operator service
The Lightning bridge is an **optional operator service**, **off by default**, and **never part of the trustless core**. It is independent of the optional SMTP/email bridge and of mandatory NIP-05 identity and NIP-17 messaging. It is not a node-protocol role and adds no API, Nostr event, or role value to the closed core-role set ([spec §6.1](/specification#61-components-and-responsibilities)). The bridge service adds no key custody — the operator never sees SPEND material through it — and can never touch settled balances; whether the same operator separately hosts operational bundles as a hosted-wallet provider is an independent trust decision ([spec §6.6](/specification#66-threat-model-and-trust-configurations)).
:::

## What the bridge is

The Lightning bridge is an operator-run swap service that sits at the edge between the Lightning Network and zkCoins. It exists so that one NIP-05 `user@domain` identifier ([spec §4.3](/specification#43-addressing-for-delivery)) is payable **from any Lightning wallet** and can **pay any Lightning invoice** — the two rails meet at the operator, not in the protocol.

The operator **MAY** delegate the Lightning side to an external Lightning service provider. From the user's view this delegation is invisible: the operator remains the **sole counterparty** for every swap, and the user relates only to the operator that fronts their identifier.

The bridge adds no new wire protocol to the core. On the zkCoins side it acts as an ordinary sender or recipient; on the Lightning side it acts as an ordinary Lightning node. Everything below is the operator wiring those two ordinary roles together.

## Discovery and gating

Receive and send use different gates. **Receive discovery** is exclusively standard Lightning Address discovery: the recipient's valid kind-0 profile contains `lud16`, and the corresponding LUD-16/LNURL-pay endpoint completes successfully. If `lud16` is absent or that endpoint fails, Lightning receive is unavailable. **Send-to-Lightning** has no implicit discovery: the user or operator **MUST** explicitly configure the bridge service, and the service **MUST** return a successful quote before the wallet transfers any zkCoins. There is no fallback to another service and no new zkCoins API, Nostr event, event tag, or node role in this specification. Neither path is a member of, or advertised through, the closed `roles` set ([spec §6.4](/specification#64-external-interfaces-abstract), *Core surface vs optional roles*); a client that has not confirmed a path through these signals **MUST** treat it as absent, never assuming or falling back to a swap endpoint it was not shown evidence for.

The operator publishes or displays its service terms as operator conditions, outside the zkCoins wire protocol: supported swap assets (`asset_id`), pricing for both legs, fee schedule, delivery window, refund policy, and per-swap and aggregate in-flight caps. zkCoins is multi-asset with no native token, so the settlement asset is never implicit. When the aggregate in-flight cap is reached, the operator **MUST** refuse new quotes and stop issuing LNURL invoices until open swaps settle.

## Receive path — Lightning into zkCoins

The identifier's domain serves LNURL-pay (LUD-16) at `https://<domain>/.well-known/lnurlp/<user>`, and the user's standard kind-0 profile publishes the same value in `lud16` ([spec §4.3](/specification#43-addressing-for-delivery), *One identifier, independent optional bridges*). The client **MUST** successfully resolve and validate that standard LUD-16/LNURL-pay endpoint before treating Lightning receive as available. The identifier always resolves as NIP-05 at `/.well-known/nostr.json?name=<user>`; LNURL is an additional independent rail. If `lud16` is absent or the endpoint fails, Lightning receive is unavailable while NIP-05, NIP-17, and native zkCoins continue to work.

An inbound payment on this rail flows in two independent settlements:

1. A Lightning payment settles at the **operator's Lightning node**. From the payer's perspective this is a normal LNURL-pay to a Lightning address.
2. The operator then delivers the **equivalent zkCoins payment** to the identifier's kind-0-resolved `address` as an ordinary bundle delivery ([spec §4.2](/specification#42-bundle-delivery)). "Equivalent" is defined by the operator's published or displayed conditions: the delivered amount is what the stated rate and fee schedule for this leg yields, in the stated asset. The receive leg has no per-swap quote; the Lightning payer simply pays. The binding rate and fee are the operator conditions in effect when it issues the LNURL invoice — a snapshot at invoice time. These conditions bind an honest operator's service obligation; they are not a new zkCoins wire field or discovery mechanism and are not a promise the recipient can enforce cryptographically. Here the operator is simply a **normal zkCoins sender**: it constructs the delivery event and blob like any other payer, and the recipient's node credits the coin **only after the standard verification** against Bitcoin (§4.2, §4.5). The bridge earns no special trust on this leg — a bridged receive is indistinguishable, at the recipient, from any other incoming coin.

Because the delivered payment is an ordinary bundle, it reaches the recipient through the **ordinary path**: the recipient's node discovers it, verifies it, and surfaces it exactly as it would any other incoming coin. The recipient's wallet needs no bridge-specific handling and does not have to know the coin arrived over Lightning — from its side it received zkCoins, full stop.

The two settlements are not simultaneous. The window between them is the **user's counterparty exposure to the operator** — until the zkCoins delivery verifies, the identifier's owner is owed, not paid — discussed under *Trust model* below. Because the recipient credits only on its own verification against Bitcoin, a bridge that takes the Lightning payment and then fails to deliver the zkCoins side has **defaulted on an owed delivery** — it has not, and cannot, forge a credited coin at the recipient. The operator's receive-side obligation is to deliver the equivalent zkCoins within its stated delivery window; a **definitive non-delivery** within that window is the receive-leg default the *Trust model* describes. Unlike a send — where a definitively failed Lightning payment refunds the **funded stake** to the quote's refund target — the receive leg has **no such refund path**, because the inbound leg is a Lightning payment already held by the operator; the user's only recourse is the operator's stated policy.

## Send path — zkCoins out to Lightning

To pay a Lightning invoice (or a Lightning address) from a zkCoins balance, the user or operator first **MUST** explicitly configure the chosen bridge and obtain a successful quote from it. Without both, Lightning send is unavailable. The user's wallet then sends zkCoins to that **bridge operator's address** as an ordinary transfer, and the operator pays the invoice over Lightning. The quote interaction is operator-service behavior outside the zkCoins wire protocol; this specification adds no endpoint or event for it. The exchange runs through a normative state machine:

| State | Entered when | Operator obligation in this state |
|---|---|---|
| `quoted` | the user requests a swap for a given invoice or amount, naming a **refund target** | disclose the **amount, the fee/spread, the exact refund amount, and the applicable caps**, issue the swap's `Invoice` ([spec §4.3](/specification#43-addressing-for-delivery)), **before** the user commits |
| `funded` | the user's zkCoins transfer — paying the quote's `Invoice` and reported under the swap identifier — verifies (§4.2, §4.5) | attempt the Lightning payment for the quoted invoice |
| `settled` | the Lightning payment confirms | the swap is complete; nothing further is owed |
| `refunded` | the Lightning payment **fails definitively** | return the quote's **stated refund amount** to the quote's **refund target** |

The obligations are hard requirements on the operator:

- The operator **MUST** disclose the fee and spread in the `quoted` state, before the user transfers anything, and the quote **MUST** state the **exact refund amount** — a discrete fee component, separate from any spread, since a spread alone leaves a refund incomputable — so `refunded` follows deterministically from the quote. A swap the user has not seen priced **MUST NOT** execute.
- The quote **MUST** include an operator-issued `Invoice` ([spec §4.3](/specification#43-addressing-for-delivery)) for the swap amount with a unique memo — the swap identifier. The memo binds the quote **payer-side only**: `coin.identifier` commits `prev_ash ‖ recipient ‖ asset_id ‖ amount ‖ coin_index` and the `CoinProof` bundle carries no memo ([spec §1.4](/specification#14-identifiers-and-hashes), [§1.5](/specification#15-core-data-structures)), so the operator cannot read a swap identifier off the incoming transfer itself. Attribution is explicit instead: with or before the payment, the user's wallet **MUST** report the payment's identity — its `coin.identifier`, or the delivery's `detect_tag`/`blob_id` — to the swap API under the swap identifier, and the operator matches the verified incoming coin against that report. A reported transfer whose quote validity has already expired belongs to no open swap, and the operator **MUST** return it to the quote's refund target (below).
- The quote request **MUST** name the user's **refund target** — a NIP-05 identifier, or an `addr_sig`-verifiable `Invoice`/kind-0 profile ([spec §4.3](/specification#43-addressing-for-delivery)) — because a zkCoins recipient never learns a sender from the transfer itself ([spec §4.2](/specification#42-bundle-delivery)) and can send only to an `addr_sig`-verified target; resolution by bare address is not supported. Every `refunded` payout and every returned late transfer goes to that target. A transfer that cannot be attributed to any open swap — no report, no matching identity — is **not returnable**: the operator cannot identify its sender. This is why a wallet pays the bridge only quote-bound, with the attribution report above.
- The operator **MUST** return the quote's stated refund amount whenever the Lightning payment fails definitively (no route, invoice expiry, or a permanent failure returned by Lightning). A definitively failed swap ends in `refunded`, never in the operator silently keeping the funds.
- The operator **MUST** apply the **per-swap** and **aggregate in-flight** caps stated in the send quote or, for receive, in its published or displayed conditions: an operator that honors those terms owes at most the stated aggregate in-flight cap at any time. The caps are **self-attested and operator-enforced** — no user can verify them from outside — so the one bound a user enforces independently is their **own per-swap stake** (*Trust model* below).

The distinction between a **definitive** and a **transient** Lightning failure governs which state a swap ends in. A transient failure (a route that timed out, a temporarily-unavailable peer) keeps the swap in `funded` while the operator retries within the quote's validity; a **definitive** failure moves it to `refunded`. Exhaustion of the quote's validity is a definitive failure **only when no payment attempt is in flight**: the swap then moves to `refunded` under the refund rule above. If an attempt **is** in flight at expiry, the operator **MUST** start no new attempts and **MUST** await that attempt's definitive resolution — an in-flight HTLC cannot be cancelled sender-side; it resolves only by preimage or by timeout, and refunding while it is pending would let a payee holding a hold invoice collect the refund and then release the preimage, taking both legs. Settlement of the awaited attempt ends the swap `settled`; its failure or HTLC timeout ends it `refunded`. Termination survives the carve-out: every Lightning HTLC resolves definitively no later than its CLTV timeout, so no swap can remain in `funded` indefinitely. Under this classification a single funded swap resolves to exactly **one** terminal state — `settled` or `refunded` — and a user can never both receive the Lightning payment and collect the refund.

## Trust model

Each swap is **custodial within its window**. Lightning settlement and zkCoins settlement are **not atomic**: between the two legs the operator — **not the protocol** — owes one side until the swap completes. On a receive, the operator owes the zkCoins delivery after the Lightning payment lands; on a send, the operator owes the Lightning payment (or the refund) after the zkCoins transfer verifies. A dishonest or insolvent operator can default on that in-flight obligation. The caps bound this honestly, not trustlessly: they are **self-attested and operator-enforced**, so an operator that honors its quote terms or published/displayed receive conditions owes at most the stated **aggregate in-flight cap** at any time, while a dishonest one can simply exceed it. The two legs carry different loss shapes. On a **send**, the user risks a **funded stake** — coins it has already transferred — bounded by what it chose to put in flight with this operator at once; that self-chosen stake is the bound a user enforces independently. On a **receive**, there is no such stake: the user's existing settled balance is untouched, and the exposure is instead an **owed-delivery default** on the value the Lightning payer put in flight, bounded — for an honest operator — only by its stated conditions.

What the bridge **cannot** do is as important as what it can:

- The bridge **service** adds no key custody — not the seed, not the SPEND branch, not the operational bundle. A user swaps by making an ordinary transfer, exactly as they would to any other address. Whether the same operator **separately** hosts an account's operational bundle as a hosted-wallet provider is an independent trust decision ([spec §6.6](/specification#66-threat-model-and-trust-configurations)), no part of the bridge service.
- It **never sees SPEND material** and **cannot spend, forge, or double-spend** a user's coins ([spec §6.1](/specification#61-components-and-responsibilities)).
- It **cannot affect settled balances**. Once a bridged coin is verified and credited, it is an ordinary zkCoins coin under the user's own custody; the bridge has no further reach into it.
- It **cannot touch non-bridged traffic** at all. Coins that never transit the bridge are entirely outside its view and its control.

This shape is a **deliberate trade-off the swapping user accepts**, in the same spirit as the wallet–node trust configurations of the specification: a sovereign user who wants no in-flight custody simply does not run and does not use a bridge, and pays or receives Lightning by other means. A user who does use one exchanges the atomicity of a pure on-chain transfer for the reach of the Lightning Network, with the quote terms or published/displayed receive conditions as the honest bound on what that reach can cost them.

The swap is custodial because it is a swap, not because zkCoins delegates anything to it. An **atomic** construction — one where the Lightning leg and the zkCoins leg either both complete or both revert with no in-flight custody — would require a **hash-time-locked transition in the core protocol**, binding a Lightning HTLC preimage to a zkCoins state transition. That construction is **out of scope for this extension**: the bridge specified here is a swap service at the edge, and its honest description is a bounded-custody one.

## Privacy

The operator learns the **Lightning counterpart, the amounts, and the timing** of the payments it bridges — this is inherent to standing between the two rails. It learns nothing about **non-bridged traffic** beyond what its separately chosen NIP-05-hosting or account-hosting roles already expose ([spec §4.3](/specification#43-addressing-for-delivery)): a coin the user sends or receives without going through the bridge is invisible to it. Running the bridge therefore widens the operator's view only over the swaps that pass through it, not over the account as a whole.

## Regulatory note

Operating a Lightning bridge is a **custodial financial service** — the operator holds value in flight across each swap window — and obtaining any licensing that service requires is the **operator's own responsibility**.

## See also

- [Mail bridge](/mail-bridge) — the independent optional operator service that makes the same NIP-05 identifier a working email address.
