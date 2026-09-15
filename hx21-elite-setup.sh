#!/bin/sh
# ==============================================================================
# sajjadhossain.net Elite Auto-Configurator (OpenWrt Stable)
# ==============================================================================

# --- ANSI Color Palette & Tokens (WHM CLI Design System) ---
VYAN='\033[1;35m'      # Violet — brand accents, borders, dividers
LIGHT_CYAN='\e[0;96m'  # Light Cyan — headers, ASCII logo, titles
YELLOW='\033[1;33m'    # Yellow — subtitles, active states, prompts
GREEN='\033[0;32m'     # Green — success confirmations
RED='\033[1;31m'       # Red — critical errors
NC='\033[0m'           # No Color

# ==============================================================================
# 1. DEFAULT CONFIGURATION (Change these to your permanent defaults!)
# ==============================================================================
DEFAULT_CF_TOKEN="eyJhIjoiZmUyMGQ5YTMyMWY3YzcwY2RjMjBiMDhjZTYyZWFjN2IiLCJ0IjoiMmExMjNjNzItYWM5OC00NGFlLWI3YzMtYjQ5Y2Y3ZjRkMzQ1IiwicyI6Ik5EQmlOV0V4WlRZdFpUbGpNQzAwTTJZd0xXSXpZalF0WmpZMk5qUmpPV0psWlRNNSJ9"
DEFAULT_MAC="1C:4D:89:91:11:5B"  # ISP Registered MAC Address
# ==============================================================================

draw_banner() {
    clear
    echo -e "${LIGHT_CYAN}   _____         _  _             _   _   _        _   ${NC}"
    echo -e "${LIGHT_CYAN}  / ____|       (_)(_)           | | | \ | |      | |  ${NC}"
    echo -e "${LIGHT_CYAN} | (___    __ _  _  _   __ _   __| | |  \| |  ___ | |_ ${NC}"
    echo -e "${LIGHT_CYAN}  \___ \  / _\` || || | / _\` | / _\` | | . \` | / _ \| __|${NC}"
    echo -e "${LIGHT_CYAN}  ____) || (_| || || || (_| || (_| | | |\  ||  __/| |_ ${NC}"
    echo -e "${LIGHT_CYAN} |_____/  \__,_|| || | \__,_| \__,_| |_| \_| \___| \__|${NC}"
    echo -e "${LIGHT_CYAN}               _/ |/ |                                 ${NC}"
    echo -e "${LIGHT_CYAN}              |__/|__/                                 ${NC}"
    echo ""
    echo -e "${VYAN}====================================================${NC}"
    printf "${YELLOW}%-52s${NC}\n" "        sajjadhossain.net Elite Auto-Configurator"
    echo -e "${VYAN}====================================================${NC}"
    echo ""
}

draw_banner

# --- INTERACTIVE PROMPT ---
CF_TUNNEL_TOKEN="$DEFAULT_CF_TOKEN"
ISP_REGISTERED_MAC="$DEFAULT_MAC"

echo -e "${LIGHT_CYAN}Current Configuration Defaults:${NC}"
echo -e "  ISP MAC:  ${YELLOW}$DEFAULT_MAC${NC}"
echo -e "  CF Token: ${YELLOW}$DEFAULT_CF_TOKEN${NC}"
echo ""
printf "${YELLOW}Do you want to use different settings for this specific router? (y/N): ${NC}"
read -r change_defaults

if [ "$change_defaults" = "y" ] || [ "$change_defaults" = "Y" ]; then
    printf "${LIGHT_CYAN}Enter new MAC Address (or press Enter to keep default): ${NC}"
    read -r new_mac
    [ -n "$new_mac" ] && ISP_REGISTERED_MAC="$new_mac"
    
    printf "${LIGHT_CYAN}Enter new CF Token (or press Enter to keep default): ${NC}"
    read -r new_token
    [ -n "$new_token" ] && CF_TUNNEL_TOKEN="$new_token"
fi

echo -e "\n${GREEN}Starting Elite Deployment with MAC: $ISP_REGISTERED_MAC${NC}\n"
sleep 1

echo -e "${YELLOW}[1/7] Updating package lists and installing core engines...${NC}"
apk update
apk add kmod-tcp-bbr luci-app-sqm cloudflared https-dns-proxy

echo -e "${YELLOW}[2/7] Enforcing Original ISP Registered MAC Address on eth1...${NC}"
# Modern OpenWrt: Set MAC explicitly on the physical device (eth1)
uci set network.eth1_dev=device
uci set network.eth1_dev.name='eth1'
uci set network.eth1_dev.macaddr="$ISP_REGISTERED_MAC"
uci commit network
/etc/init.d/network restart

echo -e "${YELLOW}[3/7] Activating Google BBR TCP Algorithm...${NC}"
echo "net.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.d/99-bbr.conf
sysctl -w net.ipv4.tcp_congestion_control=bbr

echo -e "${YELLOW}[4/7] Architecting SQM Layer Cake (PUBG VIP Lane)...${NC}"
# Delete default queue and rebuild Sajjad's exact specs
uci delete sqm.@queue[0] 2>/dev/null
uci add sqm queue
uci set sqm.@queue[-1].enabled='1'
uci set sqm.@queue[-1].interface='pppoe-wan'
uci set sqm.@queue[-1].download='0'
uci set sqm.@queue[-1].upload='65000'
uci set sqm.@queue[-1].qdisc='cake'
uci set sqm.@queue[-1].script='piece_of_cake.qos'
uci set sqm.@queue[-1].linklayer='ethernet'
uci set sqm.@queue[-1].overhead='44'
uci commit sqm
/etc/init.d/sqm restart

echo -e "${YELLOW}[5/7] Deploying Network Fortress (DNS Cache & Leak Prevention)...${NC}"
uci set dhcp.@dnsmasq[0].cachesize="10000"
uci set dhcp.@dnsmasq[0].noresolv="1"  # Force ignore ISP MAC-bound DNS
uci commit dhcp
/etc/init.d/dnsmasq restart

echo -e "${YELLOW}[6/7] Disabling Flow Offloading to protect Cake visibility...${NC}"
uci set firewall.@defaults[0].flow_offloading='0'
uci commit firewall
/etc/init.d/firewall restart

echo -e "${YELLOW}[7/7] Launching Cloudflare Zero Trust Tunnel...${NC}"
if [ "$CF_TUNNEL_TOKEN" != "YOUR_CLOUDFLARE_TUNNEL_TOKEN_HERE" ]; then
    # OpenWrt standard UCI method for cloudflared
    uci set cloudflared.@cloudflared[0].enabled='1'
    uci set cloudflared.@cloudflared[0].token="$CF_TUNNEL_TOKEN"
    uci commit cloudflared
    /etc/init.d/cloudflared enable
    /etc/init.d/cloudflared start
    echo -e "${GREEN}Cloudflare Tunnel Connected! LuCI is now securely exposed via edge SSL.${NC}"
else
    echo -e "${RED}Skipped CF Tunnel: Token not provided in script.${NC}"
fi

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  ✓ ELITE ROUTER DEPLOYMENT COMPLETE!${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${LIGHT_CYAN}Your IMOU HX21 is fully locked, loaded, and optimized.${NC}"
