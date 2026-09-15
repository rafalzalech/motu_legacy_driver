# Original MOTU UltraLite Tahoe driver source

This directory contains the reproducible patch, build scripts, local installer,
verification tools, and diagnostics for the original FireWire-only MOTU
UltraLite on macOS Tahoe.

The repository distributes source only. It contains no prebuilt or
author-signed ASFW application or DriverKit extension. Follow the complete
[build and installation guide](../README.md) to create and ad-hoc sign your own
copy locally.

## Quick build

Install Xcode 27.0, CMake, and XcodeGen, then run from the repository root:

```bash
./motu_tahoe_driver/prepare_source.sh
./motu_tahoe_driver/build_driver.sh
./motu_tahoe_driver/install_motu_ultralite_tahoe.sh --check
./motu_tahoe_driver/install_motu_ultralite_tahoe.sh --install
```

The source preparation is pinned to ASFireWire commit
`ac8a124a683d2f8201cd14ee0d2de8265e4834f0`. It verifies and applies:

```text
patches/0001-add-original-motu-ultralite-audio-support.patch
SHA-256: ab2be05d8d3c5a88d7a5b9906e8e382103e02ea4dc403dc91ff416ca7eeecd9d
```

The resulting tree is identical to the source in
[`rafalzalech/ASFireWire`](https://github.com/rafalzalech/ASFireWire/tree/feature/motu-ultralite-v2-audio)
at commit `b70b43a3df8ed34522dda443bdb46c9dbeedcf7f`.

## Tested profile

- Original UltraLite, `Unit_Sw_Version 0x00000d`
- 48 kHz
- 14 Core Audio outputs and 14 inputs
- Main Out on logical outputs 1-2
- Analog outputs on 3-10
- S/PDIF outputs on 11-12
- Phones on 13-14
- Analog inputs on 1-8
- S/PDIF inputs on 9-10
- CueMix Mix1 return on 11-12

MIDI, additional sample rates, and other MOTU models are outside the current
scope.

## Local packaging

After building, a user can create a package containing their own local build:

```bash
./motu_tahoe_driver/package_installer.sh
```

Generated applications, build directories, and ZIP archives are ignored by
Git and must not be committed to this repository.

## No warranty or responsibility

This experimental software is provided **AS IS** without warranties. Rafal
Zalech and the contributors accept no responsibility or liability for damage,
data loss, system instability, security problems, incompatibility, or other
consequences. Building, signing, installing, and using the driver is entirely
at the user's own risk. The procedure requires disabling SIP while the locally
signed DriverKit extension is used.

See [LICENSE](../LICENSE), [NOTICE](../NOTICE), and
[THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
