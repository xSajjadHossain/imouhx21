# IMOU HX21: OpenWrt Flashing Architecture & Sysadmin FAQ

This document serves as a technical reference for the underlying architecture, memory constraints, and partition logic encountered when flashing the IMOU HX21 router from stock firmware to OpenWrt.

## 1. Hardware & Memory Constraints

### Why did the router crash (`Killed` / `Connection reset by peer`) during backups?
The IMOU HX21 has very limited RAM. On embedded Linux devices, the `/tmp` directory is typically mounted as a `ramfs` or `tmpfs` (a RAM disk). 
When we attempted to compress and save the massive 110MB `mtd5` (UBI/OS) partition into `/tmp`, the router's physical memory completely filled up. The Linux kernel's OOM (Out of Memory) killer stepped in to protect the system by shooting down active processes—which included killing the active SSH daemon, resulting in a dropped connection.

### How do you bypass embedded memory limits for backups?
**Network Streaming.** Instead of executing compression on the router and saving the file locally to `/tmp`, we instruct the router to only perform a raw read (`cat`), pipe that binary data over the SSH connection, and let the host machine (Mac/PC) handle the CPU-intensive compression and disk I/O.
```bash
# Sysadmin trick to bypass router RAM entirely:
ssh root@192.168.10.1 "cat /dev/mtd5" | gzip -c > ./mtd5_ubi.bin.gz
```

## 2. Partition Architecture & Data Safety

### Did we lose the router's OEM Core Data (MAC Address, Wi-Fi Calibration)?
**No. Zero data loss occurred.** The router's flash memory is divided into strictly isolated block devices (partitions). 
When we executed `mtd erase ubi`, we only destroyed the partition containing the IMOU Operating System. The unique hardware identifiers and RF tuning data are stored in a heavily protected, isolated partition called `Factory`. We never wrote to or erased the `Factory` partition.

### The IMOU HX21 MT7981 Flash Layout
*   `mtd0 (spi0.0)`: The master block device (the entire raw flash chip).
*   `mtd1 (BL2)`: Bootloader Level 2 (Preloader).
*   `mtd2 (u-boot-env)`: Environmental variables for the bootloader.
*   **`mtd3 (Factory)`**: The holy grail. Contains the EEPROM, base MAC addresses, and Wi-Fi radio calibration data.
*   `mtd4 (FIP)`: The main U-Boot bootloader.
*   `mtd5 (ubi)`: The Operating System (Root filesystem and Linux kernel).

### How does OpenWrt adapt without losing this OEM data?
OpenWrt hardware profiles are precision-engineered for specific devices. When the OpenWrt kernel boots on the HX21, it is programmed to look exactly at the physical memory address of the `Factory` partition (`0x180000`). It reads the OEM MAC addresses and calibration parameters dynamically and injects them directly into the Wi-Fi hardware drivers (mt76) on the fly. 

## 3. The Bare-Metal TFTP Recovery

### Why was a Windows laptop and Ethernet required for Phase 4?
Once we flashed the new bootloader and erased the `ubi` (OS) partition, the router had no operating system. It woke up using only **U-Boot** (a bare-metal bootloader). U-Boot does not contain Wi-Fi drivers. Therefore, the Wi-Fi radios are physically inert during this phase. Communication is strictly limited to the hardwired Ethernet switch.

### How does the TFTP recovery work?
When U-Boot detects that the main OS partition is missing or corrupt, it falls back to a hardcoded recovery script. 
1. It initializes the Ethernet switch.
2. It assigns itself a temporary IP (usually `192.168.1.1`).
3. It broadcasts a TFTP request into the Ethernet cable, explicitly searching for a server at `192.168.1.254` hosting a specific recovery file (e.g., `initramfs-recovery.itb`).
4. Once received, it loads that file entirely into temporary RAM and boots it. 

*Note: This is why the host laptop must have a static IP assigned to `192.168.1.254` with no gateway. The host will lose internet access during this phase because it is isolated to a direct hardware link with the router.*
