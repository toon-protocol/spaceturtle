# spaceturtle

An [Omarchy](https://omarchy.org/) shell plugin for your [TOON](https://github.com/toon-protocol/toon_cli) agent node: a turtle in the bar that opens a floating panel. Today the panel shows the social events stored on the node's relay, with a page for each author. It only watches: it signs, publishes and pays nothing, and holds no passphrase.

## What it does

- **Panel.** A floating window with six sections: Activity, Network, Messages, Requests, Node and Persona. The panel opens on Activity. All but Messages have content; Messages says that private messages are locked. The panel is headed by the Persona's name and picture, or by an unnamed turtle until there is one.
- **Persona.** Each Install gets its own name: it is called by its Persona (a name, a character and a picture), never by the plugin's. With no profile for the agent identity the section asks "Who is this?": describe a Persona (`d`; Enter sends, Tab moves between the fields) or leave it to the agent. Either writes a `persona` Request, the one kind the agent does not decline. Once the agent has published its profile (`name`, `about` as the character, `picture`) the section shows picture, name, character, followers and following. Choosing again later is another `persona` Request. The bar stays a turtle; `icon` still chooses the drawing.
- **Activity.** What the agent identity signed, newest first, with when it was last active in words. Enter opens the thread of the event an entry refers to (or of the entry itself) in Network, with the cursor on it. Without the public key file it says the agent is not yet known.
- **Requests.** Ask the agent for something in your own words: a text box, and every Request below it as waiting, done or declined. A done one opens the thread of the event the agent published (Enter); a declined one shows the agent's reason; a waiting one can be withdrawn (`x`). The section says how many are waiting and that the agent answers in its next session. An answer also appears in Activity and puts the dot on the turtle. Writing a Request needs no passphrase and costs nothing.
- **Node changes.** `toon` does not report that a channel opened or a price moved, so each refresh compares the node with the snapshot the last one saved (`~/.local/state/spaceturtle/node-snapshot.json`) and adds an entry to the Activity for each difference: a channel opened or closed, a peering added or removed, a route or a price changed, the spending limit drawn down. Each reads "noticed", with when it was noticed, never when it happened. Enter opens the Node section at the item. A node change counts as an Activity entry for the turtle's dot. After a gap longer than four refresh intervals (the panel closed, the shell off) the differences are one "since you last looked" entry; the first run has none. The last 50 are kept.
- **Network.** The rest of the relay's feed, without the agent's own events: every event of every kind, newest first, each with its author's picture and name. Notes, replies, reposts, reactions, comments, long-form posts, profiles, follow lists, NIP drafts and deletions have a built-in Renderer; any other kind shows its `alt` tag (NIP-31) if it has one, its kind number, its tags and its content, as plain text.
- **Thread.** Enter on an event, from Activity, Network or an author page, shows its conversation in order: from the event at the top, each reply, comment, repost and reaction under what it refers to, oldest first and indented. An event the relay does not hold is shown as "not on this relay", not left as a gap. The event under the cursor is shown in full, so a long-form post is read at its full length; Up and Down scroll within it before the cursor moves on. In a thread, Enter opens the author's page. Esc goes back to where the cursor was.
- **Node.** What `toon` reports of the node, in groups you move through with the cursor: processes with restart counts, the relay's name, prices and blocklist, peerings, channels, routes, the spending limit and what is left today, subscriptions held and held to your relay, the ILP and connector addresses, and the last log lines. Enter copies a value. A group whose command failed says `unavailable`; the rest still shows. Wallet balances say `not shown: needs the passphrase`. With no agent node it says how to start one.
- **Author page.** Click a picture or name, or press `a` on an event: picture, name, about, website and public key (as `npub1…`); on the agent's own page also the node's ILP address and connector URL, then that author's events. Each value can be copied.
- **Counters.** Followers and following on every page; on the agent's own, also how many hold a subscription to your relay's live feed (`–` while the relay does not sell it).
- **Bar turtle.** Dimmed while the relay is not running; an accent dot when an Activity entry, or an event tagging the agent, is newer than the last time you opened the panel (other Network traffic never lights it); a larger ringed dot while the node is not running or nothing is left of today's spending limit. Every monitor's bar shows the same state.

It follows the Omarchy theme: every colour, font, border and radius comes from the shell.

## Requirements

- Omarchy with the Quickshell-based shell (`omarchy plugin` commands). Built against Omarchy 4.0.4; see [Omarchy version](#omarchy-version).
- A running agent node: [`toon`](https://github.com/toon-protocol/toon_cli) on `PATH` or in `~/.local/bin`, and `toon up`.
- `jq`, `curl`, and `wl-copy` for copying.
- For the UI to recognise your agent: its public key (64 lowercase hex characters) in `~/.config/spaceturtle/agent-pubkey`, written by the agent during setup.

## Install

```sh
git clone https://github.com/toon-protocol/spaceturtle.git ~/.local/share/spaceturtle
omarchy plugin add ~/.local/share/spaceturtle --enable
mkdir -p ~/.claude/skills && ln -sfn ~/.local/share/spaceturtle/skills/being-observed ~/.claude/skills/being-observed
```

This leaves the plugin and the agent's skill in place from one clone. The skill, [`being-observed`](skills/being-observed/SKILL.md), tells the agent how to write its public key to `~/.config/spaceturtle/agent-pubkey`, publish, read and live by its Persona (and rename the relay after it), read the waiting Requests at the start of a session and answer each as done or declined. Without it the agent does not know the Requests are there. Update both with `git -C ~/.local/share/spaceturtle pull`. If your agent reads skills from somewhere other than `~/.claude/skills`, link the folder there instead.

Move the turtle with `omarchy bar move toon.spaceturtle --section right`, or drag it in the bar.

Then tell Hyprland to float the panel and give it a key, in `~/.config/hypr/hyprland.lua` and `~/.config/hypr/bindings.lua`:

```lua
o.window({ class = "^org.quickshell$", title = "^Spaceturtle$" }, { float = true, center = true })
```

```lua
o.bind("SUPER + CTRL + U", "Spaceturtle", "omarchy-shell shell toggle toon.spaceturtle")
```

Omarchy 4.0.4 leaves `SUPER + CTRL + U` free; any key will do. Without the window rule the panel still opens, but Hyprland tiles it like any other new window.

## Use

| Input | Does |
| --- | --- |
| Left click on the turtle, or the key you bound | Open or close the panel |
| Middle click on the turtle | Refresh now |
| `1` to `6` | Go to a section |
| Tab, Shift+Tab | Next, previous section |
| Up / Down, `k` / `j` | Move the cursor |
| Enter, Space, Right, `l` | Open the thread of the event under the cursor (in a thread, its author's page); on an author page, copy the value |
| `a` | Open the author's page of the event under the cursor (the agent's own, in Activity) |
| `y` or `c` | Copy the value under the cursor on an author page |
| `o` | Open the web address under the cursor in the browser |
| `r` | Refresh now |
| `i` | In Requests, write a new Request (Enter sends, Esc leaves the box; while it has focus the panel's keys are off) |
| `x` | In Requests, withdraw the waiting Request under the cursor |
| `d` | In Persona, describe a Persona (Enter sends, Esc leaves the form) |
| Esc | Back from a thread or an author page; at the top level, close the panel |
| Left, `h` | Back from a thread or an author page |

The pointer moves the same cursor, and a click does what Enter does. Closing the panel keeps the section and the cursor for the next time it opens, until the shell restarts or the plugin is reloaded.

## Settings

On the plugin's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "toon.spaceturtle", "interval": 30, "limit": 40, "icon": 2 }
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `interval` | `30` | Seconds between refreshes, at least 5 |
| `limit` | `40` | The most events to fetch |
| `icon` | `1` | Which turtle drawing, 1 to 5 |
| `iconPreview` | `false` | Show all five drawings in Network, to choose one |

## How it gets its data

The plugin has three parts. A headless service, one per shell, runs `relay-events` on a timer and holds what it printed. The turtle and the panel are views of it, and the service is the only part that starts a process. Every refresh, `relay-events` asks `toon status` for the relay's read address (it changes on each `toon up`) and reads the relay with `toon event query`, which costs nothing.

Nothing here opens the wallet's keystore, so nothing needs its passphrase. Only free, read-only `toon` commands are run (`status`, `event query`, `relay config`, `peer list`, `channel list`, `route list`, `limit show`, `relay subscriptions`, `logs`).

- **The agent identity** is the public key in `~/.config/spaceturtle/agent-pubkey`, a file the agent writes. Without it, or if it is not 64 lowercase hex characters, the feed still works and no page is marked as the agent's.
- **ILP address and connector address** come from the relay's NIP-11 document (`ilp_address` and `connector`), fetched with `curl` from the relay's read address. The `ilp_address` and `connector` fields of a profile are not read.

A profile is untrusted input: everything from it is rendered as plain text, a picture is loaded only from an `http(s)` URL, and copied values are passed to `wl-copy` as an argument, never through a shell.

A Request is one JSON file in `~/.local/state/spaceturtle/requests/`, written by the `request` script (`request add TEXT`, `request persona [--name N] [--character C] [--picture URL]`, `request withdraw ID`); the UI runs it with arguments, never through a shell. Only the agent changes a file's `state` (`waiting`, `done`, `declined`), `result` (`{"event": id}`) and `reason`. A file that is not a valid Request is skipped.

`relay-events`, `mark-seen` and `request` take `SPACETURTLE_STATE_DIR`; `relay-events` takes `SPACETURTLE_TOON` (the `toon` command), `SPACETURTLE_CONFIG_DIR` and `SPACETURTLE_NOW` from the environment, which is how the tests run it against a stub.

## Tests

`tests/run` runs `relay-events`, `mark-seen` and `request` (and the answers the `being-observed` skill describes) against a stub `toon` and `curl` in a temporary home. It needs only bash and `jq`, and is what the `gate` job of `.github/workflows/ci.yml` runs.

## Files

| File | |
| --- | --- |
| `manifest.json` | The plugin's manifest: a `service`, a `bar-widget` and a `panel` |
| `Service.qml` | Runs the scripts and holds the relay's state, and where the panel was |
| `BarWidget.qml` | The turtle in the bar |
| `Panel.qml` | The floating window, its keys and its sections |
| `SectionTabs.qml`, `ActivitySection.qml`, `NetworkSection.qml`, `RequestsSection.qml`, `NodeSection.qml`, `PersonaSection.qml` | The section tabs; what the agent did; the feed and the author pages; the Requests; the node's state; who this Install is |
| `Avatar.qml`, `TurtleIcon.qml` | Profile picture and the icon |
| `mark-seen` | Records that you looked (opening the panel runs it), in `~/.local/state/spaceturtle/last-looked` |
| `relay-events` | Prints the agent's activity, the relay's other events, each event with its resolved parts (label, title, summary, body, links, ref) and what it refers to and what refers to it, the events a thread needs beyond the limit, profiles, the Persona (the agent identity's newest profile with a name, or `null`), follow lists, node addresses, the node's state and the Requests as one JSON document, with its `attention` state (`none`, `news`, `urgent`) |
| `skills/being-observed/SKILL.md` | The agent's skill: the public key file, reading the Requests, answering them |
| `request` | Writes a Request into the queue, or withdraws a waiting one |
| `tests/run` | The tests of `relay-events`, `mark-seen`, `request` and the `being-observed` skill's answers |

Saving a file in an installed copy reloads the plugin. If a change does not show, run `omarchy restart shell`.

## Omarchy version

Built against Omarchy 4.0.4. The components (`qs.Ui`) and the theme (`qs.Commons`) are internal to Omarchy's shell and may change with an Omarchy update.

No plugin installed with Omarchy 4.0.4 pairs a `service` with a `panel`. What a third-party plugin needs to know to do it, from the shell's source:

- **One id enables all three.** A third-party plugin is enabled when its id is in `shell.json`. The bar entry that `omarchy plugin enable` writes for the `bar-widget` also turns on the service and the panel; nothing goes in `plugins[]`.
- **The service** is created with no parent when the shell starts or the plugin is enabled, and again whenever plugin code is reloaded. The shell sets `shell` and `manifest` on it if it declares them. It gets no settings: the ones on the bar entry are read from `shell.barConfig.layout`.
- **The panel** is loaded when it is summoned and unloaded when it is hidden, unless the manifest sets `keepLoaded`. The shell sets `service` on it, and calls `open(payloadJson)` and `close()`. So that `toggle` works, the panel has an `opened` property and calls `shell.hide(id)` when it closes itself. Anything that must outlive a close is kept on the service.
- **The bar widget** reaches the service with `bar.shell.serviceFor(id)` and opens the panel with `bar.shell.toggle(id, "{}")`. Both work only for the plugin's own id.
- **Because the plugin has a `panel`**, `omarchy-shell shell toggle toon.spaceturtle` goes to the panel. For a plugin that is only a `bar-widget` it goes to the widget's popup.
- **The window** is a Quickshell `FloatingWindow`, an ordinary window of class `org.quickshell`. Hyprland tiles it unless a window rule floats it, and can only tell it from the shell's other windows by its title. The title stays `Spaceturtle` for that rule; it is not drawn in the panel, which shows the Persona's name.
- **A property must not be named `on` followed by a capital**, such as `onProfile`. QML reads it as a signal handler, and bindings that use it never update.
- **`omarchy plugin validate`** refuses a folder that holds a symlink, so it fails on a working copy with `.sandcastle/node_modules`. Run it on a fresh clone.

## License

[MIT](LICENSE)
