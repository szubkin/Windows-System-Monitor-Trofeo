# v0.1.0 — main release

Promoted on 8 October 2026 from v0.0.20 after the user confirmed automatic recovery following Windows sleep.

Includes the five equal-width CPU/GPU/MEMORY/NETWORK/DISK cards, graphs, hardware names, configurable temperature colors, dark settings, Windows 10 style tray menu, state icons, preview and connection status, optional logon startup, and a self-contained Windows x64 installer with .NET 8.

Recovery waits if Windows reports the WinUSB device before its USB interface is ready. It rediscovers the same device and opens a fresh connection without changing the driver. Wrong drivers and ambiguous interfaces remain errors. v0.1.0 preserves the verified v0.0.20 behavior; this promotion changes version identifiers and release documentation.

Install: exit Trofeo from the tray, run Trofeo-Setup-0.1.0.exe into the existing installation folder, then open Trofeo Monitor. Settings and logs are retained. CPU sensors require separately installed PawnIO and administrator access.

The v0.0.19 release remains available as a previous baseline. See VALIDATION.md for test history and the scope of hardware verification.
