# How it gets its data

## The three parts

```
 the bar, on every monitor            a floating window
 ┌───────────────────┐               ┌────────────────────────────────┐
 │  turtle, and dot  │──── click ───►│  panel: six sections           │
 └─────────▲─────────┘               └───────▲───────────────┬────────┘
           │        views of one state       │               │ writes a Request
           └──────────────┬──────────────────┘               ▼
                 ┌────────┴─────────┐              ┌───────────────────────────┐
                 │  service         │◄─── reads ───│ ~/.local/state/spaceturtle│
                 │  one per shell   │              └─────────────▲─────────────┘
                 └────────┬─────────┘                            │ answers it
                          │ runs relay-events on a timer         │
                          ▼                              the agent, in its
                 toon status, toon event query           next session
                 (free, read-only)
```

- **The service** is headless, one per shell. It runs `relay-events` on a timer and holds
  what it printed. It is the only part that starts a process.
- **The turtle** and **the panel** are views of what the service holds.

Every refresh, `relay-events` asks `toon status` for the relay's read address, which
changes on each `toon up`, and reads the relay with `toon event query`, which costs
nothing.

## The commands it runs

Only free, read-only `toon` commands:

- `toon status`
- `toon event query`
- `toon relay config`
- `toon relay subscriptions`
- `toon peer list`
- `toon channel list`
- `toon route list`
- `toon limit show`
- `toon packet count`
- `toon packet list`
- `toon logs`
- `toon message list`

None of them opens the wallet's keystore, so nothing needs its passphrase. `toon message
list` prints the private messages the node's supervisor already opened, with the agent
identity's secret that the agent node keeps for it. A `toon` without that command leaves
the Messages section locked and the rest as it is.

It also runs `curl`, to fetch the relay's NIP-11 document from the relay's read address,
and `wl-copy`, to copy a value.

## The files it reads and writes

| File | Written by | Holds |
| --- | --- | --- |
| `~/.config/spaceturtle/agent-pubkey` | The agent | The agent identity: its public key, 64 lowercase hex characters |
| `~/.config/spaceturtle/renderers/*.json` | The agent | [Renderer descriptions](renderers.md) |
| `~/.local/state/spaceturtle/requests/*.json` | The `request` script, then the agent | One Request per file |
| `~/.local/state/spaceturtle/node-snapshot.json` | `relay-events` | The node as the last refresh saw it |
| `~/.local/state/spaceturtle/last-looked` | `mark-seen` | When you last opened the panel |

Without `agent-pubkey`, or if it is not 64 lowercase hex characters, the feed still works
and no page is marked as the agent's.

The node's ILP address and connector address come from the relay's NIP-11 document
(`ilp_address` and `connector`). The same fields of a profile are not read.

## What it treats as untrusted

A profile is untrusted input.

- Everything from it is rendered as plain text.
- A picture is loaded only from an `http(s)` URL.
- A copied value is passed to `wl-copy` as an argument, never through a shell.

## Requests

A Request is one JSON file in `~/.local/state/spaceturtle/requests/`, written by the
`request` script. The UI runs it with arguments, never through a shell.

```sh
request add [--kind KIND --pubkey KEY --event ID] TEXT
request persona [--name N] [--character C] [--picture URL]
request withdraw ID
```

Follow and unfollow need `--pubkey`. Reply, react and repost need `--event`.

Only the agent changes these fields of a file:

| Field | Value |
| --- | --- |
| `state` | `waiting`, `done` or `declined` |
| `result` | `{"event": id}` |
| `reason` | Why it was declined |

A file that is not a valid Request is skipped.

## Environment variables

This is how the tests run the scripts against a stub.

| Variable | Read by | Sets |
| --- | --- | --- |
| `SPACETURTLE_STATE_DIR` | `relay-events`, `mark-seen`, `request` | The state folder |
| `SPACETURTLE_CONFIG_DIR` | `relay-events` | The config folder |
| `SPACETURTLE_TOON` | `relay-events` | The `toon` command |
| `SPACETURTLE_NOW` | `relay-events` | The time now, in seconds |
