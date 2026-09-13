# IMOU HX21 (OpenWrt) - The Complete A-Z Configuration Journey

This document is the comprehensive, start-to-finish sysadmin guide detailing the exact process, the issues faced, and the solutions implemented when transitioning the IMOU HX21 (MediaTek Filogic MT7981B) from stock firmware to a highly tuned OpenWrt deployment.

---

## Phase 1: Flashing & The ISP PPPoE Block (MAC Address Issue)

**What Happened:** 
After developer Jahidul successfully flashed the OpenWrt firmware (via U-Boot and TFTP), the router booted, but the ISP instantly blocked the PPPoE internet connection. 

**The Root Cause (ISP MAC Binding):** 
Many GPON ISPs strictly bind your internet session to the physical MAC (Media Access Control) address of the router they originally provisioned. When OpenWrt was flashed, the WAN interface's MAC address changed from the stock IMOU MAC to an OpenWrt-generated MAC. The ISP's authentication server saw an "unauthorized" device trying to dial the PPPoE connection and dropped the connection.

**The Fix (MAC Cloning):**
To fix this, you must "spoof" or clone the original router's MAC address onto the new OpenWrt WAN interface.
1. Find the original WAN MAC address (usually printed on the sticker under the router or noted from the stock firmware).
2. Go to **Network** -> **Interfaces** -> **WAN** (or `pppoe-wan`).
3. Click **Advanced Settings**.
4. In the **Override MAC address** field, enter the original stock MAC address.
5. Click **Save & Apply**. The ISP will now recognize the router and authorize the PPPoE dial-in.

---

## Phase 2: Post-Flash Terminal Setup (The `apk` Era)

**What Happened:** 
When we SSH'd into the router to install packages, standard commands like `opkg update` failed.

**The Root Cause:** 
We flashed a bleeding-edge OpenWrt SNAPSHOT (`r31762`). Starting in late 2024, OpenWrt officially deprecated the `opkg` package manager in favor of Alpine Linux's `apk` (Alpine Package Keeper) for snapshot builds.

**The Fix:**
All terminal package management must now use `apk`. 
```bash
# Update package lists
apk update

# Install required sysadmin packages
apk add iperf3 sqm-scripts luci-app-sqm acme nextdns
```

---

## Phase 3: NextDNS & The Cloudflare Timeout

**What Happened:** 
To bypass ISP DNS hijacking and block ads, we installed the NextDNS CLI directly onto the router. However, during network testing on Cloudflare's speed test, we received a persistent **"ICE connection timeout"** error on the packet loss test.

**The Root Cause (WebRTC Blocking):** 
This was initially perceived as a network failure, but it was actually NextDNS doing its job too well. By default, NextDNS blocks WebRTC connections to prevent IP leaks (a method where websites can discover your true IP address even behind VPNs/proxies). Cloudflare's packet loss test relies on WebRTC.

**The Fix:** 
No action needed. We recognized this as a highly secure, sysadmin-level posture. It is a feature, not a bug.

---

## Phase 4: Local LuCI SSL & Rebinding Protection

**What Happened:** 
We wanted to access the OpenWrt GUI securely without browser warnings via `https://local.sajjadhossain.net`.

**The Setup:** 
1. Used the `acme` package with a Cloudflare API token to generate Let's Encrypt ECC certificates.
2. Mapped the generated certificates in `/etc/config/uhttpd` and restarted the web server.

**The Issue (DNS Rebinding):** 
NextDNS actively blocks "DNS Rebinding"—a security feature that stops public domain names from resolving to private local IP addresses (like `192.168.1.1`). This caused the browser to fail to load the LuCI interface.

**The Fix (Local Host Override):** 
We injected a manual override directly into the router's host file so the router resolves it before sending the query to NextDNS.
```bash
echo "192.168.1.1 local.sajjadhossain.net" >> /etc/hosts
/etc/init.d/dnsmasq restart
```

---

## Phase 5: Bufferbloat Mastery (PPPoE Overhead)

**What Happened:** 
The connection suffered from severe latency spikes (Bufferbloat) under heavy upload/download load.

**The Setup:** 
We deployed Smart Queue Management (`sqm-scripts`) using the `cake` algorithm (`piece_of_cake.qos`).

**The Critical Tweaks:**
1. **Interface Selection (`pppoe-wan`):** We strictly applied SQM to the logical `pppoe-wan` interface, NOT the physical `eth1` port. If applied to `eth1`, SQM fails to calculate the 8-byte PPPoE encapsulation overhead, resulting in inaccurate traffic shaping.
2. **Asymmetric Shaping (Download `0`):** Due to the ISP's volatile routing (175 Mbps BDIX local vs. 15 Mbps International), shaping the download speed was impossible. We set **Download (Ingress) to `0`** (unshaped) to let Cake handle only the upload queue.
3. **Upload Shaping (`65000`):** We hard-capped the **Upload (Egress) to 65000 Kbps** (slightly below the 70 Mbps physical ISP bottleneck).

**The Result:** 
The OpenWrt CPU successfully took over queue management from the ISP's hardware. Waveform tests returned a mathematically perfect **A+ Grade (+0ms / +0ms active latency)** on wired connections.

---

## Phase 6: Hardware Validation (iperf3)

**What Happened:** 
We needed to prove that the router's Filogic CPU and the local ethernet cables were capable of Gigabit wire speeds without dropping packets.

**The Fix:** 
We ran `iperf3 -s` on the router and connected from an M1 Mac. 
The test pushed a perfectly stable **937 Mbits/sec** with **0 TCP Retries**, proving the local hardware is pristine and capable of handling maximum throughput without CPU exhaustion.

---

## Phase 7: MediaTek Filogic Sysadmin Optimizations

We applied final architectural tweaks to optimize the MT7981B chip:

* **Flow Offloading (Disabled):** We deliberately left Software and Hardware Flow Offloading disabled (`None`). While offloading boosts raw throughput on weak CPUs, it completely bypasses the SQM `cake` queues and ruins the bufferbloat fix.
* **Packet Steering (RPS/RFS):** We verified that manual Packet Steering checkboxes were removed from the modern firewall4 (nftables) GUI because the latest MediaTek drivers and the kernel automatically handle interrupt load balancing across the ARM cores.
* **Wi-Fi Airspace (DFS Channels):** The `BD - Bangladesh` regulatory domain locks out DFS channels. We changed the Country Code to `US - United States` to unlock channels 52-144, allowing the 5GHz radio to operate in completely interference-free airspace.
* **Seamless Roaming (802.11r):** Configured Fast Transition (802.11r) across identical SSIDs to allow modern clients (iPhones, Macs) to instantly jump between 2.4GHz and 5GHz bands without dropping VoIP or WhatsApp calls.
