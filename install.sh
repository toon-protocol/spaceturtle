#!/bin/bash
# Installs spaceturtle's launcher for one person, without root:
#
#   curl -fsSL https://raw.githubusercontent.com/toon-protocol/spaceturtle/main/install.sh | bash
#
# It checks the machine first and changes nothing if something is missing. Then it puts the
# launcher and the agent definition of one release in ~/.local/share/spaceturtle/launcher,
# links `spaceturtle` into ~/.local/bin, and puts microsandbox (`msb`), which the zones run
# in, in ~/.local/share/spaceturtle/msb: a copy that is spaceturtle's alone, at the
# version the launcher is tested with. The launcher it installs pulls the zone images of that
# same release. It needs no account, asks for none and starts nothing: it ends by saying
# what to run next.
# Run it again to move to the newest release, then `spaceturtle upgrade`.
#
# Environment:
#   SPACETURTLE_VERSION      the release to install, such as v0.2.0 (default: the latest)
#   SPACETURTLE_INSTALL_DIR  where the launcher goes (default: ~/.local/share/spaceturtle/launcher)
#   SPACETURTLE_BIN_DIR      where the link goes (default: ~/.local/bin)
#   SPACETURTLE_KVM, SPACETURTLE_MSB_HOME, SPACETURTLE_SYSTEMCTL  as the launcher reads them
#   SPACETURTLE_CURL         the curl program (default: curl)
set -euo pipefail

repo=toon-protocol/spaceturtle
dir=${SPACETURTLE_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/spaceturtle/launcher}
bin=${SPACETURTLE_BIN_DIR:-$HOME/.local/bin}
kvm=${SPACETURTLE_KVM:-/dev/kvm}
# As the launcher finds it: microsandbox refuses a home of more than 54 characters.
msb_home=${SPACETURTLE_MSB_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/spaceturtle/msb}
(( ${#msb_home} <= 54 )) || [[ -n ${SPACETURTLE_MSB_HOME:-} ]] || msb_home=$HOME/.spaceturtle-msb
systemctl_=${SPACETURTLE_SYSTEMCTL:-systemctl}
curl_=${SPACETURTLE_CURL:-curl}
# microsandbox, pinned: the release the launcher is tested with. The checksum is the one the
# release's checksums.sha256 gives for microsandbox-linux-x86_64.tar.gz.
msb_version=${SPACETURTLE_MSB_VERSION:-0.7.8}
msb_sha256=${SPACETURTLE_MSB_SHA256:-86f9f72dc3e639c7175bc07909b4b63ce412517c1ef8a2e1921171af5682fded}

say() { echo "spaceturtle: $*"; }
die() { echo "spaceturtle: $*" >&2; exit 1; }

# Everything the machine lacks, said at once, before anything is changed.
lacking=()
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || lacking+=("a Linux machine on x86_64: the zone images are built for nothing else")
if [[ ! -e $kvm ]]; then lacking+=("KVM ($kvm): turn on virtualisation in the firmware (VT-x or AMD-V) and load the kvm module")
elif [[ ! -r $kvm || ! -w $kvm ]]; then lacking+=("the right to use KVM ($kvm): run 'sudo usermod -aG kvm \$USER', then sign out and in again")
fi
(( ${#msb_home} <= 54 )) || lacking+=("a shorter home for microsandbox than $msb_home: set SPACETURTLE_MSB_HOME to a directory of 54 characters or fewer")
# microsandbox is built against the GNU C library.
getconf GNU_LIBC_VERSION >/dev/null 2>&1 || lacking+=("the GNU C library (glibc 2.28 or newer), which microsandbox needs")
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

# microsandbox is a program and the library that holds the zones' kernel, side by side.
if [[ $("$msb_home/bin/msb" --version 2>/dev/null) != "msb $msb_version" ]]; then
  say "installing microsandbox $msb_version, which the zones run in"
  "$curl_" -fsSL -o "$tmp/msb.tar.gz" "https://github.com/superradcompany/microsandbox/releases/download/v$msb_version/microsandbox-linux-x86_64.tar.gz" \
    || die "microsandbox could not be downloaded, so the launcher has nothing to run the zones in. Run this again."
  echo "$msb_sha256  $tmp/msb.tar.gz" | sha256sum -c - >/dev/null || die "the download of microsandbox is not the release it should be, so it was not installed"
  mkdir "$tmp/msb"
  tar -xzf "$tmp/msb.tar.gz" -C "$tmp/msb" || die "the download of microsandbox is not an archive"
  lib=$(cd "$tmp/msb" && ls libkrunfw.so.*.*.* 2>/dev/null | head -n 1) || lib=
  [[ -s $tmp/msb/msb && -n $lib ]] || die "the download of microsandbox does not hold what it should"
  mkdir -p "$msb_home/bin" "$msb_home/lib"
  install -m 0644 "$tmp/msb/$lib" "$msb_home/lib/$lib"
  abi=${lib#libkrunfw.so.}; abi=${abi%%.*}
  ln -sfn "$lib" "$msb_home/lib/libkrunfw.so.$abi"
  ln -sfn "libkrunfw.so.$abi" "$msb_home/lib/libkrunfw.so"
  install -m 0755 "$tmp/msb/msb" "$msb_home/bin/msb"
fi

say "installed. What to run next:"
n=1
step() { echo "  $n. $*"; n=$((n + 1)); }
case ":$PATH:" in *":$bin:"*) ;; *) step "export PATH=\"$bin:\$PATH\"     (and add it to your shell's profile)" ;; esac
step "spaceturtle start     (about a minute; makes the Install on devnet)"
step "spaceturtle key       (your model provider's key, read without showing it)"
step "spaceturtle           (talk to your agent)"
