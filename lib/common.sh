# shellcheck shell=bash
# Variables set here (OS_*, ARCH, DESKTOP, VIRT) are used by the scripts that source it.
# shellcheck disable=SC2034
#
# Shared helpers for setup.sh, verify.sh and tasks/*.sh.
# This file is sourced, not run.

SECLAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Exit codes a task can use besides 0 (OK) and 1 (FAILED).
RC_SKIPPED=3
RC_ACTION=4

info() { printf '[*] %s\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
fail() { printf '[FAILED] %s\n' "$*" >&2; }

# Print a step the student has to do by hand. setup.sh repeats these notes
# in its final summary.
action_needed() {
    printf '[ACTION NEEDED] %s\n' "$*"
    if [ -n "${SECLAB_NOTES:-}" ]; then
        printf '%s\n' "$*" >> "$SECLAB_NOTES"
    fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep 'ok installed' >/dev/null
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        fail "This task changes the system. Run it with sudo: sudo $0"
        exit 1
    fi
}

# The student account that root tasks act for (group membership, CD path).
target_user() {
    local user="${SECLAB_USER:-${SUDO_USER:-}}"
    if [ -z "$user" ] || [ "$user" = root ]; then
        return 1
    fi
    printf '%s\n' "$user"
}

# Sets OS_ID, OS_LIKE, OS_VERSION, OS_NAME, ARCH, DESKTOP and VIRT.
# SECLAB_VIRT overrides the detected hypervisor (used for testing).
detect_env() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
    fi
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
    OS_VERSION="${VERSION_ID:-}"
    OS_NAME="${PRETTY_NAME:-$OS_ID}"

    ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"

    local session="${XDG_CURRENT_DESKTOP:-}"
    case "${session,,}" in
        "")         DESKTOP=none ;;
        *gnome*)    DESKTOP=gnome ;;
        *cinnamon*) DESKTOP=cinnamon ;;
        *xfce*)     DESKTOP=xfce ;;
        *)          DESKTOP=other ;;
    esac

    VIRT="${SECLAB_VIRT:-}"
    if [ -z "$VIRT" ]; then
        VIRT="$(systemd-detect-virt --vm 2>/dev/null || true)"
    fi
    VIRT="${VIRT:-none}"
}

# apt-get without questions. It waits up to 10 minutes for the package lock
# (a fresh VM often runs automatic updates in the background) and keeps
# existing configuration files on upgrades.
apt_get() {
    DEBIAN_FRONTEND=noninteractive apt-get -y \
        -o DPkg::Lock::Timeout=600 \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        "$@"
}

# "apt-get update" ignores DPkg::Lock::Timeout for the package list lock,
# so wait for it here.
apt_update() {
    local try out
    for try in $(seq 1 60); do
        if out="$(apt_get update 2>&1)"; then
            printf '%s\n' "$out"
            return 0
        fi
        if ! grep -q 'Could not get lock' <<< "$out"; then
            printf '%s\n' "$out" >&2
            return 1
        fi
        if [ "$try" -eq 1 ]; then
            info "Another program is updating the package lists (automatic updates). Waiting up to 10 minutes..."
        fi
        sleep 10
    done
    printf '%s\n' "$out" >&2
    return 1
}

# Install packages in one go. If that fails, retry them one at a time and
# name every package that still fails.
apt_install() {
    local pkg failed=()
    if apt_get install "$@"; then
        return 0
    fi
    warn "Installing everything at once failed, retrying one package at a time..."
    for pkg in "$@"; do
        apt_get install "$pkg" || failed+=("$pkg")
    done
    if [ ${#failed[@]} -gt 0 ]; then
        fail "Could not install: ${failed[*]}"
        return 1
    fi
}

# Keyboard layout codes as used by X11 (it, gb, de, ...).
valid_layout() {
    [[ "$1" =~ ^[a-z]{2,6}$ ]] || return 1
    if [ -r /usr/share/X11/xkb/rules/base.lst ]; then
        sed -n '/^! layout/,/^! variant/p' /usr/share/X11/xkb/rules/base.lst | grep "^  $1 " >/dev/null
    fi
}

# Desktop settings. Failures are counted in SETTING_ERRORS so a task can
# apply every other setting first and report the failures at the end.
SETTING_ERRORS=0

# Set a GSettings key only if this desktop version has it.
gset() {
    if ! gsettings range "$1" "$2" >/dev/null 2>&1; then
        info "$1 $2: not on this version, skipped."
    elif gsettings set "$1" "$2" "$3"; then
        ok "$1 $2 = $3"
    else
        SETTING_ERRORS=$((SETTING_ERRORS + 1))
    fi
}

# Set an Xfce setting (created if it does not exist yet).
xset_prop() {
    if xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4"; then
        ok "$1 $2 = $4"
    else
        SETTING_ERRORS=$((SETTING_ERRORS + 1))
    fi
}

# True inside a desktop session that GSettings or Xfconf can talk to.
has_desktop_session() {
    [ "$DESKTOP" != none ] && { [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || [ -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]; }
}

# Run each task in its own process and append "<task>|<status>" to
# $SECLAB_RESULTS. A failing task never stops the ones after it.
run_tasks() {
    local task rc status
    for task in "$@"; do
        printf '\n==> %s\n' "$task"
        rc=0
        bash "$SECLAB_ROOT/tasks/$task.sh" || rc=$?
        case "$rc" in
            0)             status=OK ;;
            "$RC_SKIPPED") status=SKIPPED ;;
            "$RC_ACTION")  status="ACTION NEEDED" ;;
            *)             status=FAILED ;;
        esac
        if [ -n "${SECLAB_RESULTS:-}" ]; then
            printf '%s|%s\n' "$task" "$status" >> "$SECLAB_RESULTS"
        fi
    done
}
