# The agent's zone builds its own docker-agent

A session is a chat that `docker-agent` draws. On an empty conversation it draws its own name in large letters, from a list of lines fixed in the program, and no flag, setting or field of an agent definition puts anything in its place except a welcome message, which is Markdown drawn once. spaceturtle's banner is a turtle that swims. So the agent's zone image no longer takes `docker-agent` as Docker built it: it builds the same release again from its source, with the changes of `images/agent/docker-agent.patch`. The first adds `--banner-file`. The file is a film of frames, and `docker-agent` plays it on the clock its spinners already use, until the conversation starts, cut down to the middle of it when the chat is smaller. The image makes the film: the turtle of the banner the README shows, flying through a field of stars large enough to fill the chat of a large terminal.

The second change adds `--sidebar-section`. The chat's sidebar has a fixed list of sections (Session, Token Usage, Agent, Tools) and none for what an agent node runs. The flag adds a section whose body is the output of a command, run again every five seconds. The launcher gives it `spaceturtle-apps`, a script in the image that asks `toon status` with the session's agent key and lists each app, whether it runs, and the apps that wait for the Observer.

Both changes are offered to `docker/docker-agent`, the banner as [pull request 4578](https://github.com/docker/docker-agent/pull/4578) and the sidebar section as [pull request 4585](https://github.com/docker/docker-agent/pull/4585). When a release of theirs holds both, the build stage and the patch go, and the image takes Docker's program again.

## Considered Options

- **A welcome message that holds a still of the banner.** Rejected: it does not move, and `docker-agent` draws it as a code block, in one colour, on a panel.
- **The launcher plays the banner before the chat opens.** Rejected: the agent's zone starts in about a second, so the launcher had to hold the chat back for the banner to be seen at all.
- **Wait for Docker to take the change.** Rejected as the only way: it may take weeks, or not happen. It is done as well.
- **A chat of spaceturtle's own in place of `docker-agent`'s.** Rejected: the whole of a chat screen to build and keep, for a banner.

## Consequences

- The `docker-agent` in the agent's zone is not the one Docker published. It is held to the commit of the release (`DOCKER_AGENT_COMMIT`), built by a pinned Go, and differs by a patch of two flags that anyone can read. The banner touches only the chat's drawing. The sidebar section runs a command in the agent's zone every five seconds while a chat is open: the one the launcher names, with what the session already has, the agent key. It asks the node for its status, which the key's scope allows and which costs nothing, and it can do no more than the agent can.
- Moving `docker-agent` to a new release means the patch must still apply. The image build fails if it does not, which is where this is found. The sidebar is a file Docker changes often, so this is more likely for the second change than for the first.
- The image build takes about four minutes longer.
- A release still publishes the agent definition with `docker-agent` as Docker published it, which is enough: the definition holds nothing of the banner.
- Only a session with someone there is given the banner and the section. An unattended one has no chat.
