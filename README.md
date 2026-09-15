# Build a MOTU UltraLite FireWire driver for macOS Tahoe

This source project restores Core Audio support for the **original
FireWire-only MOTU UltraLite** on macOS Tahoe 26. It is built on the Apache-2.0
[ASFireWire](https://github.com/mrmidi/ASFireWire) DriverKit project and does
not depend on Apple's removed `IOFireWireFamily` kernel extension.

This repository intentionally provides **source code only**. It does not ship a
prebuilt, notarized, or author-signed driver. Each user must inspect the source,
build it with their own Xcode installation, and ad-hoc sign the resulting app
and DriverKit extension on their own Mac.

> [!CAUTION]
> This is experimental software provided **AS IS**, without warranties of any
> kind. Rafal Zalech and the project contributors accept no responsibility or
> liability for hardware damage, system instability, security problems, data
> loss, loss of work, incompatibility, or any other consequence of building,
> installing, or using it. You assume all risk. The procedure requires reducing
> macOS security by disabling SIP while the locally signed driver is in use.

## Supported hardware and current limits

The tested device is the original FireWire UltraLite reporting:

```text
Unit_Sw_Version: 0x00000d
Vendor/OUI:      0x0001f2
```

The driver was tested on Apple silicon with macOS 26.6.2 and Xcode 27.0.

Current support:

- 48 kHz audio
- 14 Core Audio outputs and 14 inputs
- Main Out, eight analog outputs, S/PDIF, and headphones
- Eight analog inputs, S/PDIF, and the CueMix Mix1 return
- macOS system audio on logical outputs 1-2
- Apple silicon `arm64e` DriverKit binary
- Intel `x86_64` slices are built but have not been hardware-tested here

MIDI and sample rates other than 48 kHz are not implemented. This profile is
not intended for UltraLite-mk3, AVB, USB, or other MOTU models.

## Hardware connection

The tested connection is:

```text
MOTU UltraLite FireWire 400
  → FireWire 400-to-800 cable
  → Apple Thunderbolt-to-FireWire Adapter
  → Apple Thunderbolt 3 (USB-C)-to-Thunderbolt 2 Adapter
  → Mac
```

Use a known-good cable and adapter chain. A USB-C connector alone does not
provide FireWire; the chain must carry Thunderbolt.

## 1. Prepare the Mac

You need:

- macOS Tahoe 26
- Full Xcode 27.0 with the macOS 26 SDK
- Git
- CMake
- XcodeGen
- Homebrew, unless CMake and XcodeGen are already installed another way
- About 3 GB of free build space

Install the command-line dependencies:

```bash
brew install cmake xcodegen
```

Select the full Xcode installation, accept its license, and confirm the version:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -version
```

## 2. Clone and prepare the source

```bash
git clone https://github.com/rafalzalech/motu_legacy_driver.git
cd motu_legacy_driver
./motu_tahoe_driver/prepare_source.sh
```

The preparation script:

1. Clones MrMidi's ASFireWire repository.
2. Checks out upstream commit
   `ac8a124a683d2f8201cd14ee0d2de8265e4834f0`.
3. Verifies the local patch checksum.
4. Applies the original UltraLite changes.

The same source is published in
[`rafalzalech/ASFireWire`](https://github.com/rafalzalech/ASFireWire/tree/feature/motu-ultralite-v2-audio)
at commit `b70b43a3df8ed34522dda443bdb46c9dbeedcf7f`.

The reproducible patch is:

```text
motu_tahoe_driver/patches/0001-add-original-motu-ultralite-audio-support.patch
SHA-256: ab2be05d8d3c5a88d7a5b9906e8e382103e02ea4dc403dc91ff416ca7eeecd9d
```

## 3. Build, test, and sign locally

Run:

```bash
./motu_tahoe_driver/build_driver.sh
```

This runs the ASFireWire C++ test suite, builds Release version `0.3.0` build
`12`, and ad-hoc signs the app and embedded DriverKit extension on your Mac.
The signature has no Apple Developer identity or Team ID.

The output is:

```text
motu_tahoe_driver/build/ASFireWire/build/DerivedData/Build/Products/Release/ASFW.app
```

Verify your local build:

```bash
APP="motu_tahoe_driver/build/ASFireWire/build/DerivedData/Build/Products/Release/ASFW.app"
DEXT="$APP/Contents/Library/SystemExtensions/net.mrmidi.ASFW.ASFWDriver.dext"

codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E 'Signature|TeamIdentifier'
lipo -archs "$DEXT/net.mrmidi.ASFW.ASFWDriver"
```

For the tested build, the final command includes `arm64e`. The signature report
should show an ad-hoc signature and no Team ID.

## 4. Disable SIP from macOS Recovery

Apple normally blocks locally signed DriverKit extensions with restricted
entitlements. This development build requires System Integrity Protection to be
disabled while it is in use.

On Apple silicon:

1. Shut down the Mac.
2. Press and hold the power button until startup options appear.
3. Select **Options**, then **Continue**.
4. Choose **Utilities → Terminal**.
5. Run:

   ```bash
   csrutil disable
   ```

6. Follow the on-screen confirmation and restart.

On Intel, start Recovery by holding **Command-R** while starting the Mac, then
run the same command from Recovery Terminal. See Apple's
[macOS Recovery instructions](https://support.apple.com/en-gb/102518).

Disabling SIP reduces macOS protection. Re-enable it from Recovery with
`csrutil enable` when you stop using this locally signed driver.

## 5. Check and install your build

From the repository root, run the read-only preflight:

```bash
./motu_tahoe_driver/install_motu_ultralite_tahoe.sh --check
```

The script uses the Release app produced in step 3. It checks the bundle IDs,
version, code signatures, required entitlements, and processor architecture.
It does not compare against or download an author-built binary.

Install your local build:

```bash
./motu_tahoe_driver/install_motu_ultralite_tahoe.sh --install
```

The installer requests administrator access, enables Driver Extension developer
mode, backs up an existing `/Applications/ASFW.app`, copies your build into
`/Applications`, and opens ASFW.

You can supply another local build explicitly:

```bash
./motu_tahoe_driver/install_motu_ultralite_tahoe.sh --check /path/to/ASFW.app
./motu_tahoe_driver/install_motu_ultralite_tahoe.sh --install /path/to/ASFW.app
```

## 6. Activate the extension

In ASFW, press **Install**. If macOS asks for approval:

1. Open **System Settings**.
2. Go to **General → Login Items & Extensions**.
3. Open **Driver Extensions**.
4. Enable or approve ASFW.

Apple documents this settings area in
[Change Login Items & Extensions settings](https://support.apple.com/en-ae/guide/mac-help/mtusr003/mac).

Restart after approval, even if ASFW reports that the extension is loaded.

## 7. Connect and verify the UltraLite

After restarting, connect the adapter chain and turn on the UltraLite. Run:

```bash
./motu_tahoe_driver/install_motu_ultralite_tahoe.sh --verify
```

A successful result includes:

```text
Driver extension: active and enabled (0.3.0/12)
Core Audio device: MOTU UltraLite detected
Installation verified.
```

Select **MOTU UltraLite** in **System Settings → Sound → Output**, Audio MIDI
Setup, or your audio application. The macOS volume slider can appear greyed out
at zero. That is expected for this hardware-controlled interface and does not
mean its audio stream is muted. Set listening level with the UltraLite's front
panel and your monitor or headphone controls.

## Channel map

| Core Audio outputs | UltraLite destination |
|---|---|
| 1-2 | Main Out 1-2 |
| 3-10 | Analog outputs 1-8 |
| 11-12 | S/PDIF |
| 13-14 | Phones |

| Core Audio inputs | UltraLite source |
|---|---|
| 1-8 | Analog inputs 1-8 |
| 9-10 | S/PDIF |
| 11-12 | CueMix Mix1 return |
| 13-14 | Transport padding; no physical input |

Stereo system audio and Max/MSP `dac~ 1 2` play through Main Out 1-2.

## Optional local package

After building, you may package **your own locally signed copy** for your own
machines:

```bash
./motu_tahoe_driver/package_installer.sh
```

The resulting ZIP is created under `motu_tahoe_driver/artifacts/`, which Git
ignores. The package records that it contains the local builder's signature.

## Troubleshooting

Check extension state:

```bash
systemextensionsctl list | grep -E 'ASFW|net\.mrmidi'
```

Check Core Audio:

```bash
system_profiler SPAudioDataType
```

Check the Thunderbolt adapter:

```bash
system_profiler SPThunderboltDataType
```

If the extension is active but the UltraLite is absent, power off the interface,
reconnect the adapter chain, power it on, and run `--verify` again. If the
extension remains disabled, enable ASFW under **System Settings → General →
Login Items & Extensions → Driver Extensions**, then restart.

If an old MOTU installation produces damaged-app or malware warnings at login,
disable only its matching legacy startup jobs:

```bash
./motu_ultralite_firewire_bundle/install_motu_ultralite_firewire.sh --disable-autostart
```

The custom Tahoe driver does not install the legacy MOTU kext, discovery
service, HTTP server, or MIDI proxy.

## Uninstall

Use **Uninstall** in `/Applications/ASFW.app`, or run:

```bash
systemextensionsctl uninstall - net.mrmidi.ASFW.ASFWDriver
```

Restart after removal. If you no longer need an ad-hoc DriverKit build, boot
into Recovery, run `csrutil enable`, and restart again.

## License, warranty, and third-party software

The custom source, patch, scripts, and documentation are distributed under
Apache License 2.0. The upstream ASFireWire license, copyright, and NOTICE are
preserved. See [LICENSE](LICENSE), [NOTICE](NOTICE), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The Apache License already disclaims warranties and limits liability. This
project provides no additional warranty, support promise, fitness guarantee, or
assumption of responsibility. Installation and use are entirely at the user's
own risk.

Linux FireWire audio sources and Apple's legacy interfaces were consulted only
as behavioral references. No GPL- or APSL-licensed implementation code was
copied into the custom driver.

The older `motu_ultralite_firewire_bundle` directory contains third-party MOTU
software and is not covered by this repository's Apache license. The custom
Tahoe DriverKit source does not depend on those files.
