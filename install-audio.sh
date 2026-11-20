#!/bin/bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/common.sh"
(( EUID == 0 )) || fail 'Run with sudo on the Debian host.'
require_target

headers=linux-headers-$kernel
source_package=linux-source-7.3
version=$(dpkg-query -W -f='${Version}' "linux-image-$kernel")
# Header installation invokes DKMS autoinstall. Skip the older drivers on this kernel.
for legacy in apple-ib-drv snd_hda_macbookpro; do
    override=/etc/dkms/$legacy-0.1-$kernel.conf
    if [[ ! -e $override ]]; then
        install -Dm0644 /dev/stdin "$override" <<'DKMS'
AUTOINSTALL=""
DKMS
    fi
done
apt-get --no-remove install dkms build-essential python3 "$headers=$version" "$source_package=$version"

module=snd_hda_macbookpro/7.3.4
destination=/usr/src/snd_hda_macbookpro-7.3.4
if [[ ! -d $destination ]]; then
    stage=$(mktemp -d /usr/src/.macbook-audio.XXXXXX)
    trap 'rm -rf -- "$stage"' EXIT
    driver="$here/audio"
    cp "$driver"/{LICENSE,Makefile,install.cirrus.driver.sh,patch_cs8409.c.diff,patch_cs8409.h.diff} "$stage/"
    cp -R "$driver"/{makefiles,patch_cirrus} "$stage/"
    python3 - "$stage/install.cirrus.driver.sh" <<'PY'
from pathlib import Path
import sys

script = Path(sys.argv[1])
text = script.read_text()
start = "else\n\t# here we assume the distribution kernel source"
assert text.count(start) == 1, "Unexpected Cirrus installer source"
debian = """elif [[ $UNAME == 7.3.4+deb13-amd64 ]]; then
    expected=$(dpkg-query -W -f='${Version}' "linux-headers-$UNAME")
    actual=$(dpkg-query -W -f='${Version}' linux-source-7.3)
    [[ -n $expected && $actual == "$expected" ]]
    tar --strip-components=2 -xf /usr/src/linux-source-7.3.tar.xz \\
        --directory=build/ linux-source-7.3/sound/hda

"""
script.write_text(text.replace(start, debian + start))
PY
    chmod 0755 "$stage/install.cirrus.driver.sh"
    bash -n "$stage/install.cirrus.driver.sh"
    cat > "$stage/dkms.conf" <<'DKMS'
PACKAGE_NAME="snd_hda_macbookpro"
PACKAGE_VERSION="7.3.4"
BUILD_EXCLUSIVE_KERNEL="^7[.]3[.]4[+]deb13-amd64$"
PRE_BUILD="install.cirrus.driver.sh -k $kernelver --dkms"
MAKE[0]="make KERNELRELEASE=$kernelver"
BUILT_MODULE_NAME[0]="snd-hda-codec-cs8409"
BUILT_MODULE_LOCATION[0]="build/hda/codecs/cirrus"
DEST_MODULE_LOCATION[0]="/kernel/extra"
AUTOINSTALL="no"
DKMS
    chmod 0755 "$stage"
    mv -T -- "$stage" "$destination"
fi

if ! dkms_installed "$module" "$kernel" || ! dkms_module_path "$kernel" snd_hda_codec_cs8409; then
    dkms install "$module" -k "$kernel"
fi
dkms_module_path "$kernel" snd_hda_codec_cs8409 || fail 'The DKMS codec is missing for 7.3.4.'
update-initramfs -u -k "$kernel"
printf 'Reboot into %s and test the internal speakers and microphone.\n' "$kernel"
