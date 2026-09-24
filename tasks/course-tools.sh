#!/usr/bin/env bash
#
# Install the course tools listed in packages/packages.txt (root).

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
require_root

# One package per line; comments, blank lines and Windows line endings are ignored.
mapfile -t packages < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "$SECLAB_ROOT/packages/packages.txt")

info "Installing ${#packages[@]} course packages..."
apt_update
apt_install "${packages[@]}"
ok "All course packages are installed."
