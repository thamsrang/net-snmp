# Capturing the requests an agent receives

Part of the [Windows documentation](README.md). Related: [client tools](CLIENT.md), [running the agent as a service](SERVICE.md) and [agent configuration](AGENT-CONFIG.md).

Three levels of detail are available: the agent's own log, a trap receiver log, and a network capture. The `snmpd` and `snmptrapd` outputs below were captured from local test runs (agent on `127.0.0.1:1161`-`1163`, receiver on `1164`).

## 1. `snmpd` (requests from clients)

Run the agent in the foreground with logging to a file or console, plus one of these options:

| Option | What is logged |
|--------|----------------|
| `-a` | source address of each request only |
| `-V` | source address, request type (GET, GETNEXT, GETBULK, SET) and the OIDs asked for |
| `-d` | full hex dump of every packet received and every response sent, including the community string or v3 headers |
| `-Lf <file>` | write the log to a file (use `-Lo` for the console); add `-A` to append instead of overwrite |

Options can be combined, for example:

```
snmpd.exe -f -Lf C:\ProgramData\Net-SNMP\snmpd.log -V
```

Example log with `-V` (one good request, one with a wrong community):

```
Received SNMP packet(s) from UDP: [127.0.0.1]:64044->[0.0.0.0]:0
  GET message
    -- SNMPv2-MIB::sysName.0
Received SNMP packet(s) from UDP: [127.0.0.1]:64047->[0.0.0.0]:0
  GET message
    -- SNMPv2-MIB::sysName.0
```

The address before `->` is the client's IP and source port. The part after `->` is the local address and is shown as `0.0.0.0:0`, so it is not useful. The agent logs a request even when it rejects it (for example a wrong community, which gets no reply), so `-V` is how you see rejected requests.

Example with `-d` (a GET for `sysName.0` and its response; the client's community `public` is visible in the bytes):

```
Received 41 byte packet from UDP: [127.0.0.1]:54788->[0.0.0.0]:0
0000: 30 27 02 01  01 04 06 70  75 62 6C 69  63 A0 1A 02    0'.....public ..
...
Sending 53 bytes to UDP: [127.0.0.1]:54788->[0.0.0.0]:0
0000: 30 33 02 01  01 04 06 70  75 62 6C 69  63 A2 26 02    03.....public..&.
...
```

`-a` prints only `Received SNMP packet(s) from UDP: [127.0.0.1]:60886->[0.0.0.0]:0` for each request.

Notes:

- There is no timestamp on these lines and no built-in log rotation. Rotate the file yourself (for example stop the service, rename the file, start it again).
- `-d` writes community strings and other secrets into the log in clear text. Restrict access to the log file and do not leave `-d` on.
- Logging every request with `-V` or `-d` makes the log grow quickly on a busy agent. Use it for troubleshooting, not permanently.
- For the Windows service, add the options when registering, for example `snmpd.exe -register -quiet -Lf C:\ProgramData\Net-SNMP\snmpd.log -V` (see [SERVICE.md](SERVICE.md), section 2).
- Keep the config folder and the persistent folder separate (see [SERVICE.md](SERVICE.md), section 1), otherwise the agent overwrites its own `snmpd.conf`.

## 2. `snmptrapd` (traps and informs sent to a receiver)

The receiver must be told which communities to accept; traps from any other community are silently dropped (nothing is logged). Create `snmptrapd.conf` in the config folder:

```
authCommunity log,execute,net public
```

Then run it in the foreground. **Options must come before the listen address**, otherwise the option is treated as an address and fails with `couldn't open ...`:

```
snmptrapd.exe -f -Lf C:\ProgramData\Net-SNMP\traps.log udp:162
```

Send a test trap from another terminal:

```
snmptrap -v2c -c public 127.0.0.1:162 "" NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatNotification netSnmpExampleHeartbeatRate i 123
```

Logged result (v2c trap, then a v1 trap):

```
2026-10-08 23:25:27 <UNKNOWN> [UDP: [127.0.0.1]:50352->[0.0.0.0]:0]:
DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (3565776228) 412 days, 16:56:02.28 SNMPv2-MIB::snmpTrapOID.0 = OID: NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatNotification NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatRate = INTEGER: 123
2026-10-08 23:25:28 127.0.0.1 [127.0.0.1] (via UDP: [127.0.0.1]:64824->[0.0.0.0]:0) TRAP, SNMP v1, community public
        NET-SNMP-EXAMPLES-MIB::netSnmpExampleNotifications Enterprise Specific Trap (17) Uptime: 412 days, 16:56:04.38
        NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatRate = INTEGER: 5
```

The log has a timestamp, the sender, the version, the community, and every variable binding. Useful options:

| Option | Effect |
|--------|--------|
| `-Lf <file>` / `-Lo` | log to file / console |
| `-d` | also hex-dump each received packet (shows the community in clear text) |
| `-n` | do not resolve sender addresses to names (avoids the `<UNKNOWN>` / `gethostbyaddr not available` text and speeds up logging) |
| `-F <format>` | custom log line; see `snmptrapd -h` and the `snmptrapd` man page for the `%` codes. Quote the whole format, for example `-F "%V\n%B\n%v\n"` (the format option was not verified here) |

A v2c trap with an unaccepted community produced no log line at all, so if a trap is missing, check the community in `authCommunity` first, then use `-d` to confirm it arrived.

## 3. What the client sent (`-d` on the client tools)

Add `-d` to any client tool to print the exact packets it sends and receives:

```
snmpget -d -v2c -c public 192.168.1.10 sysName.0
```

## 4. Capturing on the network (independent of Net-SNMP)

Use this when you want to see traffic to or from devices you do not control, or compare what an agent logs with what really arrived. These tools were not run as part of this guide.

- **Wireshark with Npcap.** Capture on the interface, filter `snmp` (or `udp.port == 161`, `udp.port == 162` for traps). It decodes the request type, OIDs, community and values. Traffic to `127.0.0.1` needs the Npcap loopback adapter.
- **Built-in `pktmon`** (Windows 10 version 2004 and later, elevated prompt), for traffic on real interfaces:
  ```
  pktmon filter add -p 161
  pktmon start --capture --pkt-size 0 -f C:\temp\snmp.etl
  pktmon stop
  pktmon etl2pcap C:\temp\snmp.etl --out C:\temp\snmp.pcapng
  ```
  Open the `.pcapng` in Wireshark. Remove the filter afterwards with `pktmon filter remove`.
- SNMPv3 `authPriv` payloads are encrypted, so a capture shows only headers unless you give Wireshark the user credentials (SNMP preferences, Users Table). v1 and v2c show the community string and all values in clear text.

## 5. SNMPv3: are the authentication and encryption types captured?

Only partly. The algorithm **names** (MD5, SHA, DES, AES) are never written to the agent log, but the user, the security level and whether verification worked can be.

To log them, add USM debug tokens to the agent (tested):

```
snmpd.exe -f -Lf C:\ProgramData\Net-SNMP\snmpd.log -V -Dusm,snmpv3,snmp_parse
```

For each v3 request the log then contains lines like:

```
snmp_parse: Parsed SNMPv3 message (secName:, secLevel:noAuthNoPriv): USM unknown engineID     <- discovery step, sent first by every v3 client
usm: match on user userSha
usm: Verification succeeded.
snmp_parse: Parsed SNMPv3 message (secName:userSha, secLevel:authPriv):
  GET message
    -- SNMPv2-MIB::sysName.0
usm: Encryption successful.
```

| Information | In the agent log? |
|-------------|-------------------|
| User name (`secName`) | Yes |
| Security level (`noAuthNoPriv`, `authNoPriv`, `authPriv`) | Yes |
| Authentication check result | Yes: `Verification succeeded.` or `Verification failed.` (wrong password or algorithm) |
| Request type and OIDs | Yes (`-V`) |
| Authentication algorithm (MD5, SHA, SHA-256 ...) | No |
| Privacy algorithm (DES, AES) | No |
| Passwords or keys | No |

Each v3 request appears twice in the log: a first exchange where the agent says `Unknown Engine ID` (engine discovery) and then the real request.

A failed login does show up: wrong passphrase gives `usm: Verification failed.` on the agent and `Authentication failure (incorrect password, community or key)` on the client. An unknown user gives `Unknown user name` on the client.

**How to find out which algorithms a user uses.** Ask the agent for its user table, using any authorised v3 user (tested):

```
snmpwalk -v3 -l authPriv -u userSha -a SHA -A authpass123 -x AES -X privpass123 -On 127.0.0.1 1.3.6.1.6.3.15.1.2.2.1.5
snmpwalk -v3 -l authPriv -u userSha -a SHA -A authpass123 -x AES -X privpass123 -On 127.0.0.1 1.3.6.1.6.3.15.1.2.2.1.8
```

`...2.2.1.5` is `usmUserAuthProtocol` and `...2.2.1.8` is `usmUserPrivProtocol`. The value for each user is an OID that names the algorithm. The table row is identified by the agent's engine ID and the user name, which is encoded in the trailing numbers of the index (for example `...117.115.101.114.77.100.53` is the text `userMd5`). Results from the test agent:

| Value OID | Meaning (`snmptranslate`) |
|-----------|---------------------------|
| `.1.3.6.1.6.3.10.1.1.2` | `usmHMACMD5AuthProtocol` (MD5) |
| `.1.3.6.1.6.3.10.1.1.3` | `usmHMACSHAAuthProtocol` (SHA-1) |
| `.1.3.6.1.6.3.10.1.1.5` | `snmpAuthProtocols.5`, SHA-256 (the user created with `SHA-256`) |
| `.1.3.6.1.6.3.10.1.2.2` | `usmDESPrivProtocol` (DES) |
| `.1.3.6.1.6.3.10.1.2.4` | `snmpPrivProtocols.4`, AES-128 (the users created with `AES`) |

The user must be allowed to read that part of the tree. It worked with a user configured as `rwuser <name> priv` (no restricted view). It is also recorded in the agent's `snmpd.conf` (`createUser` lines) and the persistent file.

**What the packet itself shows.** The `-d` hex dump contains the USM fields, but the packet carries only the HMAC bytes and an 8-byte salt, not algorithm names. From the standards (RFC 3414 and RFC 7860), the authentication parameter length hints at the hash: 12 bytes for MD5 or SHA-1, 16 for SHA-224, 24 for SHA-256, 32 for SHA-384, 48 for SHA-512. The privacy parameter is an 8-byte salt for both DES and AES, so DES and AES cannot be told apart from the packet. This length rule was not checked against a dump here. With `authPriv` the PDU is also encrypted, so the OIDs are not readable in a capture; the agent log is the better place to see them.

**From the client side.** The algorithm in use is whatever you pass with `-a` and `-x` (or `defAuthType` / `defPrivType` in `snmp.conf`), so a client log or script already records it.

## 6. Confirming the algorithms from the log

The log never prints "SHA" or "AES", but a successful v3 request proves them. Authentication keys are derived for one specific hash, and the encrypted PDU only decodes with the right cipher, so a mismatch always shows up as a failure line. Use the log from section 5 (`-V -Dusm,snmpv3,snmp_parse`) together with the user's configured algorithms.

**Rule.** A request counts as proof of the user's configured algorithms only when its real request (the second `Received` block, after the `unknown engineID` discovery step) has all of these lines:

```
usm: match on user userSha
usm: Verification succeeded.                                   <- authentication algorithm and passphrase match the agent's
snmp_parse: Parsed SNMPv3 message (secName:userSha, secLevel:authPriv):
  GET message                                                  <- PDU decrypted and parsed: privacy algorithm and passphrase match
    -- SNMPv2-MIB::sysName.0
usm: Encryption successful.                                    <- the response was encrypted
```

Then look up what `userSha` is configured with (section 5, walk `usmUserAuthProtocol` and `usmUserPrivProtocol`). Those are the algorithms that were used.

**Failure patterns** (all tested, agent user `userSha` configured as SHA and AES):

| Client used | Agent log | Client sees |
|-------------|-----------|-------------|
| Correct SHA + AES | `Verification succeeded.`, `GET message`, `Encryption successful.` | the value |
| `-a MD5` (wrong auth algorithm) | `Verification failed.` and `Authentication failed for userSha` | `Authentication failure` |
| Wrong auth passphrase | same as wrong auth algorithm | `Authentication failure` |
| `-x DES` (wrong privacy algorithm) | `Verification succeeded.` then `secLevel:authPriv): ASN.1 parse error in message` | `Timeout: No Response` |
| Wrong privacy passphrase | same as wrong privacy algorithm | `Timeout: No Response` |
| `-l authNoPriv` (lower level) | `secLevel:authNoPriv` then `GET message` | `authorizationError (access denied to that object)` because the user is limited to `priv` |

Limits of this method:

- A wrong auth algorithm cannot be told apart from a wrong auth passphrase, and a wrong privacy algorithm cannot be told apart from a wrong privacy passphrase. The log says the pair did not match, not which part was wrong.
- If the privacy step fails there is no response and no explicit "decryption failed" line; look for `ASN.1 parse error in message` right after `Verification succeeded.`.
- The proof is only as good as the user's configured algorithms, so check them with the user-table walk. Do not rely on the user name alone.

**Making the log meaningful.** Create one user per algorithm combination and give the user name that meaning, then restrict access to the ones you accept:

```
createUser auditSha256Aes SHA-256 <authpass> AES <privpass>
rouser auditSha256Aes priv
```

Do not create MD5 or DES users if you do not want them to be used. Then any request with `secName:auditSha256Aes` and `secLevel:authPriv` that shows `Verification succeeded.` and `GET message` used SHA-256 and AES-128, and no weaker combination can succeed.

**Checking a client rather than the agent.** To prove what a client really sends, run a test agent with the log above and a user whose algorithms you know, point the client at it and read the pattern in the table.

## 7. Which one to use

| Goal | Use |
|------|-----|
| Who is querying my agent, and for what OIDs | `snmpd -V` (or `-a` for addresses only) |
| Which v3 user and security level, and did login succeed | `snmpd -V -Dusm,snmpv3,snmp_parse` |
| Which algorithms a v3 user is configured with | walk `usmUserAuthProtocol` and `usmUserPrivProtocol` |
| Exact bytes in and out of the agent | `snmpd -d` |
| Traps and informs received | `snmptrapd -Lf <file>` with `authCommunity` |
| Exactly what my client sends | client tool with `-d` |
| Traffic to or from other devices, or proof of what is on the wire | Wireshark / `pktmon` |
