#!/usr/bin/env bash
# Build the MSI. Run build-installer.sh first (it creates installer/stage) and install WiX 5:
#   dotnet tool install --global wix --version 5.0.2
set -e
cd "$(dirname "$0")/.."
payload="$PWD/installer/stage/ucrt64"
[ -d "$payload" ] || { echo "Run installer/build-installer.sh first"; exit 1; }
version=$(sed -n 's/^PACKAGE_VERSION=.\(.*\).$/\1/p' configure | head -1)
wix=$(cygpath -u "$USERPROFILE")/.dotnet/tools/wix.exe

"$wix" build -arch x64 -d Version="$version" -d PayloadDir="$(cygpath -w "$payload")" \
    -o "$(cygpath -w "$PWD/installer/net-snmp-$version-x64.msi")" installer/net-snmp.wxs
echo "Created installer/net-snmp-$version-x64.msi"

rm -f "installer/net-snmp-$version-x64.msi.zip"
powershell.exe -NoProfile -Command "Compress-Archive -Force -Path '$(cygpath -w "$PWD/installer/net-snmp-$version-x64.msi")' -DestinationPath '$(cygpath -w "$PWD/installer/net-snmp-$version-x64.msi.zip")'"
echo "Created installer/net-snmp-$version-x64.msi.zip"
