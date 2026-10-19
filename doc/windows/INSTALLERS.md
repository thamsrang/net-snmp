# Net-SNMP Windows installers

Two installers are built from the same staged files. Pick one.

| | NSIS setup | MSI |
|---|---|---|
| File | `installer/net-snmp-5.9.5.2-setup.exe` | `installer/net-snmp-5.9.5.2-x64.msi` |
| Size | about 30 MB | about 26 MB |
| Wizard | license page, component page, install-folder page | none (silent-style install) |
| Built with | NSIS 3.11 (`installer/net-snmp.nsi`) | WiX 5.0.2 (`installer/net-snmp.wxs`) |
| Needs administrator | yes | yes (per-machine, `ALLUSERS=1`) |
| Best for | one-off manual installs | managed deployment (Group Policy, Intune, SCCM) |

How they are built: [BUILD.md](BUILD.md).

Status of this document: file contents and the MSI tables were inspected directly, and both installers were rebuilt after every change. The installers themselves were **not run**, because installing needs an elevated prompt and changes machine-wide settings. Install-time behavior below comes from reading the installer scripts and the MSI database, so test an install and an uninstall on a non-production machine before rolling out.

## 1. What gets installed

Default folder: `C:\Program Files\Net-SNMP`

| Folder | Contents |
|--------|----------|
| `bin` | SNMP client tools (`snmpget`, `snmpwalk`, `snmpset`, `snmptrap`, ...), the helper scripts `net-snmp-config` and `net-snmp-create-v3-user`, and the runtime DLLs |
| `sbin` | `snmpd.exe` (agent) and `snmptrapd.exe` (trap receiver) |
| `share\snmp\mibs` | the standard MIB files |
| `etc\snmp` | empty; put `snmpd.conf`, `snmptrapd.conf` and `snmp.conf` here |
| `uninstall.exe` | NSIS only |

The MSI contains 98 files. Header files, static libraries and man pages are not installed. There is no Perl and no `snmpconf` wizard.

Runtime DLLs in `bin`: `libcrypto-3-x64.dll`, `libwinpthread-1.dll`, `libsystre-0.dll`, `libintl-8.dll`, `libtre-5.dll`, `libiconv-2.dll`.

## 2. What they change on the machine

Both installers make the same machine-wide environment changes. The executables are built for the path prefix `/ucrt64`, which does not exist on Windows, so these variables tell them where things are:

| Variable | Value | Effect |
|----------|-------|--------|
| `PATH` | the existing value, plus `<folder>\bin;<folder>\sbin` | commands run from any prompt |
| `MIBDIRS` | `<folder>\share\snmp\mibs` | MIB names (`sysDescr`) resolve |
| `SNMPCONFPATH` | `<folder>\etc\snmp` | configuration files are read from here |

Notes:

- `MIBDIRS` and `SNMPCONFPATH` are **overwritten** if they already existed. The MSI uses "set" for both (confirmed in its `Environment` table). Re-add any custom values afterwards, for example `MIBDIRS` with extra MIB folders.
- Because `SNMPCONFPATH` is set, `snmp.conf` in `%USERPROFILE%\.snmp` is no longer read unless you add that folder to the variable (see [CLIENT.md](CLIENT.md), section 4).
- Open a **new** terminal after installing. Already-open terminals keep the old environment. A service started before a reboot may also not see the new variables; reboot once to be safe.
- Registry keys written:

| Key | Value | Installer |
|-----|-------|-----------|
| `HKLM\Software\Net-SNMP` | `InstallDir` | both |
| `HKLM\Software\Net-SNMP` | `ConfDir` | MSI |
| `HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Net-SNMP` | name, version, uninstall command | NSIS (the MSI registers itself the standard way) |

## 3. What they do not do

- They do **not** register `snmpd` as a Windows service unless you ask for it (section 4). `snmptrapd` is never registered by the installers; do it by hand (`snmptrapd.exe -register`). See [AGENT-CONFIG.md](AGENT-CONFIG.md) and [SERVICE.md](SERVICE.md).
- They do **not** create `snmpd.conf`, so a freshly started `snmpd` answers nobody until you create one.
- They do **not** open the Windows Firewall.
- They are not code-signed, so Windows SmartScreen will probably warn before running the `.exe`. This was not tested.

## 4. Install

### NSIS

Double-click the setup, accept the license, choose the components and a folder, finish. The component page has one optional entry, **Windows service for snmpd (starts at boot)**, which is off by default.

Silent install (not run here; standard NSIS switches):

```
net-snmp-5.9.5.2-setup.exe /S /D=C:\Net-SNMP
net-snmp-5.9.5.2-setup.exe /S /SERVICE=1 /D=C:\Net-SNMP
```

`/SERVICE=1` also registers the `Net-SNMP Agent` service. `/D=` must be the last argument and must not be quoted, even if the path has spaces. Run from an elevated prompt.

### MSI

Interactive: double-click the `.msi`. There is no wizard; it installs straight away.

Silent, from an elevated prompt (not run here; standard `msiexec` options):

```
msiexec /i net-snmp-5.9.5.2-x64.msi /qn /l*v C:\Temp\net-snmp-install.log
msiexec /i net-snmp-5.9.5.2-x64.msi /qn INSTALLFOLDER="D:\Net-SNMP"
msiexec /i net-snmp-5.9.5.2-x64.msi /qn REGISTER_SERVICE=1
```

`INSTALLFOLDER` should be accepted because it is an upper-case directory identifier in the package; confirm in your environment. `REGISTER_SERVICE=1` registers the `Net-SNMP Agent` service (see below). The log (`/l*v`) shows what happened if the install fails.

### Service option

Both installers can register the agent as a Windows service. This is **off by default**.

| | NSIS | MSI |
|---|------|-----|
| Turn on | tick the component, or `/SERVICE=1` | `REGISTER_SERVICE=1` |
| What runs | `snmpd.exe -register -quiet` | the same, as a deferred action after the files are copied |
| Result | service `Net-SNMP Agent`, start type Automatic, LocalSystem | same |
| Started? | no | no |

The service is registered but **not started**, because it has no configuration yet. Create `etc\snmp\snmpd.conf`, then `sc.exe start "Net-SNMP Agent"` (see [SERVICE.md](SERVICE.md)). A failure to register is ignored so that it never blocks the install; confirm with `sc.exe query "Net-SNMP Agent"` afterwards. The MSI action is skipped on a repair or modify (`Installed` is set), and registering again when the service already exists simply fails harmlessly.

### Check the result

In a **new** terminal:

```
snmpget -V
snmptranslate -IR sysDescr
echo %MIBDIRS%
echo %SNMPCONFPATH%
```

`snmptranslate` should print `SNMPv2-MIB::sysDescr`. A `Cannot find module (SNMPv2-MIB)` error means `MIBDIRS` is not visible to that terminal.

## 5. Upgrade

- **MSI.** The package has an upgrade code (`{6B1F6C3E-3D0A-4E5B-9B53-2F4E7C1A8D90}`) and a major-upgrade rule, so installing a newer MSI replaces an older Net-SNMP MSI install. Installing an older version over a newer one is blocked with "A newer version of Net-SNMP is already installed." Both rules are in the MSI's `Upgrade` table. The package stops the `Net-SNMP Agent` and `Net-SNMP Trap Handler` services before replacing files (confirmed in its `ServiceControl` table) and does not unregister them during an upgrade, so a registered service keeps pointing at the same path. It is not restarted afterwards: start it again.
- **NSIS.** Running a newer setup over an old one overwrites the files. The `bin` and `sbin` folders are added to `PATH` only if they are not already there, so repeated installs no longer duplicate entries. Stop a running service first, because its files are in use.
- Switching between the NSIS and MSI installers on one machine is not supported: uninstall one before installing the other.
- A running service holds its files open. Stop it before upgrading with the NSIS setup.

## 6. Uninstall

Both uninstallers stop and remove the `Net-SNMP Agent` and `Net-SNMP Trap Handler` services if they exist (they run `snmpd.exe -unregister` and `snmptrapd.exe -unregister`; a missing service is ignored). This also removes a service you registered by hand under those names. If a service entry is left behind anyway, delete it with `sc.exe delete "Net-SNMP Agent"`.

### NSIS

Apps and features, or:

```
"C:\Program Files\Net-SNMP\uninstall.exe" /S
```

It removes the `bin`/`sbin` entries from `PATH`, deletes `MIBDIRS` and `SNMPCONFPATH`, and deletes `bin`, `sbin`, `share` and `uninstall.exe`. Your configuration is **kept**: `etc\snmp` is removed only if it is empty, and the install folder only if nothing else is left in it. Anything you added to `bin`, `sbin` or `share` is deleted.

### MSI

Apps and features, or by file (the product code changes with each build, so use the file rather than a code):

```
msiexec /x net-snmp-5.9.5.2-x64.msi /qn
```

The environment entries are marked for removal on uninstall (confirmed in the `Environment` table). Windows Installer removes only the files it installed, so files you created in `etc\snmp` should stay behind; this was not tested.

## 7. Known limitations

- Strongest SNMPv3 privacy protocol is AES-128 (no AES-192/256). See BUILD.md section 8.
- Service registration is opt-in, covers only `snmpd`, and does not start the service. There is no firewall rule or starter configuration.
- The NSIS installer still rewrites the whole machine `PATH` value when it appends its folders, and when it removes them on uninstall. This is simple but less careful than the MSI, which adds and removes only its own entries. In environments where `PATH` is managed centrally, prefer the MSI.
- Unsigned installers.
- English only.
- Only 64-bit Windows.
