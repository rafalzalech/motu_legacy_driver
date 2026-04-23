# MOTU Ultralite FireWire Legacy Driver Bundle

This repository contains a portable copy of the MOTU components from a working
macOS installation for an old MOTU Ultralite FireWire interface.

Main bundle:
- [`motu_ultralite_firewire_bundle`](./motu_ultralite_firewire_bundle)

Inside the bundle:
- MOTU applications from `/Applications`
- MOTU support files from `/Library/Application Support/MOTU`
- MIDI device definitions from `/Library/Audio/MIDI Devices/MOTU`
- launch agents and daemons used by the installed stack
- legacy kernel extension `MOTUFireWireAudio.kext`

Install on another Mac:

```bash
cd motu_ultralite_firewire_bundle
bash ./install_motu_ultralite_firewire.sh
```

Notes:
- the bundle mirrors files from the working machine
- the installer uses `sudo` and copies files back to their original locations
- newer macOS versions may still require kext approval and a reboot
