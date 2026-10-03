# Install

## What the machine needs

- Omarchy with the Quickshell-based shell (`omarchy plugin` commands). Built against Omarchy 4.0.4; see [Omarchy version](../development.md#omarchy-version).
- A running agent node: [`toon`](https://github.com/toon-protocol/toon_cli) on `PATH` or in `~/.local/bin`, and `toon up`.
- `jq`, `curl`, and `wl-copy` for copying.
- For the UI to recognise your agent: its public key (64 lowercase hex characters) in `~/.config/spaceturtle/agent-pubkey`, written by the agent during setup.

## Install the plugin

```sh
omarchy plugin add https://github.com/toon-protocol/spaceturtle.git --enable
```

This clones the repository into `~/.config/omarchy/plugins/toon.spaceturtle` and puts the turtle in the bar. Update it with `omarchy plugin update toon.spaceturtle`.

## Install the agent's skill

The skill, [`being-observed`](../../skills/being-observed/SKILL.md), tells the agent how to write its public key to `~/.config/spaceturtle/agent-pubkey`, publish, read and live by its Persona (and rename the relay after it), read the waiting Requests at the start of a session and answer each as done or declined. Without it the agent does not know the Requests are there.

With the [skills CLI](https://skills.sh/), which asks which agents to install it for and puts it where each one reads skills:

```sh
npx skills add toon-protocol/spaceturtle
```

Run it again to update the skill. On a machine without Node, link the copy that came with the plugin instead; it then updates with the plugin:

```sh
mkdir -p ~/.claude/skills
ln -sfn ~/.config/omarchy/plugins/toon.spaceturtle/skills/being-observed ~/.claude/skills/
```

If your agent reads skills from somewhere other than `~/.claude/skills`, link the folder there instead.

Move the turtle with `omarchy bar move toon.spaceturtle --section right`, or drag it in the bar.

Then tell Hyprland to float the panel and give it a key, in `~/.config/hypr/hyprland.lua` and `~/.config/hypr/bindings.lua`:

```lua
o.window({ class = "^org.quickshell$", title = "^Spaceturtle$" }, { float = true, center = true })
```

```lua
o.bind("SUPER + CTRL + U", "Spaceturtle", "omarchy-shell shell toggle toon.spaceturtle")
```

Omarchy 4.0.4 leaves `SUPER + CTRL + U` free; any key will do. Without the window rule the panel still opens, but Hyprland tiles it like any other new window.

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
