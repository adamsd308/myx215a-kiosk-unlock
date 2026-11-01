# USB and mode troubleshooting

## The cable finding matters

The owner tried **three different micro-USB cables that failed to provide data** before finding a working one. A charging cable can make an accessible tablet look completely absent. Earlier attempts repeatedly misattributed this to mode or driver behavior.

Use micro-USB, a verified data-transfer cable, and a direct computer port where possible. The USB-C connector was not the successful data path in this session. If possible, prove the exact cable transfers files from another device on the same computer.

On Windows:

```powershell
pnputil /enum-devices /connected /bus USB
adb devices -l
```

No tablet USB entry means no interface is currently enumerated. A missing ADB driver is one possibility only after Windows actually sees an interface. Reconnect the cable, confirm the mode, and try a known data cable before changing drivers.

## Distinguish the modes

| State | What matters |
| --- | --- |
| Chinese factory diagnostics menu | Successful root ADB route, observed composite USB `0E8D:2006`. |
| Normal Android | Enable USB debugging; reconnect if needed. |
| Recovery with Apply update from ADB | Sideload is not a full shell. Not the successful method. |
| Fastboot | Does not itself provide an ADB shell. |
| Black-screen BROM, `0E8D:0003` | Earlier firmware-read path; not required for kiosk removal. |

The owner recalls reaching the factory menu by connecting the tablet to power, holding Power + both volume buttons for about 5–10 seconds, releasing Power only, and continuing to hold both volume buttons until the Chinese menu appears. **Then connect computer micro-USB.** The owner reports hearing the Windows USB connection sound at that point. See the [factory-menu instructions](../README.md#1-reach-the-chinese-factory-menu). Button timing remains approximate and needs repeat testing; the owner has clarified the USB connection order.

Earlier BROM access instead required holding all buttons while reconnecting and keeping them held through initial tool detection. **The visible Chinese menu is the factory-mode target; black-screen BROM is not required.** Android settings cannot verify the physical boot-button timing.

## Windows sees factory USB but ADB is empty

The tested factory composite has storage (`MI_00`), ADB (`MI_01`), and serial (`MI_02`) interfaces. Check the driver for the ADB interface specifically. Do not replace drivers on unrelated devices, the entire USB hub, or the mass-storage interface.

Start by running `adb devices -l`; do not install additional drivers if the tablet already appears as `device`. A Windows connection sound indicates a USB connection event, not that the correct ADB driver is installed. Platform-tools provides the ADB executable, while Windows uses a separate compatible USB driver; it might already be installed or bind automatically.

The test computer already had driver changes from earlier research, so a clean Windows driver installation has not been independently reproduced. Official platform-tools are linked in the [README](../README.md). Google USB driver information is [here](https://developer.android.com/studio/run/win-usb); arbitrary vendor IDs may need a correctly matched WinUSB binding. Do not assume installing the Google driver alone supports every MYX interface.

## Other ADB states

- `unauthorized`: unlock the screen and accept the computer's debugging authorization prompt.
- `offline`: reconnect and allow the device to finish booting.
- `sideload`: return to the right mode; this is not factory root ADB.
- `adb root` refuses: stop. This build has not met the prerequisites for these scripts.
- `system_server` is present: do not edit the offline XML files; return to factory mode.

Do not select Clear eMMC, factory reset, or flash another MT8176 tablet's ROM as a USB troubleshooting step.
