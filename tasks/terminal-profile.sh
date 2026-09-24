#!/usr/bin/env bash
#
# Turn on the "nice terminal" for the current user (run as the student,
# not with sudo): Starship prompt, fastfetch and a few lab shortcuts via
# config/bashrc, and JetBrains Mono as the terminal font.
# Your own ~/.bashrc is kept; one marked block at its end loads the
# profile, and deleting that block turns it off again.

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

if [ "$(id -u)" -eq 0 ]; then
    fail "Run this as your normal user, without sudo."
    exit 1
fi
detect_env

FONT="JetBrains Mono 12"
MARKER="# >>> sec-lab terminal >>>"

mkdir -p "$HOME/.config/sec-lab"
install -m 644 "$SECLAB_ROOT/config/bashrc" "$HOME/.config/sec-lab/bashrc"
ok "Terminal profile installed in ~/.config/sec-lab/bashrc."

if ! grep -qF "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'BLOCK'

# >>> sec-lab terminal >>>
# Computer Security Lab terminal profile. Delete this block to turn it off.
if [ -f "$HOME/.config/sec-lab/bashrc" ]; then
    . "$HOME/.config/sec-lab/bashrc"
fi
# <<< sec-lab terminal <<<
BLOCK
    ok "Your .bashrc now loads the terminal profile."
else
    ok "Your .bashrc already loads the terminal profile."
fi

# Replace the prompt settings only if they are ours (first line unchanged),
# never a starship.toml the student wrote.
starship_config="$HOME/.config/starship.toml"
if [ ! -f "$starship_config" ] || [ "$(head -n 1 "$starship_config")" = "$(head -n 1 "$SECLAB_ROOT/config/starship.toml")" ]; then
    install -m 644 "$SECLAB_ROOT/config/starship.toml" "$starship_config"
    ok "Prompt settings installed in ~/.config/starship.toml."
else
    info "Keeping your own ~/.config/starship.toml."
fi

if has_desktop_session; then
    case "$DESKTOP" in
        gnome|cinnamon)
            gset org.gnome.desktop.interface monospace-font-name "'$FONT'"
            ;;
        xfce)
            xset_prop xsettings /Gtk/MonospaceFontName string "$FONT"
            xset_prop xfce4-terminal /font-use-system bool true
            ;;
    esac
else
    info "No desktop session: the terminal font is set the next time this runs inside the desktop."
fi

if [ "$SETTING_ERRORS" -gt 0 ]; then
    fail "The terminal font could not be set, see above."
    exit 1
fi
ok "Open a new terminal window to see the new look."
