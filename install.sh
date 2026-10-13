#!/bin/bash
# Installs spaceturtle's launcher for one person, without root:
#
#   curl -fsSL https://raw.githubusercontent.com/toon-protocol/spaceturtle/main/install.sh | bash
#
# It checks the machine first and changes nothing if something is missing. Then it puts the
# launcher and the agent definition of one release in ~/.local/share/spaceturtle/launcher,
# links `spaceturtle` into ~/.local/bin, and installs Docker Sandboxes (`sbx`) if the machine
# has none. The launcher it installs pulls the zone images of that same release. It does not
# sign in to Docker or start anything: it ends by saying what to run next.
# Run it again to move to the newest release, then `spaceturtle upgrade`.
#
# Environment:
#   SPACETURTLE_VERSION      the release to install, such as v0.2.0 (default: the latest)
#   SPACETURTLE_INSTALL_DIR  where the launcher goes (default: ~/.local/share/spaceturtle/launcher)
#   SPACETURTLE_BIN_DIR      where the link goes (default: ~/.local/bin)
#   SPACETURTLE_KVM, SPACETURTLE_SBX, SPACETURTLE_SYSTEMCTL  as the launcher reads them
#   SPACETURTLE_CURL         the curl program (default: curl)
set -euo pipefail

repo=toon-protocol/spaceturtle
dir=${SPACETURTLE_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/spaceturtle/launcher}
bin=${SPACETURTLE_BIN_DIR:-$HOME/.local/bin}
kvm=${SPACETURTLE_KVM:-/dev/kvm}
sbx=${SPACETURTLE_SBX:-sbx}
systemctl_=${SPACETURTLE_SYSTEMCTL:-systemctl}
curl_=${SPACETURTLE_CURL:-curl}
# Docker Sandboxes, pinned: the release the launcher is tested with. The checksum is the
# digest GitHub records for the release's DockerSandboxes-linux-amd64.tar.gz.
sbx_version=${SPACETURTLE_SBX_VERSION:-0.47.0}
sbx_sha256=${SPACETURTLE_SBX_SHA256:-a89cb4380075ebb20938103bc98ec63327fbeabe43a71f0575ddb285a051eab4}

say() { echo "spaceturtle: $*"; }
die() { echo "spaceturtle: $*" >&2; exit 1; }

# Everything the machine lacks, said at once, before anything is changed.
lacking=()
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || lacking+=("a Linux machine on x86_64: the zone images are built for nothing else")
[[ -e $kvm ]] || lacking+=("KVM ($kvm): turn on virtualisation in the firmware (VT-x or AMD-V) and load the kvm module")
command -v "$systemctl_" >/dev/null 2>&1 || lacking+=("systemd, for the user units that keep the Install running")
for program in "$curl_" jq tar sha256sum; do
  command -v "$program" >/dev/null 2>&1 || lacking+=("$program")
done
if (( ${#lacking[@]} )); then
  echo "spaceturtle: this machine lacks what spaceturtle needs, so nothing was installed:" >&2
  printf '  - %s\n' "${lacking[@]}" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

version=${SPACETURTLE_VERSION:-}
if [[ -z $version ]]; then
  version=$("$curl_" -fsSL "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name // empty') || version=
  [[ -n $version ]] || die "the latest release could not be read from GitHub. Name one: SPACETURTLE_VERSION=v0.2.0"
fi
[[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] || die "'$version' is not a release, such as v0.2.0"

say "installing the launcher of $version"
"$curl_" -fsSL -o "$tmp/source.tar.gz" "https://github.com/$repo/archive/refs/tags/$version.tar.gz" || die "$version could not be downloaded"
mkdir "$tmp/source"
tar -xzf "$tmp/source.tar.gz" -C "$tmp/source" --strip-components=1 || die "the download of $version is not an archive"
[[ -s $tmp/source/spaceturtle && -s $tmp/source/agent/spaceturtle.yaml ]] || die "$version holds no launcher"

# The new launcher is whole before it takes the old one's place.
mkdir -p "$(dirname "$dir")" "$bin"
rm -rf "$dir.new"
mkdir -p "$dir.new/agent"
install -m 0755 "$tmp/source/spaceturtle" "$dir.new/spaceturtle"
install -m 0644 "$tmp/source/agent/spaceturtle.yaml" "$dir.new/agent/spaceturtle.yaml"
# The launcher pulls the zone images of the release named here.
echo "${version#v}" > "$dir.new/version"
rm -rf "$dir.old"
[[ ! -e $dir ]] || mv "$dir" "$dir.old"
mv "$dir.new" "$dir"
rm -rf "$dir.old"
ln -sfn "$dir/spaceturtle" "$bin/spaceturtle"

if ! command -v "$sbx" >/dev/null 2>&1 && [[ ! -x $HOME/.docker/sbx/bin/sbx ]]; then
  say "installing Docker Sandboxes $sbx_version, which the zones run in"
  "$curl_" -fsSL -o "$tmp/sbx.tar.gz" "https://github.com/docker/sbx-releases/releases/download/v$sbx_version/DockerSandboxes-linux-amd64.tar.gz" \
    || die "Docker Sandboxes could not be downloaded. Install it from https://github.com/docker/sbx-releases, then run 'spaceturtle start'."
  echo "$sbx_sha256  $tmp/sbx.tar.gz" | sha256sum -c - >/dev/null || die "the download of Docker Sandboxes is not the release it should be, so it was not installed"
  tar -xzf "$tmp/sbx.tar.gz" -C "$tmp"
  bash "$tmp/docker-sbx/install.sh" || die "Docker Sandboxes' own installer failed. Install it from https://github.com/docker/sbx-releases, then run 'spaceturtle start'."
fi

say "installed. What to run next:"
n=1
step() { echo "  $n. $*"; n=$((n + 1)); }
path_add=
command -v "$sbx" >/dev/null 2>&1 || path_add="\$HOME/.docker/sbx/bin:"
case ":$PATH:" in *":$bin:"*) ;; *) path_add+="$bin:" ;; esac
[[ -z $path_add ]] || step "export PATH=\"$path_add\$PATH\"     (and add it to your shell's profile)"
PATH="$HOME/.docker/sbx/bin:$PATH" "$sbx" ls >/dev/null 2>&1 || step "sbx login && sbx daemon start -d     (a Docker account; it opens a browser)"
step "spaceturtle start     (about a minute; makes the Install on devnet)"
step "spaceturtle key       (your model provider's key, read without showing it)"
step "spaceturtle session   (talk to your agent)"
