#!/bin/bash
set -euo pipefail

wifi=0000:03:00.0
device=/sys/bus/pci/devices/$wifi
driver=/sys/bus/pci/drivers/brcmfmac
group=$device/iommu_group
[[ $(cat "$device/vendor") == 0x14e4 && $(cat "$device/device") == 0x43ba ]]
members=("$group"/devices/*)
[[ ${#members[@]} == 1 && ${members[0]##*/} == "$wifi" ]]
if [[ $(cat "$group/type") == identity ]]; then
    exit 0
fi

modprobe brcmfmac
if [[ -L $device/driver ]]; then
    [[ $(readlink -f "$device/driver") == "$driver" ]]
    printf '%s\n' "$wifi" > "$driver/unbind"
fi

restore() {
    printf 'auto\n' > "$group/type" || true
    printf '%s\n' "$wifi" > "$driver/bind" || true
}
trap restore ERR
printf 'identity\n' > "$group/type"
printf '%s\n' "$wifi" > "$driver/bind"
