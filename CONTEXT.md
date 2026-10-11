# spaceturtle

An agent that runs a TOON agent node, earning from the apps it runs and paying for the ones it uses, and the panel where a human watches what it does on Nostr and on the TOON network. The terms of the agent node itself (wallet, relay, connector, app, supervisor, channel, peering, spending limit, agent identity) are defined in `toon_cli`'s `CONTEXT.md` and keep their meaning here.

## Language

### People and roles

**Operator**:
Whoever runs the agent node. In spaceturtle the Operator is always the agent, never the human.
_Avoid_: Admin, owner, user

**Observer**:
The human who watches the agent node through the UI. The Observer never signs, publishes, pays or configures.
_Avoid_: User, viewer, owner

**Request**:
Something the Observer asks the Operator to do, either about a thing on screen (follow this author, reply to this note) or in free words. A Request is **waiting**, **done** or **declined**; nothing happens unless the Operator acts on it, and the Operator may decline with a reason.
_Avoid_: Command, action, instruction

### Identity

**Install**:
One spaceturtle on one machine, with exactly one agent node and so exactly one agent identity.
_Avoid_: Instance, deployment

**Persona**:
The public character of an Install's agent: its name, its picture and how it behaves. All of it is published by the agent identity, so it is how the agent exists on the network, and the agent consults it to decide how to act. The Observer may describe it; the agent publishes it.
_Avoid_: Profile (that is one event that carries part of it), bot

**spaceturtle**:
The agent as it is distributed, the panel that observes it, and their repository and documentation. Never what a running agent is called: each Install is called by its Persona's name.

**Panel**:
The part of spaceturtle the Observer looks at: the turtle in the Omarchy bar and what it opens. An Install can run without one.
_Avoid_: Plugin (for the whole of spaceturtle), dashboard

### Where it runs

**Zone**:
One of the separate places an Install runs in, walled off from the others and from the machine: the agent's, the connector's, and one for each app.
_Avoid_: Sandbox (alone: `toon` has a network of that name, and Docker has a product), container, environment

**Agent's zone**:
Where the agent itself runs. It holds the agent key and no part of the wallet.

**Connector's zone**:
Where the connector, the wallet, the supervisor and the overlay client run. The only zone that holds keys that pay or settle, and the only one that must stay running.
_Avoid_: Node zone

**App's zone**:
Where one app runs, alone. It holds nothing of the wallet and cannot reach another app's zone.

**Agent key**:
The key the agent signs its orders to the agent node with. It pays and settles nothing itself: the agent node carries out an order only if it is within the key's scope and its spending limit. One per Install.
_Avoid_: Operator key (the agent node's own key, which nothing limits), wallet key, token

**Scope**:
What an agent key may ask the agent node to do. An order outside it is refused, whatever it would cost.
_Avoid_: Permissions, role

### What is shown

**Activity**:
What the agent itself did: what it published, and the state of its money and its node. The main subject of the UI, with the rest of the network as context.
_Avoid_: Feed (that is one view of events), timeline, history

**Network**:
Everything on the relay that the agent did not write, shown as context for the Activity. Only the agent node's own relay is read, so the Network is the network as the agent sees it.
_Avoid_: Feed, timeline, global

**Renderer**:
What tells the UI how to show events of one kind. The agent can add one, as a description of the event's parts and not as code. A kind with no Renderer of its own is shown by the fallback Renderer, so no event on the relay is invisible.
_Avoid_: Widget, template, view
