#!/usr/bin/env bash
#
# Computer Security Lab (AY 2026-2027)
# Verification script for installed course tools
# Instructors: Prof. Maccari / Prof. Busi
#

set -euo pipefail

# Detect architecture
RAW_ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$RAW_ARCH" in
    x86_64|amd64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        ARCH="$RAW_ARCH"
        ;;
esac

CURRENT_USER="${USER:-$(id -un 2>/dev/null || echo "student")}"

echo "=========================================================="
echo " Computer Security Lab (AY 2026-2027) - Verification"
echo " Detected Architecture: $ARCH"
echo " Current User:          $CURRENT_USER"
echo "=========================================================="

OK_COUNT=0
MISSING_COUNT=0
SKIPPED_COUNT=0

resolve_cmd() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        command -v "$cmd"
    elif [ -x "/usr/sbin/$cmd" ]; then
        echo "/usr/sbin/$cmd"
    elif [ -x "/sbin/$cmd" ]; then
        echo "/sbin/$cmd"
    elif [ -x "/usr/local/sbin/$cmd" ]; then
        echo "/usr/local/sbin/$cmd"
    else
        return 1
    fi
}

check_cmd() {
    local label="$1"
    local cmd="$2"
    local note="${3:-}"
    local path

    if path="$(resolve_cmd "$cmd")"; then
        echo "  [OK]      $label ($path)"
        OK_COUNT=$((OK_COUNT + 1))
    else
        if [ -n "$note" ]; then
            echo "  [SKIP]    $label ($note)"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        else
            echo "  [MISSING] $label (command: $cmd)"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        fi
    fi
}

check_python_venv() {
    if python3 -c "import venv" >/dev/null 2>&1; then
        echo "  [OK]      python3 venv module (import venv)"
        OK_COUNT=$((OK_COUNT + 1))
    else
        echo "  [MISSING] python3 venv module (python3-venv)"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
}

echo ""
echo "-- Core CLI Tools & Editors --"
check_cmd "man" "man"
check_cmd "less" "less"
check_cmd "tree" "tree"
check_cmd "nano" "nano"
check_cmd "vim" "vim"

echo ""
echo "-- Networking & Diagnostics --"
check_cmd "ip (iproute2)" "ip"
check_cmd "ss (iproute2)" "ss"
check_cmd "ifconfig (net-tools)" "ifconfig"
check_cmd "netstat (net-tools)" "netstat"
check_cmd "arp (net-tools)" "arp"
check_cmd "ping" "ping"
check_cmd "traceroute" "traceroute"
check_cmd "dig (dnsutils)" "dig"
check_cmd "whois" "whois"
check_cmd "telnet" "telnet"
check_cmd "curl" "curl"
check_cmd "wget" "wget"
check_cmd "ethtool" "ethtool"

echo ""
echo "-- Security & Network Analysis --"
check_cmd "nmap" "nmap"
check_cmd "tcpdump" "tcpdump"
check_cmd "wireshark" "wireshark"
check_cmd "tshark" "tshark"
check_cmd "dumpcap" "dumpcap"
check_cmd "iptables" "iptables"
check_cmd "nft (nftables)" "nft"
check_cmd "nc (netcat)" "nc"
check_cmd "socat" "socat"
check_cmd "arping" "arping"
check_cmd "ssh (openssh-client)" "ssh"
check_cmd "gpg (gnupg)" "gpg"
check_cmd "openssl" "openssl"

echo ""
echo "-- Development, Debugging & Scripting --"
check_cmd "gcc (build-essential)" "gcc"
check_cmd "make (build-essential)" "make"
check_cmd "gdb" "gdb"
check_cmd "strace" "strace"
if [ "$ARCH" = "arm64" ]; then
    check_cmd "ltrace" "ltrace" "upstream ARM64 limitation, skipped"
else
    check_cmd "ltrace" "ltrace"
fi
check_cmd "python3" "python3"
check_cmd "pip3 (python3-pip)" "pip3"
check_python_venv
check_cmd "perl" "perl"
check_cmd "git" "git"
check_cmd "file" "file"
check_cmd "objdump (binutils)" "objdump"
check_cmd "xxd" "xxd"

echo ""
echo "-- Utilities & Formats --"
check_cmd "jq" "jq"
check_cmd "zip" "zip"
check_cmd "unzip" "unzip"
check_cmd "rsync" "rsync"

echo ""
echo "-- Wireshark Non-Root Configuration --"
if id -nG 2>/dev/null | grep -qw "wireshark"; then
    echo "  [OK]      User '$CURRENT_USER' is a member of the 'wireshark' group."
else
    echo "  [NOTICE]  User '$CURRENT_USER' is not active in the 'wireshark' group in this shell."
    echo "            If setup.sh was recently run, please log out and back in,"
    echo "            or run 'newgrp wireshark' to activate group membership."
fi

if [ -x /usr/bin/dumpcap ]; then
    echo "  [OK]      /usr/bin/dumpcap binary is present and executable."
else
    echo "  [MISSING] /usr/bin/dumpcap not found."
fi

echo ""
echo "=========================================================="
echo " Verification Summary"
echo "=========================================================="
echo " Available: $OK_COUNT"
echo " Missing:   $MISSING_COUNT"
echo " Skipped:   $SKIPPED_COUNT"
echo "=========================================================="

if [ "$MISSING_COUNT" -eq 0 ]; then
    echo "[+] All required tools are verified and ready for the lab."
    exit 0
else
    echo "[-] Some required tools are missing. Run ./setup.sh to install them."
    exit 1
fi
