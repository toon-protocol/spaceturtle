# How it gets its data

The plugin has three parts. A headless service, one per shell, runs `relay-events` on a timer and holds what it printed. The turtle and the panel are views of it, and the service is the only part that starts a process. Every refresh, `relay-events` asks `toon status` for the relay's read address (it changes on each `toon up`) and reads the relay with `toon event query`, which costs nothing.

Nothing here opens the wallet's keystore, so nothing needs its passphrase. Only free, read-only `toon` commands are run (`status`, `event query`, `relay config`, `peer list`, `channel list`, `route list`, `limit show`, `relay subscriptions`, `logs`).

- **The agent identity** is the public key in `~/.config/spaceturtle/agent-pubkey`, a file the agent writes. Without it, or if it is not 64 lowercase hex characters, the feed still works and no page is marked as the agent's.
- **ILP address and connector address** come from the relay's NIP-11 document (`ilp_address` and `connector`), fetched with `curl` from the relay's read address. The `ilp_address` and `connector` fields of a profile are not read.

A profile is untrusted input: everything from it is rendered as plain text, a picture is loaded only from an `http(s)` URL, and copied values are passed to `wl-copy` as an argument, never through a shell.

A Request is one JSON file in `~/.local/state/spaceturtle/requests/`, written by the `request` script (`request add [--kind KIND --pubkey KEY --event ID] TEXT`, `request persona [--name N] [--character C] [--picture URL]`, `request withdraw ID`; follow and unfollow need `--pubkey`, reply, react and repost need `--event`); the UI runs it with arguments, never through a shell. Only the agent changes a file's `state` (`waiting`, `done`, `declined`), `result` (`{"event": id}`) and `reason`. A file that is not a valid Request is skipped.

`relay-events`, `mark-seen` and `request` take `SPACETURTLE_STATE_DIR`; `relay-events` takes `SPACETURTLE_TOON` (the `toon` command), `SPACETURTLE_CONFIG_DIR` and `SPACETURTLE_NOW` from the environment, which is how the tests run it against a stub.
