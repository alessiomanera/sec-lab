# Computer Security Lab (AY 2026-2027)

Post-install setup script and verification tools for the Computer Security Lab course, taught by Prof. Maccari and Prof. Busi.

---

## What this does

This repository provides an automated post-install script for students preparing their virtual machine (VM) for the Computer Security Lab exercises.

It installs and configures:
- Command-line utilities and text editors.
- Networking diagnostics and legacy protocol tools (`iproute2`, `net-tools`, `traceroute`, `telnet`).
- Network analysis and traffic capture tools (`nmap`, `tcpdump`, `wireshark`, `tshark`, `socat`, `netcat`).
- Binary analysis, debugging, and development tools (`build-essential`, `gdb`, `strace`, `binutils`, `xxd`).
- Python scripting environment with virtual environment support (`python3`, `python3-pip`, `python3-venv`).
- Wireshark non-root packet capture permissions for standard student user accounts.

**What this is not:**
This repository does not install a full offensive-security distribution such as Kali Linux, nor does it install unnecessary server daemons (Apache, BIND, DHCP server, Samba). It keeps your standard Ubuntu or Linux Mint desktop lightweight, fast, and secure.

---

## Before you start

Before running the setup script, ensure you have:

1. **Installed a Linux VM:** Install either **Ubuntu** (recommended) or **Linux Mint** inside VirtualBox, VMware, or UTM.
2. **Chosen the correct ISO architecture for your computer:**
   - **Intel or AMD computer (Windows, macOS, or Linux host):**
     Download and install the **`amd64` / `x86_64`** ISO.
   - **Apple Silicon Mac (M1, M2, M3, M4):**
     Download and install the **`arm64` / `aarch64`** ISO (e.g. Ubuntu Desktop ARM64).
3. **An active internet connection** inside the VM to download packages.
4. **A student user account with `sudo` privileges** (the default user created during OS installation).

> **Note on Host Operating Systems:** The script runs entirely inside the Linux guest system. It does not matter whether your physical computer runs Windows, macOS, or Linux. The script automatically detects the architecture of the Linux guest.

---

## Installation

Open a terminal inside your Linux VM and run the following commands:

```bash
# 1. Clone the repository
git clone https://github.com/alessiomanera/sec-lab.git

# 2. Enter the repository directory
cd sec-lab

# 3. Ensure scripts have execution permissions
chmod +x setup.sh verify.sh

# 4. Run the setup script
./setup.sh
```

The script will prompt for your `sudo` password if not already elevated, display the detected operating system and architecture, and ask for confirmation before making changes.

---

## Verification

After installation finishes, verify that all course tools are correctly installed and accessible by running:

```bash
./verify.sh
```

You should see output similar to:

```text
==========================================================
 Computer Security Lab (AY 2026-2027) - Verification
 Detected Architecture: amd64
 Current User:          student
==========================================================

-- Core CLI Tools & Editors --
  [OK]      man (/usr/bin/man)
  [OK]      less (/usr/bin/less)
  [OK]      tree (/usr/bin/tree)
  [OK]      nano (/usr/bin/nano)
  [OK]      vim (/usr/bin/vim)

-- Networking & Diagnostics --
  [OK]      ip (iproute2) (/usr/bin/ip)
  [OK]      ss (iproute2) (/usr/bin/ss)
  [OK]      ifconfig (net-tools) (/usr/sbin/ifconfig)
  ...
==========================================================
 Verification Summary
==========================================================
 Available: 37
 Missing:   0
 Skipped:   0
==========================================================
[+] All required tools are verified and ready for the lab.
```

---

## What gets installed

The packages installed by `setup.sh` are specified in `packages/packages.txt`:

| Category | Package / Tool | Purpose in Lab |
| :--- | :--- | :--- |
| **Core & Shell** | `man-db`, `less` | Manual pages and terminal pagination |
| | `tree` | Recursive directory tree visualization |
| | `nano`, `vim` | Terminal text editors |
| **Networking** | `iproute2` (`ip`, `ss`) | Modern interface and socket inspection |
| | `net-tools` (`ifconfig`, `netstat`, `arp`) | Classic networking commands referenced in lab materials |
| | `iputils-ping`, `traceroute` | Network connectivity and path analysis |
| | `dnsutils` (`dig`, `nslookup`) | DNS querying and inspection |
| | `whois` | Domain and IP registration lookups |
| | `telnet` | Plaintext protocol inspection (HTTP, SMTP) |
| | `curl`, `wget` | Command-line network transfers and downloads |
| | `ethtool` | Network interface hardware queries |
| **Security & Capture** | `nmap` | Network port scanning and service discovery |
| | `tcpdump` | Command-line packet capture and filtering |
| | `wireshark`, `tshark` | Graphical and terminal packet analysis |
| | `iptables`, `nftables` | Packet filtering and firewall rules |
| | `netcat-openbsd` (`nc`) | Raw TCP/UDP connections and banner grabbing |
| | `socat` | Bidirectional data relay and port forwarding |
| | `arping` | ARP-level host probing on local segments |
| | `openssh-client` | SSH client for remote laboratory access |
| | `gnupg` (`gpg`) | PGP/GPG key management and cryptographic signing |
| | `openssl` | TLS/SSL diagnostics and certificate inspection |
| **Development & Debug** | `build-essential` (`gcc`, `make`) | C compilation environment for lab exercises |
| | `gdb` | GNU debugger for binary analysis |
| | `strace` | System call tracing |
| | `ltrace` | Library call tracing (amd64) |
| | `python3`, `python3-pip`, `python3-venv` | Python 3 interpreter and virtual environment support |
| | `perl` | Scripting interpreter |
| | `git` | Version control |
| | `file`, `binutils` (`objdump`, `readelf`) | File type identification and binary disassembly |
| | `xxd` | Hexadecimal dump utility |
| **Utilities** | `jq` | JSON parsing and filtering in shell pipelines |
| | `zip`, `unzip`, `xz-utils` | Archive extraction and compression |
| | `rsync` | File synchronization |

### Deliberately excluded packages

- **Base system components** (`sudo`, `coreutils`, `procps`, `psmisc`, `util-linux`): Already part of any standard Ubuntu or Linux Mint installation.
- **Server infrastructure** (`apache2`, `bind9`, `isc-dhcp-server`, `squid`, `samba`): Excluded to prevent running persistent background services that consume VM resources or expose open ports.
- **`openssh-server`**: Excluded from default installation so the VM does not run an active SSH listener by default. If you need SSH access from your host machine into the VM, install it explicitly:
  ```bash
  sudo apt install -y openssh-server
  sudo systemctl enable --now ssh
  ```
- **`imagemagick`**: Excluded to keep the installation lean and avoid unnecessary image processing attack surfaces.

---

## Architecture support

The script supports both `amd64` (x86-64) and `arm64` (aarch64):

| Architecture | Platform | Status | Notes |
| :--- | :--- | :--- | :--- |
| **`amd64`** | Intel and AMD PCs, Intel Macs | **Fully supported** | All packages install normally. |
| **`arm64`** | Apple Silicon Macs (M1/M2/M3/M4) | **Fully supported** | `ltrace` is skipped on ARM64 due to upstream limitations in arm64 breakpoint support. All other tools install normally. |

### Note on Linux Mint on ARM64
Official Linux Mint ISO releases target `amd64`. If you are using an unofficial community ARM64 build of Linux Mint on Apple Silicon, ensure your apt package sources point to functional ARM64 repositories. On Apple Silicon Macs, **Ubuntu Desktop ARM64** is the recommended choice.

---

## Wireshark non-root packet capture

By default in Linux, capturing live network packets requires administrative privileges. Running the full graphical Wireshark application as `root` is a security risk.

`setup.sh` automatically configures Wireshark for safe, unprivileged use:
1. Enables the `wireshark-common/install-setuid` debconf setting.
2. Creates the `wireshark` system group.
3. Adds your student user account to the `wireshark` group.
4. Grants network packet capture capabilities (`cap_net_raw,cap_net_admin+eip`) to `/usr/bin/dumpcap`.

### Action required after setup

For group membership changes to take effect:
- **Log out of your Linux desktop session and log back in**, OR
- **Reboot the virtual machine**.

Alternatively, to test Wireshark immediately in the current terminal window without logging out, run:

```bash
newgrp wireshark
wireshark &
```

---

## Troubleshooting

### 1. Permission denied when running `./setup.sh`
Ensure the script has executable permissions:
```bash
chmod +x setup.sh verify.sh
./setup.sh
```

### 2. Wireshark says "No interfaces found" or "Capture permission denied"
Your user is not yet active in the `wireshark` group. Confirm your group membership:
```bash
groups
```
If `wireshark` is not in the list, log out and log back in, or reboot the VM.

### 3. `apt-get update` fails or cannot reach mirrors
Ensure your virtual machine has working internet access:
```bash
ping -c 3 8.8.8.8
```
In VirtualBox settings, ensure the network adapter is set to **NAT** or **Bridged Adapter**.

### 4. How to check your Linux guest architecture
Inside your VM terminal, run:
```bash
dpkg --print-architecture
```
This prints `amd64` (Intel/AMD) or `arm64` (Apple Silicon).

---

## Updating

If the package list or setup scripts are updated during the course, pull the latest changes and rerun:

```bash
cd sec-lab
git pull origin main
./setup.sh
./verify.sh
```

---

## Scope

This repository is maintained specifically for the **Computer Security Lab (AY 2026-2027)** at the University. It is designed to be minimal, reproducible, and easy to maintain.
