# spaceturtle

An [Omarchy](https://omarchy.org/) shell plugin for your [TOON](https://github.com/toon-protocol/toon_cli) agent node: a turtle in the bar that opens a floating panel. Today the panel shows the social events stored on the node's relay, with a page for each author.

## What it does

- **Panel.** A floating window with six sections: Activity, Network, Messages, Requests, Node and Persona. Only Network has content so far; Messages says that private messages are locked.
- **Network.** Notes, replies, reposts, reactions, comments and long-form posts from the relay, newest first, each with its author's picture and name.
- **Author page.** Open an event: picture, name, about, website, ILP address, connector URL and public key (as `npub1…`), then that author's events. Each value can be copied.
- **Follow.** On someone else's page, a button adds them to or removes them from your agent identity's follow list (NIP-02, kind 3) on your relay.
- **Counters.** Followers and following on every page; on your own, also how many hold a subscription to your relay's live feed (`–` while the relay does not sell it).
- **Bar turtle.** Dimmed while the relay is not running; an accent dot when events arrived since you last looked. Every monitor's bar shows the same state.

It follows the Omarchy theme: every colour, font, border and radius comes from the shell.

## Requirements

- Omarchy with the Quickshell-based shell (`omarchy plugin` commands). Built against Omarchy 4.0.4; see [Omarchy version](#omarchy-version).
- A running agent node: [`toon`](https://github.com/toon-protocol/toon_cli) on `PATH` or in `~/.local/bin`, and `toon up`.
- `jq`, and `wl-copy` for copying.

## Install

```sh
omarchy plugin add https://github.com/toon-protocol/spaceturtle.git --enable
```

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
| Enter, Space, Right, `l` | Open the author of the event under the cursor; on an author page, copy the value or press Follow |
| `o` | Open the web address under the cursor in the browser |
| `r` | Refresh now |
| Esc | Back from an author page; at the top level, close the panel |
| Left, `h` | Back from an author page |

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

Two things open the wallet's keystore, and so need its passphrase:

- reading your agent identity's public key, once; it is then cached in `~/.cache/spaceturtle/identity`,
- publishing your follow list when you press Follow.

The scripts use `TOON_PASSPHRASE_FILE` or `TOON_PASSPHRASE` if the shell's environment has one, and otherwise fall back to `~/.config/toon/passphrase`, the path the `toon` guide suggests. Without a passphrase the feed still works; your own profile is not recognised and there is no Follow button.

A profile is untrusted input: everything from it is rendered as plain text, a picture is loaded only from an `http(s)` URL, and copied values are passed to `wl-copy` as an argument, never through a shell.

`ILP` and `Node` on an author page come from two fields that are not part of NIP-01, `ilp_address` and `connector`, which a TOON agent node may put in its kind 0 profile to say where it is paid.

## Files

| File | |
| --- | --- |
| `manifest.json` | The plugin's manifest: a `service`, a `bar-widget` and a `panel` |
| `Service.qml` | Runs the scripts and holds the relay's state, and where the panel was |
| `BarWidget.qml` | The turtle in the bar |
| `Panel.qml` | The floating window, its keys and its sections |
| `SectionTabs.qml`, `NetworkSection.qml` | The section tabs; the feed and the author pages |
| `Avatar.qml`, `TurtleIcon.qml` | Profile picture and the icon |
| `relay-events` | Prints the relay's events, profiles and follow lists as one JSON document |
| `relay-follow` | Adds a key to, or removes it from, the follow list |
| `relay-lib` | Shared by the two scripts |

Saving a file in an installed copy reloads the plugin. If a change does not show, run `omarchy restart shell`.

## Omarchy version

Built against Omarchy 4.0.4. The components (`qs.Ui`) and the theme (`qs.Commons`) are internal to Omarchy's shell and may change with an Omarchy update.

No plugin installed with Omarchy 4.0.4 pairs a `service` with a `panel`. What a third-party plugin needs to know to do it, from the shell's source:

- **One id enables all three.** A third-party plugin is enabled when its id is in `shell.json`. The bar entry that `omarchy plugin enable` writes for the `bar-widget` also turns on the service and the panel; nothing goes in `plugins[]`.
- **The service** is created with no parent when the shell starts or the plugin is enabled, and again whenever plugin code is reloaded. The shell sets `shell` and `manifest` on it if it declares them. It gets no settings: the ones on the bar entry are read from `shell.barConfig.layout`.
- **The panel** is loaded when it is summoned and unloaded when it is hidden, unless the manifest sets `keepLoaded`. The shell sets `service` on it, and calls `open(payloadJson)` and `close()`. So that `toggle` works, the panel has an `opened` property and calls `shell.hide(id)` when it closes itself. Anything that must outlive a close is kept on the service.
- **The bar widget** reaches the service with `bar.shell.serviceFor(id)` and opens the panel with `bar.shell.toggle(id, "{}")`. Both work only for the plugin's own id.
- **Because the plugin has a `panel`**, `omarchy-shell shell toggle toon.spaceturtle` goes to the panel. For a plugin that is only a `bar-widget` it goes to the widget's popup.
- **The window** is a Quickshell `FloatingWindow`, an ordinary window of class `org.quickshell`. Hyprland tiles it unless a window rule floats it, and can only tell it from the shell's other windows by its title.
- **A property must not be named `on` followed by a capital**, such as `onProfile`. QML reads it as a signal handler, and bindings that use it never update.
- **`omarchy plugin validate`** refuses a folder that holds a symlink, so it fails on a working copy with `.sandcastle/node_modules`. Run it on a fresh clone.

## License

[MIT](LICENSE)
