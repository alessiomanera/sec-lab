#!/usr/bin/env bash
#
# Desktop look and feel for the current user (run as the student, inside
# the desktop, not with sudo). Supports GNOME (Ubuntu), Cinnamon and Xfce
# (Linux Mint). Settings that do not exist on this desktop version are
# skipped.
#
# Options (environment variables):
#   SECLAB_DESKTOP_ITEMS  which changes to make, default:
#                         "text dark dock animations nolock pin"
#   SECLAB_TEXT_SIZE      text size in percent: 100, 125 (default), 150, 175
#   SECLAB_KEYBOARD       keyboard layout code to put first, US stays second
# Example, only make the text bigger:
#   SECLAB_DESKTOP_ITEMS=text SECLAB_TEXT_SIZE=150 ./tasks/desktop.sh

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

if [ "$(id -u)" -eq 0 ]; then
    fail "Run this as your normal user, without sudo."
    exit 1
fi
detect_env
if [ "$DESKTOP" = none ] || { [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]; }; then
    info "No desktop session found (for example over SSH). Run ./tasks/desktop.sh from a terminal inside the desktop."
    exit "$RC_SKIPPED"
fi

# An empty SECLAB_DESKTOP_ITEMS means "no items"; only an unset one gets the default.
ITEMS="${SECLAB_DESKTOP_ITEMS-text dark dock animations nolock pin}"
SIZE="${SECLAB_TEXT_SIZE:-125}"
LAYOUT="${SECLAB_KEYBOARD:-}"
ERRORS=0

want() { [[ " $ITEMS " == *" $1 "* ]]; }

if ! [[ "$SIZE" =~ ^[0-9]+$ ]] || [ "$SIZE" -lt 100 ] || [ "$SIZE" -gt 200 ]; then
    fail "Text size must be a percentage between 100 and 200, not '$SIZE'."
    exit 1
fi
if [ -n "$LAYOUT" ] && ! valid_layout "$LAYOUT"; then
    fail "Unknown keyboard layout code '$LAYOUT'."
    exit 1
fi
FACTOR="$((SIZE / 100)).$(printf '%02d' $((SIZE % 100)))"

# Set a GSettings key only if this desktop version has it.
gset() {
    if ! gsettings range "$1" "$2" >/dev/null 2>&1; then
        info "$1 $2: not on this version, skipped."
    elif gsettings set "$1" "$2" "$3"; then
        ok "$1 $2 = $3"
    else
        ERRORS=$((ERRORS + 1))
    fi
}

# Set an Xfce setting (created if it does not exist yet).
xset_prop() {
    if xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4"; then
        ok "$1 $2 = $4"
    else
        ERRORS=$((ERRORS + 1))
    fi
}

# Put the first terminal found and Wireshark at the front of a favorites
# list, without duplicates. Usage: pin_apps SCHEMA KEY TERMINAL_ID...
pin_apps() {
    local schema="$1" key="$2" id current pinned=()
    shift 2
    if ! gsettings range "$schema" "$key" >/dev/null 2>&1; then
        info "$schema $key: not on this version, skipped."
        return
    fi
    for id in "$@"; do
        if [ -f "/usr/share/applications/$id" ]; then
            pinned+=("$id")
            break
        fi
    done
    if [ -f /usr/share/applications/org.wireshark.Wireshark.desktop ]; then
        pinned+=(org.wireshark.Wireshark.desktop)
    fi
    if [ ${#pinned[@]} -eq 0 ]; then
        info "No Terminal or Wireshark launcher found to pin."
        return
    fi
    current="$(gsettings get "$schema" "$key")"
    gset "$schema" "$key" "$(python3 - "$current" "${pinned[@]}" <<'PY'
import ast, sys
current, pinned = sys.argv[1], sys.argv[2:]
if current.startswith("@as "):
    current = current[4:]
print(pinned + [app for app in ast.literal_eval(current) if app not in pinned])
PY
)"
}

# Mint shows a welcome window at every login until this flag exists.
mint_welcome_off() {
    if [ "$OS_ID" = linuxmint ]; then
        mkdir -p "$HOME/.linuxmint/mintwelcome"
        touch "$HOME/.linuxmint/mintwelcome/norun.flag"
        ok "Mint welcome screen turned off."
    fi
}

not_here() { info "$1: not applicable on $DESKTOP, skipped."; }

gnome() {
    local ui=org.gnome.desktop.interface dock=org.gnome.shell.extensions.dash-to-dock
    if want text; then
        gset "$ui" text-scaling-factor "$FACTOR"
        if [ "$SIZE" -ge 150 ]; then
            gset "$ui" cursor-size 32
        fi
    fi
    if want dark; then
        gset "$ui" color-scheme "'prefer-dark'"
        if [ -d /usr/share/themes/Yaru-dark ]; then
            gset "$ui" gtk-theme "'Yaru-dark'"
        fi
        gset "$ui" accent-color "'blue'"
    fi
    if want dock; then
        gset "$dock" dock-position "'BOTTOM'"
        gset "$dock" click-action "'minimize-or-previews'"
        gset "$dock" extend-height false
        gset org.gnome.desktop.wm.preferences button-layout "'appmenu:minimize,maximize,close'"
    fi
    if want animations; then
        gset "$ui" enable-animations false
    fi
    if want nolock; then
        gset org.gnome.desktop.session idle-delay "uint32 0"
        gset org.gnome.desktop.screensaver lock-enabled false
        gset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "'nothing'"
    fi
    if want pin; then
        pin_apps org.gnome.shell favorite-apps org.gnome.Ptyxis.desktop org.gnome.Terminal.desktop
    fi
    if [ -n "$LAYOUT" ]; then
        if [ "$LAYOUT" = us ]; then
            gset org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
        else
            gset org.gnome.desktop.input-sources sources "[('xkb', '$LAYOUT'), ('xkb', 'us')]"
        fi
    fi
}

cinnamon() {
    local ui=org.cinnamon.desktop.interface theme=Mint-Y-Dark-Aqua
    if want text; then
        gset "$ui" text-scaling-factor "$FACTOR"
        if [ "$SIZE" -ge 150 ]; then
            gset "$ui" cursor-size 32
        fi
    fi
    if want dark; then
        if [ -d "/usr/share/themes/$theme" ]; then
            gset "$ui" gtk-theme "'$theme'"
            gset org.cinnamon.theme name "'$theme'"
        fi
        gset org.x.apps.portal color-scheme "'prefer-dark'"
    fi
    if want dock; then
        not_here "Dock"
    fi
    if want animations; then
        gset org.cinnamon desktop-effects-workspace false
        gset "$ui" enable-animations false
    fi
    if want nolock; then
        gset org.cinnamon.desktop.session idle-delay "uint32 0"
        gset org.cinnamon.desktop.screensaver lock-enabled false
        gset org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0
        gset org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-type "'nothing'"
    fi
    if want pin; then
        pin_apps org.cinnamon favorite-apps org.gnome.Terminal.desktop
    fi
    if [ -n "$LAYOUT" ]; then
        if [ "$LAYOUT" = us ]; then
            gset org.gnome.libgnomekbd.keyboard layouts "['us']"
        else
            gset org.gnome.libgnomekbd.keyboard layouts "['$LAYOUT', 'us']"
        fi
    fi
    mint_welcome_off
}

xfce() {
    local theme=Mint-Y-Dark-Aqua
    if want text; then
        xset_prop xsettings /Xft/DPI int $((96 * SIZE / 100))
        if [ "$SIZE" -ge 150 ]; then
            xset_prop xsettings /Gtk/CursorThemeSize int 32
        fi
    fi
    if want dark; then
        if [ -d "/usr/share/themes/$theme" ]; then
            xset_prop xsettings /Net/ThemeName string "$theme"
        fi
        if [ -d "/usr/share/themes/$theme/xfwm4" ]; then
            xset_prop xfwm4 /general/theme string "$theme"
        fi
        gset org.x.apps.portal color-scheme "'prefer-dark'"
    fi
    if want dock; then
        not_here "Dock"
    fi
    if want animations; then
        not_here "Animations"
    fi
    if want nolock; then
        xset_prop xfce4-screensaver /saver/enabled bool false
        xset_prop xfce4-screensaver /lock/enabled bool false
        xset_prop xfce4-power-manager /xfce4-power-manager/dpms-enabled bool false
        xset_prop xfce4-power-manager /xfce4-power-manager/blank-on-ac int 0
    fi
    if want pin; then
        not_here "Pinning apps"
    fi
    if [ -n "$LAYOUT" ]; then
        xset_prop keyboard-layout /Default/XkbDisable bool false
        if [ "$LAYOUT" = us ]; then
            xset_prop keyboard-layout /Default/XkbLayout string us
            xset_prop keyboard-layout /Default/XkbVariant string ""
        else
            xset_prop keyboard-layout /Default/XkbLayout string "$LAYOUT,us"
            xset_prop keyboard-layout /Default/XkbVariant string ","
        fi
    fi
    mint_welcome_off
}

case "$DESKTOP" in
    gnome)    gnome ;;
    cinnamon) cinnamon ;;
    xfce)     xfce ;;
    *)
        info "The desktop '$XDG_CURRENT_DESKTOP' is not supported; desktop settings skipped."
        exit "$RC_SKIPPED"
        ;;
esac

if [ "$ERRORS" -gt 0 ]; then
    fail "$ERRORS desktop setting(s) could not be applied, see above."
    exit 1
fi
ok "Desktop settings applied. Some take effect after the next login."
