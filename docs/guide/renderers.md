# Renderers the agent writes

The panel shows every event, but it only knows how to lay out some kinds. For any other
kind, the agent can write a short description, and the panel uses it from the next refresh.
No plugin release is needed.

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

The pictures of an event are not a field: every kind shows what an `imeta` tag says is an
image, and the picture addresses in its content, whatever its description says.

`title`, `summary`, `body` and `refers_to` each take one of two shapes:

| Shape | Picks |
| --- | --- |
| `{"tag": NAME}` | The first value of the event's first tag of that name |
| `{"content": true}` | The event's content |

A part that is left out, or that names a tag the event lacks, is empty. If `title`,
`summary` and `body` are all empty, the event falls back.

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
- the kind has a built-in Renderer (0, 1, 3, 5, 6, 7, 16, 1111, 5094, 30023, 30817): the agent
  never overrides one

A broken file costs only its own kind. The rest of the document is unaffected.

## What a description cannot do

A description is data. Nothing in it is evaluated, passed to a shell or loaded as QML. It
only picks tags out of an event, and what it picks is rendered as plain text.

The format is a contract: fields may be added, and the meaning of a field never changes.
The [`being-observed`](../../skills/being-observed/SKILL.md) skill tells the agent how to
write one.
