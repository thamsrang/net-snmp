#!/usr/bin/env bash
# Install Net-SNMP from this package into /usr/local. Run as root.
#   ./install.sh [--systemd]   --systemd also installs and enables the snmpd service
set -e
here="$(cd "$(dirname "$0")" && pwd)"

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo ./install.sh)"; exit 1; }

cp -a "$here/usr/local/." /usr/local/
ldconfig

missing=$(ldd /usr/local/sbin/snmpd | awk '/not found/{print $1}')
if [ -n "$missing" ]; then
    echo "Missing runtime libraries: $missing"
    echo "Debian/Ubuntu: apt install libssl3    RHEL/Fedora: dnf install openssl-libs"
    exit 1
fi

# Never overwrite an existing config.
mkdir -p /usr/local/etc/snmp
[ -e /usr/local/etc/snmp/snmpd.conf ] || cp "$here/snmpd.conf" /usr/local/etc/snmp/snmpd.conf

if [ "$1" = "--systemd" ]; then
    cp "$here/snmpd.service" /etc/systemd/system/snmpd.service
    systemctl daemon-reload
    systemctl enable --now snmpd
    echo "snmpd service enabled and started"
fi

echo "Installed. Binaries are in /usr/local/bin and /usr/local/sbin."
