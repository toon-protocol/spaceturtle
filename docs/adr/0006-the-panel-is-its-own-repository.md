# The panel is its own repository

spaceturtle began as an Omarchy plugin: a turtle in the bar and a panel, with this repository as the plugin, since Omarchy installs a plugin from the root of a git repository. It is now an agent for `docker-agent` and the harness that runs it (ADR 0003, ADR 0004), and the panel is one optional way to watch, on one desktop. So the panel moves to its own repository, `toon-protocol/spaceturtle-panel`, with its history, and this repository holds the agent, its skill, the launcher, the zone images and the release. What the two share is a contract, not code: the files the agent shares with its Observer (the public key, the Requests, the Renderers), described in `docs/guide/observing.md` for whoever observes and in the `being-observed` skill for the agent. The launcher reads and writes those files too, so an Install needs no panel to be asked for things or to report what it did.

## Considered Options

- **Keep the panel at the root and the harness beside it.** Rejected: the repository is then an Omarchy plugin that happens to carry an agent, every factory session is told so, and the panel's QML, demo and five guides outweigh the agent in a repository about the agent.
- **Move the panel to a subdirectory.** Rejected: `omarchy plugin add` clones a repository and reads `manifest.json` at its root, so a panel in a subdirectory cannot be installed.
- **Delete the panel.** Rejected: it is the only thing that shows a person the Network side of what the agent does, and reading an Install's node is work for it, not a reason to drop it.

## Consequences

- The plugin id stays `toon.spaceturtle`, so an installed copy keeps working; its remote is the new repository.
- The agent definition pins the skill by commit in this repository. The skill stays here, and the pin moves with it as before.
- The panel reads an agent node through `toon` on the machine, and cannot yet read the node of an Install, inside the connector's zone, nor the Install's directories by default. That is the panel repository's first issue (ADR 0003, consequences).
- ADR 0001 and ADR 0002 stand: whoever observes never acts for the agent, and a Renderer is data. They are the contract both repositories keep.
