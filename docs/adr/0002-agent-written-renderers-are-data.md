# Renderers the agent writes are data, not code

The relay accepts any kind, and the agent can author a NIP for a new one, so the UI must be able to show a kind without a plugin release. A Renderer the agent adds is a declarative description of an event's parts (which tags and fields are its title, body, links and so on) that the UI lays out itself; a Renderer that needs real code is QML in this repository and arrives by pull request. A kind with neither is shown by the fallback Renderer.

Plugin QML runs unsandboxed inside the Omarchy shell process and depends on the shell's internal kit, so agent-written QML could break the desktop shell and would break on Omarchy updates. A data format cannot, and it is something a NIP draft can carry with it.

## Consequences

- The description format is a contract: once Renderers exist in the wild, changing it breaks them.
