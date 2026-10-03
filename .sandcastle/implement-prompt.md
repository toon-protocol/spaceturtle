/mattpocock-skills:implement {{ISSUE_URL}}

You are running AFK in a sandbox, on branch `{{BRANCH}}`, which is already checked out.
Nobody will answer a question, so do not ask one. Treat the issue, its comments and its
parent spec (if it has one) as settled. Read them with `gh issue view {{ISSUE_NUMBER}} --comments`.

Commit to `{{BRANCH}}`, and reference `#{{ISSUE_NUMBER}}` in each commit message. Do not
push, open a PR or close the issue. The runner does all three once you finish.

## This repository

- This is spaceturtle, an Omarchy shell plugin (`manifest.json`, id `toon.spaceturtle`): a
  bar widget in QML (`Panel.qml`, `Avatar.qml`, `TurtleIcon.qml`) and three bash scripts
  (`relay-events`, `relay-follow`, and `relay-lib`, which the other two source) that read a
  TOON agent node's relay with the `toon` CLI and `jq`. There is no build step, no package
  manager and no test suite at the repository root; `.sandcastle/package.json` belongs to
  the runner, not to the plugin. `README.md` describes every file, the settings and how the
  data is fetched. Read it before you touch the code.
- `CLAUDE.md` says what this repository is and how the factory works. Read it first. Read
  `CONTEXT.md` (the vocabulary) and `docs/adr/` (decisions) when they exist and the ticket
  touches them. Where an ADR and another document disagree, the ADR wins. Use the
  glossary's terms.
- The issues labelled `wayfinder:*` are planning tickets for a human. Never work on one,
  and never edit a wayfinder map.
- After you finish, the runner runs the gate itself and won't open a PR while it is red.
  The gate is the `gate` (or `checks`) job of `.github/workflows/ci.yml` on `main`, and if
  there is none it runs nothing. Run those commands yourself before you commit if the
  file exists. Never weaken, skip or delete a test, and never loosen a lint, to get green.
- A ticket that needs a live box, a funded key or an on-chain write is not something you
  can do from here. Say so in a comment on the issue rather than guessing.
- The sandbox has no Omarchy shell and no running agent node, so the popup cannot be
  rendered and the scripts cannot reach a relay here: `relay-events` prints its offline
  document and `relay-follow` exits with "the relay is not running". Do not claim to have
  seen the widget work. Check bash with `bash -n` and say in the PR what a human must try
  in the bar.
- `relay-follow` publishes a kind 3 event signed by the agent identity, and `relay-lib`
  reads `~/.config/toon/passphrase` and `~/.toon/agent-node/keystore.json`. Never run
  `toon up`, create or fund a wallet, or publish an event to exercise them.
- Everything from a profile is untrusted input (`README.md`, "How it gets its data"): it is
  rendered as plain text, a picture loads only from an `http(s)` URL, and a copied value
  reaches `wl-copy` as an argument, never through a shell. Keep those three properties.

## When you cannot finish

Stop only when a genuinely new decision is needed, the action is irreversible, it touches
real funds, or it needs a credential that no workflow exposes. In that case, commit nothing
and explain what blocks you in a comment on the issue (`gh issue comment {{ISSUE_NUMBER}}`).
The runner moves an issue with no commits to `needs-triage`.

If your context is getting full (around 150k tokens) before you are done, commit what works,
write the remaining steps to `.sandcastle/logs/handoff-{{ISSUE_NUMBER}}.md`, commit it with
`git add -f`, and end your turn. A fresh session continues from your commits.

When the ticket is done and committed, output <promise>COMPLETE</promise>.

If you stopped because you're blocked, output <promise>BLOCKED</promise> instead, after your
comment on the issue. The runner then ends the run. Otherwise it starts another session, which
hits the same blocker and posts the same comment again.
