# Net-SNMP on Windows: documentation index

This folder documents the Windows build of Net-SNMP 5.9.5.2 made with MSYS2 UCRT64 and OpenSSL, and the installers built from it.

| Document | Read it to |
|----------|-----------|
| [BUILD.md](BUILD.md) | build the programs and the installers from source |
| [INSTALLERS.md](INSTALLERS.md) | install, upgrade and remove with the NSIS setup or the MSI; what they change on the machine |
| [AGENT-CONFIG.md](AGENT-CONFIG.md) | write `snmpd.conf`: listeners, communities, SNMPv3 users, access control, `extend`, traps; which MIBs the agent serves |
| [CLIENT.md](CLIENT.md) | use the client tools (`snmpget`, `snmpwalk`, ...), `snmp.conf`, MIBs, SNMPv3, troubleshooting |
| [SERVICE.md](SERVICE.md) | run `snmpd` as a Windows service and at startup |
| [REQUEST-CAPTURE.md](REQUEST-CAPTURE.md) | log what an agent receives, receive traps, confirm SNMPv3 algorithms from the log |

## What this build is

- 64-bit Windows executables (GCC 15.2, UCRT) with OpenSSL 3.5.
- SNMPv1, v2c and v3; authentication MD5, SHA-1 and SHA-2 family; privacy DES and AES-128.
- Client tools, `snmpd` and `snmptrapd`.
- Not included: Perl modules and scripts (`snmpconf`, `mib2c`), Python, MySQL trap logging, AES-192/256.

## Quick start

1. Install `installer/net-snmp-5.9.5.2-x64.msi` (or the NSIS setup) from an elevated prompt.
2. Open a new terminal and run `snmpget -V`.
3. Create `C:\Program Files\Net-SNMP\etc\snmp\snmpd.conf` (see AGENT-CONFIG.md, section 3).
4. Test in the foreground: `snmpd.exe -f -Lo`, then `snmpget -v2c -c <community> 127.0.0.1 sysDescr.0`.
5. Register as a service if wanted ([SERVICE.md](SERVICE.md)).

## What has and has not been verified

| Area | Status |
|------|--------|
| Build, installers produced | done on this tree |
| Client tools against a local agent (v1, v2c, v3) | run |
| `snmpd.conf` examples in AGENT-CONFIG.md | run against temporary agents |
| Request logging and SNMPv3 algorithm checks | run |
| Installing and uninstalling the NSIS and MSI packages, including the opt-in service registration | **not run** (needs an elevated prompt; both packages build, and the MSI tables were inspected) |
| Windows service registration | **not run** (needs an elevated prompt; from the source code) |
| Wireshark and `pktmon` capture, `snmptrapd -F` formats, SHA-224/384/512, AES-192/256 | **not run** |

Each document says which of its statements are untested.
