---
type: resource
status: active
area: neben
tags: [crypto, bitcoin, privacy, quelle, blockstream]
updated: 2026-04-21
---

# Blockstream Blog — Bitcoin's Shielded CSV Protocol Explained

Zurück zur [[zkCoins/quellen|Quellen & Links]]

**Quelle:** [blog.blockstream.com](https://blog.blockstream.com/bitcoins-shielded-csv-protocol-explained/)
**Autorin:** Kiara Bickers
**Datum:** 11. Dezember 2024

---

Bitcoin development today focuses on two major issues: (1) scaling and (2) privacy. The usual proposals to Bitcoin involve adding new opcodes and scripting tools. But an old idea is coming back, one that could make transactions more private and peer-to-peer. Right now, every Bitcoin transaction is broadcast to the entire network for verification. It's an effective way to prevent double-spending, but it also means more information is exposed than is strictly necessary. This leads to heavier computational demands, higher costs, and a system that struggles to scale. But what if moving part of the transaction process client-side didn't just improve efficiency, but also unlocks a whole new era of privacy on Bitcoin?

In our recently published paper, Blockstream, in collaboration with Alpen Labs and ZeroSync, we introduce the Shielded CSV Protocol, an improvement on Client-Side Validation (CSV) that offers truly private transactions. This new protocol is a significant step towards enhancing the privacy of Bitcoin transactions and has the potential to increase transaction capacity from 11 per second to over 100 per second, through some additional measures we'll cover in this blog post.

This post offers a high-level overview of the Shielded CSV Protocol, which aims to advance layer one blockchain performance while remaining fully compatible with Bitcoin. Developed by the combined minds of Jonas Nick, Liam Eagen, and Robin Linus. Here's the backstory on Shielded CSV, and why it has the potential to change everything.

## Bitcoin Then and Now

### The Double-Spend Problem: How Bitcoin Solved It

Before Bitcoin, it was widely believed that creating a reliable digital currency was impossible without a trusted middleman. The double-spend problem meant there was no way to ensure a "digital coin" couldn't be spent more than once. It was a fundamental flaw that kept digital currency from becoming a reality.

Then, in 2009, Satoshi addressed this problem by introducing the shared public ledger called the blockchain. Instead of relying on a single trusted authority, Bitcoin uses a network of nodes on a shared public ledger, where every transaction is recorded and verified. This system ensures that each coin is unique, making it impossible to spend the same coin twice.

When a Bitcoin transaction is added to the chain, it follows this process:

1. The user's wallet signs the transaction and broadcasts it to the Bitcoin network.
2. Full nodes on the network validate the transaction, ensuring everything checks out.
3. The transaction is then included in a block, confirmed, and permanently recorded in the shared public ledger.

During validation, nodes verify that the coins exist, check the validity of the signature, and enforce the critical double-spend rule -- making sure each coin is spent only once. The whole purpose of this ledger is to maintain order, showing clearly who owns which coins and when they moved.

Since its inception, Bitcoin's developers keep coming back to the same question: is this really the best and most private way to handle transactions? How can we make this system leaner, more efficient, and more private?

### A Privacy Problem: Public Transactions

Bitcoin's biggest privacy challenge is that bitcoin transactions are out there in the open on the blockchain. Satoshi saw this vulnerability from the beginning. In the original whitepaper, he suggested a straightforward solution: users should create new keys for each transaction and avoid reusing addresses.

The idea was to make it harder to link transactions back to a single owner. But in practice, with all the advanced chain analysis methods available today, maintaining privacy is much harder than it seems. Even with new addresses, linking transactions and identifying patterns has become easier for those intent on tracing user activity.

In response, privacy-focused protocols like Zcash have introduced novel ways to conceal transaction details using more advanced cryptography and things like zk-SNARKs. But these methods come with significant trade-offs: transactions are larger, making the verification process for nodes more resource-intensive and expensive to verify.

### A Communication Problem: Communication is Inefficient

In Bitcoin's design, mining serves two fundamental purposes: (1) proof-of-publication for transactions and (2) providing a consensus on the order of transactions. However, Bitcoins' system also intertwines these core functions with less essential tasks, like transaction validation and coin issuance.

Across all blockchains, whether it's Bitcoin, Ethereum, Zcash, or Dogecoin, the transaction process always looks the same: wallets sign transactions, broadcast them to the network, and full nodes validate them. But is validating every transaction directly on the blockchain really necessary?

We think there's a better way. The idea traces back to a 2013 insight, when Peter Todd first mentioned Client-Side Validation. In a mailing list post, he asked about whether a successful crypto-coin system could operate with "only proof-of-publication, and a consensus on the order of transactions." The surprising answer was yes.

Instead of requiring every full node to verify every transaction, CSV allows you to send coins with proof of their validity directly to the recipient. It means that even if a block contains an invalid transaction, full nodes won't reject it. The result? Less on-chain communication and a more efficient system overall.

### CSV: A Peer-to-Peer Scaling Solution

CSV shifts the responsibility of transaction validation from every node in the network to the individual transaction recipients. This makes Bitcoin even more peer-to-peer. Imagine if we didn't have to use the blockchain to store full transaction details. Instead of a detailed, identity-linked transaction, you'd only see a simple 64-byte nullifier, completely meaningless to anyone looking at the public record on the blockchain, but significant to the sender and recipient.

When every node is required to verify every transaction, it congests the network and slows it down. By shifting transaction validation to the client side, the amount of data stored on the blockchain can shrink significantly -- from 560 weight units (WU) on average to something approaching 64 WU, which is about 8.75 times smaller, making the system leaner and more efficient.

The compliance protocol gives Bitcoin a massive scalability boost, allowing users to process nearly 10 times more transactions -- close to 100 per second.

## Bitcoin Tomorrow

### How Does Shielded CSV Make Bitcoin More Private?

CSV protocols generally improve privacy over transparent blockchain transactions because some information is moved client-side. But in traditional CSV protocols like RGB and Taproot Assets, when a coin is sent, both the sender and receiver can view the full transaction history.

In Shielded CSV, we use zk-SNARK-like schemes to "compress" the proofs, ensuring that no transaction information is leaked. This means that the transaction history remains hidden, offering better privacy compared to existing protocols.

### What is a Nullifier, and How Does it Prevent Double-Spends?

When making a payment, the sender hands the transaction directly to the receiver. A small piece of data derived from the transaction, gets written to the blockchain which is called the nullifier.

Full nodes in the network are only required to perform a single Schnorr signature verification per Shielded CSV nullifier. The receiver checks the coin's validity and makes sure the nullifier is on the blockchain to stop any double-spending.

Other CSV protocols have nullifiers too, but in many cases they are full Bitcoin transactions, and not derived "random blobs" as we have here. Shielded CSV nullifiers make it harder to do chain analysis.

### Does Shielded CSV Require a Soft or Hard Fork?

Shielded CSV doesn't require a soft or hard fork. It works with Bitcoin as-is. CSV separates transaction validation from the consensus rules, allowing flexibility without changing the core protocol. Since Bitcoin blocks can store any type of data, different CSV protocols like RGB, Taproot Assets, or multiple versions of Shielded CSV can coexist without conflict.

Nodes don't have to reject blocks containing unfamiliar data. Instead, they only need to interpret the data on the "client-side" if it's relevant to them. By offloading transaction verification, the blockchain's primary role is reduced to: confirming transaction data in an agreed-upon order and preventing double-spends.

### Does Shielded CSV allow me to Transact in Bitcoin?

Shielded CSV operates as a separate system, using the Bitcoin blockchain to record nullifiers and prevent double-spending within the CSV protocol. But to integrate it directly with Bitcoin and allow seamless transactions, a bridging solution is still needed. The current protocol doesn't dive deeply into how bridging with BitVM could function, but this area is a development that is still under active research.

Right now, bridging is possible through the use of a trusted party or a federation, but the end goal is a fully trustless system, one that eliminates the need for any intermediaries. Achieving this would mean true, seamless interaction between Bitcoin and Shielded CSV, allowing users to enjoy enhanced privacy without compromising on the trustless values of Bitcoin. It's a complex challenge, but one that could redefine how Bitcoin scales and secures its transactions.

## Read the Full Paper

The Shielded CSV Protocol offers an approach to improving Bitcoin's scalability and privacy, potentially bringing in a new era of more efficient, peer-to-peer transactions. By offloading transaction validation to the client side, it significantly reduces on-chain data, allowing for greater transaction throughput and enhanced privacy -- all without requiring a hard or soft fork. If you're curious to read more about how this protocol works and the trade-offs involved, the full paper, "Shielded CSV: Private and Efficient Client-Side Validation," is available for those seeking deeper technical understanding.

*Note: an earlier version of this article was first published in Bitcoin Magazine*
