# LY frame protocol used by v0.0.2

This implementation targets only VID 0416 / PID 5408 and the 1920x462 profile (PM 65/66). It is independently written C# using the published wire format. No upstream source is bundled.

The transport uses the actual verified WinUSB bulk endpoints 0x09 OUT / 0x81 IN. It sends the v0.0.1 device-info query before any image. PM is 64 + response[20], with raw values <=3 clamped to 1; SUB is response[22]+1. For this panel family the default JPEG rotation is 0 at SUB 2/3/4 and 180 otherwise. `--rotation` overrides image rotation only.

JPEG: baseline, 8-bit, 3 components, 4:2:0, 1920x462, quality 90. GDI+ encoder parameters and output are checked in the tests. Maximum payload is 449999 bytes. The PNG preview remains upright; the wire JPEG includes the rotation.

Frame packetization:

| Offset | Value |
|---|---|
| 0, 1 | 01 FF |
| 2..5 | JPEG byte length, uint32 LE |
| 6..7 | This chunk payload length, uint16 LE |
| 8 | 01 (LY) |
| 9..10 | Chunk count, uint16 LE, excluding alignment blocks |
| 11..12 | Zero-based chunk index, uint16 LE |
| 13..15 | zero |
| 16..511 | up to 496 JPEG bytes, then zero padding |

Number of data chunks = floor(JPEG bytes / 496) + 1. An exact multiple gets an empty terminal chunk. The complete buffer is zero padded to a multiple of four 512-byte blocks. USB writes contain 4096 bytes, with a possible final 2048-byte write. There is a single 512-byte reply read after each whole frame; no per-packet ACK, alternate framing experiments, error retry, brightness, reset or firmware commands. A bounded display session repeats the same prepared image about every 156 ms to keep it visible; this is not an error retry.

An exact 512-byte reply beginning 03 FF is logged as transfer completion. Its status fields are not yet decoded: this does not prove that firmware rendered the image. Physical-screen confirmation is required.

Sources checked 2026-09-28:

- [USBLCDNEW protocol, LY section](https://github.com/Lexonight1/thermalright-trcc-linux/blob/main/doc/PROTOCOL_USBLCDNEW.md)
- [Current LY implementation](https://github.com/Lexonight1/thermalright-trcc-linux/blob/main/src/trcc/adapters/device/ly_lcd.py) — terminal-chunk behavior, padding, PM/SUB, rotation and size cap.
- [Reported frame size limit](https://github.com/Lexonight1/thermalright-trcc-linux/issues/251)

Other summaries found during research contain conflicting chunk layouts (including EF/69 and 4080-byte payloads). Those are not implemented here. The chosen format agrees with the detailed LY protocol document and current upstream implementation, and has completed a transfer on this user's device.

Static-frame keepalive references: [LcdFusion Windows implementation](https://github.com/itsmylife44/LcdFusion/blob/main/LcdFusion/ThermalrightDirectService.cs) uses 150 ms between frames; [omarchy-trofeo](https://github.com/thedarkcr0w/omarchy-trofeo) documents blanking when idle. Both support the same 496-byte payload packetization. The first single-frame test on this device returned an ACK but the user saw the previous image.

The optional --reset-pipes recovery flag invokes [WinUsb_ResetPipe](https://learn.microsoft.com/en-us/windows/win32/api/winusb/nf-winusb-winusb_resetpipe) once on OUT/IN before handshake. It is a USB endpoint stall/data-toggle reset, not a device/driver reset. It did not recover the observed timeout after the extended display test.


## v0.0.3 diagnostics
The default LY framing is unchanged. --usb-block-size 2048 splits the same packed byte stream at 2048-byte boundaries instead of 4096; --block-delay-ms adds a pause between OUT writes. These controls are diagnostic and not a demonstrated protocol requirement. There is still only one ACK read after the complete frame. Dynamic frames use the same baseline JPEG format. Ctrl+C is observed between complete frames. WinUSB power policies are read via WinUsb_GetPowerPolicy; no power setting is written.


After hardware validation, v0.0.3 now defaults to 2048-byte USB writes and a requested 1 ms inter-write pause; the FPS cap defaults to 4. The logical 512-byte LY chunks and frame-level ACK are unchanged. Measured output was ~1.26 FPS on this machine, with 227 successful frames over 180 seconds. 4096-byte writes without pauses remain available only as explicit experimental overrides.

