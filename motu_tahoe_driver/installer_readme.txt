MOTU UltraLite FireWire driver for macOS Tahoe
================================================

This package contains ASFW.app built and ad-hoc signed by the person who ran
package_installer.sh. The repository does not distribute a prebuilt driver.

The experimental driver supports the original FireWire-only MOTU UltraLite
(Unit_Sw_Version 0x00000d) at 48 kHz. MIDI and other sample rates are not yet
implemented.

Prerequisite
------------

SIP must be disabled from macOS Recovery while using this locally signed
DriverKit build. The installer enables Driver Extension developer mode.

Install
-------

1. Run "Install My MOTU UltraLite Build.command" from Terminal.
2. Enter the administrator password when asked.
3. In ASFW, press Install.
4. Approve ASFW under System Settings > General > Login Items & Extensions >
   Driver Extensions if macOS asks.
5. Restart, turn on the UltraLite, and run "Verify MOTU UltraLite.command".

The driver installs as /Applications/ASFW.app. An existing copy is backed up
under /Library/Application Support/ASFW UltraLite/Backups.

Channel order
-------------

  Outputs 1-2    Main Out 1-2
  Outputs 3-10   Analog outputs 1-8
  Outputs 11-12  S/PDIF
  Outputs 13-14  Phones

  Inputs 1-8     Analog inputs 1-8
  Inputs 9-10    S/PDIF
  Inputs 11-12   CueMix Mix1 return

License and responsibility
--------------------------

The source is based on the Apache-2.0 ASFireWire project. See the included
LICENSE and NOTICE files. This experimental software is provided "AS IS",
without warranties or responsibility for damage, data loss, incompatibility,
or other consequences. Each user builds, signs, installs, and uses it at their
own risk.
