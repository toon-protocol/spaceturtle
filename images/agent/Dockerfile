# The agent's zone: docker-agent's own sandbox image with `toon` added, and docker-agent built
# again so that it plays spaceturtle's banner. The agent runs the agent node's commands with an
# agent key the launcher places at session start; this image holds no home for toon, no
# keystore, no passphrase and no key (ADR 0003).
# Build arguments come from images/versions.env and have no defaults here.
ARG DOCKER_AGENT_VERSION
ARG DOCKER_AGENT_BASE_DIGEST
ARG GO_VERSION
ARG GO_IMAGE_DIGEST

# docker-agent of the same release, built again with two changes (ADR 0005): --banner-file,
# which draws a film of frames where docker-agent's own banner would be, and --sidebar-section,
# which shows a command's output in the chat's sidebar. The source is held to
# the commit of the release, and the film's turtle is the one of the banner the README shows,
# which the build is given as the context named assets (docs/assets).
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine@${GO_IMAGE_DIGEST} AS docker-agent
ARG TARGETARCH
ARG DOCKER_AGENT_VERSION
ARG DOCKER_AGENT_COMMIT
RUN apk add --no-cache git
WORKDIR /src
RUN git clone --quiet --depth 1 --branch "v${DOCKER_AGENT_VERSION}" https://github.com/docker/docker-agent.git . \
 && [ "$(git rev-parse HEAD)" = "$DOCKER_AGENT_COMMIT" ]
COPY docker-agent.patch /tmp/
RUN git apply /tmp/docker-agent.patch
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -trimpath -tags no_audio \
      -ldflags "-s -w -X github.com/docker/docker-agent/pkg/version.Version=v${DOCKER_AGENT_VERSION} -X github.com/docker/docker-agent/pkg/version.Commit=${DOCKER_AGENT_COMMIT}" \
      -o /out/docker-agent .
COPY banner.awk /tmp/
COPY --from=assets spaceturtle-banner-dark.svg /tmp/
RUN awk -f /tmp/banner.awk /tmp/spaceturtle-banner-dark.svg > /out/banner.txt && [ "$(grep -c "$(printf '\f')" /out/banner.txt)" = 239 ]

FROM docker/docker-agent-sbx-templates:${DOCKER_AGENT_VERSION}@${DOCKER_AGENT_BASE_DIGEST}

ARG TARGETARCH
ARG TOON_VERSION
ARG TOON_SHA256_AMD64
ARG TOON_SHA256_ARM64

USER root
RUN <<SCRIPT
#!/bin/bash
set -euxo pipefail
case "$TARGETARCH" in
  amd64) arch=x86_64; sum=$TOON_SHA256_AMD64 ;;
  arm64) arch=aarch64; sum=$TOON_SHA256_ARM64 ;;
  *) echo "no toon for $TARGETARCH" >&2; exit 1 ;;
esac
file=toon-v${TOON_VERSION}-linux-${arch}.tar.gz
curl -fsSL -o "/tmp/$file" "https://github.com/toon-protocol/toon_cli/releases/download/v${TOON_VERSION}/$file"
echo "$sum  /tmp/$file" | sha256sum -c -
tar -xzf "/tmp/$file" -C /tmp
install -m 0755 "/tmp/toon-v${TOON_VERSION}-linux-${arch}/toon" /usr/local/bin/toon
rm -rf /tmp/toon-v*
toon --version
SCRIPT
COPY --from=docker-agent /out/docker-agent /usr/local/bin/docker-agent
COPY --from=docker-agent /out/banner.txt /usr/local/share/spaceturtle/banner.txt
COPY --chmod=0755 spaceturtle-apps /usr/local/bin/spaceturtle-apps
RUN docker-agent run --help | grep -q -- --banner-file && docker-agent run --help | grep -q -- --sidebar-section
USER agent
LABEL org.opencontainers.image.title="spaceturtle agent's zone" \
      org.opencontainers.image.description="docker-agent's sandbox image with toon and spaceturtle's banner, with nothing of a wallet in it" \
      org.opencontainers.image.version="${TOON_VERSION}"
