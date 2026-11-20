#!/bin/bash
set -euo pipefail

action=${1:-disable}
if (( $# > 1 )) || [[ $action != disable && $action != restore ]]; then
    printf 'Usage: %s [disable|restore]\n' "$0" >&2
    exit 2
fi

if (( EUID != 0 )); then
    exec sudo -- "$0" "$action"
fi

service=t1-touchbar.service
dropin=/etc/systemd/system/$service.d/90-no-idle-dimming.conf
systemctl cat "$service" >/dev/null

if [[ $action == disable ]]; then
    install -Dm0644 /dev/stdin "$dropin" <<'SYSTEMD'
[Service]
ExecStart=
ExecStart=/usr/local/sbin/t1-touchbar-daemon --base-mode spcl --fn-mode fn --idle-timeout 0
SYSTEMD
else
    rm -f -- "$dropin"
fi

systemctl daemon-reload
systemctl restart "$service"
systemctl is-active "$service"
