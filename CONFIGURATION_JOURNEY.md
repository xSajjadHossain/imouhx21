# OpenWrt Network Configuration & Tuning Journey

This document summarizes the architectural decisions, sysadmin-level configurations, and troubleshooting steps taken after successfully flashing OpenWrt to the IMOU HX21 (MediaTek Filogic MT7981B).

## 1. DNS Security & ISP Hijack Prevention (NextDNS CLI)
* **The Goal:** Bypass local ISP DNS hijacking and implement network-wide ad/tracker blocking.
* **The Implementation:** We deployed the NextDNS CLI directly on the router. This encrypts all outbound DNS requests, bypassing the ISP entirely.
* **Sysadmin Discovery:** During initial network testing, Cloudflare's packet loss test returned an "ICE Connection Timeout" error. We diagnosed this not as a network failure, but as NextDNS successfully blocking a WebRTC IP leak. This is a highly secure, desirable posture.

## 2. Local SSL for LuCI (Bypassing Rebinding Protection)
* **The Goal:** Secure the local OpenWrt web interface (LuCI) with a valid SSL certificate (`https://local.sajjadhossain.net`) to eliminate browser security warnings.
* **The Implementation:** 
  * Deployed `acme` with a Cloudflare API token to generate ECC certificates.
  * Mapped the cert/key in `/etc/config/uhttpd`.
  * **The Fix:** NextDNS blocked the local IP resolution due to DNS Rebinding Protection. We bypassed this by injecting `192.168.1.1 local.sajjadhossain.net` directly into the router's `/etc/hosts`, allowing the router to resolve the domain locally before the request ever hit NextDNS.

## 3. SQM & Bufferbloat Mastery (Handling PPPoE Overhead)
* **The Issue:** Severe latency spikes (bufferbloat) under heavy upload/download load, a common issue with GPON ISPs using dumb hardware buffers.
* **The Architecture:** Deployed `sqm-scripts` using the `cake` algorithm and `piece_of_cake.qos` script.
* **Critical Tweaks:**
  * **Interface Selection:** Applied SQM to the logical `pppoe-wan` interface (instead of the physical `eth1`). This is absolutely critical because `cake` must be aware of the 8-byte PPPoE encapsulation overhead to calculate packet sizes accurately.
  * **Asymmetric Shaping:** The ISP download speeds were wildly volatile depending on the CDN (175 Mbps BDIX vs 15 Mbps international). Therefore, we set **Download (Ingress) to `0`** to leave it unshaped. We set **Upload (Egress) to `65000`** (just below the physical ~70 Mbps bottleneck).
* **The Result:** The OpenWrt CPU successfully took over queue management from the ISP. Waveform tests returned a mathematically perfect **A+ Grade (+0ms / +0ms active latency)** on wired connections.

## 4. Hardware Validation (The `apk` Migration)
* **The Issue:** Needed to verify that the local physical layer (Mac -> Ethernet -> Router) was flawless.
* **The Implementation:** Attempted to install `iperf3`. Discovered that the bleeding-edge OpenWrt SNAPSHOT (`r31762`) deprecated `opkg` in favor of Alpine Linux's `apk` package manager. 
* **The Result:** Ran `apk update && apk add iperf3`. The local LAN test pushed a perfectly stable **937 Mbits/sec** with **0 TCP Retries**, proving the M1 Mac, ethernet cable, and Filogic router CPU were performing flawlessly at Gigabit wire speeds.

## 5. MediaTek Filogic Sysadmin Optimizations
* **Flow Offloading (Disabled):** We deliberately left Software and Hardware Flow Offloading disabled (`None`). While offloading boosts raw throughput on weak CPUs, it bypasses the SQM `cake` queues and ruins the bufferbloat fix. The MT7981B CPU easily handles ~940 Mbps without offloading.
* **Packet Steering (RPS/RFS):** We verified that manual RPS checkboxes were removed from the modern firewall4 (nftables) GUI because the latest MediaTek drivers and the kernel automatically handle interrupt load balancing across the ARM cores.
* **Wi-Fi Airspace (DFS Channels):** The `BD - Bangladesh` regulatory domain locks out DFS channels. We changed the Country Code to `US - United States` to unlock channels 52-144, allowing the 5GHz radio to operate in completely interference-free airspace.
* **Seamless Roaming (802.11r):** Configured Fast Transition (802.11r) across identical SSIDs to allow modern clients (iPhones, Macs) to instantly jump between 2.4GHz and 5GHz bands without dropping VoIP or WhatsApp calls.
