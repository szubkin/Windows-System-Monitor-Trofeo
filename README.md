# Windows System Monitor Trofeo 0.1.0

Windows x64 / .NET 8 live display monitor. Existing Microsoft WINUSB and Windows System Monitor 0.2 are unchanged.

## Install and launch

The main release is **v0.1.0**, promoted from the user-verified v0.0.20 recovery fix. v0.0.19 remains archived as a previous release. Close Trofeo through Exit in the tray, run `Trofeo-Setup-0.1.0.exe`, choose the existing installation folder, then open Trofeo Monitor. The self-contained Windows x64 installer includes .NET 8 and preserves existing settings. Historical PowerShell installers below are retained for reference.

- Trofeo Monitor.lnk: requests elevation, then runs in the tray without a console window.
- Trofeo Stability Test.lnk: requests elevation, then runs a 30-minute test and prints PASS or NOT CONFIRMED.

Close TRCC before launching. Use Stop or Exit in the tray to stop gracefully. When using the command-line stability test, Ctrl+C stops between complete frames; closing the console with X can prevent the final report. Autostart is optional. Power settings are unchanged.

Sleep recovery: v0.0.19 exited when PnP reported WINUSB with no interface path during resume. v0.1.0 retains the v0.0.20 fix: wait and rediscover the same device with the existing 5–30 second backoff, then open a new WinUSB session. Wrong drivers and multiple interface paths remain terminal; probe/stability modes remain strict. The user confirmed physical sleep/wake recovery with v0.0.20 on 8 October 2026. v0.1.0 changes the release number without changing that recovery behavior.

Settings are in trofeo-settings.json: FPS=6, USB block=4096, pause=0ms, CPU sensors enabled, test duration=1800 seconds. Change StabilitySeconds to 3600 for an hour. Existing settings are preserved by the installer.

## Stability evidence

A full test must complete the configured duration with exit 0, average FPS at least 80% of target, no gap over 2 seconds, enough sensor checks (at least 80% of duration), and no missing GPU temperature or enabled CPU temperature after a 10-second warmup. A cancelled test is not a pass. These criteria validate one run on this USB connection, not indefinite reliability or calibration of sensors.

Results: logs/daily-<timestamp>-<PID>/stability-result.txt and *-summary.json. During the run, *-progress.json is updated once per minute and marked running; it is removed on orderly completion. A leftover running report does not mean a finished test. Logs contain startup, errors and final summary. --verbose restores detailed dumps and five-second progress.

## Command-line modes

--monitor --continuous runs indefinitely. --monitor --hold-seconds 1800 runs a bounded test; do not combine --continuous with --hold-seconds. Zero seconds retains one-frame behavior. --monitor-preview --cpu-sensors checks sensor acquisition without USB. Other modes: --list, --probe, --preview, --test-pattern, --demo, --check-runtime. CLI defaults remain the slower 2048-byte/1ms profile; shortcuts use the verified new-port 4096-byte/0ms profile from settings.

CPU temperature requires installed PawnIO and administrator access. PawnIO 2.2.0 and CPU Package temperature were confirmed by the user's elevated v0.0.6 test. GPU telemetry uses the existing NVIDIA driver (RTX 2080 SUPER, index 0); unsupported values are shown as unavailable. Stale hardware data older than five seconds is cleared. RAM uses GiB; network uses MiB/s summed across active non-loopback interfaces (VPN adapters may double-count); disk shows system-drive capacity, not I/O speed.

## Build

Run build.ps1 with .NET 8 SDK. It runs 70 C# checks and 6 launcher-verdict checks, publishes in a fresh folder and validates the published Windows mutex ACL dependency. Original dependency packages are included for offline restore. See THIRD-PARTY-NOTICES.md. See VALIDATION.md for confirmed runs and remaining verification.

## v0.0.9 dashboard

Five equal-width cards (358 pixels each, 16-pixel gaps, 33-pixel outer margins): CPU, GPU, memory, network, system disk. CPU/GPU utilization graphs show the last 60 seconds with a fixed 0–100% scale. Network IN (turquoise) and OUT (blue) share an automatically scaled MiB/s axis. History starts empty, is bounded to 61 real samples, and draws gaps for missing data or interruptions longer than 2.5 seconds. New CPU frequency is the average reported clock of CPU cores, not effective frequency. Memory and disk bars represent used capacity.

System-disk temperature is read only when exactly one non-dynamic physical device maps to the Windows drive letter; unavailable or ambiguous data stays blank. Disk rates use Windows DISK_PERFORMANCE counters for the system volume and actual elapsed monotonic time, with a warmup sample and reset handling. All hardware reads run in the sensor worker, not the USB frame loop. Additional sensors remain subject to hardware/permissions support. The UI footer contains the GPU model; diagnostic details stay in logs.

Compact image-mode log now contains errors and final summary only. Minute progress remains available in progress JSON; --verbose restores all startup/USB/progress information. Diagnostic modes such as --monitor-preview still print their results.

Reference: LibreHardwareMonitor 0.9.6 StorageDevice source (exact package commit) maps Storage.Partitions to drive letters and exposes SMART temperature. https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/blob/3d331e3370efb858411f19511373eff65a218701/LibreHardwareMonitorLib/Hardware/Storage/StorageDevice.cs
Disk performance structure: https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ns-winioctl-disk_performance

## v0.0.10 — startup and connection recovery
Install with Install-v0.0.10.ps1, then from an administrator Windows PowerShell:
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Windows System Monitor Trofeo\Manage-Autostart.ps1" -Action Enable
This registers a highest-privilege interactive task for the current user, 20 seconds after sign-in, without storing a password. It does not start the monitor immediately. Close TRCC. The existing Monitor shortcut starts recovery mode now; the scheduled launch is hidden. No wake timer or sleep prevention is configured.
Use the same command with -Action Stop to request graceful stop of v0.0.10, -Action Disable to remove autostart, or -Action Status to inspect the task. Stop from an administrator console. Disable does not stop an already-running monitor.
Monitor now uses --continuous --recover. It waits when USB is absent, closes failed connections, rediscovers the same instance and handshakes before rendering a fresh frame. Delay increases from 5 to 30 seconds. Long pauses over 10 seconds reopen the connection. Access denied, another owner, unsupported driver/profile and unrelated failures remain terminal. A device that cannot resynchronize may still need a physical power cycle. Stability mode does not retry.
Validation on hardware: start Monitor, unplug USB for 15 seconds, reconnect and wait up to 45 seconds for clocks/graphs to move; repeat after Windows sleep/wake. Finally sign out/in to check the background task, then exercise Stop. Preserve logs from all attempts. Do not claim recovery success until these physical checks pass.

## v0.0.13 tray
Trofeo Monitor opens a hidden elevated tray controller and starts the monitor. Right-click for start/stop/restart, log folder, autostart and exit. Exit requests graceful monitor stop. A 45-second stop timeout cancels restart and reports an error. Status indicates process state, not verified USB delivery. An existing monitor is adopted without launching another. Windows may put the icon behind the tray arrow. Re-enable autostart with Manage-Autostart.ps1 -Action Enable to replace an older task action with the tray controller. UAC is needed at manual launch, not for each menu action.

## v0.0.14 icons
Application/shortcut icon and four tray states: turquoise for acknowledged frames, yellow for waiting/reconnecting or missing fresh telemetry, grey for stopped, red for terminal failure. logs/monitor-status.json is atomic telemetry for the current monitor process. The tray rejects another PID or running data older than 5 seconds. Exit the old tray before installing, then launch Trofeo Monitor. Existing scheduled task points at the same tray script and needs no re-registration.

## v0.0.15 settings
Right-click tray > Settings. Apply saves validated configuration and restarts a running monitor; a stopped monitor remains stopped. Options: FPS 1–10, automatic/0/180 rotation, all active network interfaces or one interface, system disk or a fixed drive, CPU sensors, logon startup. Missing selected adapters/drives show unavailable data rather than switching silently. Existing USB pacing and stability-test duration remain unchanged. Settings backup: trofeo-settings.json.bak.
Retention defaults to 30 days / 200 MiB; configurable 1–365 days and 20–2000 MiB. Runs at launch and hourly while the tray is active. Current and most recent sessions are preserved, so their size can exceed the limit. Only recognized session files in logs/daily-* are cleaned; old release artifacts, backups, root tray.log and other user files are untouched. Exit the old tray before installing v0.0.15.

## v0.0.16 temperature colors
Settings includes CPU yellow/red and GPU yellow/red temperatures. Defaults CPU 75/90 C, GPU 70/85 C; these are customizable display thresholds. Below yellow: turquoise; at/above yellow: yellow; at/above red: red. Missing values: grey. Values must satisfy 1 <= yellow < red <= 130. Apply restarts a running monitor. No fan control or shutdown action is added.

## v0.0.17 preview and status
Tray > Preview and status opens a resizable window showing the latest acknowledged frame, actual recent FPS, process uptime, frame count, successful reconnections after the first connection, and last error/time. The monitor exports JPEG at most once per second only while the preview window heartbeat is fresh (5 seconds). USB is owned by the original monitor only. A disconnected/stopped monitor retains its last frame with status/timestamp; it is not a live feed. Restart resets counters. Preview files and status are in logs.

## v0.0.18 settings backup
Settings: Export saves the current form values to a separate JSON file; Import validates a file (maximum 64 KB), then populates the form; Defaults populates standard values. Import/reset require Apply to save and restart. Cancel leaves the saved configuration unchanged. Windows scheduled-task autostart is separate and is neither exported nor changed by import/defaults. Existing settings backup is retained on Apply.

## v0.0.19 dark settings and tray menu
Settings uses a graphite background, light text and dark fields/buttons. The tray context menu uses rectangular Windows 10 style, grey selection, separators and a check mark for autostart. The controller uses Windows PowerShell 5.1, as invoked by the shortcut and scheduled task. Exit Trofeo from the tray before opening artifacts/Trofeo-Setup-0.0.19.exe; install into the existing folder, then open Trofeo Monitor. Settings are preserved. Setup closes its window after successful installation.
