# Developing spaceturtle

[`CLAUDE.md`](../CLAUDE.md) describes how the repository is worked on, including by the AFK factory.

## Tests

`tests/run` runs `relay-events` (with its Renderer descriptions), `mark-seen` and `request` (and the answers the `being-observed` skill describes) against a stub `toon` and `curl`, and the launcher's `spaceturtle start`, `stop`, `upgrade`, `backup`, `remove`, `waiting`, `approve`, `refuse`, `status` and `agent-key` against a stub `sbx`, in a temporary home, holds the agent definition to the safety rules of ADR 0003 through `tests/check-agent`, holds the zone images' files to their pins through `tests/check-images`, and runs the `release/` scripts against a stub `docker-agent`. It needs bash, `jq` and `yq` (mikefarah's), and is what the `gate` job of `.github/workflows/ci.yml` runs.

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
| `Avatar.qml`, `MediaStrip.qml`, `TurtleIcon.qml` | Profile picture, an event's pictures, videos and sounds, and the icon |
| `mark-seen` | Records that you looked (opening the panel runs it), in `~/.local/state/spaceturtle/last-looked` |
| `relay-events` | Prints the agent's activity, the relay's other events, each event with its resolved parts (label, title, summary, body, links, ref) and what it refers to and what refers to it, the events a thread needs beyond the limit, profiles, the Persona (the agent identity's newest profile with a name, or `null`), follow lists, node addresses, the node's state, the Requests and the agent's private messages (grouped into conversations, or why they cannot be read) as one JSON document, with its `attention` state (`none`, `news`, `urgent`) |
| `skills/being-observed/SKILL.md` | The agent's skill: the public key file, the Persona (creating, reading and living by it, renaming the relay), reading the Requests, answering them, writing a Renderer for a kind |
| `request` | Writes a Request into the queue, or withdraws a waiting one |
| `spaceturtle` | The launcher: `spaceturtle start` brings up the connector's zone on devnet from the connector's zone image (`SPACETURTLE_CONNECTOR_IMAGE`), copying nothing in from the machine, doing only the steps not yet done, with its step markers in `~/.local/state/spaceturtle/launcher`; `start`'s flags choose the network (`--network`, `--evm-rpc-url`, `--evm-chain-id` and the rest of `toon init`'s), kept in `launcher.conf`; `session`, `timer`, `set` and `key` start the agent's sessions, by hand and on a timer, and keep its settings in `~/.config/spaceturtle/launcher.conf`; `waiting`, `approve` and `refuse` list, approve and refuse the apps the agent node holds until the Observer approves them; `start` also makes the agent key once, and `agent-key show`, `replace`, `revoke` and `limit` show, replace, revoke and limit it from outside the agent's zone; `status` shows the timer and the last unattended session, each zone's state, the node's network, its apps and relay, whether the supervisor runs and how many apps wait; `stop`, `upgrade`, `backup` and `remove` stop, replace, back up and remove the Install (`upgrade` carries the passphrase in memory through `sbx exec`; `remove` keeps the wallet's storage and the backup directory); `supervise` is what the unit that keeps the connector's zone running runs |
| `install.sh` | The one command a person runs first: checks the machine, installs the launcher and the agent definition of a release with a `version` file beside them (the launcher then pulls that release's zone images), links it into `~/.local/bin`, and installs the pinned Docker Sandboxes if there is no `sbx` |
| `agent/spaceturtle.yaml` | The agent's definition for `docker-agent`: its instruction, its file tool and the skills it loads. A release publishes it as it is |
| `images/agent/Dockerfile`, `images/connector/Dockerfile`, `images/connector/connector-start` | The agent's zone image (`docker-agent`'s sandbox image plus `toon`, no wallet or key) and the connector's zone image (`toon`, the container engine, gVisor's `runsc`, the overlay client's proxy line), and `connector-start`, which starts the engine, the two forwarders an agent key is used through and the supervisor without `systemd --user` |
| `images/versions.env`, `images/versions` | Every pin the two images add, with its checksum, and the `docker-agent` program a release publishes with; the command that prints the images' versions for release notes |
| `.github/workflows/images.yml` | Builds both images on every change to `images/`. It does not publish |
| `release/references`, `release/publish-definition`, `release/mark-latest`, `release/notes` | What a release publishes, under which names; the definition pushed to each registry and read back, byte for byte; `latest` moved to a release once it is all published; the release's notes |
| `.github/workflows/release.yml` | A tag `vX.Y.Z` runs the gate, then publishes the definition and both images. See [Releasing](releasing.md) |
| `tests/check-images` | Checks that no Dockerfile carries a version of its own, that `toon` and gVisor are pinned and verified, that the agent's image names no passphrase, wallet or key, and that `images/versions` prints each pin |
| `tests/check-agent` | Checks an agent definition against the rules that keep the agent away from the money and from approving its own apps (ADR 0003), and that `docker-agent` will publish it as written |
| `tests/run` | The tests of `relay-events`, `mark-seen`, `request`, the launcher, the `being-observed` skill's answers, `tests/check-agent`, `tests/check-images` and the `release/` scripts (against a stub `docker-agent`) |

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
