# The agent's zone: docker-agent's own sandbox image with `toon` added. The agent runs the
# agent node's commands with an agent key the launcher places at session start; this image
# holds no home for toon, no keystore, no passphrase and no key (ADR 0003).
# Build arguments come from images/versions.env and have no defaults here.
ARG DOCKER_AGENT_VERSION
ARG DOCKER_AGENT_BASE_DIGEST
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
USER agent
LABEL org.opencontainers.image.title="spaceturtle agent's zone" \
      org.opencontainers.image.description="docker-agent's sandbox image with toon, with nothing of a wallet in it" \
      org.opencontainers.image.version="${TOON_VERSION}"
