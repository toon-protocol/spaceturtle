# The launcher

Every command of the launcher, and what it changes. Each one that uses a zone stops first,
and says why, when KVM or a signed-in `sbx` is missing.

`spaceturtle start` brings up the connector's zone on devnet: a detached Docker Sandboxes
virtual machine made from the connector's zone image
(`ghcr.io/toon-protocol/spaceturtle-connector-zone:latest`, or `SPACETURTLE_CONNECTOR_IMAGE`),
which holds the pinned `toon`; nothing is copied into it from your machine. It has an any-address rule scoped to that zone alone, the agent node
initialised inside it, the wallet funded from the faucet, the supervisor started (the image's `connector-start`, which also starts the container engine for the apps), and a
sealed backup of the wallet written to `~/spaceturtle-backup` (`SPACETURTLE_BACKUP_DIR`).
Keep that backup. The passphrase is made inside the zone; it is never printed and never written to your
machine's disk, and `upgrade` carries it in memory to the new zone. A second run
creates, initialises and funds nothing, and an interrupted run finishes the rest. It needs
KVM and a signed-in `sbx`, and says what is missing and how to fix it before it does
anything. The wallet's storage is `~/.local/share/spaceturtle/wallet` (`SPACETURTLE_DATA_DIR`),
mounted into the zone and outside its image.

`spaceturtle mainnet [--keep-limit]` moves a devnet Install to mainnet. It says that real
funds are now at stake, that there is no faucet, and which wallet addresses to fund, then
asks you to type `mainnet`; anything else changes nothing. It lowers the spending limit to
the mainnet default unless you pass `--keep-limit`. On an Install already on mainnet it says
so and changes nothing. It runs `toon status --json`, `toon wallet addresses`,
`toon network set mainnet` and `toon limit set --network-default` in the connector's zone.

`spaceturtle session` starts a `docker-agent` session in the agent's zone, from the agent's
zone image (`SPACETURTLE_AGENT_IMAGE`) and `agent/spaceturtle.yaml`. The zone may reach the
model provider and one loopback port, the one that leads to the connector's zone
(`SPACETURTLE_CONNECTOR_PORT`), and nothing else. No session starts while the connector's
zone is not running. The model key is yours: put it in
`~/.config/spaceturtle-launcher/model-key` (`SPACETURTLE_MODEL_KEY_FILE`) or run
`spaceturtle key`. It is given to the session as an environment variable, never as an
argument, and sits outside every directory the agent may read. Without it the launcher stops
and says so.

- `spaceturtle key` reads the model key from the terminal, without showing it, and writes
  it to `~/.config/spaceturtle-launcher/model-key`, readable by you alone.
- `spaceturtle set model <provider/model>` changes the model.
- `spaceturtle timer on|off|interval <N>m|h|d` controls the timer, which starts a session
  with nobody present (`spaceturtle session --unattended`). `start` turns it on, every 6h,
  unless you turned it off.
- `spaceturtle set ceiling <dollars>` sets the ceiling on model cost of one unattended
  session (default 1).
- `spaceturtle status` shows the timer, its interval and the last unattended session's time,
  and for each of the connector's zone (`running`, `stopped` or `not created`), the agent's
  zone (`in a session` or `idle`) and every app the node has, whether it runs; then the
  node's network and whether its relay answers from inside the connector's zone. While the
  connector's zone is stopped or not created it says those cannot be read, and still exits 0.
- `spaceturtle stop` stops the timer's unit (its on/off setting stays), a session in the
  agent's zone and then the connector's zone, and loses nothing; `start` brings it back
  without creating, initialising or funding anything. With no zone it says there is nothing
  to stop.
- `spaceturtle upgrade` replaces the connector's zone with one from the newest connector's
  zone image and leaves the wallet's storage as it was. It makes a fresh backup first and
  stops, changing nothing, if that fails or if the passphrase cannot be read out of the old
  zone. The passphrase goes from the old zone to the new one through the standard input and
  output of `sbx exec`, in the launcher's memory only. `toon init` and the faucet do not run
  again. The agent's zone is removed too, so the next `session` uses the newest agent's zone
  image.
- `spaceturtle backup` writes a fresh sealed backup to `~/spaceturtle-backup` and says where;
  the backup already there is replaced only once the new one has arrived whole. It needs the
  connector's zone running.
- `spaceturtle remove [--delete-wallet]` offers a fresh backup (the passphrase goes with the
  zone), then removes both zones, the timer's units, the step markers, the settings and the
  model key. It keeps the wallet's storage and the backup directory and says where they are.
  `--delete-wallet` also deletes the wallet's storage, and only after you type `delete`;
  anything else, or no input, changes nothing. Nothing ever deletes the backup directory.

The agent may ask to add an app whose image is not TOON's own, and the agent node holds it
until you approve it. These commands run `toon` with the home in the zone, and the agent has
no tool for any of them:

| Command | What it does |
| --- | --- |
| `spaceturtle waiting` | Lists each waiting app with its image and how long it has waited |
| `spaceturtle approve <app>` | Starts it; an image that is not TOON's own runs under the sandboxed runtime |
| `spaceturtle refuse <app> [reason]` | Discards it |
| `spaceturtle status` | Also says whether the supervisor is running and how many apps are waiting |
| `spaceturtle agent-key show` | The agent key's scope, limits and what is left today; never the private half |
| `spaceturtle agent-key replace` | Makes a new key, revokes the old one, places the new private half in the agent's zone; the wallet is untouched |
| `spaceturtle agent-key revoke` | Removes the key from the agent node's list and deletes its private half from the agent's zone; the agent's next order is refused |
| `spaceturtle agent-key limit <amount>` | Sets the key's spending limit; the agent has no tool for it |

`start` makes exactly one agent key, with the default scope (ADR 0003) and the default spending
limit. Its private half goes from the connector's zone to the agent's zone through a pipe, and
is kept nowhere else. A second `start` makes none, and neither does `upgrade` after a revoke.

Approving or refusing an app that is not waiting says so and changes nothing. The list is
read from the apps `toon status --json` reports as `pending`.
