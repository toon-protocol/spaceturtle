# The launcher

Every command of the launcher, and what it changes. Each one that uses a zone stops first,
and says why, when KVM or a signed-in `sbx` is missing.

`spaceturtle start` brings up the connector's zone on devnet: a detached Docker Sandboxes
virtual machine made from the connector's zone image
(`ghcr.io/toon-protocol/spaceturtle-connector-zone:latest`, or `SPACETURTLE_CONNECTOR_IMAGE`),
which holds the pinned `toon`; nothing is copied into it from your machine. It has an any-address rule scoped to that zone alone, the agent node
initialised inside it, the wallet funded from the faucet, the agent key made, the supervisor started (the image's `connector-start`, which also starts the container engine for the apps), and a
sealed backup of the wallet written to `~/spaceturtle-backup` (`SPACETURTLE_BACKUP_DIR`).
Keep that backup. The passphrase is made inside the zone; it is never printed and never written to your
machine's disk, and `upgrade` carries it in memory to the new zone. A second run
creates, initialises and funds nothing, and an interrupted run finishes the rest. It needs
KVM and a signed-in `sbx`, and says what is missing and how to fix it before it does
anything. The wallet's storage is `~/.local/share/spaceturtle/wallet` (`SPACETURTLE_DATA_DIR`),
mounted into the zone and outside its image. It is the whole of `toon`'s home, so it also
holds the agent identity's secret; the passphrase that opens the wallet is not in it.

Docker Sandboxes stops a zone 30 seconds after the last command attached to it ends, and
nothing starts its daemon when your machine does. So `start` writes and enables a systemd
user unit, `spaceturtle-connector.service`, which starts the daemon, holds one session open
in the zone with the supervisor in it (`spaceturtle supervise`), and is started again
whenever that session ends. That is what brings the zone back after the machine restarts.
A user unit runs once you log in, or at boot if your user lingers
(`loginctl enable-linger`). `journalctl --user -u spaceturtle-connector` shows the
supervisor's output.

`start` leaves your machine's `sbx` policy as it is, and initialises it as `balanced` only
when there is none. It publishes two ports of the connector's zone on your machine's
loopback, `47100` and `47101` (`SPACETURTLE_CONNECTOR_PORT` names the first): the
supervisor's orders and the relay TOON app's connector, which is all the agent's zone
reaches of the node. An app whose image is not on `toon`'s list of trusted images runs under
gVisor: `start` writes `runsc` to the home's `untrusted-runtime`.

`spaceturtle mainnet [--keep-limit]` moves a devnet Install to mainnet. It says that real
funds are now at stake, that there is no faucet, and which wallet addresses to fund, then
asks you to type `mainnet`; anything else changes nothing. It lowers the spending limit to
the mainnet default unless you pass `--keep-limit`. On an Install already on mainnet it says
so and changes nothing. It runs `toon wallet show`, `toon network set mainnet` and
`toon limit set --network-default` in the connector's zone. **`toon` 0.2.0 has neither of
the last two**, so today the command stops at "toon could not move the node to mainnet" and
changes nothing: an Install stays on devnet.

`spaceturtle session` starts a `docker-agent` session in the agent's zone, which is made
from the agent's zone image (`SPACETURTLE_AGENT_IMAGE`), on a copy of
`agent/spaceturtle.yaml` that the zone mounts read-only. The launcher allows the zone three
things by rules that name it: the model provider's host, the host of the connector of the
node's network (a packet for an app behind that connector is sealed to it), and the two
loopback ports that lead to the connector's zone. Your machine's own `sbx` policy applies on
top: `balanced` lets every sandbox reach a list of common hosts, and `sbx policy reset`
followed by `sbx policy init deny-all` leaves the zone those three things alone. No session
starts while the connector's zone is not running. The model key is yours: put it in
`~/.config/spaceturtle-launcher/model-key` (`SPACETURTLE_MODEL_KEY_FILE`) or run
`spaceturtle key`. It is given to the session as an environment variable, never as an
argument, and sits outside every directory the agent may read. Without it the launcher stops
and says so.

A session by hand is a conversation, and `docker-agent` asks you before a tool runs. An
unattended one has nobody to ask, so every tool the definition offers runs unasked; the
definition's tools, the agent key's scope and its spending limit are what bound it.

- `spaceturtle key` reads the model key from the terminal, without showing it, and writes
  it to `~/.config/spaceturtle-launcher/model-key`, readable by you alone.
- `spaceturtle set model <provider/model>` changes the model. The launcher knows
  `anthropic`, `openai`, `google` and `mistral`, whose key file holds an API key, and
  `chatgpt`, a ChatGPT account in place of an API key: its key file holds the account's
  access token (`docker agent setup` signs in and keeps it as `access_token` in
  `~/.config/cagent/chatgpt-auth.json`), which runs out after some days.
- `spaceturtle timer on|off|interval <N>m|h|d` controls the timer, which starts a session
  with nobody present (`spaceturtle session --unattended`). `start` turns it on, every 6h,
  unless you turned it off. The interval counts from when the timer starts, so the first
  session comes one interval after `start`.
- `spaceturtle set ceiling <dollars>` sets the ceiling on model cost of one unattended
  session (default 1). It is `docker-agent`'s `budget`, written into the session's copy of
  the definition, and the session stops when it is reached. `docker-agent` can only count
  the cost of a model it knows the price of: a session on a ChatGPT account costs it
  nothing, so there the ceiling never stops one.
- `spaceturtle status` shows the timer, its interval and the last unattended session's time,
  and for each of the connector's zone (`running`, `stopped` or `not created`), the agent's
  zone (`in a session` or `idle`) and every app the node has, whether it runs; then the
  node's network and whether its relay answers from inside the connector's zone. While the
  connector's zone is stopped or not created it says those cannot be read, and still exits 0.
- `spaceturtle stop` stops the timer's unit (its on/off setting stays), a session in the
  agent's zone, the unit that keeps the connector's zone running and then that zone, and
  loses nothing; `start` brings it back without creating, initialising or funding anything.
  A stopped Install stays stopped when the machine restarts. With no zone it says there is
  nothing to stop.
- `spaceturtle upgrade` replaces the connector's zone with one from the newest connector's
  zone image and leaves the wallet's storage as it was. It makes a fresh backup first and
  stops, changing nothing, if that fails or if the passphrase cannot be read out of the old
  zone. The passphrase goes from the old zone to the new one through the standard input and
  output of `sbx exec`, in the launcher's memory only. `toon init` and the faucet do not run
  again. The agent's zone is removed too, so the next `session` uses the newest agent's zone
  image; what the agent kept in that zone goes with it, and it gets a new agent key.
- `spaceturtle backup` writes a fresh sealed backup to `~/spaceturtle-backup` and says where;
  the backup already there is replaced only once the new one has arrived whole. It needs the
  connector's zone running.
- `spaceturtle remove [--delete-wallet]` offers a fresh backup (the passphrase goes with the
  zone), then removes both zones, the timer's units and the unit that keeps the connector's
  zone running, the step markers, the settings and the model key. It keeps the wallet's storage and the backup directory and says where they are.
  `--delete-wallet` also deletes the wallet's storage, and only after you type `delete`;
  anything else, or no input, changes nothing. Nothing ever deletes the backup directory.

The agent may ask to add an app whose image is not TOON's own, and the agent node holds it
until you approve it. These commands run `toon` with the home in the zone, and the agent has
no tool for any of them:

| Command | What it does |
| --- | --- |
| `spaceturtle waiting` | Lists each waiting app with its image or URL, and how long it has waited when `toon` says (0.2.0 does not, so it reads `unknown`) |
| `spaceturtle approve <app>` | Starts it; an image that is not TOON's own runs under the sandboxed runtime |
| `spaceturtle refuse <app> [reason]` | Discards it |
| `spaceturtle status` | Also says whether the supervisor is running and how many apps are waiting |
| `spaceturtle agent-key show` | The agent key's scope, limits and what is left today; never the private half |
| `spaceturtle agent-key replace` | Makes a new key, revokes the old one, places the new private half in the agent's zone; the wallet is untouched |
| `spaceturtle agent-key revoke` | Removes the key from the agent node's list and deletes its private half from the agent's zone; the agent's next order is refused |
| `spaceturtle agent-key limit <amount>` | Sets what the key may spend in a UTC day, in the token's base units (`5000000` is 5 USDC), and brings what one command may pay down to it if that was more; the agent has no tool for it |

`start` makes exactly one agent key, with the default scope (ADR 0003) and the default spending
limit. Its private half goes from the connector's zone to the agent's zone through a pipe, and
is kept nowhere else. On the way in, the two addresses in the key file become the two ports of
your machine that lead to the connector's zone. A second `start` makes none, and neither does
`upgrade` after a revoke.

With an agent key `toon` 0.2.0 reads status and the connector's log, sends packets, adds a
peering, sets a route's price, adds and removes apps, publishes events, reads and sends
private messages and shows the limit. It does not yet write a route, remove a peering, fund
a channel, land vouchers or query a relay with one, so the agent has no tool for those and
you do them: `sbx exec -e TOON_PASSPHRASE_FILE=/home/agent/.config/toon-passphrase st-connector toon route add ...`.

Approving or refusing an app that is not waiting says so and changes nothing. The list is
read from the `pending_apps` of `toon status --json`.
