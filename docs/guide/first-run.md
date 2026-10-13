# The first run

## Before you start

Have these ready. You need no account anywhere to install or run spaceturtle; the model
provider's key is the only thing that is not on your machine already. `spaceturtle start`
checks the first of these before anything else and stops, changing nothing, when it is
missing:

- **A Linux machine with KVM** (`/dev/kvm`) that you may use. A zone is a virtual machine.
  If `/dev/kvm` is there but not yours to use, `sudo usermod -aG kvm $USER`, then sign out
  and in again.
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

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/toon-protocol/spaceturtle/main/install.sh | bash
```

[`install.sh`](../../install.sh) needs no root and no account. It first checks the machine
(Linux on x86_64 with glibc, KVM you may use, systemd, `curl`, `jq`, `tar`) and installs
nothing if something is missing. Then it:

- puts the launcher and the agent definition of the latest release in
  `~/.local/share/spaceturtle/launcher`, and links `spaceturtle` into `~/.local/bin`;
- puts [microsandbox](https://github.com/superradcompany/microsandbox), which the zones run
  in, in `~/.local/share/spaceturtle/microsandbox`, at the version the launcher is tested
  with and checked against its checksum. It is a program and a library in that directory,
  and nothing else of your machine is changed;
- says what to run next. It starts nothing.

The launcher it installs pulls the zone images of that same release. Run it again to move to
the newest release, then `spaceturtle upgrade`. `SPACETURTLE_VERSION=v0.2.0` installs that
release instead.

To work from a clone instead, run `install.sh` once for microsandbox, then put the clone's
[`spaceturtle`](../../spaceturtle) on your `PATH`, by its directory or by a link; it then
pulls the `latest` images.

## The first run

```sh
spaceturtle start
```

On devnet, it:

1. makes the connector's zone, a virtual machine from the connector's zone image, with
   nothing copied in from your machine;
2. initialises the agent node inside it, makes the wallet and funds it from the devnet
   faucet;
3. makes the agent key, with the default scope and spending limit, and places its private
   half in the agent's zone;
4. starts the supervisor, which runs the node's apps, in a systemd user unit that starts it
   again if it ends and brings the zone back after a restart;
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
