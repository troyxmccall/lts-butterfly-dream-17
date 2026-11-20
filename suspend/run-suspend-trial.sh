#!/bin/bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helper="$here/thunderbolt-test.py"

if [[ $(uname -r) != 7.3.4+deb13-amd64 ]]; then
    printf '%s\n' 'Boot Debian kernel 7.3.4+deb13-amd64 for this trial.' >&2
    exit 1
fi

python3 "$helper" check
sudo python3 "$helper" arm
cleanup() {
    sudo rtcwake -m disable || true
    sudo python3 "$helper" disarm || true
}
trap cleanup EXIT

sudo rtcwake -m no -s 45
sudo systemctl suspend
sudo journalctl -b -u systemd-suspend.service --no-pager -n 30
python3 "$helper" check
