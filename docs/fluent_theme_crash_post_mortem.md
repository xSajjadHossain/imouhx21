# Post-Mortem: Fluent Theme Installation Crash (OpenWrt Snapshot)

## What Happened
On September 14, 2026, an attempt was made to install `luci-theme-fluent` using the developer's official `install.sh` script on a bleeding-edge OpenWrt Snapshot (using the `apk` package manager).

During installation, the script ran `apk add luci-theme-fluent`. Because themes depend on the LuCI web interface, the `apk` package manager forcefully pulled the latest dependencies from the remote repository.

Critically, this included upgrading the router's core scripting engine:
- `ucode`
- `libucode`
- `ucode-mod-fs`
- `luci-base`

## The Root Cause (The Snapshot Trap)
OpenWrt Snapshots are compiled daily. The base firmware installed on the router was compiled a few days/weeks prior. By forcefully injecting today's `ucode` binaries into an older snapshot, it caused an Application Binary Interface (ABI) mismatch.

`ucode` is the central engine that OpenWrt uses to run `procd` (the init system) and `netifd` (the network daemon). 

When the router was rebooted (or when `uhttpd` was restarted), the mismatched `ucode` binaries crashed. Because `netifd` relies on `ucode`, the network daemon failed to start. As a result, the router could not bring up the Wi-Fi radios (SSID disappeared) or the WAN interface (internet dropped).

## How We Fixed It
The router was "soft-bricked" (kernel alive, network stack dead). Because physical Ethernet access was still available, we recovered the router using OpenWrt's built-in overlay reset command:

```bash
firstboot -y && reboot
```

This command wiped the `/overlay` partition (destroying the corrupted `ucode` packages and the Fluent theme) and booted the router back into the read-only `/rom` partition, restoring it to a clean state. We then restored the working backup archive (`imouhx21bk.zip`).

## Sysadmin Takeaway
**Never run `apk upgrade` on core system packages (like `libc`, `kernel`, or `ucode`) on an OpenWrt Snapshot.** Snapshots are rolling releases. If you need a new package that requires core library upgrades, you must flash a completely new `sysupgrade` image first.
