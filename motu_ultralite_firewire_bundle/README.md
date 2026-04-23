# MOTU Ultralite FireWire Bundle

This bundle mirrors the MOTU components currently present on this Mac for the
working Ultralite FireWire setup.

Main driver:
- `/Library/Extensions/MOTUFireWireAudio.kext`
- Bundle id: `com.motu.driver.FireWireAudio`
- Version: `1.6 88494`

Contents:
- MOTU apps in `/Applications`
- MOTU support files in `/Library/Application Support/MOTU`
- MIDI device definition in `/Library/Audio/MIDI Devices/MOTU`
- Launch agents and launch daemon used by the installed MOTU stack
- The legacy FireWire kernel extension in `/Library/Extensions`

Install on another Mac:

```bash
cd /path/to/motu_ultralite_firewire_bundle
bash ./install_motu_ultralite_firewire.sh
```

Notes:
- The script re-execs with `sudo` if needed.
- On newer macOS releases, third-party kext approval and a reboot may still be
  required after copying.
- This bundle does not include per-user MOTU preferences from `~/Library`.
