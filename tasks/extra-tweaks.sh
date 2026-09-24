#!/usr/bin/env bash
#
# Optional: GNOME Tweaks and Extension Manager (root, GNOME only).

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
require_root

if ! command_exists gnome-shell; then
    info "GNOME Tweaks and Extension Manager are only for the GNOME desktop, skipped."
    exit "$RC_SKIPPED"
fi

apt_update
apt_install gnome-tweaks gnome-shell-extension-manager
ok "GNOME Tweaks and Extension Manager installed."
