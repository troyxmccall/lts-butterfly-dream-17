# Install Debian 13 on a 2017 Intel MacBook Pro

```bash
        _,met$$$$$gg.          admin@butterfly-dream-17
     ,g$$$$$$$$$$$$$$$P.       ---------------------------
   ,g$$P""       """Y$$.".     OS: Debian GNU/Linux 13 (trixie) x86_64
  ,$$P'              `$$$.     Host: MacBookPro14,3 (1.0)
',$$P       ,ggs.     `$$b:    Kernel: Linux 7.3.4+deb13-amd64
`d$$'     ,$P"'   .    $$$     Uptime: 21 mins
 $$P      d$'     ,    $$P     Packages: 1946 (dpkg), 21 (flatpak-user), 9 (snap)
 $$:      $$.   -    ,d$$'     Shell: bash 5.2.37
 $$;      Y$b._   _,d$P'       Display (Color LCD): 2880x1800 @ 60 Hz (as 1648x1030) in 15" [Built-in]
 Y$$.    `.`"Y$$$$P"'          DE: GNOME 48.7
 `$$b      "-.__               WM: Mutter (Wayland)
  `Y$$b                        WM Theme: Adwaita
   `Y$$.                       Theme: Adwaita [GTK2/3/4]
     `$$b.                     Icons: Adwaita [GTK2/3/4]
       `Y$$b.                  Font: Cantarell (11pt) [GTK2/3/4]
         `"Y$b._               Cursor: Adwaita (24px)
             `""""             Terminal: /dev/pts/0
                               CPU: Intel(R) Core(TM) i7-7820HQ (8) @ 3.90 GHz
                               GPU 1: AMD Radeon RX Graphics [Discrete]
                               GPU 2: Intel HD Graphics 630 @ 1.10 GHz [Integrated]
                               Memory: 2.98 GiB / 15.52 GiB (19%)
                               Swap: 0 B / 15.90 GiB (0%)
                               Disk (/): 10.82 GiB / 24.02 GiB (45%) - ext4
                               Disk (/home): 19.96 GiB / 294.78 GiB (7%) - ext4
                               Disk (/tmp): 240.94 MiB / 2.68 GiB (9%) - ext4
                               Local IP (enp70s0): 192.168.x.xxx/24
                               Battery (A1820): 98% [AC Connected]
                               Locale: en_US.UTF-8
```


Confirm the model is **MacBookPro14,3** in macOS System Report or run `cat /sys/class/dmi/id/product_name` on Linux. Use kernel `7.3.4+deb13-amd64` with these scripts.

## 1. Start with Debian 13

Connect wired Ethernet before you begin. You’ll need it to download packages until the built-in Wi-Fi is working. Use a USB Ethernet adapter or a Thunderbolt dock with Ethernet. OWC Thunderbolt docks have worked in our setup. Debian may show the wired interface as `eth0` or under a different name. [OWC Thunderbolt 3 Dock](https://eshop.macsales.com/shop/docks/owc-thunderbolt-3-dock)

Already on Debian 13? Skip to step 2. Otherwise, back up your data, write the **amd64 Debian 13 netinst** image to a USB drive with [balenaEtcher](https://etcher.balena.io/) or `dd`. balenaEtcher verifies the write automatically. Start the Mac while holding **Option** and pick the USB’s **EFI Boot** entry. [Debian installer downloads](https://www.debian.org/distrib/netinst) · [Verify the installer image](https://www.debian.org/CD/verify)

If you’re keeping macOS or OpenCore, back up the EFI System Partition too. In Debian’s manual partitioner, reuse the existing EFI partition without formatting it and keep macOS partitions out of the format list. If Debian asks to write a fallback bootloader to the removable-media path, decline to preserve OpenCore’s `EFI/BOOT`. [Debian partitioning guide](https://www.debian.org/releases/trixie/amd64/ch06s03.en.html)

## 2. Boot the tested kernel

Enable `trixie-backports` if it isn’t already enabled. Keep `non-free-firmware` enabled in your Debian sources for Broadcom firmware. Confirm that APT offers the exact kernel package below. Backports rotates packages, so if this release is gone from your mirror, stop here. Keep your current working kernel available in GRUB. [Debian Backports instructions](https://backports.debian.org/Instructions/)

```bash
sudo apt update
apt-cache policy linux-image-7.3.4+deb13-amd64
sudo apt install linux-image-7.3.4+deb13-amd64/trixie-backports
sudo systemctl mask sleep.target
sudo reboot
```

Select 7.3.4 under **Advanced options for Debian** in GRUB if needed. Run `uname -r` and confirm it prints `7.3.4+deb13-amd64`.

## 3. Bring back Wi-Fi, the Touch Bar, and fan control

Clone or download this repo and open a terminal in its top-level folder. Run the fan installer as your regular user so it builds without root.

```bash
sudo ./install.sh
sudo apt install git build-essential
./install-fan.sh
sudo reboot
```

The Wi-Fi service uses an identity IOMMU domain for the onboard Broadcom card. This bypasses DMA translation for that card’s isolated group. The Touch Bar service uses the T1’s existing HID interfaces. If an older `apple_ibridge` or `apple_touchbar` driver is loaded, the installer stops so you can remove that setup before proceeding. The fan installer builds mbpfan 2.5.0 from the pinned upstream commit and installs the included temperature profile. [mbpfan upstream](https://github.com/linux-on-mac/mbpfan)

After reboot, join a Wi-Fi network, try **Fn** on the Touch Bar, and check the services. The Wi-Fi and Touch Bar services are scoped to this kernel.

```bash
systemctl status macbook-broadcom-iommu t1-touchbar mbpfan --no-pager
```

### Stop Touch Bar blinking if it occurs

If the Touch Bar repeatedly blinks, try disabling its idle dimming. This stopped the blinking on one MacBookPro14,3. From the repo root, run:

```bash
./touchbar-dimming.sh disable
```

The script keeps the bar lit while the service is running and restarts only the Touch Bar service. To restore the default idle dimming, run `./touchbar-dimming.sh restore`.

## 4. Try internal audio

Audio is optional. The installer needs the headers and `linux-source-7.3` package at the same Debian package version as the installed kernel image.

```bash
sudo ./install-audio.sh
sudo reboot
```

Select the built-in output and input in Sound settings, play something through the speakers, then make a short microphone recording. Check `/proc/asound/pcm` for `CS8409/CS42L83 Analog` if the devices don’t appear in Sound settings. [Cirrus driver source and license](https://github.com/davidjo/snd_hda_macbookpro/tree/1931615d723899f64b352e9e7ed2368c21c49728)

## 5. Lock it down before taking it out

### Turn on the firewall

From a terminal on the laptop, block unsolicited inbound connections and allow outbound traffic. If you already manage another firewall, use that firewall to apply the same policy. Review the output for old inbound allow rules you no longer need. [Debian UFW manual](https://manpages.debian.org/trixie/ufw/ufw.8.en.html)

```bash
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status verbose
```

### Turn off services you don’t use

Run `sudo ss -lntup` to see what is listening. Turn off remote desktop, file sharing, and other network services you don’t use. If OpenSSH Server is installed and you never connect into this laptop, disable `ssh.service` and `ssh.socket` if present with `sudo systemctl disable --now UNIT`, replacing `UNIT` with each unit name. If you need inbound SSH, use key-only authentication and allow it through the firewall only from your trusted VPN or management network.

### Allow OpenSSH over Tailscale and an optional trusted LAN

From the laptop’s local terminal, add the Tailscale Debian 13 repository. Set both files to mode `0644` so APT can read the signing key. [Official Tailscale packages for Debian](https://pkgs.tailscale.com/stable/#debian-trixie)

```bash
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg |
  sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list |
  sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
sudo chmod 0644 /usr/share/keyrings/tailscale-archive-keyring.gpg \
  /etc/apt/sources.list.d/tailscale.list
sudo apt update && sudo apt install tailscale && sudo tailscale up
```

Open the sign-in URL, join your tailnet, and confirm that `tailscale status` and `ip link show tailscale0` succeed. Set the firewall defaults, add the interface-specific rule, and enable UFW from the local terminal.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0 to any port 22 proto tcp
sudo ufw enable
sudo ufw status numbered
tailscale ip -4
```

To also allow SSH from your trusted LAN, replace the example subnet with your own.

```bash
sudo ufw allow from 192.168.133.0/24 to any port 22 proto tcp
sudo ufw status numbered
```

Keep the `tailscale0` rules and your trusted subnet rule. Remove any SSH allow rule that applies to all sources on all interfaces with `sudo ufw delete NUMBER`, using the current rule number. A subnet rule also matches other networks using that subnet. If you use a dedicated Ethernet interface for your trusted LAN, add `in on INTERFACE` to the LAN rule.

Set your tailnet policy to allow TCP port 22 on this laptop only from authorized users or devices. Test a fresh SSH connection to the laptop’s Tailscale IP and, if you added the LAN rule, to its LAN IP from the trusted network. [Tailscale access controls](https://tailscale.com/docs/features/access-control)

### Verify AppArmor

Install the profile loader and tools, start the service, and check which profiles are enforcing. Use the kernel journal to investigate denials if an app stops working. [Debian AppArmor status manual](https://manpages.debian.org/trixie/apparmor/aa-status.8.en.html)

```bash
sudo apt install apparmor apparmor-utils
sudo systemctl enable --now apparmor.service
sudo aa-status
sudo journalctl -k -b -g 'apparmor="DENIED"' --no-pager
```

### Patch it, encrypt it, lock it

- Enable automatic Debian security updates with `sudo apt install unattended-upgrades` and `sudo dpkg-reconfigure unattended-upgrades`. Review Backports kernel updates separately. The setup here targets one exact release, so test the hardware on a newer kernel before relying on it and keep a working GRUB entry for rollback. [Debian security update guidance](https://www.debian.org/doc/manuals/debian-reference/ch02.en)
- Set up LUKS during installation for Debian’s system, home data, and swap. If you’re dual-booting, apply encryption to the Debian partitions you intend to use. Set a short automatic screen-lock timeout, require your password to unlock, and power off before leaving the laptop unattended for long periods. [Debian installer encryption guide](https://www.debian.org/releases/trixie/amd64/ch06s03.en.html#partman-crypto)
- If you keep booting macOS, check `csrutil status` on that side too. Running OpenCore on older Intel Macs with SIP partially disabled is a real risk — AI-assisted exploit tools are lowering the bar for local privilege escalation, and a weakened SIP is an open invitation. If you don’t need macOS, wipe it and reclaim the disk for your encrypted Debian install. If you do need it, re-enable full SIP and remove OpenCore. [Apple’s SIP configuration guide](https://developer.apple.com/documentation/security/disabling-and-enabling-system-integrity-protection)

## 6. Test suspend and lid close

Keep sleep masked for daily use until both tests pass. To test, save your work, safely eject external storage, and unplug USB-C devices and docks. Use the laptop's local terminal.

Add the PCIe setting once. It applies on subsequent normal boots, so you can leave the GRUB menu entry alone.

```bash
printf '%s\n' 'GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} pcie_port_pm=off"' |
  sudo tee /etc/default/grub.d/99-suspend-trial.cfg >/dev/null
sudo update-grub && sudo reboot
```

Boot the normal 7.3.4 entry. From the repo root, verify the boot argument and run the supervised test with the lid open. The script selects s2idle, arms a 45-second RTC alarm, and checks that the Thunderbolt controllers return. [Same-model Thunderbolt workaround](https://gist.github.com/Daniel-E-N/6435d5ea17378192aa2188d419200c44)

```bash
grep -w 'pcie_port_pm=off' /proc/cmdline &&
  python3 suspend/thunderbolt-test.py check &&
  sudo systemctl unmask sleep.target &&
  ./suspend/run-suspend-trial.sh
```

Check the built-in display, Wi-Fi, and Touch Bar after wake. If the manual test passes, arm a fresh trial and set another RTC alarm before closing the lid. Wait until suspend starts, then reopen the lid. Press Space or touch the trackpad if the panel stays dark.

```bash
sudo python3 suspend/thunderbolt-test.py arm &&
  sudo rtcwake -m no -s 45
```

After waking, check the suspend log for entry and exit and confirm the controllers returned. Disarm the trial. The helper applies the Thunderbolt workaround for one suspend at a time.

```bash
sudo journalctl -k -b -g 'PM: suspend (entry|exit)' --no-pager
python3 suspend/thunderbolt-test.py check
sudo rtcwake -m disable
sudo python3 suspend/thunderbolt-test.py disarm
```

If both tests pass, unmask sleep for daily use.

```bash
sudo systemctl unmask sleep.target
```

If the laptop hangs, reboot locally, mask sleep again with `sudo systemctl mask sleep.target`, and check the previous boot with `sudo journalctl -b -1 -u systemd-suspend.service --no-pager`. To revert the GRUB setting, remove `/etc/default/grub.d/99-suspend-trial.cfg`, run `sudo update-grub`, and reboot.

## 7. Install optional desktop tools

- **Ghostty** for the terminal. Follow the Linux installation instructions and choose a package built for Debian 13 amd64, or follow the linked source build instructions. [Ghostty installation guide](https://ghostty.org/docs/install/binary#linux)
- **Toshy** for Mac-style keyboard shortcuts. Follow the upstream instructions for your desktop session and run the installer as your regular desktop user. [Toshy installation guide](https://github.com/RedBearAK/Toshy)
- **Zed** for graphical editing. Follow the Linux x86_64 installation steps and check Vulkan support if Zed fails to open. [Zed Linux installation guide](https://zed.dev/docs/linux)
- **Firefox ESR**, **Git**, **Neovim**, **Glances**, **Podman**, and **Flatpak** are available from Debian. Remove any packages you don’t want from the command.

```bash
sudo apt update
sudo apt install firefox-esr git neovim glances podman flatpak
```

Run `glances` for a live system monitor or `podman info` as your regular user to check rootless Podman.

### Check Firefox ESR hardware video decoding

Install the Intel VA-API driver and check the render node for the Intel HD 630.

```bash
sudo apt install intel-media-va-driver vainfo
for node in /sys/class/drm/renderD*; do
  printf '/dev/dri/%s → %s\n' "${node##*/}" "$(basename "$(readlink -f "$node/device")")"
done
# Replace renderD129 with the node mapped to 0000:00:02.0 above.
intel_render=/dev/dri/renderD129
vainfo --display drm --device "$intel_render"
```

Look for `VAProfileVP9Profile0` with `VAEntrypointVLD` for VP9 decoding. In Firefox, check **Media → Codec Support Information** in `about:support` for hardware support for the codec you’re playing. In `about:config`, reset any old overrides that disabled hardware decoding or forced software WebRender. [Firefox media codec documentation](https://support.mozilla.org/en-US/kb/audio-and-video-firefox)

If native Wayland playback stutters or logs DMA-BUF import errors, fully quit Firefox and try a one-off XWayland launch with the Intel GPU:

```bash
env MOZ_ENABLE_WAYLAND=0 DRI_PRIME=pci-0000_00_02_0 \
  MOZ_DRM_DEVICE="$intel_render" \
  firefox-esr
```

Check that **Window Protocol** in `about:support` says `xwayland`, then replay the same video and compare dropped frames and CPU usage. VA-API support and lower CPU usage alone don’t confirm that Firefox used hardware decoding during playback.

## If something goes sideways

Boot your previous working kernel from **Advanced options for Debian**. For Wi-Fi or Touch Bar problems on 7.3.4, check the logs for the failing service.

```bash
sudo journalctl -b -u macbook-broadcom-iommu -u t1-touchbar -u mbpfan --no-pager
```

## Credits

- Broadcom board data and model-specific setup notes come from [Walker-18png’s MacBookPro14,3 project](https://github.com/Walker-18png/macbook-14-3-linux).
- The userspace Touch Bar daemon and fan profile come from [mythopoeic’s MacBookPro14,3 project](https://github.com/mythopoeic/macbookpro14-3-linux).
- The included Cirrus sources are from [davidjo’s audio driver](https://github.com/davidjo/snd_hda_macbookpro). Its license is included in [audio/LICENSE](audio/LICENSE).
