# The first run

## Before you start

Have these ready. `spaceturtle start` checks the first two before anything else and stops,
changing nothing, when one is missing:

- **A machine with KVM** (`/dev/kvm`). The connector's zone is a virtual machine.
- **A Docker account, signed in to Docker Sandboxes** (`sbx`). Install
  [`sbx`](https://github.com/docker/sbx-releases), then run `sbx login` and
  `sbx daemon start -d`.
- **`docker-agent`** needs no install of its own: it runs inside the agent's zone.
- **systemd**, for two user units: the one that keeps the connector's zone running, and
  the timer. To have the Install back after a restart without logging in, let your user
  linger: `loginctl enable-linger`.
- **A model provider's key**, which is yours alone. Put it in
  `~/.config/spaceturtle-launcher/model-key` or run `spaceturtle key` after the first run.
  A ChatGPT account serves too: see `set model` in [The launcher](launcher.md).
- **`bash`, `jq` and `curl`.**
- **A little money in mind.** The first run is on devnet and costs nothing. Mainnet is real
  money: read [How the money is kept safe](concepts.md#how-the-money-is-kept-safe)
  first. The network is `start`'s flags: see [The network](launcher.md#the-network).

The launcher is the file [`spaceturtle`](../../spaceturtle) in this repository. Clone the
repository once and put that file on your `PATH`.

## The first run

```sh
spaceturtle start
```

On devnet, it:

1. makes the connector's zone, a detached Docker Sandboxes virtual machine from the
   connector's zone image, with nothing copied in from your machine;
2. initialises the agent node inside it, makes the wallet and funds it from the devnet
   faucet;
3. makes the agent key, with the default scope and spending limit, and places its private
   half in the agent's zone;
4. starts the supervisor, which runs the node's apps, in a systemd user unit that keeps
   the zone running and brings it back after a restart;
5. writes a sealed backup of the wallet to `~/spaceturtle-backup`. **Keep it.**
6. turns on the timer, which starts a session every 6 hours (`spaceturtle timer off` turns
   it off).

It is safe to run again: a second run creates, initialises and funds nothing, and an
interrupted run finishes the rest. The passphrase is made inside the zone and is never
printed and never written to your machine's disk.

Then give it its model key and start a session by hand with `spaceturtle session`.

The wallet is funded with the devnet token and no gas. To pay an app on another connector
the node must open a channel, which is a transaction: send a little Base Sepolia ETH, from
a public faucet, to the EVM address `toon wallet show` prints in the connector's zone.
