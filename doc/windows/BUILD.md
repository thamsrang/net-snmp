# Building Net-SNMP 5.9.5.2 on Windows (MSYS2 UCRT64)

This produces native 64-bit Windows executables (`snmpd.exe`, `snmpget.exe`, ...) linked against the Universal C Runtime and OpenSSL, plus an optional NSIS installer and MSI.

Everything here was run on this tree with the versions listed below.

## 1. Why MSYS2 and not Visual Studio

This tree also has an MSVC build (`win32/Configure` plus `nmake`, driven by `ci/build.bat`). It needs Visual Studio and a Windows Perl, and it was not used or tested here. The MSYS2 route uses the normal autoconf `configure` script and needs only free tools.

## 2. Prerequisites

Tested versions:

| Tool | Version |
|------|---------|
| MSYS2 (UCRT64 environment) | installed in `C:\msys64` |
| GCC | 15.2.0 |
| OpenSSL | 3.5.2 |
| GNU make | 4.4.1 |
| Perl | 5.40.3 (MSYS2 `perl`) |
| NSIS (installer, optional) | 3.11 |
| .NET SDK + WiX (MSI, optional) | .NET 9 or 10, WiX 5.0.2 |

Install the build packages from an MSYS2 UCRT64 shell:

```
pacman -S --needed mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-openssl \
    mingw-w64-ucrt-x86_64-pkgconf mingw-w64-ucrt-x86_64-libsystre \
    make perl diffutils
```

For the installers:

```
pacman -S --needed mingw-w64-ucrt-x86_64-nsis        # NSIS setup .exe
dotnet tool install --global wix --version 5.0.2     # MSI
```

WiX 5 is used because it is free. Newer WiX versions have different licensing terms for some uses; check them before upgrading.

## 3. Open the right shell

Use the **MSYS2 UCRT64** shortcut (`C:\msys64\ucrt64.exe`). A plain MSYS2 or MINGW64 shell will pick the wrong compiler.

From PowerShell you can run a command in that environment without opening a shell:

```powershell
$env:MSYSTEM = 'UCRT64'; $env:CHERE_INVOKING = '1'
C:\msys64\usr\bin\bash.exe --login -c "cd /c/path/to/net-snmp-5.9.5.2 && <command>"
```

`CHERE_INVOKING=1` keeps the current directory instead of changing to the home folder.

## 4. Configure

From the top of the source tree:

```
./configure --with-defaults --disable-embedded-perl --without-perl-modules \
            --disable-scripts --with-openssl=/ucrt64
```

| Option | Why |
|--------|-----|
| `--with-defaults` | accept all defaults without prompting |
| `--disable-embedded-perl` | no Perl inside `snmpd` |
| `--without-perl-modules` | do not build the Perl bindings |
| `--disable-scripts` | skip the Perl helper scripts (`snmpconf`, `mib2c`, ...) |
| `--with-openssl=/ucrt64` | use the MSYS2 OpenSSL for SHA-2 authentication and AES privacy |

Check the summary at the end of the output:

```
Authentication support:     MD5 SHA1 SHA224 SHA256 SHA384 SHA512
Encryption support:         DES AES AES128 AES192 AES192C AES256 AES256C
```

That "Encryption support" line lists what OpenSSL can do, not what Net-SNMP enables. This build supports only DES and AES-128 for SNMPv3 privacy, because `--enable-blumenthal-aes` was not used (see section 8).

## 5. Compile

```
NOAUTODEPS=1 make -j$(nproc)
```

`NOAUTODEPS=1` skips regenerating dependency files, as `ci/build.sh` does. A successful run ends with `making all in .../mibs` and exit code 0.

## 6. Result

| Path | Contents |
|------|----------|
| `agent/snmpd.exe` | the agent (`agent/.libs/snmpd.exe` is the real binary) |
| `apps/*.exe` | client tools and `snmptrapd.exe` (real binaries in `apps/.libs`) |
| `apps/snmpnetstat/snmpnetstat.exe` | `snmpnetstat` |

The `.exe` files directly in `agent` and `apps` are libtool wrapper programs. Run them from an MSYS2 shell, or use the installed layout (section 7), which contains the real binaries and the DLLs they need.

Quick check:

```
./apps/snmpget.exe -V
NET-SNMP version: 5.9.5.2
```

## 7. Build the installers

Both scripts must run in the MSYS2 UCRT64 shell, after `make`:

```
bash installer/build-installer.sh     # NSIS: installer/net-snmp-5.9.5.2-setup.exe
bash installer/build-msi.sh           # MSI:  installer/net-snmp-5.9.5.2-x64.msi
```

`build-installer.sh` does the staging that both installers share:

1. `make install DESTDIR=installer/stage` (the install prefix is `/ucrt64`, so files land in `installer/stage/ucrt64`).
2. Removes `include`, `lib` and `share/man` from the staged tree.
3. Copies the runtime DLLs found with `ldd` (`libcrypto-3-x64.dll`, `libwinpthread-1.dll`, `libsystre-0.dll`, `libintl-8.dll`, `libtre-5.dll`, `libiconv-2.dll`) into `bin`.
4. Runs `makensis` on `installer/net-snmp.nsi`.

`build-msi.sh` reuses `installer/stage`, so run `build-installer.sh` first. It runs `wix build` on `installer/net-snmp.wxs`.

`installer/stage` is deleted and recreated on every `build-installer.sh` run. It, and the installer outputs, are build products and not part of the source.

More about the installers: [INSTALLERS.md](INSTALLERS.md).

## 8. Variations

| Goal | Change |
|------|--------|
| No OpenSSL (MD5 authentication only, no encryption) | replace `--with-openssl=/ucrt64` with `--without-openssl`. This was the very first build; it works but is weak. |
| AES-192 and AES-256 privacy | add `--enable-blumenthal-aes` (the option `ci/build.bat` uses). Not built or tested here. After building, `snmpget -x AES-256` should be accepted. Both ends must support it; it is a Net-SNMP extension. |
| Clean rebuild | `make clean`, then run `configure` again. |

After changing configure options always run `configure` again, then `make`.

## 9. Things that are different from the upstream CI script

- This tree is not a git checkout, so `ci/build.sh` (which calls `git rev-parse`) is not used.
- The install prefix stays `/ucrt64` (the MSYS2 default). Native Windows programs cannot resolve that path, so the installers set `MIBDIRS` and `SNMPCONFPATH`. Without them, MIB names and `snmp.conf` are not found. Details in [INSTALLERS.md](INSTALLERS.md).
- Perl-based tools (`snmpconf`, `mib2c`, `snmp_perl_trapd.pl`) are not built.

## 10. Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| `gcc: command not found`, or errors about `-lcrypto` | wrong shell or missing package. Use the UCRT64 shell and install `mingw-w64-ucrt-x86_64-gcc` and `-openssl`. |
| `configure` says OpenSSL not found | check `ls /ucrt64/include/openssl` and pass `--with-openssl=/ucrt64`. |
| Built programs print `Cannot find module (SNMPv2-MIB)` | set `MIBDIRS` to the folder that contains the MIB files, or use the installed layout. |
| `The program can't start because libcrypto-3-x64.dll is missing` | you ran a binary from `.libs` outside the MSYS2 shell without the DLLs on `PATH`. Use the installed layout, which bundles them. |
| `makensis: command not found` | install `mingw-w64-ucrt-x86_64-nsis`. |
| `build-msi.sh` fails with "Run installer/build-installer.sh first" | the staging folder does not exist yet. |
| `wix.exe` not found | install the dotnet tool (section 2); it lands in `%USERPROFILE%\.dotnet\tools`. |
