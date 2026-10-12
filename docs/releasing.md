# Releasing spaceturtle

A release publishes everything a person pulls, under one version:

| | GitHub's registry | Docker Hub |
| --- | --- | --- |
| The agent definition, an OCI artifact | `ghcr.io/toon-protocol/spaceturtle` | `<namespace>/spaceturtle` |
| The agent's zone image | `ghcr.io/toon-protocol/spaceturtle-agent-zone` | `<namespace>/spaceturtle-agent-zone` |
| The connector's zone image | `ghcr.io/toon-protocol/spaceturtle-connector-zone` | `<namespace>/spaceturtle-connector-zone` |

`release/references v1.2.3` prints every reference. Nothing is published as `latest`: a `latest` definition and a `latest` image could be of different releases, so a person names the version.

## Set up once

In the repository's settings, under Secrets and variables, Actions:

| | Kind | |
| --- | --- | --- |
| `DOCKERHUB_NAMESPACE` | Variable | The Docker Hub account or organisation that holds the mirror |
| `DOCKERHUB_USERNAME` | Secret | A Docker Hub user that can push to that namespace |
| `DOCKERHUB_TOKEN` | Secret | An access token of that user, with read and write |

GitHub's registry needs no secret: the workflow pushes with its own token.

A package is private when it is first published. After the first release, make each one public: the three under the organisation's Packages on GitHub, and the three repositories on Docker Hub. Until then `docker agent run` asks for a login.

## Release

```
git tag v1.2.3 && git push origin v1.2.3
```

`.github/workflows/release.yml` then:

1. Runs the gate on the tagged commit.
2. Builds each zone image once and pushes it to both registries, so both hold the same digest, then runs `toon --version` in each as each registry holds it.
3. Pushes `agent/spaceturtle.yaml` to both registries with the `docker-agent` pinned in `images/versions.env`, reads each back and fails unless it is byte for byte the file the gate checked.
4. Creates the GitHub release, with notes that name every reference and the `toon`, `docker-agent` and gVisor versions in the images. `release/notes v1.2.3` prints them.

A step that fails leaves no GitHub release, but whatever was pushed before it stays in the registries under the version. Fix the cause and run the workflow again for the same tag: every step can be repeated. A run for a tag that is already released builds the images again and pushes them over the version, so a published version is changed by cutting a new one, not by running its release again.

The images are built for `linux/amd64` only, as `.github/workflows/images.yml` tests them.

## Check the first publish by eye

Publish a pre-release first (`v0.1.0-rc.1`), which GitHub marks as one, and check:

- [ ] The six references in the release notes exist, three in each registry, all under the version
- [ ] `docker agent share pull ghcr.io/toon-protocol/spaceturtle:<version>` writes a file that `cmp` finds equal to `agent/spaceturtle.yaml` at the tag
- [ ] The same from Docker Hub
- [ ] `docker agent run ghcr.io/toon-protocol/spaceturtle:<version>` pulls the definition and starts the agent
- [ ] `docker run --rm --entrypoint toon <an image reference> --version` prints the `toon` version the notes name
- [ ] The release notes name the `toon`, `docker-agent` and gVisor versions

## Why the definition names its version

`docker agent share push` publishes a file as written only when it has a top-level `version` and no agent has an `instruction_file`. Otherwise it publishes its own rewriting of the definition, without the comments, which is not the file the gate checked. `tests/check-agent` fails a definition that would be rewritten (the `published-as-written` rule), and the release reads the published file back to be sure.
