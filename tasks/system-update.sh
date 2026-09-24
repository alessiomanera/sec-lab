#!/usr/bin/env bash
#
# Install all available updates for the system (root).
#
# nala shows a clear summary and downloads in parallel. apt-get runs after
# it because nala neither waits for the package lock nor reports it: it can
# end with "Finished Successfully" without upgrading anything (nala 0.11 and
# 0.15). apt-get finishes whatever nala did not do and gives the real result.

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
require_root

info "Refreshing the package lists..."
apt_update

if pkg_installed nala || apt_install nala; then
    info "Installing all available updates with nala (on a fresh VM this can take a while)..."
    DEBIAN_FRONTEND=noninteractive nala upgrade -y --full \
        -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
        || warn "nala stopped early; apt-get finishes the update."
else
    warn "nala could not be installed; updating with apt-get only."
fi

info "Checking that every update is installed..."
apt_get full-upgrade
apt_get autoremove

if command_exists snap && systemctl is-active --quiet snapd 2>/dev/null; then
    info "Updating snap packages..."
    snap refresh || warn "snap refresh failed; Ubuntu retries it automatically later."
fi

ok "The system is up to date."
