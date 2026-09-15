# Third-party notices

## ASFireWire

The custom DriverKit driver is based on
[ASFireWire](https://github.com/mrmidi/ASFireWire), licensed under Apache
License 2.0. The upstream copyright, license, and NOTICE attribution are
preserved in this repository and in packages users create from their own local
builds. Files changed for original MOTU UltraLite support carry modification
notices, and the exact patch is provided under `motu_tahoe_driver/patches`.

Linux FireWire audio sources, Apple's legacy FireWire interfaces, libffado, and
snd-firewire-ctl-services were used strictly as behavioral references as stated
in [NOTICE](NOTICE). No implementation code from those GPL- or APSL-licensed
projects is included in the custom changes.

## MOTU legacy software archive

The applications, kernel extension, support files, and related resources under
`motu_ultralite_firewire_bundle` are third-party software published by Mark of
the Unicorn, Inc. They are not licensed by this repository's Apache License 2.0
and no ownership or trademark rights in them are claimed here. Distribution and
use of those files remain subject to the applicable MOTU terms.

The Tahoe DriverKit installer under `motu_tahoe_driver` does not install or
depend on the archived MOTU applications or kernel extension.
