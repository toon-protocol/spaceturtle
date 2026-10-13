# The connector's zone, a virtual machine under microsandbox: toon, the container engine the
# apps run on (the base's own Docker), and gVisor's runsc for images that are not TOON's own.
# It holds no wallet: the wallet's storage is a directory the launcher mounts, so replacing
# this image leaves it alone. `connector-start` is the entrypoint; it needs no `systemd --user`.
# Build arguments come from images/versions.env and have no defaults here.
ARG CONNECTOR_BASE_DIGEST
FROM docker/sandbox-templates:shell-docker@${CONNECTOR_BASE_DIGEST}

ARG TARGETARCH
ARG TOON_VERSION
ARG TOON_SHA256_AMD64
ARG TOON_SHA256_ARM64
ARG GVISOR_VERSION
ARG GVISOR_SHA512_AMD64
ARG GVISOR_SHA512_ARM64

USER root
RUN <<SCRIPT
#!/bin/bash
set -euxo pipefail
case "$TARGETARCH" in
  amd64) arch=x86_64; tsum=$TOON_SHA256_AMD64; gsum=$GVISOR_SHA512_AMD64 ;;
  arm64) arch=aarch64; tsum=$TOON_SHA256_ARM64; gsum=$GVISOR_SHA512_ARM64 ;;
  *) echo "no build for $TARGETARCH" >&2; exit 1 ;;
esac

file=toon-v${TOON_VERSION}-linux-${arch}.tar.gz
curl -fsSL -o "/tmp/$file" "https://github.com/toon-protocol/toon_cli/releases/download/v${TOON_VERSION}/$file"
echo "$tsum  /tmp/$file" | sha256sum -c -
tar -xzf "/tmp/$file" -C /tmp
install -m 0755 "/tmp/toon-v${TOON_VERSION}-linux-${arch}/toon" /usr/local/bin/toon
toon --version

# gVisor's release is a bzip2 tarball; the loose runsc URL of its older documentation is gone.
# The base has no bzip2 (the live test on #42), so it is installed to unpack and removed after,
# leaving nothing unpinned in the image. socat, for the port forwarder, is the base's own.
apt-get update
apt-get install -y --no-install-recommends bzip2
curl -fsSL -o /tmp/gvisor.tar.bz2 "https://storage.googleapis.com/gvisor/releases/release/${GVISOR_VERSION}/${arch}/gvisor.tar.bz2"
echo "$gsum  /tmp/gvisor.tar.bz2" | sha512sum -c -
mkdir /tmp/gvisor
tar -xjf /tmp/gvisor.tar.bz2 -C /tmp/gvisor
cp -r /tmp/gvisor/runsc /tmp/gvisor/containerd-shim-runsc-v1 /tmp/gvisor/gvisor-bin /usr/local/bin/
apt-get purge -y --auto-remove bzip2
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/toon-v* /tmp/gvisor /tmp/gvisor.tar.bz2 "/tmp/$file"

# The runtime dockerd offers an app whose image is not TOON's own.
mkdir -p /etc/docker
echo '{"runtimes":{"runsc":{"path":"/usr/local/bin/runsc"}}}' > /etc/docker/daemon.json
SCRIPT

COPY --chmod=0755 connector-start /usr/local/bin/connector-start
USER agent
ENTRYPOINT ["/usr/local/bin/connector-start"]
LABEL org.opencontainers.image.title="spaceturtle connector's zone" \
      org.opencontainers.image.description="toon, a container engine and gVisor's runsc, started without systemd --user" \
      org.opencontainers.image.version="${TOON_VERSION}"
