#!/bin/bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/common.sh"
(( EUID != 0 )) || fail 'Run as your regular user. The installation steps use sudo.'
require_target

(( $# == 0 )) || fail "Usage: $0"
commit=ff73ccdffdd3ee8d4e959fbe403db04b75b0578a
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
git clone --branch v2.5.0 https://github.com/linux-on-mac/mbpfan.git "$stage/upstream"

mkdir "$stage/build"
git -C "$stage/upstream" archive "$commit" | tar -xf - -C "$stage/build"
make -C "$stage/build" bin/mbpfan

sudo apt-get --no-remove install mbpfan
sudo install -m 0755 "$stage/build/bin/mbpfan" /usr/local/sbin/mbpfan
sudo install -m 0644 "$here/hardware/mbpfan.conf" /etc/mbpfan.conf
sudo install -d -m 0755 /etc/systemd/system/mbpfan.service.d
sudo install -m 0644 /dev/stdin /etc/systemd/system/mbpfan.service.d/local-binary.conf <<'SYSTEMD'
[Service]
ExecStart=
ExecStart=/usr/local/sbin/mbpfan -f
SYSTEMD
sudo systemctl daemon-reload
sudo systemctl reset-failed mbpfan.service
sudo systemctl enable mbpfan.service
sudo systemctl restart mbpfan.service
systemctl is-active mbpfan.service
