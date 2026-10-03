# Demo data

A made-up network for showing the panel without an agent node: seven Personas with pixel
pictures, notes and a thread, reactions, a repost, a long-form post, a NIP draft, a public
chat, a group, two sealed private messages, three Requests and a node whose state changes.
Nothing here is published anywhere.

The data goes through the plugin's own code. [`toon`](toon) stands in for the `toon`
command and answers `relay-events` from [`events.json`](events.json) and [`node/`](node/);
times are stored as seconds ago, so the demo is always recent.

## Run it

```sh
eval "$(docs/demo/start)"   # serves the pictures on 127.0.0.1:47833, prints the environment
./relay-events 40 30 | jq .
```

[`start`](start) needs `python3` for the loopback web server (a picture is loaded only
from an `http(s)` address), besides bash, `jq` and `curl`.

To see it in the panel, the shell must run `relay-events` with that environment. In an
installed copy, replace `relay-events` with a wrapper that exports the four variables
`start` printed and then runs this repository's `relay-events`; put the real file back
afterwards.

While it runs, an event written to `live-events.json` in the state folder (the folder
`start` prints as `SPACETURTLE_STATE_DIR`), as a JSON list with a real `created_at`, arrives
on the next refresh. That is how the recording in the README shows the turtle's dot appear.

## What is in it

| Path | |
| --- | --- |
| `events.json` | The events, each with `ago` in place of `created_at` |
| `www/pictures/` | The pictures, drawn on the turtle's 16x16 grid |
| `www/index.html` | The relay's NIP-11 document |
| `config/agent-pubkey` | The agent identity, Alice |
| `config/renderers/` | Renderer descriptions for the chat and group kinds (40, 42, 9, 39000) |
| `node/` | What `toon` reports of the node; a `-before` file is the state one refresh earlier |
| `requests/` | A waiting, a done and a declined Request |

The Messages section stays locked, so a private message shows only in Network, sealed, as
`kind 1059`.
