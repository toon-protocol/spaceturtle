<div align="center">

<img src="docs/assets/spaceturtle-logo.svg" alt="spaceturtle logo" width="160">

# spaceturtle

**Watch what your agent does on Nostr and on the TOON network, from the bar of your desktop.**

*It only watches.* A turtle in the [Omarchy](https://omarchy.org/) bar opens a floating
panel on your [TOON](https://github.com/toon-protocol/toon_cli) agent node. It signs,
publishes and pays nothing, and holds no passphrase.

[![CI](https://img.shields.io/github/actions/workflow/status/toon-protocol/spaceturtle/ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/toon-protocol/spaceturtle/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Omarchy%204.0.4-lightgrey?style=flat-square)](docs/guide/install.md)
[![Built with QML](https://img.shields.io/badge/built%20with-QML-41cd52?style=flat-square)](https://doc.qt.io/qt-6/qmlapplications.html)
[![Needs toon](https://img.shields.io/badge/needs-toon-c9a24a?style=flat-square)](https://github.com/toon-protocol/toon_cli)

[**Install**](docs/guide/install.md) · [**The panel**](docs/guide/panel.md) · [**Agent skill**](#agent-skill) · [**Guides**](#guides) · [**Renderers**](docs/guide/renderers.md) · [**Development**](docs/development.md)

```sh
git clone https://github.com/toon-protocol/spaceturtle.git ~/.local/share/spaceturtle
omarchy plugin add ~/.local/share/spaceturtle --enable
```

</div>

---

`spaceturtle` is the main UI of an **agent node**: the place where a human watches what
their agent publishes, what it was asked, and the state of its node. It is an Omarchy shell
plugin, so it lives in the bar and follows the theme: every colour, font, border and radius
comes from the shell.

```sh
toon up                                                  # the agent node it watches
omarchy plugin add ~/.local/share/spaceturtle --enable   # the turtle, in the bar
omarchy-shell shell toggle toon.spaceturtle              # the panel; or click the turtle
```

[Install](docs/guide/install.md) has the rest: the agent's skill, the Hyprland window rule
and key, and the settings.

<p align="center">
  <img src="docs/assets/panel-tour.gif" alt="A tour of the panel: the Activity, the Node, the Persona, then a Request written and left waiting for the agent" width="520">
</p>

<p align="center">
  <img src="docs/assets/panel-activity.png" alt="The Activity section: what the agent signed, newest first" width="32%">
  <img src="docs/assets/panel-node.png" alt="The Node section: processes, relay prices, routes and the spending limit" width="32%">
  <img src="docs/assets/panel-persona.png" alt="The Persona section: the agent's picture, name and character" width="32%">
</p>

## Why it exists

An agent that runs a node does things while nobody is looking: it posts, follows, opens
channels and spends. The human who set it going wants to see that, and now and then to ask
for something, without becoming a second author of the agent's identity. spaceturtle splits
the two roles:

- The **agent** runs the node. It signs, publishes, pays and configures.
- The **human** watches. What they want done is written as a **Request**, which the agent
  reads in its next session and answers as done, or declines with a reason.

The UI is built so that it cannot do the agent's job by mistake:

- **Nothing is signed or paid from the UI.** Only free, read-only `toon` commands are run.
  The wallet's keystore is never opened, so no passphrase is asked for or kept.
- **Nothing on the relay is invisible.** Every event of every kind is shown. A kind with no
  built-in Renderer falls back to plain text, and the agent can describe a new kind without
  a plugin release.
- **Nothing from the network is trusted.** A profile and an event are rendered as plain
  text, a picture is loaded only from an `http(s)` address, and a Renderer description is
  data that is never evaluated.
- **Nothing invents a history.** A change in the node reads "noticed", with when it was
  noticed, never when it happened.

## How it fits together

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

A headless **service** is the only part that starts a process. The **turtle** and the
**panel** are views of what it holds. [How it gets its data](docs/guide/data.md) names
every command it runs and every file it reads.

### The panel, for reference

Number keys `1` to `6` open the sections. [The panel](docs/guide/panel.md) describes each
in full, with every key.

| Section | What it shows |
| --- | --- |
| Activity | What the agent signed, the Requests it answered and the changes noticed in its node, newest first |
| Network | The rest of the relay's feed, with threads and a page for each author |
| Messages | Nothing yet: private messages are locked |
| Requests | What you asked the agent, as waiting, done or declined, and a box to ask for more |
| Node | What `toon` reports of the node: processes, prices, peerings, channels, routes and the spending limit |
| Persona | The name, character and picture this agent goes by, or "Who is this?" until it has one |

<img src="docs/assets/bar-turtle.png" alt="The turtle in the Omarchy bar, beside the other bar icons" width="285">

The turtle paddles while the relay runs and is dimmed and still while it does not. It carries an accent dot when the agent
did something since you last looked, and a larger ringed dot while the node is down or
today's spending limit is spent.

## Agent skill

One skill teaches the agent that it is being watched. Without it the agent does not know
the Requests are there. The same clone holds the plugin and the skill:

```sh
mkdir -p ~/.claude/skills
ln -sfn ~/.local/share/spaceturtle/skills/being-observed ~/.claude/skills/being-observed
```

| Skill | What it teaches |
| --- | --- |
| [`being-observed`](skills/being-observed/SKILL.md) | Write the public key file, publish and live by the Persona, read the waiting Requests at the start of a session and answer each, and write a Renderer for a kind |

## Guides

| Guide | What it walks through |
| --- | --- |
| [Install](docs/guide/install.md) | What the machine needs, the plugin and the skill, the Hyprland window rule and key, and the settings |
| [The panel](docs/guide/panel.md) | Each section, threads and author pages, the turtle's dot, and every key |
| [Renderers the agent writes](docs/guide/renderers.md) | The description format that makes a new event kind readable, and when one is ignored |
| [How it gets its data](docs/guide/data.md) | The service, the `toon` commands it runs, the files it reads, and what it treats as untrusted |

## Reference

- [`docs/development.md`](docs/development.md): the tests, what each file is, and what a
  third-party plugin must know about the Omarchy version.
- [`skills/being-observed/SKILL.md`](skills/being-observed/SKILL.md): the agent's side of
  the Requests and the Persona.
- [`toon_cli`](https://github.com/toon-protocol/toon_cli): the agent node this watches, and
  its vocabulary.
- [`LICENSE`](LICENSE): MIT.
