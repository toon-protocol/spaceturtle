# Renderers the agent writes

The agent can make a new kind readable without a plugin release (ADR 0002) by writing a description of it: one JSON file per kind in `~/.config/spaceturtle/renderers/` (`SPACETURTLE_CONFIG_DIR`, else `$XDG_CONFIG_HOME/spaceturtle`, moves `~/.config/spaceturtle`). Every refresh reads the directory afresh, so a new or changed file shows after the next refresh, with no restart. Example, `renderers/nip-draft.json`:

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

| Field | Meaning |
| --- | --- |
| `kind` | Required. The event kind, a non-negative whole number. The file's name does not matter, but a file holds one description; if two files name one kind, the first by file name (in byte order) wins |
| `label` | What the event did, shown beside its author. Default `kind N` |
| `title`, `summary`, `body` | One line, a shorter line under it, and the text. Each is `{"tag": NAME}` (the first value of the event's first tag of that name) or `{"content": true}` (the event's content). Left out, or naming a tag the event lacks, the part is empty; if all three are empty the event falls back |
| `links` | A list of `{"tag": NAME}`: every value of every tag of that name that is an `http(s)` address, and nothing else |
| `refers_to` | `{"tag": NAME}` or `{"content": true}`, as above: the id of the event this one refers to, shown in the part `ref` when the event has nothing else to show |

A description is ignored, and its events fall back (`kind N`, the `alt` tag, the tags and the content), when the file is not valid JSON, `kind` is missing or not a whole number, a field has the wrong type, a source is anything but exactly one of the two shapes above, the file holds more than one value, or the kind has a built-in Renderer (0, 1, 3, 5, 6, 7, 16, 1111, 30023, 30817): the agent never overrides one. A broken file costs only its own kind; the rest of the document is unaffected. Fields not listed here are ignored.

A description is data: nothing in it is evaluated, passed to a shell or loaded as QML. It only picks tags out of an event, and what it picks is rendered as plain text. The format is a contract: fields may be added, and the meaning of a field never changes. The [`being-observed`](../../skills/being-observed/SKILL.md) skill tells the agent how to write one.
