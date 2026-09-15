# MOTU UltraLite FireWire bundle

This archive includes a signed MOTU FireWire kernel extension (`1.6 88494`) and
applications from an older working installation. The driver specifies macOS 11
or later and includes Intel x86_64 and Apple silicon arm64e code. These are
minimum prerequisites, not a certification of every later Mac or macOS release.

## Check before installing

```bash
bash ./install_motu_ultralite_firewire.sh --check
```

This is read-only and does not use sudo. It checks the platform, selected payload,
MOTU code signatures, Gatekeeper assessments for the apps, and kernel architecture.
On Tahoe or later it first looks for `com.apple.iokit.IOFireWireFamily` in loaded
extensions or kernel collections. Apple no longer supports FireWire on these
releases; a leftover extension directory alone is insufficient. If a previously
restored stack is detected, preflight continues with an explicit qualification.

The M5 Pro / macOS 26.6.2 (25G83) investigated for this repair has no detected
FireWire kernel stack. This bundle cannot make a FireWire-only UltraLite work on
that configuration. A KDK supplies developer build resources, not the missing
runtime FireWire implementation. Another Mac reported to work on Tahoe needs to
be checked separately to establish how its configuration differs.

## Installation on a compatible Mac

```bash
bash ./install_motu_ultralite_firewire.sh
```

Preflight runs before sudo or system changes, and repeats after escalation.
The installer copies only:

- `/Applications/MOTU Audio Setup.app`
- `/Applications/MOTU SMPTE Setup.app`
- `/Library/Audio/MIDI Devices/MOTU/Mackie.middev`
- `/Library/Extensions/MOTUFireWireAudio.kext`

The other archived apps and ProAudio services are not installed. Open Audio Setup
manually when needed. The installer does not add login jobs or a MIDI proxy daemon.
Existing startup jobs from the old script require the cleanup command below.

Existing versions are moved to a printed directory under
`/Library/MOTU-Legacy-Backups/repair.*` before replacement. Copies are staged next
to their destinations, assigned root:wheel ownership and suitable permissions,
and replaced without merging signed bundles. A failed replacement restores that
item; earlier successful replacements may remain and have their own backups.
Keep the printed backup path for recovery.

Activation uses `kmutil load --bundle-path /Library/Extensions/MOTUFireWireAudio.kext`.
It does not rebuild every kernel collection with `--update-all`. Activation
failure returns a nonzero status and never prints “Install complete.” A successful
load request still does not mean a device has been detected.

On Apple silicon, enable Reduced Security and user management of extensions from
identified developers in Recovery's Startup Security Utility if you choose to use
this kext. Approve MOTU in System Settings and use the requested restart. SIP and
Gatekeeper do not need to be disabled. See
[Apple's extension approval instructions](https://support.apple.com/en-us/120363).

After restarting, verify both the loaded driver and audio-device enumeration:

```bash
/usr/bin/kmutil showloaded | /usr/bin/grep -F com.motu.driver.FireWireAudio
/usr/sbin/system_profiler SPAudioDataType
```

Connect and power the interface and its Thunderbolt/FireWire adapter chain before
checking hardware. The investigated Mac had no connected Thunderbolt device at
the time of inspection.

## Startup warnings left by the old installer

The original script installed four automatic background jobs. The investigated
Mac's boot logs show Gatekeeper prompts/denials for the console launcher,
discovery helper, HTTP server and MIDI proxy. The checked top-level applications
and console launcher passed current signature and notarization assessments;
that does not establish that every possible warning was a false positive.

To stop the old jobs and prevent those matching jobs starting at the next login:

```bash
bash ./install_motu_ultralite_firewire.sh --disable-autostart
```

This command works even when installation preflight would reject the Mac. It
requires administrator authentication. Only installed plists that exactly match
the archived copies are moved into the printed backup directory. Changed jobs
are reported and left alone. It stops the matching system daemon and the current
console user's matching agents; other logged-in users may need to log out.
Applications and the kernel driver remain installed. This cleanup does not make
FireWire work or certify a rejected executable as safe.

To undo cleanup, copy the saved plists from the backup's `Library/LaunchAgents`
and `Library/LaunchDaemons` directories to their original locations, preserving
root ownership, and restart. Do not restore them if you want them to stay disabled.

The script preserves vendor signatures and quarantine metadata. It does not
ad-hoc sign drivers, clear quarantine, override malware detection, or alter global
security settings. If an app is still rejected, record its exact name and warning
and obtain an intact, compatible installer from MOTU.

## Compare a previously working Mac without connecting hardware

```bash
bash ./install_motu_ultralite_firewire.sh --diagnose
```

Alternatively, copy only `diagnose_motu.sh` to the other Mac and run it with Bash.
It needs no bundle files. It can run without sudo, but root-only bundles require
`sudo bash ./diagnose_motu.sh` for complete results. It reports OS/build, model identifier,
loaded and stored kernel extensions, registered system extensions, and installed
MOTU/FireWire/audio bundle versions, executable architectures and checksums.
It does not activate drivers or change security settings. No hardware serial
numbers are requested. Failed queries are distinguished from empty results.

The user reports the M2 MacBook Pro worked with the interface on macOS 26.7
(build 25G220) on September 9, 2026, before its ports failed. Its empty
`showloaded` result after disconnection does not disprove that observation.
The subsequent checks below describe the current state; they do not reconstruct
the earlier working session.

The M2's installed driver was subsequently inspected with sudo: its executable
SHA-256 exactly matches this archive (`96bb6f0aa06a0b4b70f541271fb30533007d49774d06e70a49b3677daaa05745`).
Its kext directory is root-only (`0700`), explaining earlier access failures.
Both Macs' `kmutil print-diagnostics` explicitly report the same unresolved
dependency on `com.apple.iokit.IOFireWireFamily`. On the M2,
`sudo kmutil showloaded --show all` also reports neither the MOTU driver nor
FireWire; `systemextensionsctl list` reports zero system extensions. The current
M2 installation therefore does not provide a working driver configuration to
copy to the M5. The reason for the earlier successful session remains unknown.
Reinstalling the identical MOTU binary, changing its permissions, or clearing
quarantine does not supply the missing Apple dependency.

ASFireWire still lists MOTU v2 as requested/not supported in its public
[device compatibility table](https://github.com/mrmidi/ASFireWire/wiki/Device-Compatibility#requested--not-supported).
For this investigation, an isolated [experimental UltraLite audio build](../motu_tahoe_driver/README.md)
was created from ASFireWire plus the active MOTU v2 development work. Its DriverKit host
stack discovered the connected hardware and successfully read its registers; the current
build adds a 48 kHz Core Audio endpoint. It is separate from this legacy kext installer.
