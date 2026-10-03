# Install

## What you need

- **Omarchy** with the Quickshell-based shell (the `omarchy plugin` commands). Built
  against Omarchy 4.0.4; see [Omarchy version](../development.md#omarchy-version).
- **A running agent node**: [`toon`](https://github.com/toon-protocol/toon_cli) on `PATH`
  or in `~/.local/bin`, and `toon up`.
- **`jq`, `curl` and `wl-copy`**. `wl-copy` is only used for copying values.

## 1. Add the plugin

```sh
omarchy plugin add https://github.com/toon-protocol/spaceturtle.git --enable
```

This clones the repository into `~/.config/omarchy/plugins/toon.spaceturtle` and puts the
turtle in the bar.

## 2. Install the agent's skill

The [`being-observed`](../../skills/being-observed/SKILL.md) skill tells the agent that it
is being watched. Without it the agent does not know the Requests are there.

```sh
npx skills add toon-protocol/spaceturtle
```

The [skills CLI](https://skills.sh/) asks which agents to install it for and puts it where
each one reads skills. Run it again to update the skill.

The skill teaches the agent to:

- write its public key to `~/.config/spaceturtle/agent-pubkey`, so the panel knows which
  events are its own
- publish and live by its Persona, and rename the relay after it
- read the waiting Requests at the start of a session, and answer each as done or declined

### Without Node

Link the copy that came with the plugin. It then updates with the plugin.

```sh
mkdir -p ~/.claude/skills
ln -sfn ~/.config/omarchy/plugins/toon.spaceturtle/skills/being-observed ~/.claude/skills/
```

If your agent reads skills from somewhere other than `~/.claude/skills`, link the folder
there instead.

## 3. Float the panel and give it a key

In `~/.config/hypr/hyprland.lua`:

```lua
o.window({ class = "^org.quickshell$", title = "^Spaceturtle$" }, { float = true, center = true })
```

In `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + U", "Spaceturtle", "omarchy-shell shell toggle toon.spaceturtle")
```

Omarchy 4.0.4 leaves `SUPER + CTRL + U` free; any key will do. Without the window rule the
panel still opens, but Hyprland tiles it like any other new window.

## Move the turtle

Drag it in the bar, or:

```sh
omarchy bar move toon.spaceturtle --section right
```

## Settings

Settings go on the plugin's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "toon.spaceturtle", "interval": 30, "limit": 40, "icon": 2 }
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `interval` | `30` | Seconds between refreshes, at least 5 |
| `limit` | `40` | The most events to fetch |
| `icon` | `1` | Which turtle drawing, 1 to 5 |
| `iconPreview` | `false` | Show all five drawings in Network, to choose one |

## Update

```sh
omarchy plugin update toon.spaceturtle
```
