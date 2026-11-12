#!/bin/bash
#===============================================
# Modify default IP
# sed -i 's/192.168.1.1/192.168.1.251/g' openwrt/package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/kenzo/g' openwrt/package/base-files/files/bin/config_generate

#2. Custom settings
#sed -i 's?zstd$?zstd ucl upx\n$(curdir)/upx/compile := $(curdir)/ucl/compile?g' tools/Makefile
#sed -i 's/$(TARGET_DIR)) install/$(TARGET_DIR)) install --force-overwrite/' package/Makefile
#sed -i 's/root:.*/root:$1$tTPCBw1t$ldzfp37h5lSpO9VXk4uUE\/:18336:0:99999:7:::/g' package/base-files/files/etc/shadow



#!/bin/bash
#=================================================
# N1 ImmortalWrt Custom Settings
#=================================================

set -e

# 1. 修改默认 LAN IP
sed -i 's/192\.168\.1\.1/192.168.3.1/g' \
package/base-files/files/bin/config_generate

# 2. 设置 root 密码
ROOT_HASH="$(openssl passwd -6 '354335')"

SHADOW_FILE="package/base-files/files/etc/shadow"

if [ -f "$SHADOW_FILE" ]; then
    sed -i "s#^root:[^:]*:#root:${ROOT_HASH}:#" "$SHADOW_FILE"
fi

# 3. 启用默认主题
# 确保 feeds 中存在 luci-theme-argone
if ! grep -q '^CONFIG_PACKAGE_luci-theme-argone=y' .config; then
    echo 'CONFIG_PACKAGE_luci-theme-argone=y' >> .config
fi

# 4. 创建首次启动配置
mkdir -p package/base-files/files/etc/uci-defaults

cat > package/base-files/files/etc/uci-defaults/99-n1-custom <<'EOF'
#!/bin/sh

#=================================================
# WAN: eth0
#=================================================

uci set network.wan='interface'
uci set network.wan.device='eth0'
uci set network.wan.proto='dhcp'
uci set network.wan.ipv6='1'

# WAN IPv6 DHCP 客户端
uci -q delete network.wan6
uci set network.wan6='interface'
uci set network.wan6.device='@wan'
uci set network.wan6.proto='dhcpv6'
uci set network.wan6.reqaddress='try'
uci set network.wan6.reqprefix='auto'

#=================================================
# LAN: br-lan
#=================================================

uci -q delete network.br_lan
uci set network.br_lan='device'
uci set network.br_lan.name='br-lan'
uci set network.br_lan.type='bridge'

# LAN 不包含 eth0
# 无线通过 wireless.network=lan 动态加入 br-lan

uci set network.lan='interface'
uci set network.lan.device='br-lan'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.3.1'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.ip6assign='60'

#=================================================
# DHCPv4 / DHCPv6 / RA
#=================================================

uci -q delete dhcp.lan
uci set dhcp.lan='dhcp'
uci set dhcp.lan.interface='lan'
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'
uci set dhcp.lan.dhcpv4='server'
uci set dhcp.lan.dhcpv6='server'
uci set dhcp.lan.ra='server'

#=================================================
# Wireless AP
#=================================================

# 自动选择第一个无线设备
RADIO="$(uci -q show wireless | \
    sed -n 's/^wireless\.\([^.=]*\)=wifi-device$/\1/p' | head -n 1)"

if [ -n "$RADIO" ]; then

    # 开启无线设备
    uci set "wireless.${RADIO}.disabled=0"

    # 新建独立 AP 配置
    uci add wireless wifi-iface
    WIFI_IFACE="$(uci -q show wireless | \
        sed -n 's/^wireless\.\([^.=]*\)=wifi-iface$/\1/p' | tail -n 1)"

    uci set "wireless.${WIFI_IFACE}.device=${RADIO}"
    uci set "wireless.${WIFI_IFACE}.mode=ap"
    #uci set "wireless.${WIFI_IFACE}.network=lan"
    uci set "wireless.${WIFI_IFACE}.ssid=小轩窗"
    uci set "wireless.${WIFI_IFACE}.encryption=psk2"
    uci set "wireless.${WIFI_IFACE}.key=00830083"
    uci set "wireless.${WIFI_IFACE}.disabled=0"

fi

#=================================================
# Default LuCI theme
#=================================================

uci -q set luci.main='main'
uci set luci.main.mediaurlbase='/luci-static/argone'

#=================================================
# Commit
#=================================================

uci commit network
uci commit dhcp
uci commit wireless
uci commit luci

exit 0
EOF

chmod +x package/base-files/files/etc/uci-defaults/99-n1-custom

echo "N1 custom configuration completed"
