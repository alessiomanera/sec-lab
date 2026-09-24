#!/usr/bin/env bash
#
# Computer Security Lab (AY 2026-2027), Prof. Maccari and Prof. Busi.
# Post-install setup for student Ubuntu and Linux Mint virtual machines.
#
# Run it as your normal user from the sec-lab folder:
#   ./setup.sh          choose what to set up in a menu
#   ./setup.sh --yes    use the recommended choices without questions

# "sh setup.sh" starts dash, which cannot run this script: switch to bash.
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

LOG="$HOME/sec-lab-setup.log"
ASSUME_YES=false
CHOICES=""
KEYBOARD=""
SIZE=125

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--yes]

Sets up this VM for the Computer Security Lab: system update, guest tools,
course tools and Wireshark, keyboard layout, terminal and desktop settings.
Run it as your normal user; it asks for your password once.

  -y, --yes   use the recommended choices, keep the keyboard layout, no questions
  -h, --help  show this help
EOF
}

for arg in "$@"; do
    case "$arg" in
        -y|--yes)  ASSUME_YES=true ;;
        -h|--help) usage; exit 0 ;;
        *)         fail "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    fail "Run ./setup.sh as your normal user, not with sudo or as root. It asks for your password once when it needs it."
    exit 1
fi

has() { [[ " $CHOICES " == *" $1 "* ]]; }

preflight() {
    local mem_kb free_kb
    echo "=========================================================="
    echo " Computer Security Lab (AY 2026-2027) setup"
    echo "=========================================================="
    echo " System:  $OS_NAME ($ARCH)"
    echo " VM:      $VIRT"
    echo " Desktop: ${XDG_CURRENT_DESKTOP:-none}"
    echo "=========================================================="

    case "$OS_ID" in
        ubuntu)
            case "$OS_VERSION" in
                22.04|24.04|26.04) ;;
                *) warn "Ubuntu $OS_VERSION is not a tested release (tested: 22.04, 24.04 and 26.04 LTS)." ;;
            esac
            ;;
        linuxmint)
            case "$OS_VERSION" in
                22|22.*) ;;
                *) warn "Linux Mint $OS_VERSION is not a tested release (tested: 22.x)." ;;
            esac
            ;;
        *)
            if [[ " $OS_LIKE " == *" ubuntu "* || " $OS_LIKE " == *" debian "* ]]; then
                warn "$OS_NAME is not Ubuntu or Linux Mint. The setup may work, but it is not tested there."
            else
                fail "$OS_NAME is not supported. Use Ubuntu or Linux Mint."
                exit 1
            fi
            ;;
    esac
    case "$ARCH" in
        amd64|arm64) ;;
        *) fail "Unsupported architecture $ARCH (only amd64 and arm64)."; exit 1 ;;
    esac
    if ! command_exists sudo; then
        fail "sudo is missing. Install Ubuntu or Linux Mint with the normal desktop installer."
        exit 1
    fi

    case "$DESKTOP" in
        none)  warn "No desktop session found (for example over SSH): desktop settings will be skipped. Run ./setup.sh in a terminal inside the VM desktop to get them." ;;
        other) warn "The desktop '$XDG_CURRENT_DESKTOP' is not supported: only system changes will be made." ;;
    esac
    if ! getent hosts archive.ubuntu.com >/dev/null 2>&1; then
        warn "No internet connection (archive.ubuntu.com cannot be found). Check that the VM network adapter is set to NAT."
    fi
    mem_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
    if [ "$mem_kb" -lt 3500000 ]; then
        warn "The VM has less than 4 GB of memory ($((mem_kb / 1024)) MB). With the VM powered off, give it at least 4096 MB."
    fi
    if [ "$(nproc)" -lt 2 ]; then
        warn "The VM has only 1 CPU. With the VM powered off, give it at least 2."
    fi
    free_kb="$(df -Pk / | awk 'NR == 2 {print $4}')"
    if [ "$free_kb" -lt $((15 * 1024 * 1024)) ]; then
        warn "Less than 15 GB of free disk space ($((free_kb / 1024 / 1024)) GB). The updates and tools may not fit."
    fi
    if [ "$VIRT" = oracle ] && [ "$ARCH" = amd64 ] && command_exists lspci; then
        if ! lspci | grep -i 'VMware SVGA II' >/dev/null; then
            warn "The VirtualBox graphics controller is not VMSVGA, so the VM window stays small and does not resize. Power off the VM, set Settings > Display > Graphics Controller to VMSVGA, then run ./setup.sh again."
        fi
    fi
}

# Menu entries as "tag|label|default". Desktop entries are shown only where
# they do something.
menu_items() {
    echo "update|Update the whole system (with nala)|on"
    echo "guest|VM guest tools: resizable window, shared clipboard|on"
    echo "course|Course tools and Wireshark capture permission|on"
    echo "keyboard|Keyboard layout (asked next)|on"
    echo "terminal|Nice terminal: Starship prompt, fastfetch, JetBrains Mono font|on"
    case "$DESKTOP" in
        gnome|cinnamon|xfce)
            echo "text|Bigger text (size asked next)|on"
            echo "dark|Dark theme|on"
            ;;
    esac
    if [ "$DESKTOP" = gnome ]; then
        echo "dock|Dock at the bottom, click an icon to minimize|on"
    fi
    case "$DESKTOP" in
        gnome|cinnamon)
            echo "animations|Turn off animations (smoother in a VM)|on"
            ;;
    esac
    case "$DESKTOP" in
        gnome|cinnamon|xfce)
            echo "nolock|No screen lock or blank screen in the VM|on"
            ;;
    esac
    case "$DESKTOP" in
        gnome|cinnamon)
            echo "pin|Pin Terminal and Wireshark to the favorites|on"
            ;;
    esac
    echo "vscode|Extra: Visual Studio Code|off"
    if [ "$DESKTOP" = gnome ]; then
        echo "tweaks|Extra: GNOME Tweaks and Extension Manager|off"
    fi
}

describe_choices() {
    local tag label default
    while IFS='|' read -r tag label default; do
        if ! has "$tag"; then
            continue
        fi
        case "$tag" in
            keyboard) echo "  - Keyboard layout: $KEYBOARD first, US English second" ;;
            text)     echo "  - Text size: $SIZE%" ;;
            *)        echo "  - $label" ;;
        esac
    done < <(menu_items)
}

menu_whiptail() {
    local tag label default args=() picked
    while IFS='|' read -r tag label default; do
        args+=("$tag" "$label" "${default^^}")
    done < <(menu_items)
    picked="$(whiptail --title "Computer Security Lab setup" --separate-output --checklist \
        "Space ticks or unticks an item, Enter continues. The recommended items are already ticked." \
        20 76 12 "${args[@]}" 3>&1 1>&2 2>&3)" || return 1
    CHOICES="$(tr '\n' ' ' <<< "$picked")"

    if has keyboard; then
        KEYBOARD="$(whiptail --title "Keyboard layout" --radiolist \
            "The layout you pick becomes the main one; US English stays as the second layout." \
            18 70 9 \
            keep "Keep the current layout" ON \
            it "Italian" OFF \
            gb "English (UK)" OFF \
            de "German" OFF \
            fr "French" OFF \
            es "Spanish" OFF \
            ch "Swiss" OFF \
            pt "Portuguese" OFF \
            other "Other (type the layout code)" OFF 3>&1 1>&2 2>&3)" || return 1
        while [ "$KEYBOARD" = other ] || { [ "$KEYBOARD" != keep ] && ! valid_layout "$KEYBOARD"; }; do
            KEYBOARD="$(whiptail --title "Keyboard layout" --inputbox \
                "Type the layout code, for example: us, it, gb, de, fr, es, ch, pt, nl, se, pl" \
                10 70 3>&1 1>&2 2>&3)" || return 1
        done
    fi
    if has text; then
        SIZE="$(whiptail --title "Text size" --radiolist "How big should the text be?" 14 60 4 \
            100 "100% (normal)" OFF \
            125 "125% (recommended)" ON \
            150 "150%" OFF \
            175 "175% (for very high resolution screens)" OFF 3>&1 1>&2 2>&3)" || return 1
    fi
    if [ "$KEYBOARD" = keep ]; then
        KEYBOARD=""
        CHOICES="${CHOICES/keyboard/}"
    fi
    whiptail --title "Ready to start" --yesno \
        "These changes will be made:\n\n$(describe_choices)\n\nIt can take 10 to 30 minutes. Start now?" 22 76
}

# Asks "question [Y/n]"; the second argument is the default (on or off).
ask() {
    local answer hint="[y/N]"
    if [ "$2" = on ]; then
        hint="[Y/n]"
    fi
    read -r -p "$1? $hint " answer
    if [ -z "$answer" ]; then
        [ "$2" = on ]
    else
        [[ "$answer" =~ ^[yY] ]]
    fi
}

menu_plain() {
    local item tag label default items=()
    mapfile -t items < <(menu_items)
    echo "Answer each question; Enter keeps the suggestion shown in capitals."
    for item in "${items[@]}"; do
        IFS='|' read -r tag label default <<< "$item"
        if ask "$label" "$default"; then
            CHOICES+=" $tag"
        fi
    done
    if has keyboard; then
        while true; do
            read -r -p "Keyboard layout code (it, gb, de, fr, es, ch, pt, ...), Enter keeps the current one: " KEYBOARD
            if [ -z "$KEYBOARD" ] || valid_layout "$KEYBOARD"; then
                break
            fi
            echo "Unknown layout code '$KEYBOARD'."
        done
        if [ -z "$KEYBOARD" ]; then
            CHOICES="${CHOICES/keyboard/}"
        fi
    fi
    if has text; then
        read -r -p "Text size in percent, 100, 125, 150 or 175 [125]: " SIZE
        case "${SIZE:=125}" in
            100|125|150|175) ;;
            *) echo "Using 125%."; SIZE=125 ;;
        esac
    fi
    echo "These changes will be made:"
    describe_choices
    ask "Start now" on
}

detect_env
preflight

if $ASSUME_YES; then
    while IFS='|' read -r tag _ default; do
        if [ "$default" = on ] && [ "$tag" != keyboard ]; then
            CHOICES+=" $tag"
        fi
    done < <(menu_items)
elif [ ! -t 0 ]; then
    info "No terminal to ask questions in. Run ./setup.sh in a terminal, or ./setup.sh --yes for the recommended choices."
    exit 0
elif command_exists whiptail; then
    menu_whiptail || { info "Cancelled, nothing was changed."; exit 0; }
else
    menu_plain || { info "Cancelled, nothing was changed."; exit 0; }
fi

# Everything from here on is also written to the log file.
exec > >(tee -a "$LOG") 2>&1
echo ""
echo "==== sec-lab setup started $(date '+%Y-%m-%d %H:%M'), log: $LOG"
echo "Choices:"
describe_choices

ROOT_TASKS=()
if has update; then ROOT_TASKS+=(system-update); fi
if has guest; then ROOT_TASKS+=(guest-tools); fi
if has course; then ROOT_TASKS+=(course-tools wireshark); fi
if has keyboard; then ROOT_TASKS+=(keyboard); fi
if has terminal; then ROOT_TASKS+=(terminal-tools); fi
if has vscode; then ROOT_TASKS+=(extra-vscode); fi
if has tweaks; then ROOT_TASKS+=(extra-tweaks); fi

DESKTOP_ITEMS=""
for item in text dark dock animations nolock pin; do
    if has "$item"; then DESKTOP_ITEMS+=" $item"; fi
done
USER_TASKS=()
if [ -n "$DESKTOP_ITEMS" ] || [ -n "$KEYBOARD" ]; then USER_TASKS+=(desktop); fi
if has terminal; then USER_TASKS+=(terminal-profile); fi

# Task results and notes, written by the root tasks too. They live in a
# private directory because root may not write to a user's file directly
# in /tmp (fs.protected_regular).
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
SECLAB_RESULTS="$WORK_DIR/results"
SECLAB_NOTES="$WORK_DIR/notes"
: > "$SECLAB_RESULTS"
: > "$SECLAB_NOTES"
export SECLAB_RESULTS SECLAB_NOTES

# All system tasks run in one sudo call, so a long update never stops
# halfway to ask for the password again.
if [ ${#ROOT_TASKS[@]} -gt 0 ]; then
    echo ""
    info "Administrator rights are needed for the system changes. Type your password if asked."
    # shellcheck disable=SC2016 # expanded by the root shell, not here
    sudo env SECLAB_USER="$(id -un)" SECLAB_KEYBOARD="$KEYBOARD" SECLAB_VIRT="${SECLAB_VIRT:-}" \
        SECLAB_RESULTS="$SECLAB_RESULTS" SECLAB_NOTES="$SECLAB_NOTES" \
        bash -c '. "$1"; shift; run_tasks "$@"' seclab "$SECLAB_ROOT/lib/common.sh" "${ROOT_TASKS[@]}" \
        || fail "Could not run the system tasks with sudo."
fi

if [ ${#USER_TASKS[@]} -gt 0 ]; then
    export SECLAB_DESKTOP_ITEMS="${DESKTOP_ITEMS# }" SECLAB_TEXT_SIZE="$SIZE" SECLAB_KEYBOARD="$KEYBOARD"
    run_tasks "${USER_TASKS[@]}"
fi

printf '\n==> verify\n'
verify_rc=0
bash "$SECLAB_ROOT/verify.sh" || verify_rc=$?

label_of() {
    case "$1" in
        system-update)    echo "System update" ;;
        guest-tools)      echo "VM guest tools" ;;
        course-tools)     echo "Course tools" ;;
        wireshark)        echo "Wireshark capture permission" ;;
        keyboard)         echo "Keyboard layout" ;;
        terminal-tools)   echo "Terminal tools" ;;
        terminal-profile) echo "Terminal profile" ;;
        desktop)          echo "Desktop settings" ;;
        extra-vscode)     echo "VS Code" ;;
        extra-tweaks)     echo "GNOME Tweaks" ;;
        *)                echo "$1" ;;
    esac
}

problems=0
echo ""
echo "=========================================================="
echo " Setup summary"
echo "=========================================================="
for task in "${ROOT_TASKS[@]}" "${USER_TASKS[@]}"; do
    status="$(grep "^$task|" "$SECLAB_RESULTS" | tail -n 1 | cut -d '|' -f 2 || true)"
    status="${status:-NOT RUN}"
    case "$status" in
        FAILED|"NOT RUN") problems=$((problems + 1)) ;;
    esac
    printf ' %-30s %s\n' "$(label_of "$task")" "$status"
done
if [ "$verify_rc" -eq 0 ]; then
    printf ' %-30s %s\n' "Verification" "OK"
else
    printf ' %-30s %s\n' "Verification" "FAILED"
    problems=$((problems + 1))
fi
echo "=========================================================="
if [ -s "$SECLAB_NOTES" ]; then
    echo "Still to do:"
    sed 's/^/  - /' "$SECLAB_NOTES"
fi
if [ "$problems" -gt 0 ]; then
    echo "[!] Some steps failed. Read the messages above (also in $LOG),"
    echo "    fix the problem and run ./setup.sh again; finished steps go quickly the second time."
else
    echo "[OK] Setup finished."
fi
echo "Restart the VM so every change takes effect (guest tools, groups, keyboard, updates)."
echo "After the restart, run ./verify.sh and take a VirtualBox snapshot as your clean lab baseline."

if ! $ASSUME_YES && [ -t 0 ]; then
    read -r -p "Restart now? [Y/n] " answer || answer=n
    if [[ "${answer:-y}" =~ ^[yY] ]]; then
        systemctl reboot || warn "Could not restart automatically. Restart the VM from the system menu."
    fi
fi

[ "$problems" -eq 0 ]
