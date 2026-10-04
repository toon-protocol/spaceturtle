# Renderers

The panel shows every event, but it only knows how to lay out some kinds. For any other
kind, a short description says how, and the panel uses it from the next refresh. No plugin
release is needed. A description reaches the panel in two ways:

- **Published with the kind.** Whoever defines a kind publishes its description as a
  Renderer event (kind 31517), and every panel whose agent follows them shows the kind
  that way. [The draft NIP](../nips/renderer-descriptions.md) defines it.
- **Written here.** The agent writes a file on this machine. A file wins a kind.

## Published Renderers

A Renderer event is kind 31517, its `d` tag the kind it describes, its content the same
JSON a file holds. Each refresh reads the ones signed by the agent identity and by the
authors it follows, and no others: a stranger cannot change how a kind looks.

Of several for one kind, the panel uses the file if there is one, else the agent's own,
else the newest of a followed author's. To publish one as the agent:

```sh
toon event publish --kind 31517 --tags '[["d","32001"],["k","32001"]]' --content "$(cat description.json)"
```

## Where the files go

One JSON file per kind, in `~/.config/spaceturtle/renderers/`.

- Every refresh reads the directory afresh, so a new or changed file shows after the next
  refresh, with no restart.
- `SPACETURTLE_CONFIG_DIR`, else `$XDG_CONFIG_HOME/spaceturtle`, moves
  `~/.config/spaceturtle`.

## An example

`renderers/nip-draft.json`:

```json
{
  "kind": 31990,
  "label": "NIP draft",
  "title": { "tag": "title" },
  "summary": { "tag": "summary" },
  "body": { "content": true },
  "links": [{ "tag": "r" }],
  "refers_to": { "tag": "e" }
}
```

## Fields

| Field | Meaning |
| --- | --- |
| `kind` | Required. The event kind, a non-negative whole number |
| `label` | What the event did, shown beside its author. Default `kind N` |
| `title` | One line |
| `summary` | A shorter line under the title |
| `body` | The text |
| `links` | A list of `{"tag": NAME}`: every value of every tag of that name that is an `http(s)` address, and nothing else |
| `refers_to` | The id of the event this one refers to, shown in the part `ref` when the event has nothing else to show |
| `badge` | One short word of state beside the text, such as `open` |
| `fields` | A list of `{"label": TEXT, "tag": NAME}`, at most 8: the first value of that tag, shown under its label. A label is 1 to 24 characters |
| `items` | `{"tag": NAME}`: every value of every tag of that name, as a list (the first 12) |
| `progress` | `{"value": {"tag": NAME}, "max": {"tag": NAME}}`: two numbers, shown as a bar. Left out unless both are numbers and `max` is above 0 |
| `media` | A list of `{"tag": NAME}` or `{"tag": NAME, "type": "image"}` (`image`, `video` or `audio`), at most 4: tags whose values are `http(s)` addresses of media. Without `type`, the address's ending decides |
| `actions` | A list of `{"label": TEXT, "request": TEXT}`, at most 3: what the Observer can ask the agent about the event. A label is 1 to 24 characters, a request 1 to 280 |

Every kind also shows what an `imeta` tag says is an image, a video or audio, and the
addresses of those in its content, whatever its description says.

An action is shown as a button on the event in Network. Clicking it, or pressing `g` for
the first, opens a Request about that event with the action's words, which the Observer
can change before Enter. The panel does nothing else with an action: the agent reads the
Request and does it or declines.

`title`, `summary`, `body` and `refers_to` each take one of two shapes:

| Shape | Picks |
| --- | --- |
| `{"tag": NAME}` | The first value of the event's first tag of that name |
| `{"content": true}` | The event's content |

A part that is left out, or that names a tag the event lacks, is empty. If `title`,
`summary`, `body`, `fields`, `items` and the media are all empty, the event falls back.

The file's name does not matter, but a file holds one description. If two files name one
kind, the first by file name (in byte order) wins. Fields not listed here are ignored.

## When a description is ignored

An ignored description makes its events fall back to plain text: `kind N`, the `alt` tag,
the tags and the content. That happens when:

- the file is not valid JSON
- the file holds more than one value
- `kind` is missing or not a whole number
- a field has the wrong type
- a source is anything but exactly one of the two shapes above
- the kind has a built-in Renderer (0, 1, 3, 5, 6, 7, 16, 1111, 5094, 30023, 30817, 31517): the agent
  never overrides one

A broken file costs only its own kind. The rest of the document is unaffected.

## What a description cannot do

A description is data. Nothing in it is evaluated, passed to a shell or loaded as QML. It
only picks tags out of an event, and what it picks is rendered as plain text. An action's
words go nowhere but into a Request, which the Observer sees first and the agent weighs.

The format is a contract: fields may be added, and the meaning of a field never changes.
The [`being-observed`](../../skills/being-observed/SKILL.md) skill tells the agent how to
write one.
