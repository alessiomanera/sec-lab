#!/usr/bin/env bash
#
# Computer Security Lab (AY 2026-2027)
# Post-install setup script for Ubuntu and Linux Mint
# Instructors: Prof. Maccari / Prof. Busi
#

set -euo pipefail

# Ensure script is executed with root privileges
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        echo "[*] Root privileges required. Re-running with sudo..."
        exec sudo bash "$0" "$@"
    else
        echo "[-] Error: Root privileges are required to install packages, and 'sudo' was not found." >&2
        exit 1
    fi
fi

# Identify the invoking student user
TARGET_USER="${SUDO_USER:-${USER:-$(id -un 2>/dev/null || echo "student")}}"
if [ "$TARGET_USER" = "root" ] && [ -n "${LOGNAME:-}" ] && [ "$LOGNAME" != "root" ]; then
    TARGET_USER="$LOGNAME"
fi

# Detect operating system
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
else
    echo "[-] Error: Unable to identify operating system (/etc/os-release not found)." >&2
    exit 1
fi

OS_ID="${ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"
OS_NAME="${PRETTY_NAME:-$OS_ID}"

# Validate Debian/Ubuntu family
IS_DEBIAN_FAMILY=false
if [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "linuxmint" ] || [ "$OS_ID" = "debian" ]; then
    IS_DEBIAN_FAMILY=true
elif echo "$OS_LIKE" | grep -Eq "(ubuntu|debian)"; then
    IS_DEBIAN_FAMILY=true
fi

if [ "$IS_DEBIAN_FAMILY" = false ]; then
    echo "[-] Error: Unsupported distribution '$OS_NAME'." >&2
    echo "    This setup script is designed for Ubuntu and Linux Mint." >&2
    exit 1
fi

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
        echo "[-] Error: Unsupported architecture '$RAW_ARCH'." >&2
        echo "    Supported architectures: amd64 (x86-64) and arm64 (aarch64)." >&2
        exit 1
        ;;
esac

# Locate package manifest
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/packages/packages.txt"

if [ ! -f "$MANIFEST" ]; then
    echo "[-] Error: Package manifest '$MANIFEST' not found." >&2
    exit 1
fi

# Display header
echo "=========================================================="
echo " Computer Security Lab (AY 2026-2027) - Setup"
echo " Instructors: Prof. Maccari / Prof. Busi"
echo "=========================================================="
echo " Detected OS:           $OS_NAME"
echo " Detected Architecture: $ARCH"
echo " Target Student User:   $TARGET_USER"
echo "=========================================================="

if [ "$OS_ID" = "linuxmint" ] && [ "$ARCH" = "arm64" ]; then
    echo "[!] Notice: Linux Mint on ARM64 detected."
    echo "    Official Mint releases target amd64; please ensure your"
    echo "    ARM64 repository sources are correctly configured."
    echo ""
fi

# Parse command line flags
ASSUME_YES=false
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            ASSUME_YES=true
            ;;
    esac
done

# Prompt for confirmation if running interactively
if [ "$ASSUME_YES" = false ] && [ -t 0 ]; then
    read -r -p "Proceed with package installation and configuration? [Y/n] " CONFIRM
    CONFIRM="${CONFIRM:-y}"
    case "$CONFIRM" in
        [yY]|[yY][eE][sS])
            ;;
        *)
            echo "[*] Installation cancelled by user."
            exit 0
            ;;
    esac
fi

# 1. Update package lists
echo ""
echo "[1/4] Updating package repositories..."
apt-get update -y

# 2. Pre-configure Wireshark debconf to avoid interactive prompts
echo ""
echo "[2/4] Pre-configuring debconf for Wireshark..."
if command -v debconf-set-selections >/dev/null 2>&1; then
    echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
fi

# 3. Read package manifest and classify
echo ""
echo "[3/4] Checking and installing course packages..."

declare -a PACKAGES=()
while IFS= read -r line || [ -n "$line" ]; do
    # Strip carriage returns and leading/trailing whitespace
    clean_line="$(echo "$line" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    # Ignore empty lines and comments
    if [ -z "$clean_line" ] || [[ "$clean_line" =~ ^# ]]; then
        continue
    fi
    PACKAGES+=("$clean_line")
done < "$MANIFEST"

declare -a TO_INSTALL=()
declare -a ALREADY_PRESENT=()
declare -a SKIPPED=()
declare -a FAILED=()

for pkg in "${PACKAGES[@]}"; do
    # Check if package exists in repository for current architecture
    if ! apt-cache show "$pkg" >/dev/null 2>&1; then
        echo "    [SKIP] '$pkg' is not available in repositories for $ARCH."
        SKIPPED+=("$pkg (unavailable on $ARCH)")
        continue
    fi

    # Check if already installed
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        ALREADY_PRESENT+=("$pkg")
    else
        TO_INSTALL+=("$pkg")
    fi
done

if [ ${#TO_INSTALL[@]} -gt 0 ]; then
    echo "    Installing ${#TO_INSTALL[@]} new packages: ${TO_INSTALL[*]}"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "${TO_INSTALL[@]}"; then
        echo "    [OK] Packages installed successfully."
    else
        echo "[-] Warning: Batch installation had errors. Trying individual package recovery..."
        for pkg in "${TO_INSTALL[@]}"; do
            if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"; then
                :
            else
                echo "[-] Failed to install: $pkg"
                FAILED+=("$pkg")
            fi
        done
    fi
else
    echo "    [+] All selected packages are already installed."
fi

# 4. Wireshark permission configuration
echo ""
echo "[4/4] Configuring Wireshark packet capture permissions..."

# Ensure the wireshark group exists
if ! getent group wireshark >/dev/null 2>&1; then
    groupadd -r wireshark || true
fi

# Add student user to wireshark group
if [ "$TARGET_USER" != "root" ] && id "$TARGET_USER" >/dev/null 2>&1; then
    usermod -aG wireshark "$TARGET_USER"
    echo "    [+] Added '$TARGET_USER' to 'wireshark' group."
fi

# Configure dumpcap binary permissions if present
if [ -x /usr/bin/dumpcap ]; then
    chgrp wireshark /usr/bin/dumpcap 2>/dev/null || true
    chmod 750 /usr/bin/dumpcap 2>/dev/null || true
    if command -v setcap >/dev/null 2>&1; then
        if setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap 2>/dev/null; then
            echo "    [+] Configured packet capture capabilities on /usr/bin/dumpcap."
        else
            chmod u+s /usr/bin/dumpcap 2>/dev/null || true
            echo "    [+] Set fallback SUID on /usr/bin/dumpcap."
        fi
    else
        chmod u+s /usr/bin/dumpcap 2>/dev/null || true
        echo "    [+] Set fallback SUID on /usr/bin/dumpcap."
    fi
fi

# Run verification checks
echo ""
if [ -x "$SCRIPT_DIR/verify.sh" ]; then
    echo "=========================================================="
    echo " Running Verification Checks"
    echo "=========================================================="
    "$SCRIPT_DIR/verify.sh" || true
fi

# Print final summary
echo ""
echo "=========================================================="
echo " Setup Summary"
echo "=========================================================="
echo " Detected Architecture:     $ARCH"
echo " Packages Already Present:  ${#ALREADY_PRESENT[@]}"
echo " Packages Newly Installed:  $((${#TO_INSTALL[@]} - ${#FAILED[@]}))"

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo " Packages Skipped:          ${#SKIPPED[@]}"
    for s in "${SKIPPED[@]}"; do
        echo "   - $s"
    done
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo " Packages Failed:           ${#FAILED[@]}"
    for f in "${FAILED[@]}"; do
        echo "   - $f"
    done
fi

echo "=========================================================="
if [ ${#FAILED[@]} -eq 0 ]; then
    echo "[+] Setup completed successfully."
else
    echo "[!] Setup completed with warnings. Check failed packages above."
fi
echo ""
echo "[IMPORTANT] To run Wireshark without sudo, please log out"
echo "            and log back into your session (or reboot the VM)"
echo "            so your new group membership takes effect."
echo "=========================================================="
