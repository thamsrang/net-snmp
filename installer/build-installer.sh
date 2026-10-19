#!/usr/bin/env bash
# Build the Windows installer. Run from an MSYS2 UCRT64 shell after `make`.
set -e
cd "$(dirname "$0")/.."
stage="$PWD/installer/stage"
version=$(sed -n 's/^PACKAGE_VERSION=.\(.*\).$/\1/p' configure | head -1)

rm -rf "$stage"
make install DESTDIR="$stage"
payload="$stage/ucrt64"
rm -rf "$payload/include" "$payload/lib" "$payload/share/man"

# Bundle the runtime DLLs the executables depend on.
for exe in "$payload"/bin/*.exe "$payload"/sbin/*.exe; do
    ldd "$exe" | awk '/\/ucrt64\/bin\//{print $3}'
done | sort -u | while read -r dll; do
    cp "$dll" "$payload/bin/"
done

makensis -V2 -DVERSION="$version" -DPAYLOAD="$(cygpath -w "$payload")" \
    -DOUTFILE="$(cygpath -w "$PWD/installer/net-snmp-$version-setup.exe")" \
    installer/net-snmp.nsi
echo "Created installer/net-snmp-$version-setup.exe"

rm -f "installer/net-snmp-$version-setup.exe.zip"
powershell.exe -NoProfile -Command "Compress-Archive -Force -Path '$(cygpath -w "$PWD/installer/net-snmp-$version-setup.exe")' -DestinationPath '$(cygpath -w "$PWD/installer/net-snmp-$version-setup.exe.zip")'"
echo "Created installer/net-snmp-$version-setup.exe.zip"
