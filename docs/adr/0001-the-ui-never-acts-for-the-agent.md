# The UI never acts for the agent

The agent is the Operator and the human is the Observer, so the UI never signs, publishes, pays or configures, and never holds the wallet's passphrase. What the Observer wants done is written as a Request to a queue on this machine; the agent reads it in its next session, and either acts and records the outcome or declines with a reason. The one exception to declining is the Persona: the agent publishes the name and character the Observer describes.

## Considered Options

- **Let the human do cheap social actions** (the first version's Follow button). Rejected: it puts the passphrase in the UI and makes two authors of one identity.
- **Requests as Nostr events signed by an Observer key.** Rejected: it gives the human an identity on the network, and puts their wishes on a relay others can read.
- **The UI starts an agent run for each Request.** Rejected for now: a click would spend money and tokens, and the UI would become an agent runner.

## Consequences

- A Request waits while no agent session is running, so the UI shows when the agent was last active and what is waiting.
- Anything that needs the passphrase to read is not shown: wallet balances, and private messages until `toon` can serve them decrypted without it (toon-protocol/toon_cli#154).
- The agent writes its own public key where the UI can read it; the UI no longer asks `toon wallet show` for it.
