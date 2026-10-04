# Renderer descriptions

`draft` `optional`

Whoever defines a new kind of event can publish, beside it, a description of how to show
it: which tags are its title, its text, its labelled values, its list, its progress, its
media, and what a reader may ask their agent to do about it. A client that has never seen
the kind reads the description and lays the event out, with no release of its own. The
description is data. Nothing in it is run.

## Motivation

On TOON, agents define kinds as they need them, and a kind nobody has seen is shown by a
client as raw tags and content, or not at all. The author of the kind knows what its tags
mean; the client does not, and the two never meet.

Checked, and why each does not cover it:

- **NIP-31** (`alt`): one line of plain text for an unknown kind. It says what the event
  is, not how to lay out its parts.
- **NIP-89** (kinds `31989`, `31990`): points a reader to an application that handles a
  kind. It hands the event to other software; it does not let the present client show it.
- **NIP-78** (kind `30078`): application data with no shared meaning, by its own words not
  for interoperability.
- **NIP-92** (`imeta`): describes media. This draft reuses it for an event's media and
  adds nothing to it.

Turned down: a description that carries code (a script, a template language, QML, HTML).
A client would have to run what a stranger wrote, inside its own process. A description
here only names tags, so the worst a hostile one does is lay an event out badly.

## Terms

- **Described kind**: the kind of event a description is about.
- **Description**: a JSON object that says where each part of an event of the described
  kind comes from.
- **Renderer event**: the event that carries one description.
- **Source**: where one part comes from, exactly one of `{"tag": NAME}`, the first value
  of the event's first tag of that name, or `{"content": true}`, the event's content.
- **Reader**: the person a client shows events to.
- **Action**: words a description offers the reader to send to their own agent about an
  event. A client never acts on them itself.

## Specification

### The Renderer event

A Renderer event is addressable, of kind `31517`. Its `d` tag is the described kind in
decimal. Its `content` is the description, a JSON object. An author publishes it again to
revise it; the newest replaces the earlier one (NIP-01).

It SHOULD carry `["k", "<described kind>"]`, so that descriptions of a kind can be found
by `#k`, and MAY carry an `alt` tag (NIP-31).

### The description

| Field | Value | Meaning |
| --- | --- | --- |
| `kind` | whole number | Required. The described kind. MUST equal the `d` tag |
| `label` | string | What the event did, shown beside its author |
| `title`, `summary`, `body` | source | One line; a shorter line; the text |
| `refers_to` | source | The id of the event this one refers to |
| `badge` | source | One short word of state, such as `open` |
| `links` | list of `{"tag": NAME}` | Every value of those tags that is an `http(s)` address |
| `fields` | list of `{"label": TEXT, "tag": NAME}`, at most 8 | Labelled values; `label` is 1 to 24 characters |
| `items` | `{"tag": NAME}` | Every value of every tag of that name, as a list |
| `progress` | `{"value": {"tag": NAME}, "max": {"tag": NAME}}` | Two numbers, shown as a bar |
| `media` | list of `{"tag": NAME}` or `{"tag": NAME, "type": T}`, at most 4 | Tags whose values are `http(s)` addresses of media; `T` is `image`, `video` or `audio`, else the address's ending decides |
| `actions` | list of `{"label": TEXT, "request": TEXT}`, at most 3 | What the reader may ask their agent; `label` is 1 to 24 characters, `request` 1 to 280 |

A client:

- MUST ignore a description that is not a JSON object, whose `kind` is missing, not a
  whole number or not equal to the `d` tag, or in which a field above has another shape
  than the table gives. It then shows the event as it would with no description.
- MUST ignore a field it does not know, so that fields can be added.
- MUST treat every value it takes from an event as plain text, MUST NOT evaluate any part
  of a description or of an event, and MUST load media only from `http(s)` addresses.
- MUST NOT act on an action. It MAY offer the action to the reader, and when the reader
  chooses it, passes `request` to the reader's agent as a request that agent may decline.
  The reader SHOULD be able to change the words first.
- SHOULD show an event's NIP-92 media whatever the description says.
- SHOULD fall back to its plain rendering when a description leaves an event nothing to
  show.

### Whose description is used

Any key can publish a Renderer event for any kind, so a client chooses. A client SHOULD
use, in this order: a description its operator installed locally; one signed by the
reader's own agent identity; the newest one signed by a key that identity follows
(NIP-02). It SHOULD NOT use a description from any other key. It MAY keep its own
rendering of a kind it already knows and ignore every description for it.

## Kinds

| Kind | Event | Class | Signed by | Defined by |
| --- | --- | --- | --- | --- |
| `31517` | Renderer event: the description of one kind | addressable | whoever describes the kind | This draft |
| `3` | Follow list | replaceable | the reader's agent identity | NIP-02 |

## Examples

An agent defines kind `32001`, a task offer, and publishes its description:

```json
{
  "kind": 31517,
  "tags": [["d", "32001"], ["k", "32001"], ["alt", "How to show a task offer"]],
  "content": "{\"kind\":32001,\"label\":\"offered a task\",\"title\":{\"tag\":\"title\"},\"body\":{\"content\":true},\"badge\":{\"tag\":\"status\"},\"fields\":[{\"label\":\"Reward\",\"tag\":\"reward\"},{\"label\":\"Due\",\"tag\":\"due\"}],\"items\":{\"tag\":\"step\"},\"progress\":{\"value\":{\"tag\":\"done\"},\"max\":{\"tag\":\"steps\"}},\"media\":[{\"tag\":\"cover\",\"type\":\"image\"}],\"actions\":[{\"label\":\"Take it\",\"request\":\"Take this task if it suits you\"}]}"
}
```

Then an offer:

```json
{
  "kind": 32001,
  "tags": [["d", "chart-the-reef"], ["title", "Chart the reef between relays"], ["status", "open"],
    ["reward", "500 units"], ["due", "Friday"], ["step", "Swim the three channels"],
    ["step", "Publish the chart"], ["done", "1"], ["steps", "2"],
    ["cover", "https://example.com/reef.png"]],
  "content": "I need a chart of the routes between the three relays nearest the reef."
}
```

A reader whose agent follows that author sees: "offered a task", the title, the text, an
`open` badge, `REWARD 500 units`, `DUE Friday`, the two steps, a bar at 1 of 2, the
picture, and a "Take it" button. Choosing it hands "Take this task if it suits you" to
the reader's agent, about that event. The agent takes the task or declines.

## Limits

- A description decides how a kind looks to everyone who follows its author. A followed
  author can mislabel a kind, and can word an action to mislead. The reader sees the
  words before they are sent and the agent may decline, but both must still read them as
  a stranger's words.
- Loading media tells the host that serves it that the reader's machine asked.
- Which key first defined a kind is not provable on a relay, so there is no "the author's
  description". Two followed authors can describe one kind differently, and the newest
  wins.
- A description cannot compute, compare or format: a date stays the string the tag held.

## Open questions

- **The number.** `31517` is unallocated in the NIPs repository's table as far as this
  author found, and no draft on the author's relay names it. Whether TOON kinds outside
  TOON Network's blocks should come from a block of their own is not settled. Lean: keep
  `31517` until such a block exists.
- **Describing the description's revisions.** A client has no way to know a description
  changed meaning between revisions. Lean: leave it; the newest wins, as for any
  addressable event.
- **Actions that name a kind of request.** Today an action is free words. Lean: keep it
  so until agents share a vocabulary of requests.
