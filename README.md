# IMOU HX21 OpenWrt Flashing & Recovery Guide

This repository contains the firmware files and the complete journey for safely flashing OpenWrt to the IMOU HX21 AX3000 Router.

## Hardware Capabilities

* **Router (IMOU HX21):** MediaTek Filogic MT7981B. Fully supports Gigabit wired connections and up to 3000Mbps wireless.
* **ONU (Airnet ARN1101X):** 1GE XPON ONU. It natively supports 1 Gbps local connections on its LAN port.

---

## File Explanations

Inside the `firmware/HX21/` directory, you will find the following files:

1. **`HX21-ssh.bin`** (15 KB): A modified stock configuration backup file. When you restore this configuration on the stock firmware, it enables SSH access.
2. **`openwrt-mediatek-filogic-imou_hx21-preloader.bin`** (225 KB): The first-stage bootloader (BL2). It initializes the basic hardware to boot further.
3. **`openwrt-mediatek-filogic-imou_hx21-bl31-uboot.fip`** (785 KB): The U-Boot bootloader image (FIP). It replaces the stock bootloader to boot OpenWrt.
4. **`openwrt-mediatek-filogic-imou_hx21-initramfs-recovery.itb`** (9.1 MB): The OpenWrt recovery image that runs in RAM. You will boot this using a TFTP server during the initial transition.
5. **`openwrt-mediatek-filogic-imou_hx21-squashfs-sysupgrade.itb`** (11.1 MB): The final, permanent OpenWrt firmware image. This is flashed via the sysupgrade command once you are booted into the recovery RAM image.

---

## The Journey: Backup & Flashing

**WARNING:** Backup is our TOP PRIORITY. Do not flash OpenWrt without backing up the original MTD partitions first. If the device bricks, these backups (restored via UART or TFTP) are your only way back.

### Step 1: Gain SSH Access
1. Connect to the stock web interface of the IMOU HX21.
2. Go to the configuration restore page.
3. Restore the router using the `HX21-ssh.bin` file.
4. After rebooting, SSH into the router. The default web interface password becomes `12345678`, and the SSH password is empty.

### Step 2: The Critical Backup (DO NOT SKIP)
Once connected via SSH to the stock firmware, backup all partitions to the `/tmp` directory.
Run these commands:

```bash
cat /dev/mtd0 | gzip -1 -c > /tmp/mtd0_spi0.0.bin.gz
cat /dev/mtd1 | gzip -1 -c > /tmp/mtd1_BL2.bin.gz
cat /dev/mtd2 | gzip -1 -c > /tmp/mtd2_u-boot-env.bin.gz
cat /dev/mtd3 | gzip -1 -c > /tmp/mtd3_Factory.bin.gz
cat /dev/mtd4 | gzip -1 -c > /tmp/mtd4_FIP.bin.gz
cat /dev/mtd5 | gzip -1 -c > /tmp/mtd5_ubi.bin.gz
```

**Download these files to your PC** using an SCP client (like WinSCP on Windows or `scp` on Mac/Linux) before proceeding.

### Step 3: Flashing the Bootloaders
1. Upload the `bl31-uboot.fip` and `preloader.bin` files from your PC to the `/tmp` directory on the router via SCP.
2. Write them to the flash memory via SSH:
```bash
mtd write /tmp/openwrt-mediatek-filogic-imou_hx21-bl31-uboot.fip FIP
mtd write /tmp/openwrt-mediatek-filogic-imou_hx21-preloader.bin BL2
```
*(Note: If writing BL2 fails on the first try, don't panic. You can update BL2 later from within OpenWrt using `kmod-mtd-rw`).*

### Step 4: Booting the Recovery Image
1. Set up a TFTP server on your PC (e.g., Tftpd64) with the IP address `192.168.1.254`.
2. Place `openwrt-mediatek-filogic-imou_hx21-initramfs-recovery.itb` into the TFTP server's root directory.
3. In the router's SSH session, wipe the main OS partition and reboot:
```bash
mtd erase ubi
reboot
```
The router will restart, search for the TFTP server at `192.168.1.254`, and load the recovery image directly into RAM.

### Step 5: Final Flashing
1. Connect to the router (now running the OpenWrt recovery image) at `192.168.1.1`.
2. Upload the `openwrt-mediatek-filogic-imou_hx21-squashfs-sysupgrade.itb` file to `/tmp` via SCP.
3. SSH into the router and permanently flash it:
```bash
sysupgrade -n /tmp/openwrt-mediatek-filogic-imou_hx21-squashfs-sysupgrade.itb
```

Once the router reboots, you are permanently running OpenWrt on your IMOU HX21.
