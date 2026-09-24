#!/usr/bin/env bash
#
# Let the student capture packets with Wireshark without root (root).
# The wireshark-common package does the real work (wireshark group,
# dumpcap owned by root:wireshark with capture capabilities); we only
# answer its question with "yes" and add the student to the group.

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
require_root

if ! user="$(target_user)"; then
    fail "Cannot tell which user to add to the wireshark group. Run this as: sudo $0"
    exit 1
fi

echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

if ! pkg_installed wireshark; then
    apt_update
    apt_install wireshark
fi

DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive wireshark-common
usermod -aG wireshark "$user"
ok "$user can capture packets with Wireshark after the next login."
