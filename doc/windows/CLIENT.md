# Net-SNMP on Windows: using the client tools

Part of the [Windows documentation](README.md). Related: [running the agent as a service](SERVICE.md), [capturing and logging requests](REQUEST-CAPTURE.md), [agent configuration](AGENT-CONFIG.md), [installers](INSTALLERS.md) and [building](BUILD.md).

This guide covers using the command-line tools (`snmpget`, `snmpwalk`, `snmpset`, ...) from a build made with MSYS2 UCRT64 and installed with the NSIS setup or the MSI. Commands and outputs below were checked against a local `snmpd` built from this tree (5.9.5.2).

## 1. What "client" means

A client is any program that sends SNMP requests to an agent (a router, switch, server, or `snmpd`). Net-SNMP ships these client tools in `bin`:

| Tool | Purpose |
|------|---------|
| `snmpget` | Read one or more specific OIDs |
| `snmpgetnext` | Read the OID that follows the one given |
| `snmpwalk` | Read a whole subtree using repeated GETNEXT |
| `snmpbulkwalk` | Same as `snmpwalk` but uses GETBULK (SNMPv2c/v3, much faster) |
| `snmpbulkget` | Issue a single GETBULK |
| `snmptable` | Show a conceptual table (for example `ifTable`) as columns |
| `snmpset` | Write a value (needs a read-write community or v3 user) |
| `snmpdelta` | Monitor how counters change over time |
| `snmpstatus` | Quick health summary of an agent |
| `snmpdf` | Disk usage from the HOST-RESOURCES MIB |
| `snmptranslate` | Convert between names and numeric OIDs, and print MIB trees |
| `snmptrap` / `snmpinform` | Send traps or informs to a trap receiver |
| `snmpusm` | Manage SNMPv3 users on an agent |
| `snmpvacm` | Manage access control (VACM) on an agent |
| `snmptest` | Interactive request tool |

Agent-side programs (`snmpd.exe`, `snmptrapd.exe`) are in `sbin` and are not needed for client use.

## 2. Install

Use either installer from `installer\`:

- `net-snmp-5.9.5.2-setup.exe` (NSIS)
- `net-snmp-5.9.5.2-x64.msi` (WiX)

Both install to `C:\Program Files\Net-SNMP` and set these machine-wide environment variables:

| Variable | Value | Why |
|----------|-------|-----|
| `PATH` | appends `...\bin;...\sbin` | run the tools from any prompt |
| `MIBDIRS` | `C:\Program Files\Net-SNMP\share\snmp\mibs` | where to load MIB files from |
| `SNMPCONFPATH` | `C:\Program Files\Net-SNMP\etc\snmp` | where to read `snmp.conf` from |

Open a **new** terminal after installing so the variables are picked up.

Why `MIBDIRS` is needed: the executables were built with a POSIX-style prefix (`/ucrt64`), so their built-in default search path (`/ucrt64/share/snmp/mibs`) does not exist on Windows. Without `MIBDIRS` you get:

```
MIB search path: C:\Users\<you>/.snmp/mibs;/ucrt64/share/snmp/mibs
Cannot find module (SNMPv2-MIB): At line 0 in (none)
```

Numeric OIDs still work without MIBs, but names such as `sysDescr.0` do not.

### Running without installing

From the build tree, in an MSYS2 UCRT64 shell:

```
cd /c/Users/<you>/Personal/github/net-snmp-5.9.5.2
./apps/snmpget.exe -V
```

Or point a PowerShell session at an install-style layout (for example `installer\stage\ucrt64`, created by `installer/build-installer.sh`):

```powershell
$root = "C:\path\to\net-snmp-5.9.5.2\installer\stage\ucrt64"
$env:PATH    = "$root\bin;$root\sbin;$env:PATH"
$env:MIBDIRS = "$root\share\snmp\mibs"
```

The required DLLs (`libcrypto-3-x64.dll`, `libwinpthread-1.dll`, `libsystre-0.dll`, `libintl-8.dll`, `libtre-5.dll`, `libiconv-2.dll`) are in `bin`, next to the tools.

### Verify

```
snmpget -V
NET-SNMP version: 5.9.5.2

snmptranslate -IR sysDescr
SNMPv2-MIB::sysDescr
```

If the second command prints `Cannot find module`, `MIBDIRS` is not set in this terminal.

## 3. Basic usage

General form:

```
snmpget [options] <agent>[:port] <OID> [<OID> ...]
```

`<agent>` is a host name or IP. The default UDP port is 161. Use `host:port` for another port, or `udp:host:port` / `tcp:host:port` to choose the transport explicitly. For IPv6 use `udp6:[addr]:port`.

### SNMPv1 / v2c (community string)

```
snmpget -v2c -c public 192.168.1.10 sysDescr.0 sysUpTime.0
snmpwalk -v2c -c public 192.168.1.10 system
snmpgetnext -v2c -c public 192.168.1.10 sysName.0
snmpbulkwalk -v2c -c public 192.168.1.10 ifDescr
snmptable -v2c -c public 192.168.1.10 ifTable
snmpget -v1 -c public 192.168.1.10 sysName.0
```

Example output (from a local test agent):

```
SNMPv2-MIB::sysDescr.0 = STRING: Windows IVNT-6DJPST3 10.0.26200 Windows 10 Enterprise ...
DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (303) 0:00:03.03
```

`DISMAN-EVENT-MIB::sysUpTimeInstance` is the normal name Net-SNMP prints for `sysUpTime.0`; it is not an error.

The community string is sent in clear text. Use it only on trusted networks, and prefer SNMPv3 otherwise.

### SNMPv3 (user-based security)

SNMPv3 needs a user that already exists on the agent. The security level decides what is required:

| Level | Meaning | Options needed |
|-------|---------|----------------|
| `noAuthNoPriv` | user name only | `-u` |
| `authNoPriv` | authenticated | `-u -a -A` |
| `authPriv` | authenticated and encrypted | `-u -a -A -x -X` |

```
snmpget -v3 -l authPriv -u authUser -a SHA -A authpass123 -x AES -X privpass123 192.168.1.10 sysName.0
```

Supported algorithms in this build (OpenSSL enabled):

- Authentication (`-a`): `MD5`, `SHA` (SHA-1), `SHA-224`, `SHA-256`, `SHA-384`, `SHA-512`. Tested: `MD5`, `SHA`, `SHA-256`. The others are listed in the tool's own help but were not run.
- Privacy (`-x`): `DES`, `AES` (AES-128). `AES-192` and `AES-256` are **not** available: they need the build option `--enable-blumenthal-aes`, which was not used. Passing `-x AES-256` gives `Invalid privacy protocol specified after -3x flag: AES-256`, and `createUser ... AES-256` in `snmpd.conf` gives `unknown privProtocol`.

To get AES-192/256, rebuild with `--enable-blumenthal-aes` (the same option is used by `ci/build.bat`) and re-create the installers. Both ends must support the same protocol; AES-192/256 are a Net-SNMP extension that not every vendor agent accepts.

Passphrases must be at least 8 characters. Use `-n <contextName>` and `-e <engineID>` only if the agent requires them.

Failure cases and what they print:

```
snmpget: Authentication failure (incorrect password, community or key)   <- wrong -A or -a
Timeout: No Response from 192.168.1.10:161.                              <- wrong community, wrong IP/port, firewall, ACL
```

### Writing values (`snmpset`)

```
snmpset -v2c -c private 192.168.1.10 sysLocation.0 s "Lab 1"
snmpset -v3 -l authPriv -u authUser -a SHA -A authpass123 -x AES -X privpass123 192.168.1.10 sysLocation.0 s Lab1
```

Type letters: `i` INTEGER, `u` unsigned, `s` string, `x` hex string, `a` IP address, `o` OID, `t` timeticks, `c` counter32, `b` bits, `U` counter64. The agent must grant write access (`rwcommunity` or `rwuser`).

## 4. Saving defaults in `snmp.conf`

To avoid retyping version and credentials, create `snmp.conf` in the config directory (`C:\Program Files\Net-SNMP\etc\snmp` after installation; editing there needs administrator rights).

SNMPv2c defaults:

```
defVersion 2c
defCommunity public
```

Then:

```
snmpget 192.168.1.10 sysName.0
```

SNMPv3 defaults:

```
defVersion 3
defSecurityName authUser
defSecurityLevel authPriv
defAuthType SHA
defAuthPassphrase authpass123
defPrivType AES
defPrivPassphrase privpass123
```

Other useful lines: `mibdirs +C:\my\mibs`, `mibs +ALL`, `defContext <name>`, `defaultPort 161`.

Important points:

- `SNMPCONFPATH` replaces the search path. Because the installers set it machine-wide, only that one directory is read. A per-user file at `%USERPROFILE%\.snmp\snmp.conf` is ignored unless you add it:
  ```
  setx SNMPCONFPATH "%USERPROFILE%\.snmp;C:\Program Files\Net-SNMP\etc\snmp"
  ```
  (Separator on Windows is `;`.)
- Passphrases in `snmp.conf` are stored in plain text. Restrict file permissions, or use localized keys (`defAuthMasterKey`, `defPrivMasterKey`, or `defAuthLocalizedKey`) instead of passphrases. Passphrases given with `-A`/`-X` on the command line are visible in the process list.
- To see which files were read: `snmpget -Dread_config <agent> <oid>` (look for `Reading configuration ...`).

## 5. MIBs

The installer puts the standard MIBs in `C:\Program Files\Net-SNMP\share\snmp\mibs`.

- Search path is `MIBDIRS` (or `mibdirs` in `snmp.conf`). Prefix the value with `+` to add to the default list instead of replacing it:
  ```
  setx MIBDIRS "+C:\my\vendor-mibs"
  ```
  Without `+`, the value replaces the list, so include the Net-SNMP directory too:
  ```
  setx MIBDIRS "C:\my\vendor-mibs;C:\Program Files\Net-SNMP\share\snmp\mibs"
  ```
- Load every MIB in the path for one command: `-m ALL`. Load one extra module: `-m +VENDOR-MIB`. Point at a single file: `-m +C:\my\VENDOR-MIB.txt`.
- `-M <dir>` overrides the directory for one command.
- A per-user MIB folder `%USERPROFILE%\.snmp\mibs` is also searched by default.
- Inspect a subtree: `snmptranslate -Tp -IR system`
- Name to OID: `snmptranslate -On SNMPv2-MIB::sysDescr.0` gives `.1.3.6.1.2.1.1.1.0`
- OID to name: `snmptranslate .1.3.6.1.2.1.1.1.0`

If you see `Unknown Object Identifier`, either the MIB is not loaded or the name is misspelled. Use the numeric OID, or add `-m ALL`.

## 6. Output formatting

| Option | Effect | Example |
|--------|--------|---------|
| `-On` | numeric OIDs | `.1.3.6.1.2.1.1.1.0 = STRING: ...` |
| `-Os` | last name component only | `sysDescr.0` |
| `-OS` | module and name | `SNMPv2-MIB::sysDescr.0` (default) |
| `-Of` | full path | `.iso.org.dod.internet.mgmt.mib-2.system.sysDescr.0` |
| `-Oq` | quick print, no `=` and no type | |
| `-Ov` | value only | |
| `-Ovq` | value only, no type text | `0:0:00:04.89` |
| `-OQ` | quick print, keep the `=` | |

Other common options for all tools:

| Option | Meaning |
|--------|---------|
| `-v 1\|2c\|3` | protocol version |
| `-c <string>` | community (v1/v2c) |
| `-t <seconds>` | timeout per try (default 1) |
| `-r <n>` | retries (default 5) |
| `-Cr<n>` (bulk tools) | max repetitions, for example `snmpbulkwalk -Cr25 ...` |
| `-d` | dump raw packets, for debugging |
| `-D<token>` | debug output, for example `-Dread_config`, `-Dtdomain` |
| `-V` | print version and exit |
| `-h` | help for that tool |

## 7. Practical examples

```
rem What is this device?
snmpget -v2c -c public 192.168.1.10 sysDescr.0 sysName.0 sysLocation.0 sysContact.0

rem List interfaces with status
snmpwalk -v2c -c public 192.168.1.10 ifDescr ifOperStatus

rem Interface table as columns
snmptable -v2c -c public 192.168.1.10 ifTable

rem Fast walk of a large table
snmpbulkwalk -v2c -c public -Cr50 192.168.1.10 ifXTable

rem Whole agent, numeric, to a file
snmpwalk -v2c -c public -On 192.168.1.10 .1 > walk.txt

rem Watch how interface counters change over time
snmpdelta -v2c -c public 192.168.1.10 ifInOctets.1 ifOutOctets.1

rem Agent summary
snmpstatus -v2c -c public 192.168.1.10
```

## 8. Local test recipe (no network device needed)

This runs a throw-away agent on port 1161 and queries it. All commands in section 3 were verified this way.

1. Create `C:\temp\snmpd.conf`:
   ```
   rocommunity public 127.0.0.1
   agentaddress udp:127.0.0.1:1161
   sysLocation Test
   ```
2. In one terminal (leave it open):
   ```
   snmpd.exe -f -Lo -C -c C:\temp\snmpd.conf
   ```
   `-f` stays in the foreground, `-Lo` logs to stdout, `-C` ignores the default config files.
3. In another terminal:
   ```
   snmpget  -v2c -c public 127.0.0.1:1161 sysDescr.0
   snmpwalk -v2c -c public 127.0.0.1:1161 system
   ```
4. Stop the agent with Ctrl+C.

For an SNMPv3 test add to that file `createUser authUser SHA authpass123 AES privpass123` and `rwuser authUser priv`, then start `snmpd` once. The user is created and its keys are stored in the agent's persistent directory (`SNMP_PERSISTENT_DIR` if set). Remove the `createUser` line afterwards so the passphrases are not left in plain text. Querying with the v3 command in section 3 then works.

## 9. Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| `Cannot find module (SNMPv2-MIB)`, `Unknown Object Identifier` | `MIBDIRS` not set in this terminal, or MIB not in the path. Open a new terminal or set `MIBDIRS`; use `-m ALL`. |
| `Timeout: No Response from host:161` | Wrong IP or port; agent not running; firewall blocking UDP 161; wrong community; source IP not allowed by the agent. Try `-r 1 -t 2`, and `ping` the host. |
| `Authentication failure (incorrect password, community or key)` | Wrong v3 passphrase or algorithm (`-a`, `-A`). |
| `Unknown user name` | The v3 user does not exist on the agent. |
| `Unsupported security level` | The agent user is not configured for that level (for example `authPriv`). |
| `Error in packet. Reason: noAccess` / `authorizationError` | The agent denies this community or user for that OID (VACM). |
| `Error in packet. Reason: notWritable` | The object is read-only, or you used a read-only community. |
| `No Such Object available on this agent at this OID` | The agent does not implement that object. |
| `The dll was not found` or the program fails to start | Running a binary from `.libs` without its DLLs on `PATH`. Use the installed copy, or add `C:\msys64\ucrt64\bin` to `PATH`. |
| In Windows PowerShell 5.1, text such as `NativeCommandError` appears around normal output | PowerShell is wrapping stderr when you redirect it (`2>&1`). The tool itself succeeded. Use PowerShell 7 or drop the redirect. |
| Quoting problems with spaces | Use double quotes: `snmpset ... sysLocation.0 s "Lab 1"`. In PowerShell, quote the whole argument if it contains special characters. |

Debug techniques:

- `-d` prints sent and received packets.
- `-Dread_config` shows which config files and environment variables are used.
- `-DALL` prints everything (very verbose).

## 10. Security notes

- SNMPv1/v2c community strings travel unencrypted. Use SNMPv3 `authPriv` outside a lab.
- Do not leave `public`/`private` defaults on real devices.
- Prefer SHA-256 or stronger with AES over MD5/DES when the agent supports them. This build offers AES-128 as its strongest privacy protocol (see section 3).
- Avoid putting secrets on the command line (visible to other users via the process list); use a restricted `snmp.conf`, ideally with localized keys.
- Only run `snmpset` against devices you are authorised to change.

## 11. Related documents and untested items

- Running `snmpd` or `snmptrapd` as a Windows service, and starting them at boot: [SERVICE.md](SERVICE.md).
- Logging what an agent receives, receiving traps and confirming SNMPv3 algorithms: [REQUEST-CAPTURE.md](REQUEST-CAPTURE.md). Sending traps with `snmptrap` was tested locally only for v1 and v2c; `snmpinform` and v3 traps were not tested.
- Writing `snmpd.conf`: [AGENT-CONFIG.md](AGENT-CONFIG.md).
