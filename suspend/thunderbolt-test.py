#!/usr/bin/python3 -I
"""One-boot MacBookPro14,3 Thunderbolt suspend test for Debian."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

PCI = Path("/sys/bus/pci/devices")
RUN = Path("/run/debian-setup-thunderbolt")
STATE = RUN / "state.json"
SERVICE = Path("/run/systemd/system/systemd-suspend.service.d/90-debian-setup-thunderbolt.conf")
SLEEP = Path("/run/systemd/sleep.conf.d/90-debian-setup-thunderbolt.conf")
BRANCHES = {
    "0000:04:00.0": ("0000:00:01.1", "0000:06:00.0", "0000:07:00.0"),
    "0000:7a:00.0": ("0000:00:01.2", "0000:7c:00.0", "0000:7d:00.0"),
}


def check_device(address, device, driver):
    node = PCI / address
    with (node / "config").open("rb") as config:
        expected = bytes.fromhex("86 80") + device.to_bytes(2, "little")
        if config.read(4) != expected:
            raise RuntimeError(f"Unexpected or inaccessible controller {address}")
    if not (node / "driver").is_symlink() or (node / "driver").resolve().name != driver:
        raise RuntimeError(f"{address} requires driver {driver}")
    return node.resolve(strict=True)


def topology():
    for (root, (parent, controller, usb)), parent_id in zip(BRANCHES.items(), (0x1905, 0x1909)):
        parent_path = check_device(parent, parent_id, "pcieport")
        root_path = check_device(root, 0x1578, "pcieport")
        if root_path.parent != parent_path:
            raise RuntimeError(f"Unexpected upstream port for {root}")
        for address, device, driver in ((controller, 0x15D2, "thunderbolt"), (usb, 0x15D4, "xhci_hcd")):
            if not check_device(address, device, driver).is_relative_to(root_path):
                raise RuntimeError(f"{address} is outside its expected branch")


def check():
    if Path("/sys/class/dmi/id/product_name").read_text().strip() != "MacBookPro14,3":
        raise RuntimeError("This test requires MacBookPro14,3")
    topology()
    for category in ("block", "net"):
        for node in (Path("/sys/class") / category).iterdir():
            device = node / "device"
            if device.exists() and any(root in device.resolve().parts for root in BRANCHES):
                raise RuntimeError(f"Disconnect {category} device {node.name} before testing")
    for node in PCI.iterdir():
        if not any(root in node.resolve().parts for root in BRANCHES):
            continue
        base_class = int((node / "class").read_text(), 16) >> 16
        if base_class in (1, 3) or (node / "driver").resolve().name.startswith("vfio"):
            raise RuntimeError(f"Storage, GPU or passthrough device under Thunderbolt: {node.name}")
    for device in Path("/sys/bus/usb/devices").iterdir():
        if ":" not in device.name and "-" in device.name and any(
            root in device.resolve().parts for root in BRANCHES
        ):
            raise RuntimeError(f"Disconnect USB device {device.name} before testing")
    print("Thunderbolt topology and attached-device checks passed", flush=True)


def prepare():
    check()
    if STATE.exists() or (RUN / "used").exists():
        raise RuntimeError("This test is already used. Disarm before another suspend.")
    settings = {}
    for node in PCI.iterdir():
        paths = [node / "d3cold_allowed"]
        if (node / "driver").resolve().name == "pcieport":
            paths.append(node / "power/control")
        for path in paths:
            if path.exists():
                settings[str(path)] = path.read_text().strip()
    with STATE.open("x") as state:
        json.dump(settings, state)
    (RUN / "used").touch()
    for name in settings:
        path = Path(name)
        path.write_text("0\n" if path.name == "d3cold_allowed" else "on\n")
    for root in BRANCHES:
        (PCI / root / "remove").write_text("1\n")
        if (PCI / root).exists():
            raise RuntimeError(f"{root} did not detach")
        print(f"Detached Thunderbolt branch {root}", flush=True)


def restore():
    if not STATE.exists():
        return
    settings = json.loads(STATE.read_text())
    for attempt in range(2):
        for parent, _, _ in BRANCHES.values():
            (PCI / parent / "rescan").write_text("1\n")
        time.sleep(1)
        try:
            subprocess.run(["/usr/bin/udevadm", "settle", "--timeout=10"], check=True)
            topology()
            break
        except (OSError, RuntimeError, subprocess.SubprocessError):
            if attempt == 1:
                raise
    for name, value in settings.items():
        path = Path(name)
        if path.exists():
            path.write_text(value + "\n")
    STATE.unlink()
    print("Both Thunderbolt branches and both USB-C controllers restored", flush=True)


def systemctl(*args):
    subprocess.run(["/usr/bin/systemctl", *args], check=True)


def arm():
    if "pcie_port_pm=off" not in Path("/proc/cmdline").read_text().split():
        raise RuntimeError("Boot once with pcie_port_pm=off first. See the suspend section in README.md.")
    check()
    RUN.mkdir(mode=0o700)
    created = []
    try:
        helper = RUN / "test.py"
        shutil.copyfile(__file__, helper)
        for path in (SERVICE, SLEEP):
            path.parent.mkdir(parents=True, exist_ok=True)
        with SERVICE.open("x") as config:
            created.append(SERVICE)
            config.write(f"[Service]\nExecStartPre=/usr/bin/python3 -I {helper} prepare\n"
                         f"ExecStopPost=/usr/bin/python3 -I {helper} restore\n")
        with SLEEP.open("x") as config:
            created.append(SLEEP)
            config.write("[Sleep]\nMemorySleepMode=s2idle\n")
        systemctl("daemon-reload")
    except Exception:
        # Remove only the files written by this attempt.
        for path in created:
            path.unlink(missing_ok=True)
        shutil.rmtree(RUN)
        raise
    print("Armed for one suspend this boot. Set the RTC alarm before suspending.")


def disarm():
    if not RUN.is_dir():
        return
    if STATE.exists():
        raise RuntimeError("Controller recovery is pending. Reboot to recover before testing again.")
    SERVICE.unlink(missing_ok=True)
    SLEEP.unlink(missing_ok=True)
    systemctl("daemon-reload")
    shutil.rmtree(RUN)


if __name__ == "__main__":
    actions = {"check": check, "arm": arm, "prepare": prepare, "restore": restore, "disarm": disarm}
    try:
        if len(sys.argv) != 2 or sys.argv[1] not in actions:
            raise RuntimeError("Usage: thunderbolt-test.py check|arm|disarm")
        if sys.argv[1] != "check" and os.geteuid() != 0:
            raise RuntimeError("Run with sudo on the Debian host")
        actions[sys.argv[1]]()
    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as error:
        sys.exit(str(error))
