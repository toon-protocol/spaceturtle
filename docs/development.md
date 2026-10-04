# Developing spaceturtle

[`CLAUDE.md`](../CLAUDE.md) describes how the repository is worked on, including by the AFK factory.

## Tests

`tests/run` runs `relay-events` (with its Renderer descriptions), `mark-seen` and `request` (and the answers the `being-observed` skill describes) against a stub `toon` and `curl` in a temporary home. It needs only bash and `jq`, and is what the `gate` job of `.github/workflows/ci.yml` runs.

## Demo data

[`docs/demo/`](demo/README.md) holds a made-up network and a stand-in `toon`, for showing the panel
without an agent node.

## Files

| File | |
| --- | --- |
| `manifest.json` | The plugin's manifest: a `service`, a `bar-widget` and a `panel` |
| `Service.qml` | Runs the scripts and holds the relay's state, and where the panel was |
| `BarWidget.qml` | The turtle in the bar |
| `Panel.qml` | The floating window, its keys and its sections |
| `SectionTabs.qml`, `ActivitySection.qml`, `NetworkSection.qml`, `MessagesSection.qml`, `RequestsSection.qml`, `NodeSection.qml`, `PersonaSection.qml` | The section tabs; what the agent did; the feed and the author pages; the agent's private conversations; the Requests; the node's state; who this Install is |
| `Avatar.qml`, `MediaStrip.qml`, `EventExtras.qml`, `TurtleIcon.qml` | Profile picture; an event's pictures, videos and sounds; the badge, fields, list, progress and actions a Renderer lays out; the icon |
| `mark-seen` | Records that you looked (opening the panel runs it), in `~/.local/state/spaceturtle/last-looked` |
| `relay-events` | Prints the agent's activity, the relay's other events, each event with its resolved parts (label, title, summary, body, links, ref) and what it refers to and what refers to it, the events a thread needs beyond the limit, profiles, the Persona (the agent identity's newest profile with a name, or `null`), follow lists, node addresses, the node's state, the Requests and the agent's private messages (grouped into conversations, or why they cannot be read) as one JSON document, with its `attention` state (`none`, `news`, `urgent`) |
| `skills/being-observed/SKILL.md` | The agent's skill: the public key file, the Persona (creating, reading and living by it, renaming the relay), reading the Requests, answering them, writing a Renderer for a kind |
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
