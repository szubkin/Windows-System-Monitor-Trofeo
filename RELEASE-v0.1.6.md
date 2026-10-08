# v0.1.6 — single-page settings and automatic update shutdown

Settings have no tabs: connection/general settings and screen appearance share one scrollable page. The preview is at the top and preserves 1920:462 proportions. It fills available width when space permits and adapts on smaller windows. Connection state, uptime, FPS, frames, reconnects, last error and last frame time are below settings, above the action buttons. Window resizing and working-area fit keep the bottom actions accessible.
Draft preview remains isolated from USB. Only Apply updates saved configuration and restarts the monitor.

Interactive installation requests monitor stop, waits up to 45 seconds for its process to finish the USB operation, then closes tray/launcher hosts belonging to the exact installation path and current Windows session before changing files. New trays support an exit event; old versions are closed after the monitor has stopped. Other PowerShell hosts are not targeted. If monitor shutdown times out, files are not changed. The installer still offers launch after success.

Validated: 100%/150% settings layout checks, preview aspect and status placement, live draft/Apply/Close/worker lifecycle, packaged tray SelfTest, isolated installation. Installer shutdown test used a mock monitor, legacy tray and unrelated PowerShell host with private test events; no real USB or running Trofeo process was touched. Physical update/exit verification remains pending.
