export PATH=/usr/sbin:/usr/bin:/sbin:/bin
kernel=7.3.4+deb13-amd64

fail() { printf '%s\n' "$*" >&2; exit 1; }

require_target() {
    [[ $(uname -r) == "$kernel" &&
       $(cat /sys/class/dmi/id/product_name) == MacBookPro14,3 ]] ||
        fail "This setup requires MacBookPro14,3 running $kernel."
}

dkms_installed() {
    dkms status "$1" -k "$2" 2>/dev/null | grep -E ': installed([[:space:]]|$)'
}

dkms_module_path() {
    local path
    path=$(modinfo -k "$1" -F filename "$2" 2>/dev/null) &&
        [[ $path == */updates/dkms/* && -f $path ]]
}
