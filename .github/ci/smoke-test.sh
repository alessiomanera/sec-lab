#!/usr/bin/env bash
#
# CI smoke test. Runs as root inside a fresh Ubuntu or Linux Mint container
# with the repository mounted at /src: prepares a student account the way a
# desktop install does, runs "./setup.sh --yes" twice as that student and
# checks the result. The second run starts from a new login, so it also
# proves that the student can capture packets.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
# The Linux Mint Docker images ship Ubuntu's base-files (ID=ubuntu); install
# Mint's own version so the Mint code path is tested.
mint_base="$(apt-cache policy base-files | awk '/mint/ {print $1; exit}')"
if [ -n "$mint_base" ]; then
    apt-get install -y -qq --allow-downgrades "base-files=$mint_base"
fi
apt-get install -y -qq sudo git
useradd -m -s /bin/bash student
echo 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student
cp -a /src /home/student/sec-lab
chown -R student:student /home/student/sec-lab

for run in 1 2; do
    echo "::group::setup.sh --yes, run $run"
    su - student -c 'cd sec-lab && ./setup.sh --yes'
    echo "::endgroup::"
done

fail() { echo "::error::$*"; exit 1; }
[ "$(grep -c '^wireshark:' /etc/group)" -eq 1 ] || fail "wireshark group is not unique"
id -nG student | grep -w wireshark >/dev/null || fail "student is not in the wireshark group"
[ "$(stat -c '%U:%G %a' /usr/bin/dumpcap)" = "root:wireshark 754" ] || fail "dumpcap owner or mode is wrong"
getcap /usr/bin/dumpcap | grep cap_net_raw >/dev/null || fail "dumpcap has no capture capability"
[ "$(grep -c '>>> sec-lab terminal >>>' /home/student/.bashrc)" -eq 1 ] || fail "terminal block is not unique in .bashrc"
if apt-get update 2>&1 | grep -i 'configured multiple times'; then
    fail "duplicate apt sources"
fi
echo "Smoke test passed."
