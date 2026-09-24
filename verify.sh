#!/usr/bin/env bash
#
# Computer Security Lab (AY 2026-2027), Prof. Maccari and Prof. Busi.
# Checks that the course tools are installed and that you can capture
# packets. Run it as your normal user: ./verify.sh
# The exit code is 0 only when every course tool is present and packet
# capture works (or only needs a logout).

# "sh verify.sh" starts dash, which cannot run this script: switch to bash.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
detect_env
USER_NAME="$(id -un)"

OK_COUNT=0
FAIL_COUNT=0
NOTICE_COUNT=0

pass()    { printf '  [OK]      %s\n' "$1"; OK_COUNT=$((OK_COUNT + 1)); }
missing() { printf '  [MISSING] %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
notice()  { printf '  [NOTICE]  %s\n' "$1"; NOTICE_COUNT=$((NOTICE_COUNT + 1)); }
note()    { printf '  [INFO]    %s\n' "$1"; }

# Some tools live in sbin, which is not in a normal user's PATH.
resolve_cmd() {
    local dir
    if command -v "$1" 2>/dev/null; then
        return 0
    fi
    for dir in /usr/sbin /sbin /usr/local/sbin; do
        if [ -x "$dir/$1" ]; then
            echo "$dir/$1"
            return 0
        fi
    done
    return 1
}

check_cmd() {
    local path
    if path="$(resolve_cmd "$2")"; then
        pass "$1 ($path)"
    else
        missing "$1 (command: $2)"
    fi
}

echo "=========================================================="
echo " Computer Security Lab (AY 2026-2027) verification"
echo " System: $OS_NAME ($ARCH), user: $USER_NAME"
echo "=========================================================="

echo ""
echo "-- Core tools and editors --"
check_cmd "man" man
check_cmd "less" less
check_cmd "tree" tree
check_cmd "nano" nano
check_cmd "vim" vim

echo ""
echo "-- Networking and diagnostics --"
check_cmd "ip (iproute2)" ip
check_cmd "ss (iproute2)" ss
check_cmd "ifconfig (net-tools)" ifconfig
check_cmd "netstat (net-tools)" netstat
check_cmd "arp (net-tools)" arp
check_cmd "ping" ping
check_cmd "traceroute" traceroute
check_cmd "dig (bind9-dnsutils)" dig
check_cmd "whois" whois
check_cmd "telnet" telnet
check_cmd "curl" curl
check_cmd "wget" wget
check_cmd "ethtool" ethtool

echo ""
echo "-- Security and network analysis --"
check_cmd "nmap" nmap
check_cmd "tcpdump" tcpdump
check_cmd "wireshark" wireshark
check_cmd "tshark" tshark
check_cmd "dumpcap" dumpcap
check_cmd "iptables" iptables
check_cmd "nft (nftables)" nft
check_cmd "nc (netcat-openbsd)" nc
check_cmd "socat" socat
check_cmd "arping" arping
check_cmd "ssh (openssh-client)" ssh
check_cmd "gpg (gnupg)" gpg
check_cmd "openssl" openssl

echo ""
echo "-- Development and debugging --"
check_cmd "gcc (build-essential)" gcc
check_cmd "make (build-essential)" make
check_cmd "gdb" gdb
check_cmd "strace" strace
check_cmd "ltrace" ltrace
check_cmd "python3" python3
check_cmd "pip3 (python3-pip)" pip3
if python3 -c "import venv" >/dev/null 2>&1; then
    pass "python3 venv module (python3-venv)"
else
    missing "python3 venv module (python3-venv)"
fi
check_cmd "perl" perl
check_cmd "git" git
check_cmd "file" file
check_cmd "objdump (binutils)" objdump
check_cmd "xxd" xxd

echo ""
echo "-- Utilities --"
check_cmd "jq" jq
check_cmd "zip" zip
check_cmd "unzip" unzip
check_cmd "xz (xz-utils)" xz
check_cmd "rsync" rsync

echo ""
echo "-- Packet capture without root --"
# A real one-second capture on the loopback interface, as this user.
# On failure CAPTURE_ERROR holds the first line of the error.
CAPTURE_ERROR=""
capture_works() {
    local file rc=0
    file="$(mktemp)"
    CAPTURE_ERROR="$(dumpcap -q -i lo -a duration:1 -w "$file" 2>&1 >/dev/null)" || rc=1
    CAPTURE_ERROR="$(grep -v '^Capturing on' <<< "$CAPTURE_ERROR" | grep -m 1 . | sed 's/^.*line [0-9]*: //')"
    rm -f "$file"
    return "$rc"
}
if ! command_exists dumpcap; then
    missing "Packet capture: dumpcap is not installed (run ./setup.sh)"
elif capture_works; then
    pass "Packet capture works for $USER_NAME"
elif id -nG "$USER_NAME" | grep -qw wireshark && ! id -nG | grep -qw wireshark; then
    notice "$USER_NAME was just added to the wireshark group. Log out and back in (or reboot), then run ./verify.sh again."
else
    missing "Packet capture fails for $USER_NAME ($CAPTURE_ERROR). Run: sudo ./tasks/wireshark.sh, then log out and back in."
fi

echo ""
echo "-- VM integration (information only) --"
case "$VIRT" in
    oracle) service=VBoxService ;;
    vmware) service=vmtoolsd ;;
    qemu|kvm) service=spice-vdagent ;;
    *) service="" ;;
esac
if [ -z "$service" ]; then
    note "Virtualization: $VIRT, no guest tools expected."
elif pgrep -x "$service" >/dev/null 2>&1; then
    note "Guest tools are running ($service)."
else
    note "Guest tools ($service) are not running yet. Reboot after ./setup.sh; on VirtualBox check the graphics controller is VMSVGA."
fi

echo ""
echo "-- Desktop (information only) --"
case "$DESKTOP" in
    gnome)
        note "Text size $(gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null || echo unknown), keyboard $(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null || echo unknown)"
        ;;
    cinnamon)
        note "Text size $(gsettings get org.cinnamon.desktop.interface text-scaling-factor 2>/dev/null || echo unknown), keyboard $(gsettings get org.gnome.libgnomekbd.keyboard layouts 2>/dev/null || echo unknown)"
        ;;
    xfce)
        note "DPI $(xfconf-query -c xsettings -p /Xft/DPI 2>/dev/null || echo default), keyboard $(xfconf-query -c keyboard-layout -p /Default/XkbLayout 2>/dev/null || echo default)"
        ;;
    *)
        note "No supported desktop session in this terminal."
        ;;
esac

echo ""
echo "=========================================================="
echo " Verification summary"
echo "=========================================================="
echo " OK:      $OK_COUNT"
echo " Missing: $FAIL_COUNT"
echo " Notices: $NOTICE_COUNT"
echo "=========================================================="
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "[OK] The VM is ready for the lab."
    exit 0
fi
echo "[FAILED] Something is missing. Run ./setup.sh again, or see Troubleshooting in README.md."
exit 1
