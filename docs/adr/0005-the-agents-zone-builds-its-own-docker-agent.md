# The agent's zone builds its own docker-agent

A session is a chat that `docker-agent` draws. On an empty conversation it draws its own name in large letters, from a list of lines fixed in the program, and no flag, setting or field of an agent definition puts anything in its place except a welcome message, which is Markdown drawn once. spaceturtle's banner is a turtle that swims. So the agent's zone image no longer takes `docker-agent` as Docker built it: it builds the same release again from its source, with one change, `images/agent/docker-agent-banner.patch`, which adds `--banner-file`. The file is a film of frames, and `docker-agent` plays it on the clock its spinners already use, until the conversation starts. The image makes the film from the banner the README shows.

The change is offered to `docker/docker-agent` as [pull request 4578](https://github.com/docker/docker-agent/pull/4578). When a release of theirs holds it, the build stage and the patch go, and the image takes Docker's program again.

## Considered Options

- **A welcome message that holds a still of the banner.** Rejected: it does not move, and `docker-agent` draws it as a code block, in one colour, on a panel.
- **The launcher plays the banner before the chat opens.** Rejected: the agent's zone starts in about a second, so the launcher had to hold the chat back for the banner to be seen at all.
- **Wait for Docker to take the change.** Rejected as the only way: it may take weeks, or not happen. It is done as well.
- **A chat of spaceturtle's own in place of `docker-agent`'s.** Rejected: the whole of a chat screen to build and keep, for a banner.

## Consequences

- The `docker-agent` in the agent's zone is not the one Docker published. It is held to the commit of the release (`DOCKER_AGENT_COMMIT`), built by a pinned Go, and differs by a patch of one flag that anyone can read. What it may do is unchanged: the patch touches the chat's drawing and nothing of tools, keys or the network.
- Moving `docker-agent` to a new release means the patch must still apply. The image build fails if it does not, which is where this is found.
- The image build takes about four minutes longer.
- A release still publishes the agent definition with `docker-agent` as Docker published it, which is enough: the definition holds nothing of the banner.
- Only a session with someone there is given the banner. An unattended one has no chat.
