#!/usr/bin/env bash
#
# Install the tools behind the "nice terminal" (root): the Starship prompt,
# fastfetch and the JetBrains Mono font. tasks/terminal-profile.sh then
# turns them on for the student.
#
# Starship and fastfetch come from the distribution when it has them
# (Ubuntu 26.04). Otherwise the official release is downloaded from GitHub
# and checked against the SHA256 checksum pinned below before it is
# installed; a download that does not match is never installed.

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
require_root
detect_env

STARSHIP_VERSION=v1.26.0
FASTFETCH_VERSION=2.68.1
case "$ARCH" in
    amd64)
        STARSHIP_FILE=starship-x86_64-unknown-linux-musl.tar.gz
        STARSHIP_SHA256=b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3
        FASTFETCH_FILE=fastfetch-linux-amd64.deb
        FASTFETCH_SHA256=33b046a620b4f15fb6d0f9b3ef2491e6147ae15e40d699a6eef13555634a1b28
        ;;
    arm64)
        STARSHIP_FILE=starship-aarch64-unknown-linux-musl.tar.gz
        STARSHIP_SHA256=dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b
        FASTFETCH_FILE=fastfetch-linux-aarch64.deb
        FASTFETCH_SHA256=0290a96bf225e0142a2e21238be9ef36c63c959c489f2f3ba6b4c72b5a767b9a
        ;;
    *)
        fail "No terminal tools for $ARCH."
        exit 1
        ;;
esac

has_candidate() {
    apt-cache policy "$1" 2>/dev/null | grep 'Candidate: [0-9]' >/dev/null
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
chmod 755 "$tmp"

# Download a release file and stop unless it matches the pinned checksum.
download_checked() {
    local url="$1" file="$2" sha256="$3"
    info "Downloading $url"
    curl -fsSL --retry 3 -o "$file" "$url"
    if ! echo "$sha256  $file" | sha256sum --check --status; then
        fail "Checksum mismatch for $(basename "$file"); it was not installed."
        return 1
    fi
    ok "Checksum verified for $(basename "$file")."
}

apt_update
apt_install fonts-jetbrains-mono curl ca-certificates

if command_exists fastfetch; then
    ok "fastfetch is already installed."
elif has_candidate fastfetch; then
    apt_install fastfetch
else
    download_checked \
        "https://github.com/fastfetch-cli/fastfetch/releases/download/$FASTFETCH_VERSION/$FASTFETCH_FILE" \
        "$tmp/fastfetch.deb" "$FASTFETCH_SHA256"
    chmod 644 "$tmp/fastfetch.deb"
    apt_install "$tmp/fastfetch.deb"
fi

if command_exists starship; then
    ok "Starship is already installed."
elif has_candidate starship; then
    apt_install starship
else
    download_checked \
        "https://github.com/starship/starship/releases/download/$STARSHIP_VERSION/$STARSHIP_FILE" \
        "$tmp/starship.tar.gz" "$STARSHIP_SHA256"
    tar -xzf "$tmp/starship.tar.gz" -C "$tmp" starship
    install -m 755 "$tmp/starship" /usr/local/bin/starship
    ok "Starship $STARSHIP_VERSION installed in /usr/local/bin."
fi

ok "Terminal tools installed: Starship, fastfetch and the JetBrains Mono font."
