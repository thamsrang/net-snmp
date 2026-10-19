#!/usr/bin/env bash
# Build the Linux package as a tar.gz. Run on Linux or in WSL (needs gcc, make, libssl-dev).
# The tree is copied to a scratch dir first because the source dir is already configured for Windows.
set -e
src="$(cd "$(dirname "$0")/.." && pwd)"
version=$(sed -n 's/^PACKAGE_VERSION=.\(.*\).$/\1/p' "$src/configure" | head -1)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir "$work/src"
tar -C "$src" \
    --exclude=./installer --exclude=./.git --exclude=./.libs --exclude='*/.libs' \
    --exclude='*.o' --exclude='*.lo' --exclude='*.la' --exclude='*.exe' --exclude='*.dll' \
    --exclude=./config.status --exclude=./config.log --exclude=./libtool \
    -cf - . | tar -C "$work/src" -xf -

cd "$work/src"
./configure --prefix=/usr/local --with-defaults --disable-embedded-perl \
    --without-perl-modules --disable-manuals --disable-debugging
make -j"$(nproc)"
make install DESTDIR="$work/stage"

pkg="net-snmp-$version-linux-x86_64"
mv "$work/stage" "$work/$pkg"
cp "$src"/installer/linux/{install.sh,snmpd.conf,snmpd.service,README.linux} "$work/$pkg/"
chmod +x "$work/$pkg/install.sh"
out="$src/installer/$pkg.tar.gz"
rm -f "$out"
tar -C "$work" --owner=root --group=root -czf "$out" "$pkg"
echo "Created installer/$pkg.tar.gz"
