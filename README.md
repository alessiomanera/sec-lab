# Computer Security Lab (AY 2026-2027)

Post-install setup for the virtual machine you use in the Computer Security Lab course, taught by Prof. Maccari and Prof. Busi.

You install Ubuntu or Linux Mint in a VM, run one command, answer one menu and restart once. Afterwards the VM is up to date, its window resizes with the host window, copy and paste works between host and VM, your keyboard layout is set, the desktop is easier to read, and every tool used in the lab is installed, including Wireshark with packet capture for your normal user.

---

## Supported systems

| Linux in the VM | Architecture | Desktop |
| :--- | :--- | :--- |
| Ubuntu 22.04, 24.04 and 26.04 LTS | amd64 and arm64 | GNOME (default Ubuntu desktop) |
| Linux Mint 22.x | amd64 | Cinnamon or Xfce |

Which architecture you need depends on your computer (the "host"):

- **Windows PC, Intel Mac or Linux PC:** use the **amd64** (x86-64) ISO. Ubuntu or Linux Mint both work.
- **Apple Silicon Mac (M1 and later):** use the **Ubuntu Desktop arm64** ISO. Linux Mint has no arm64 release.

The script runs inside the Linux VM (the "guest"). It does not matter which system your computer runs; the script detects the guest architecture by itself.

---

## 1. Check the VirtualBox settings first

These settings are made in VirtualBox on your computer, with the VM **powered off** (not paused or saved). They are the most common reason for a tiny VM window that does not resize.

| Setting | Where in VirtualBox | Value |
| :--- | :--- | :--- |
| Graphics controller | Settings > Display > Screen | **VMSVGA** |
| Video memory | Settings > Display > Screen | 128 MB |
| Processors | Settings > System > Processor | 2 or more |
| Memory | Settings > System > Motherboard | 4096 MB or more |
| Shared clipboard | Settings > General > Features | Bidirectional |
| Scale factor (only on HiDPI or Retina screens) | Settings > Display > Screen | 200% |

The same settings from a terminal on your computer, with the VM powered off (replace `My VM` with the name of your VM):

```bash
VBoxManage modifyvm "My VM" --graphicscontroller=vmsvga --vram=128 --cpus=2 --memory=4096 --clipboard-mode=bidirectional
```

VMware and UTM need no special settings.

---

## 2. Run the setup

Open a terminal inside the VM desktop and paste this line:

```bash
sudo apt install -y git && git clone https://github.com/alessiomanera/sec-lab.git && cd sec-lab && ./setup.sh
```

It asks for your password (the one you chose when installing Linux), then shows a menu. The recommended items are already ticked; press Enter to accept them, or use the arrow keys and Space to change them.

| Menu item | What it does |
| :--- | :--- |
| Update the whole system (with nala) | Installs all available updates. It uses [nala](https://gitlab.com/volian/nala), a friendlier front end for apt with a clear summary and parallel downloads, and you can keep using it afterwards (`sudo nala install ...`). |
| VM guest tools | VirtualBox Guest Additions, VMware tools or SPICE tools, so the window resizes and the clipboard works. Guest Additions that are already installed are left alone. |
| Course tools and Wireshark | Installs the tools listed below and lets you capture packets without `sudo`. |
| Keyboard layout | Your layout becomes the main one (also on the login screen); US English stays as the second layout. |
| Nice terminal | A colorful [Starship](https://starship.rs) prompt that shows the folder, the git branch, the Python virtual environment and the exit code of failed commands; a system summary ([fastfetch](https://github.com/fastfetch-cli/fastfetch)) when a terminal opens; the JetBrains Mono font; the shortcuts `ll`, `myip`, `ports` and `update`. Your own `~/.bashrc` is kept. |
| Bigger text | Text size of 100%, 125% (recommended), 150% or 175%. |
| Dark theme | Dark desktop and application theme. |
| Dock at the bottom (Ubuntu) | Dock at the bottom of the screen; clicking an open app's icon minimizes it. |
| Turn off animations (Ubuntu, Mint Cinnamon) | Makes the desktop feel faster inside a VM. |
| No screen lock or blank screen | The VM no longer locks or goes black while you read or wait. |
| Pin Terminal and Wireshark (Ubuntu, Mint Cinnamon) | Adds both to the dock (Ubuntu) or the menu favorites (Mint Cinnamon). |
| Extra: Visual Studio Code | Not ticked by default. Installs VS Code from Microsoft; it then updates with the system. |
| Extra: GNOME Tweaks (Ubuntu) | Not ticked by default. Installs GNOME Tweaks and Extension Manager. |

The menu only shows the items that apply to your desktop. A final screen lists your choices before anything changes. The whole run takes about 10 to 30 minutes, mostly for the system update. At the end you see a summary with `OK`, `SKIPPED`, `ACTION NEEDED` or `FAILED` for each step.

To use the recommended choices without any questions (the keyboard layout is then left as it is):

```bash
./setup.sh --yes
```

---

## 3. Restart, verify, take a snapshot

When the setup asks, restart the VM. The restart activates the guest tools, your new group membership for Wireshark, the keyboard layout on the login screen and any new kernel.

After logging in again, open a terminal and run:

```bash
cd sec-lab
./verify.sh
```

A ready VM ends with:

```text
==========================================================
 Verification summary
==========================================================
 OK:      50
 Missing: 0
 Notices: 0
==========================================================
[OK] The VM is ready for the lab.
```

Then take a VirtualBox snapshot (Machine > Take Snapshot). It is your clean lab baseline: if an exercise breaks the VM, restore the snapshot instead of reinstalling.

---

## What gets installed

The course tools are listed in `packages/packages.txt`:

| Category | Package (commands) | Used for |
| :--- | :--- | :--- |
| Core | `man-db`, `less` | Manual pages and paging |
| | `tree` | Directory trees |
| | `nano`, `vim` | Terminal text editors |
| Networking | `iproute2` (`ip`, `ss`) | Interfaces, routes and sockets |
| | `net-tools` (`ifconfig`, `netstat`, `arp`) | Classic networking commands used in lab material |
| | `iputils-ping`, `traceroute` | Reachability and path analysis |
| | `bind9-dnsutils` (`dig`, `nslookup`) | DNS queries |
| | `whois` | Domain and IP registration lookups |
| | `telnet` | Talking to plaintext protocols by hand |
| | `curl`, `wget` | HTTP and file transfers |
| | `ethtool` | Network interface details |
| Security and capture | `nmap` | Port scanning and service discovery |
| | `tcpdump` | Command line packet capture |
| | `wireshark`, `tshark` | Graphical and terminal packet analysis |
| | `iptables`, `nftables` | Packet filtering and firewall rules |
| | `netcat-openbsd` (`nc`), `socat` | Raw TCP and UDP connections, relays |
| | `arping` | ARP probing on the local network |
| | `openssh-client` | SSH client |
| | `gnupg` (`gpg`), `openssl` | Keys, signatures, TLS and certificates |
| Development and debugging | `build-essential` (`gcc`, `make`) | Compiling C programs |
| | `gdb` | Debugger |
| | `strace`, `ltrace` | System call and library call tracing |
| | `python3`, `python3-pip`, `python3-venv` | Python 3 and virtual environments |
| | `perl`, `git` | Scripting and version control |
| | `file`, `binutils` (`objdump`, `readelf`), `xxd` | Inspecting binaries and hex dumps |
| Utilities | `jq` | JSON on the command line |
| | `zip`, `unzip`, `xz-utils` | Archives and compression |
| | `rsync` | Copying and syncing files |

All of them are available on amd64 and arm64.

### Not installed on purpose

- **Servers** (`apache2`, `bind9`, `isc-dhcp-server`, `squid`, `samba`): they would run in the background all the time and open ports. Install one when an exercise asks for it.
- **`openssh-server`**: without it nobody can log in to your VM over the network. If you need it, `sudo apt install -y openssh-server` installs and starts it.
- **`imagemagick`**: not needed for the lab.

### Python packages

On Ubuntu 24.04 and later, and on Linux Mint 22, `pip install` outside a virtual environment is blocked by the system. Create one per project:

```bash
python3 -m venv ~/venvs/lab
source ~/venvs/lab/bin/activate
pip install requests
```

---

## Wireshark without root

Running the Wireshark window as root is a security risk, so the setup lets your normal user capture instead. It answers "yes" to the Wireshark package question "Should non-superusers be able to capture packets?", which makes the package give the capture helper `dumpcap` the needed capabilities and restrict it to the `wireshark` group, and then adds you to that group.

Group changes apply from your next login, which is why the setup ends with a restart. Until then `./verify.sh` shows a notice instead of an error. Start Wireshark from the app menu and pick an interface (for example `enp0s3`, or `any`) to capture.

---

## Changing something later

Every step is a separate script in `tasks/` that you can run on its own:

| To... | Run |
| :--- | :--- |
| Run the menu again | `./setup.sh` |
| Only update the system | `sudo ./tasks/system-update.sh` |
| Only reinstall the course tools | `sudo ./tasks/course-tools.sh` |
| Fix Wireshark capture permission | `sudo ./tasks/wireshark.sh` |
| Change the keyboard layout (for example to German) | `sudo SECLAB_KEYBOARD=de ./tasks/keyboard.sh` and `SECLAB_KEYBOARD=de ./tasks/desktop.sh` |
| Change only the text size | `SECLAB_DESKTOP_ITEMS=text SECLAB_TEXT_SIZE=150 ./tasks/desktop.sh` |
| Install VS Code | `sudo ./tasks/extra-vscode.sh` |
| Set up the nice terminal | `sudo ./tasks/terminal-tools.sh` and `./tasks/terminal-profile.sh` |

Scripts started with `sudo` change the system; `tasks/desktop.sh` and `tasks/terminal-profile.sh` change your own account and run without `sudo`, in a terminal inside the desktop. Running any of them twice is safe.

---

## Troubleshooting

**"Could not get lock" or the setup waits for another program.** A fresh VM installs updates in the background right after the first boot. The setup waits up to 10 minutes for it to finish. If it still fails, restart the VM and run `./setup.sh` again.

**The VM window is small and does not resize.** Check the VirtualBox settings in step 1, especially Graphics Controller = VMSVGA, then restart the VM. The guest tools only take effect after a restart.

**Apple Silicon Mac with VirtualBox: "ACTION NEEDED" for guest tools.** On arm64, VirtualBox Guest Additions only come from the Guest Additions CD. In the VM window menu choose Devices > Insert Guest Additions CD Image, wait until the CD appears on the desktop, then run `./setup.sh` again.

**Switching the keyboard layout.** Press Super+Space on Ubuntu (Super is the Windows or Command key), or click the layout indicator in the panel on Linux Mint.

**Wireshark shows no interfaces or "permission denied".** Log out and back in, or restart. If it still fails, run `sudo ./tasks/wireshark.sh`, restart and run `./verify.sh`.

**A step shows FAILED.** Read the messages above the summary. Everything the setup printed is also saved in `~/sec-lab-setup.log`. Fix the cause (usually the network) and run `./setup.sh` again; finished steps are quick the second time.

**No internet in the VM.** In VirtualBox, set Settings > Network > Adapter 1 > Attached to: NAT, then try `ping -c 3 ubuntu.com` in the VM.

**Going back to the plain terminal.** Open `~/.bashrc` in a text editor and delete the block between `# >>> sec-lab terminal >>>` and `# <<< sec-lab terminal <<<`. The prompt settings are in `~/.config/starship.toml` if you only want to change them.

**Which architecture is my VM?** Run `dpkg --print-architecture`. It prints `amd64` or `arm64`.

---

## Updating

If this repository changes during the course, update your copy and run the setup again:

```bash
cd sec-lab
git pull
./setup.sh
```

---

## Scope

This repository prepares student VMs for the Computer Security Lab (AY 2026-2027). It is a plain Bash script with no other dependencies, meant to be easy to read: `setup.sh` shows the menu and runs the scripts in `tasks/`, `lib/common.sh` holds the shared helpers, `config/` holds the terminal profile and prompt settings, and `verify.sh` checks the result. Starship and fastfetch come from the Ubuntu archive where it has them (26.04); on older releases the official release files are installed only if they match the SHA256 checksums pinned in `tasks/terminal-tools.sh`. It does not turn the VM into an offensive security distribution such as Kali Linux.
