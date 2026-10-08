# v0.0.19 — main baseline

Selected as the main version on 8 October 2026.

Includes direct WinUSB system monitoring, equal-width CPU/GPU/MEMORY/NETWORK/DISK cards, temperature colors, hardware names, graphs, tray status icons, settings, preview and connection status, optional logon startup, and a self-contained Windows x64 installer.

This release adds dark settings and a rectangular Windows 10 style tray menu. Successful setup closes its window. Existing Microsoft WinUSB is retained and Windows System Monitor 0.2 is not modified.

Validation: settings/menu visually checked; settings reset and Apply tested in an isolated copy; launcher and tray-state checks passed; clean install and update preserved custom settings; embedded runtime verified. See VALIDATION.md for hardware test history.

Known issue: after sleep the tray may remain while the screen stops updating. Recovery remains under investigation. No new sleep recovery fix is included in this baseline.

Install: exit the previous tray controller, run Trofeo-Setup-0.0.19.exe into the existing installation folder, then open Trofeo Monitor. Settings are preserved. Windows 10/11 x64; .NET 8 is included. CPU temperature sensors require separately installed PawnIO and administrator access.
