#!/usr/bin/env bash
#
# Optional: install Visual Studio Code (root), following Microsoft's
# instructions for Debian and Ubuntu: install the official .deb and let
# it add Microsoft's apt repository, so VS Code updates with the system.

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
require_root
detect_env

if pkg_installed code; then
    ok "VS Code is already installed; it updates together with the system."
    exit 0
fi

case "$ARCH" in
    amd64) build=linux-deb-x64 ;;
    arm64) build=linux-deb-arm64 ;;
    *)     fail "VS Code is not available for $ARCH."; exit 1 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
chmod 755 "$tmp"

# Answer "yes" to the package's question about adding the Microsoft repository.
echo "code code/add-microsoft-repo boolean true" | debconf-set-selections

apt_update
# The package script needs gpg to write the repository key, but does not depend on it.
apt_install curl ca-certificates gpg
info "Downloading VS Code from code.visualstudio.com..."
curl -fL --retry 3 -o "$tmp/code.deb" "https://code.visualstudio.com/sha/download?build=stable&os=$build"
chmod 644 "$tmp/code.deb"
apt_install "$tmp/code.deb"
ok "VS Code installed. Start it from the app menu or with: code"
