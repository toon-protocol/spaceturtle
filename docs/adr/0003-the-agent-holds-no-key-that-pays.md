# The agent holds no key that pays

spaceturtle is distributed as an agent for `docker-agent`, and an agent that reads notes from strangers and may add any image as an app must not sit beside the wallet. So an Install runs in three kinds of zone: the agent's, the connector's, and one for each app. The agent holds only an agent key. It signs each order with it, and the agent node carries the order out, with keys the agent never sees, only if the order is within that key's scope and spending limit. The Observer creates, changes and revokes the agent key from outside the agent's zone.

The scope lets the agent do a provider's daily work: send packets, add and remove peerings, write routes, fund a channel it already has, land vouchers, add and remove apps, set prices, read status and logs, and publish events, which the supervisor signs with the agent identity. It does not let the agent withdraw a channel or open one toward a counterparty of its choosing, and an app whose image is not TOON's own waits for the Observer to approve it.

## Considered Options

- **One zone for everything.** Rejected: the agent is kept from the keys only by its list of tools, and one escaped app reaches the wallet.
- **A server of our own in front of `toon`.** Rejected: it would enforce the spending limit in a third place and have to follow every change to `toon`. The connector's operator surface already takes signed orders from listed keys; it lacks only a scope and a limit for each key.
- **`toon-client` with a small wallet for the agent.** Rejected as the way to its own agent node: it only sends packets, it puts a key that pays in the agent's zone, and the agent would pay its own connector for what an operator does free. It stays the right tool for an agent with no agent node.
- **A token instead of a signature.** Rejected: the connector's rule is that a token never moves value, because a token cannot say who acted and cannot be revoked for one holder.
- **A zone per app as its own virtual machine.** Rejected: Docker Sandboxes cannot run an image as its workload on a local machine and its sandboxes cannot reach each other. Each app is a hardened container, under a sandboxed runtime when the image is not TOON's own.
- **Building on `hermes-agent`.** Rejected: it is a second runtime to support, not a way to distribute, and its review pass edits skills in place.

## Consequences

- This cannot ship until the connector gives each write key a scope and a spending limit, and `toon` can be operated from another zone and runs apps hardened. Those are changes to `connector` and `toon_cli`, not to this repository.
- The spending limit moves from a file `toon` checks to the connector, which holds the money.
- Only the connector's zone must stay running. The agent runs in sessions and on a timer, so `docker-agent`'s own sandbox serves it unchanged.
- The connector's zone is a virtual machine, which needs KVM on every machine that runs spaceturtle. A machine without KVM needs another form of that zone. It was first a Docker Sandboxes virtual machine, which also needed a Docker account; ADR 0004 replaces that.
- Whoever breaks into the connector's zone holds everything in the settlement addresses and channels. The wallet is funded with little, on devnet first.
- ADR 0001 stands: the panel still never acts. The panel reading an agent node inside a zone is not designed yet.
