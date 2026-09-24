#!/usr/bin/env bash
#
# Set the system keyboard layout used by the login screen and the text
# console (root). The chosen layout comes first, US English stays second.
# Usage: sudo SECLAB_KEYBOARD=it ./tasks/keyboard.sh
#
# localectl cannot change the layout on Ubuntu and Mint, so this edits
# /etc/default/keyboard, which the login screen and Xorg read.

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
require_root

layout="${SECLAB_KEYBOARD:-}"
if [ -z "$layout" ]; then
    info "No keyboard layout chosen, keeping the current one."
    exit "$RC_SKIPPED"
fi
if ! valid_layout "$layout"; then
    fail "Unknown keyboard layout code '$layout' (examples: it, gb, de, fr, es, ch, pt)."
    exit 1
fi

if [ "$layout" = us ]; then
    layouts=us
    variants=""
else
    layouts="$layout,us"
    variants=","
fi

if [ ! -f /etc/default/keyboard ]; then
    apt_update
    apt_install keyboard-configuration
fi

sed -i -e "s/^XKBLAYOUT=.*/XKBLAYOUT=\"$layouts\"/" \
       -e "s/^XKBVARIANT=.*/XKBVARIANT=\"$variants\"/" /etc/default/keyboard
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive keyboard-configuration
ok "Keyboard layouts: $layouts (login screen and text console, after a reboot)."
