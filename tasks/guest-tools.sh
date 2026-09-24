#!/usr/bin/env bash
#
# Install the hypervisor's guest tools (root): the VM window resizes with
# the host window and copy and paste works between host and VM.
# Tools that are already installed (for example Guest Additions from the
# VirtualBox CD) are left untouched.

set -euo pipefail
# shellcheck source=lib/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
require_root
detect_env
user="$(target_user || true)"

# VirtualBox shared folders are readable only by the vboxsf group.
add_to_vboxsf() {
    if [ -n "$user" ] && getent group vboxsf >/dev/null; then
        usermod -aG vboxsf "$user"
        ok "$user can open VirtualBox shared folders after the next login."
    fi
}

guest_additions_installed() {
    compgen -G '/opt/VBoxGuestAdditions-*' >/dev/null
}

# Run the installer from a Guest Additions CD mounted by the desktop.
install_from_cd() {
    local cd_dir="$1" installer=VBoxLinuxAdditions.run rc=0
    if [ "$ARCH" = arm64 ]; then
        installer=VBoxLinuxAdditions-arm64.run
    fi
    if [ ! -f "$cd_dir/$installer" ]; then
        fail "$installer is not on the Guest Additions CD in $cd_dir."
        exit 1
    fi
    info "Installing the build tools the Guest Additions need..."
    apt_update
    apt_install build-essential bzip2 "linux-headers-$(uname -r)"
    info "Running $installer from the Guest Additions CD..."
    # The installer's exit code is not reliable (it is non-zero when only a
    # reboot is missing), so check the result instead.
    sh "$cd_dir/$installer" --nox11 || rc=$?
    if ! guest_additions_installed; then
        fail "The Guest Additions installer did not finish (exit code $rc)."
        exit 1
    fi
    ok "Guest Additions installed from the CD."
}

case "$VIRT" in
    oracle)
        if guest_additions_installed || pkg_installed virtualbox-guest-utils; then
            ok "VirtualBox Guest Additions are already installed, leaving them as they are."
            add_to_vboxsf
            exit 0
        fi
        cd_dir=""
        for dir in /media/*/VBox_GAs_*; do
            if [ -d "$dir" ]; then
                cd_dir="$dir"
                break
            fi
        done
        if [ -n "$cd_dir" ]; then
            install_from_cd "$cd_dir"
        elif [ "$ARCH" = amd64 ]; then
            apt_update
            apt_install virtualbox-guest-utils virtualbox-guest-x11
        else
            action_needed "Guest Additions for ARM64 come only from the VirtualBox CD. In the VirtualBox menu choose Devices > Insert Guest Additions CD Image, then run ./setup.sh again."
            exit "$RC_ACTION"
        fi
        add_to_vboxsf
        ;;
    vmware)
        if pkg_installed open-vm-tools-desktop; then
            ok "VMware tools are already installed."
        else
            apt_update
            apt_install open-vm-tools-desktop
        fi
        ;;
    qemu|kvm)
        if pkg_installed spice-vdagent; then
            ok "SPICE guest tools are already installed."
        else
            apt_update
            apt_install spice-vdagent qemu-guest-agent
        fi
        ;;
    *)
        info "No guest tools to install here (virtualization: $VIRT)."
        exit "$RC_SKIPPED"
        ;;
esac
