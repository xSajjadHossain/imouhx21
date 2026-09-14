# The Ultimate OpenWrt Upgrade: Flashing, Tuning, and Securing the IMOU HX21

Welcome to the complete, start-to-finish sysadmin journey of transforming an IMOU HX21 router (powered by the MediaTek Filogic MT7981B) from a locked-down stock device into a highly tuned, Zero-Trust secured OpenWrt powerhouse.

This guide simplifies every technical hurdle we faced—from dangerous TFTP flashing requirements to bypassing aggressive ISP restrictions and entirely defeating CGNAT limitations.

---

## Phase 1: Escaping Stock Firmware (The Flashing Process)

Stock firmware is restrictive. To replace it with OpenWrt, we had to execute a high-risk flash operation.

### 1. Unlocking the Terminal (SSH)
The stock IMOU interface doesn't allow command-line access. We bypassed this by using the "Restore Configuration" feature to upload a modified backup file (`HX21-ssh.bin`). Upon rebooting, this forced the router to open Port 22, granting us root SSH access.

### 2. The Insurance Policy (MTD Backups)
Before overwriting the bootloader, we dumped full backups of all stock partitions. If anything went wrong, these files were our un-brick mechanism.
```bash
cat /dev/mtd0 | gzip -1 -c > /tmp/mtd0_spi0.0.bin.gz
# (Repeated for mtd1 through mtd5)
```

### 3. The TFTP Ethernet Trap
**The Danger:** We initially planned to flash the device using an M1 Mac over Wi-Fi. This was a "Hard Red Flag." The U-Boot bootloader relies entirely on TFTP to fetch the OpenWrt recovery image, and **U-Boot does not possess Wi-Fi drivers**.
**The Fix:** We pivoted to a laptop with a physical Ethernet port, ran a local TFTP server, and wiped the OS (`mtd erase ubi`). The router seamlessly pulled the OpenWrt recovery image via Ethernet into its RAM, allowing us to permanently flash it safely using `sysupgrade`.

---

## Phase 2: Beating the ISP (MAC Cloning)

**The Problem:** Once OpenWrt was running, our PPPoE internet connection was instantly blocked by the ISP.
**The Reason:** Many ISPs in Bangladesh strictly bind your internet session to the physical MAC address of the original stock router. OpenWrt generated a new MAC address, causing the ISP to reject the connection.
**The Fix:** We went to **Network -> Interfaces -> WAN -> Advanced Settings** and spoofed (cloned) the original stock IMOU MAC address. The ISP authorized the connection instantly.

---

## Phase 3: The New Era of OpenWrt (APK Package Manager)

**The Problem:** Standard commands like `opkg update` failed completely.
**The Reason:** We flashed a bleeding-edge OpenWrt SNAPSHOT. OpenWrt has officially deprecated the old `opkg` system in favor of Alpine Linux's **`apk`** (Alpine Package Keeper).
**The Fix:** We adapted our sysadmin muscle memory to the new era:
```bash
apk update
apk add iperf3 sqm-scripts luci-app-sqm acme nextdns
```

---

## Phase 4: Privacy & SSL (NextDNS & Local Domains)

We deployed NextDNS directly onto the router to block ads and prevent ISP DNS hijacking. We also wanted secure, warning-free HTTPS access to the router's web interface via `https://local.sajjadhossain.net`.

1. **SSL Generation:** We used the `acme` package with a Cloudflare API token to generate Let's Encrypt certificates directly on the router.
2. **DNS Rebinding Fix:** NextDNS actively blocks public domains from resolving to private local IPs (`192.168.1.1`) as a security measure. This broke our local domain. We fixed it by injecting a manual override into the router's local hosts file:
   ```bash
   echo "192.168.1.1 local.sajjadhossain.net" >> /etc/hosts
   /etc/init.d/dnsmasq restart
   ```

*(Fun Fact: NextDNS perfectly blocks WebRTC to prevent IP leaks, which is why Cloudflare's packet loss test occasionally times out. This is a feature, not a bug).*

---

## Phase 5: Eradicating Lag (SQM & Bufferbloat)

Under heavy load, our connection suffered from massive latency spikes (Bufferbloat). We fixed this by deploying Smart Queue Management (`sqm-scripts`) using the `cake` algorithm.

**The Critical Tweaks:**
1. **Target the Logical Interface:** We strictly applied SQM to `pppoe-wan`, NOT the physical `eth1` port, ensuring SQM correctly calculated the 8-byte PPPoE overhead.
2. **Asymmetric Shaping:** Due to volatile ISP routing (fast local BDIX vs slow International speeds), shaping the download was impossible. We set **Download to `0`** (unshaped) and strictly hard-capped the **Upload to 65000 Kbps**.
3. **No Offloading:** We kept Hardware/Software Flow Offloading **Disabled**. Offloading boosts throughput on weak CPUs but completely bypasses SQM queues.

**The Result:** A mathematically perfect **A+ Grade (+0ms active latency)** on Waveform bufferbloat tests.

---

## Phase 6: Wireless Supremacy (DFS & Fast Roaming)

To get the most out of the Filogic wireless chip:
* **Unlocked Airspace:** The default Bangladesh regulatory domain locks out DFS channels. We changed the Country Code to `US` to unlock channels 52-144, moving our 5GHz radio into interference-free airspace.
* **Seamless Roaming:** We enabled Fast Transition (802.11r) across identical SSIDs, allowing iPhones and Macs to instantly jump between 2.4GHz and 5GHz bands without dropping calls.

---

## Phase 7: The Ultimate Remote Access (Cloudflare Tunnels & Zero Trust)

**The Problem:** We needed to manage the router remotely, but the ISP utilizes strict **CGNAT** (Carrier-Grade NAT). Traditional Port Forwarding and DDNS are completely useless under CGNAT.
**The Solution:** We deployed a Cloudflare `cloudflared` Tunnel directly on the router to create an outbound, encrypted proxy to Cloudflare's edge.

### The Terminal Copy/Paste Bug
When pasting the massive 200+ character Cloudflare Tunnel Token into the Mac SSH terminal, the terminal aggressively word-wrapped the string, inserting invisible line breaks that destroyed the `uci set` command. 
**The Fix:** We built the string in chunks using variables to bypass the terminal emulator's wrapping behavior:
```bash
T="eyJh..."
T="${T}iMmEx..."
uci set cloudflared.@cloudflared[0].token="$T"
```

### The 502 Bad Gateway Bug
Once the tunnel was running, trying to access `https://local.sajjadhossain.net` resulted in a **502 Bad Gateway**.
**The Cause:** Cloudflare was trying to route traffic to the raw IP `https://192.168.1.1`, but our router's SSL certificate was explicitly branded for `local.sajjadhossain.net`. The mismatch caused Cloudflare to drop the connection for security.
**The Fix:** In the Cloudflare Dashboard's Tunnel settings, we expanded **TLS**, toggled **No TLS Verify** to ON, and set the **Origin Server Name** to `local.sajjadhossain.net`. It instantly punched through the CGNAT.

### The Final Lockdown: Zero Trust
Bypassing CGNAT meant our OpenWrt login screen was now exposed to the entire public internet, risking botnet brute-force attacks. 
We immediately deployed a **Cloudflare Access Application** over the tunnel. Now, before anyone can even see the OpenWrt login screen, they are intercepted at Cloudflare's edge and forced to authenticate via an **Email OTP (One-Time Password)**. 

The router is now invincible, highly tuned, and accessible from anywhere in the world.

---

## Phase 8: Hardware Validation (iperf3)

We needed to prove that the router's MediaTek Filogic CPU and the local ethernet cables were genuinely capable of Gigabit wire speeds without bottlenecking.

**The Setup (Router as Server):**
We installed the `iperf3` package on the OpenWrt router to act as the speed test server.
```bash
apk add iperf3
```
Then, we started the iperf3 server daemon on the router, telling it to listen on the default port:
```bash
iperf3 -s
```

**The Test (Mac as Client):**
On the M1 Mac (connected via Gigabit Ethernet to the router's LAN port), we ran the iperf3 client command to blast the router with TCP traffic for 10 seconds:
```bash
iperf3 -c 192.168.1.1
```

**The Results:**
The test pushed a perfectly stable **937 Mbits/sec** with **0 TCP Retries**. This mathematically proved that our local hardware, cables, and the router's CPU switching capacity are in pristine condition and fully capable of handling 1 Gbps fiber connections in the future.

---

## Phase 9: The Snapshot Trap & Moving to Stable

**The Disaster:** On Sept 14, 2026, an attempt was made to install `luci-theme-fluent` using a third-party `install.sh` script. Because the router was running a bleeding-edge OpenWrt Snapshot, the `apk add` command aggressively pulled the absolute latest core libraries (like `ucode`) from the remote repository.

**The Crash:** Injecting today's `ucode` binaries into last week's Snapshot firmware caused a fatal ABI mismatch. The network daemon (`netifd`) crashed, killing Wi-Fi, dropping the LAN, and soft-bricking the router.

**The Recovery:**
1. The WAN cable to the ONU was physically disconnected to blind the ISP and prevent a permanent MAC block.
2. The router was hardware-reset (`firstboot -y && reboot`), destroying the corrupted `/overlay` partition and returning it to a clean state.
3. A full configuration backup (`.tar.gz`) was restored via the LuCI web interface.

**The Permanent Fix (Moving to Stable):**
To prevent this from ever happening again, the router was upgraded from the volatile Snapshot branch to the **OpenWrt 25.12.5 Stable Release** using a `sysupgrade` image. On the Stable branch, core libraries are frozen, meaning packages and themes can be safely installed without risking catastrophic system mismatches.
