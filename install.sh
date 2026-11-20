#!/bin/bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/common.sh"
(( EUID == 0 )) || fail 'Run with sudo on the Debian host.'
require_target
if grep -Eq '^(apple_ibridge|apple_touchbar) ' /proc/modules; then
    fail 'The kernel Touch Bar driver is already loaded.'
fi

hardware="$here/hardware"
apt-get --no-remove install firmware-brcm80211 python3
install -Dm0644 "$hardware/brcmfmac43602-pcie.txt" \
    /usr/lib/firmware/updates/brcm/brcmfmac43602-pcie.txt
update-initramfs -u -k "$kernel"
install -m 0755 "$hardware/t1-touchbar-daemon.py" /usr/local/sbin/t1-touchbar-daemon
install -m 0755 "$hardware/broadcom-iommu.sh" /usr/local/sbin/macbook-broadcom-iommu
install -m 0644 "$hardware/macbook-broadcom-iommu.service" /etc/systemd/system/
install -m 0644 "$hardware/t1-touchbar.service" /etc/systemd/system/
install -d -m 0755 /etc/systemd/system/t1-touchbar.service.d
printf '[Unit]\nConditionKernelVersion=7.3.4+deb13-amd64\n' \
    > /etc/systemd/system/t1-touchbar.service.d/debian-kernel.conf
systemctl enable macbook-broadcom-iommu.service t1-touchbar.service
printf 'Enabled for the next boot into 7.3.4.\n'
