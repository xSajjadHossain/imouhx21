# IMOU HX21 (OpenWrt) - The Complete A-Z Flashing & Configuration Journey

This document is the comprehensive, start-to-finish sysadmin guide detailing the exact process, the errors faced, and the solutions implemented when transitioning the IMOU HX21 (MediaTek Filogic MT7981B) from stock firmware to a highly tuned OpenWrt deployment.

---

## Phase 1: The Initial Flashing Execution (Stock to OpenWrt)

Before any network tuning could begin, we had to safely overwrite the stock IMOU firmware with OpenWrt. This was a high-risk operation that required specific fail-safes.

### Step 1: Unlocking SSH
The stock firmware does not allow terminal access. 
1. We logged into the IMOU web interface and used the "Restore Configuration" feature to upload a modified backup file (`HX21-ssh.bin`).
2. Upon reboot, this modified backup forced the router to open port 22. The web interface password changed to `12345678`, and SSH access was granted with an empty password.

### Step 2: The Critical MTD Backups
Before touching the bootloader, we pulled full backups of all stock partitions. This was our insurance policy against bricking.
```bash
cat /dev/mtd0 | gzip -1 -c > /tmp/mtd0_spi0.0.bin.gz
cat /dev/mtd1 | gzip -1 -c > /tmp/mtd1_BL2.bin.gz
cat /dev/mtd2 | gzip -1 -c > /tmp/mtd2_u-boot-env.bin.gz
cat /dev/mtd3 | gzip -1 -c > /tmp/mtd3_Factory.bin.gz
cat /dev/mtd4 | gzip -1 -c > /tmp/mtd4_FIP.bin.gz
cat /dev/mtd5 | gzip -1 -c > /tmp/mtd5_ubi.bin.gz
```
We downloaded these via SCP to local storage.

### Step 3: The TFTP Ethernet Requirement (The Near-Brick Warning)
* **The Error Avoided:** We initially planned to flash the device using an M1 Mac over Wi-Fi. We executed a "Hard Red Flag" stop because the U-Boot bootloader relies entirely on TFTP (Trivial File Transfer Protocol) to fetch the OpenWrt recovery image, and **U-Boot does not possess Wi-Fi drivers**. 
* **The Fix:** We pivoted, grabbed a Windows laptop with a physical Ethernet port, and set up a TFTP server on `192.168.1.254` to serve the `initramfs-recovery.itb` file.
* We then wiped the OS via SSH (`mtd erase ubi`) and rebooted. The router seamlessly pulled the OpenWrt recovery image from the Windows TFTP server into RAM.
* From the RAM recovery environment, we ran `sysupgrade -n /tmp/openwrt-mediatek-filogic-imou_hx21-squashfs-sysupgrade.itb` to permanently flash the router.

---

## Phase 2: The ISP PPPoE Block (MAC Address Issue)

**What Happened:** 
After developer Jahidul's OpenWrt firmware successfully flashed and the router booted, we configured PPPoE, but the ISP instantly blocked the internet connection.

**The Root Cause (ISP MAC Binding):** 
Many GPON ISPs in Bangladesh strictly bind your internet session to the physical MAC (Media Access Control) address of the router they originally provisioned. When OpenWrt was flashed, the WAN interface generated a new MAC address. The ISP's authentication server saw an "unauthorized" device trying to dial the PPPoE connection and dropped it.

**The Fix (MAC Cloning):**
To fix this, we spoofed the original stock router's MAC address onto the new OpenWrt WAN interface.
1. Navigated to **Network** -> **Interfaces** -> **WAN** (or `pppoe-wan`).
2. Clicked **Advanced Settings**.
3. In the **Override MAC address** field, we entered the original stock IMOU MAC address.
4. Clicked **Save & Apply**. The ISP recognized the router and authorized the PPPoE dial-in.

---

## Phase 3: Post-Flash Terminal Setup (The `apk` Era)

**What Happened:** 
When we SSH'd into the router to install packages, standard commands like `opkg update` failed.

**The Root Cause:** 
We flashed a bleeding-edge OpenWrt SNAPSHOT (`r31762`). Starting in late 2024, OpenWrt officially deprecated the `opkg` package manager in favor of Alpine Linux's `apk` (Alpine Package Keeper).

**The Fix:**
All terminal package management was adapted to `apk`.
```bash
apk update
apk add iperf3 sqm-scripts luci-app-sqm acme nextdns
```

---

## Phase 4: NextDNS & The Cloudflare Timeout

**What Happened:** 
To bypass ISP DNS hijacking and block ads, we deployed the NextDNS CLI directly onto the router. However, during network testing on Cloudflare's speed test, we received a persistent **"ICE connection timeout"** error on the packet loss test.

**The Root Cause (WebRTC Blocking):** 
This was initially perceived as a network failure, but it was actually NextDNS doing its job perfectly. NextDNS blocks WebRTC connections to prevent IP leaks. Cloudflare's packet loss test relies on WebRTC.

**The Fix:** 
No action needed. We recognized this as a highly secure, sysadmin-level posture. It is a feature, not a bug.

---

## Phase 5: Local LuCI SSL & Rebinding Protection

**What Happened:** 
We wanted to access the OpenWrt GUI securely without browser warnings via `https://local.sajjadhossain.net`.

**The Setup:** 
1. Used the `acme` package with a Cloudflare API token to generate Let's Encrypt ECC certificates.
2. Mapped the generated certificates in `/etc/config/uhttpd` and restarted the web server.

**The Issue (DNS Rebinding):** 
NextDNS actively blocks "DNS Rebinding"—a security feature that stops public domains from resolving to private local IPs (`192.168.1.1`). This caused the browser to fail to load the LuCI interface.

**The Fix (Local Host Override):** 
We injected a manual override directly into the router's host file so it resolves locally before hitting NextDNS.
```bash
echo "192.168.1.1 local.sajjadhossain.net" >> /etc/hosts
/etc/init.d/dnsmasq restart
```

---

## Phase 6: Bufferbloat Mastery (PPPoE Overhead)

**What Happened:** 
The connection suffered from severe latency spikes (Bufferbloat) under heavy upload/download load.

**The Setup:** 
Deployed Smart Queue Management (`sqm-scripts`) using the `cake` algorithm.

**The Critical Tweaks:**
1. **Interface Selection (`pppoe-wan`):** We strictly applied SQM to the logical `pppoe-wan` interface, NOT the physical `eth1` port. If applied to `eth1`, SQM fails to calculate the 8-byte PPPoE encapsulation overhead.
2. **Asymmetric Shaping (Download `0`):** Due to the ISP's volatile routing (175 Mbps local BDIX vs. 15 Mbps International), shaping the download speed was impossible. We set **Download (Ingress) to `0`** (unshaped).
3. **Upload Shaping (`65000`):** We hard-capped the **Upload (Egress) to 65000 Kbps** (slightly below the 70 Mbps physical ISP bottleneck).

**The Result:** 
Waveform tests returned a mathematically perfect **A+ Grade (+0ms / +0ms active latency)** on wired connections.

---

## Phase 7: Hardware Validation (iperf3)

**What Happened:** 
We needed to prove that the router's Filogic CPU and the local ethernet cables were capable of Gigabit wire speeds.

**The Fix:** 
Ran `iperf3 -s` on the router and connected from an M1 Mac. The test pushed a perfectly stable **937 Mbits/sec** with **0 TCP Retries**, proving the local hardware is pristine.

---

## Phase 8: MediaTek Filogic Sysadmin Optimizations

We applied final architectural tweaks to optimize the MT7981B chip:

* **Flow Offloading (Disabled):** Left Software/Hardware Flow Offloading disabled (`None`). Offloading boosts raw throughput on weak CPUs but completely bypasses SQM `cake` queues, ruining the bufferbloat fix.
* **Packet Steering (RPS/RFS):** Verified that manual Packet Steering checkboxes were removed from the modern firewall4 (nftables) GUI because the latest MediaTek drivers and the kernel automatically handle interrupt load balancing.
* **Wi-Fi Airspace (DFS Channels):** The `BD - Bangladesh` regulatory domain locks out DFS channels. We changed the Country Code to `US - United States` to unlock channels 52-144, allowing the 5GHz radio to operate in interference-free airspace.
* **Seamless Roaming (802.11r):** Configured Fast Transition (802.11r) across identical SSIDs to allow modern clients to instantly jump between 2.4GHz and 5GHz bands without dropping calls.
