#!/usr/bin/env bash
#
# Install all available updates for the system (root).

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
require_root

info "Refreshing the package lists..."
apt_update

info "Installing all available updates (on a fresh VM this can take a while)..."
apt_get full-upgrade
apt_get autoremove

if command_exists snap && systemctl is-active --quiet snapd 2>/dev/null; then
    info "Updating snap packages..."
    snap refresh || warn "snap refresh failed; Ubuntu retries it automatically later."
fi

ok "The system is up to date."
