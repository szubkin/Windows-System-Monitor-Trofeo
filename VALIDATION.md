# Validation v0.0.3 — 2026-09-28

## Verified without hardware

Release build: no errors or warnings. 40 checks passed: handshake corruption/truncation; LY chunk boundary cases; zero/maximum/oversized frames; exact-boundary terminal chunk; baseline JPEG geometry and 4:2:0; byte-exact reconstruction from 2048/4096 USB writes; one ACK only after all writes; no retry/read after a failed write; malformed ACK rejection; cancellation cannot truncate an in-flight frame; changing demo images; mutex duplicate-owner rejection and release.

CLI rejects invalid FPS, duration, mutually exclusive modes and display-only options on preview. Preview mode runs without accessing USB. Dynamic PNG preview inspected visually; clock/counter/marker fit the canvas.

## Hardware evidence

Installed v0.0.2 user-run short test (18:41:39): 63 completed frames in 10 seconds, normal exit. This confirms short sessions can succeed after restarting the display.

Unchanged v0.0.2 baseline run (18:46:18): planned 180 seconds, failed after 13.49 seconds with Win32 31. User states they did not restart/disconnect the device or launch TRCC during the previous long run. The failure is not tied to precisely 60 seconds. Evidence: artifacts/qa/baseline-180s.txt.

v0.0.3 dynamic run (18:52:07), after user-confirmed display restart: 321 frames completed in 55.99 seconds, ~5.74 FPS. Frame 322 failed at OUT block 16/25 with 2048/4096 bytes transferred, Win32 error 31. JPEG was 98677 bytes. Summary and failed JPEG/wire frame were saved. Evidence: artifacts/qa/demo-180s.txt and logs/v0.0.3-demo/trofeo-20260928-185207-724-12096-summary.json.

WinUSB power policy read at open: AUTO_SUSPEND=0, SUSPEND_DELAY_MS=0. No power policies were changed. System/DriverFrameworks queries returned no matching events; that is not proof of absence of a USB fault.

The 2048-byte / 1 ms pacing option is an experimental transport variation motivated by the partial 4096-byte write. It preserves every LY frame byte; it does not change command headers or the ACK sequence. The subsequent successful controlled run is recorded below. Root cause and hours-long stability remain unresolved.

## Boundaries

No driver, registry, brightness or firmware modifications. Installed C:\Windows System Monitor Trofeo sources remain v0.0.2 until the user runs Install-v0.0.3.ps1. The new build is staged in the workspace. Earlier version output folders are retained.

Installer v0.0.3 validated against a disposable copy of the installed v0.0.2 project: backup and hash verification passed, older DLL unchanged, installed preview passed, repeat installation refused. The conservative hardware test was subsequently run; see results below.


## Controlled paced run — 23:42:07
User confirmed display restart and TRCC closed before test. With --demo --hold-seconds 180 --fps 4 --usb-block-size 2048 --block-delay-ms 1: outcome completed, 227 frames, 180.1995 seconds, 1.2597 FPS, 23244800 wire bytes, no USB errors, process exit 0. Max USB time 835.98 ms; max render time 51.59 ms. User confirmed clock, counter and marker update correctly. Evidence: logs/v0.0.3-paced/trofeo-20260928-234207-283-4608-summary.json and artifacts/qa/paced-180s.txt.
The paced values are now the v0.0.3 defaults. Actual pacing is slower than the requested 4 FPS due to Windows sleep granularity. This establishes a successful three-minute operating configuration; it does not isolate the cause or establish hours-long stability. Prior pending-status statements above describe earlier checkpoints.


Final published build was reopened without restarting the device, using only --demo --hold-seconds 10 (new defaults): 13 frames, 10.276 seconds, 1.265 FPS, exit 0, no USB errors. Evidence: logs/v0.0.3-default-reopen/trofeo-20260928-234556-002-17336-summary.json. Final Release rebuild passed all 40 checks with no warnings/errors.


## v0.0.4 — 2026-09-29

Added live CPU, RAM, aggregate network rates and Windows drive capacity dashboard. Build: zero warnings/errors; 48 automated checks passed, including counter reset handling, CPU idle accounting, network rate intervals, dashboard dimensions/payload cap and unavailable rendering. Live monitor-preview read real machine data successfully; upright PNG visually inspected. Installer exercised against a workspace copy with source hashes verified against installed v0.0.3. No driver changes.

User's repeat v0.0.3 fast test on the new port completed 1031 frames / 180.03 seconds / 5.73 FPS without USB errors or long logging gaps. Prior port failure cause remains unproven.
`nLive v0.0.4 USB monitor smoke test: 87 completed frames / 15.07 seconds / 5.80 FPS, outcome completed, no USB errors; 4096-byte blocks, no delay, target 6 FPS. Log: artifacts/v0.0.4/logs/trofeo-20260929-000502-661-16308.log. Physical appearance still requires user confirmation.

User-installed v0.0.4 live monitor test (2026-09-29): 1031 frames / 180.08 seconds / 5.73 FPS, completed without reported USB errors or long log gaps. USB transfers typically 5.5–6.1 ms. User reports the display appears correct. Evidence: trofeo-20260929-000624-322-17872-summary.json and supplied console log. This validates the three-minute run on the new port, not indefinite stability or independent sensor accuracy.

## v0.0.5 — 2026-09-29

Added background NVIDIA NVML telemetry and optional LibreHardwareMonitor CPU temperature integration. Build: zero warnings/errors; 54 checks passed, including CPU sensor priority, distance-to-TjMax exclusion, invalid/stale data and six-card dashboard payload. Preview visually inspected at 1920x462.

Hardware preview: RTX 2080 SUPER, 21% load, 36 C, 1066/8192 MiB VRAM. CPU temperature unavailable; PawnIO is not installed/detected. Actual CPU temperature acquisition remains unverified, not represented as a successful test. The final code reports this prerequisite explicitly.

USB monitor test: 116 frames / 20.05 seconds / 5.80 FPS, completed without USB errors; 4096-byte blocks, no delay, target 6 FPS. GPU data changed during the session. Log: artifacts/v0.0.5/logs/trofeo-20260929-001807-516-9196.log. Physical appearance awaits user confirmation. Subsequent change only added explicit PawnIO prerequisite detection; all 54 checks rerun successfully.

Sources: NVIDIA NVML API https://docs.nvidia.com/deploy/nvml-api/nvml-api-reference.html ; LibreHardwareMonitor source pinned to NuGet's repository commit 3d331e3370efb858411f19511373eff65a218701, including PawnIo/PawnIo.cs and Hardware/Cpu/IntelCpu.cs.

Final packaging check: installer exercised in separate workspace copy, then full offline build/tests/publish repeated there. Explicit win-x64 target avoids long-path copies of unrelated platform assets; BlackSharp.Core pinned to supplied 1.0.7 to make offline restore deterministic. Final preview confirms NVIDIA values and reports missing PawnIO. CPU temperature still unverified.

## v0.0.6 — CPU initialization packaging fix

User v0.0.5 test: 1037 frames / 180.05 seconds / 5.76 FPS without USB failures, but CPU initialization consistently failed with null identity; GPU telemetry available. Cause isolated to System.Threading.AccessControl.dll: previous publication retained 33072-byte platform stub; fresh Windows x64 publication uses 41224-byte Windows implementation. In a disposable copy, replacing the Windows DLL with the old DLL makes --check-runtime fail (PlatformNotSupportedException); restoring it passes. Fresh sensor preview no longer reports the identity initialization failure.

Build now publishes to a fresh unique directory and checks the published mutex ACL runtime both there and in the final release. 54 existing automated checks pass. Read-only preview: PawnIO=2.2.0.0, elevated=False; CPU still unavailable in this restricted process, GPU available. Requires user elevated preview to verify actual CPU temperature; no claim that CPU temperature is already fixed end-to-end. WinUSB and Windows System Monitor 0.2 unchanged.

## v0.0.7 — daily launcher and long-run test preparation

Added --continuous, compact logs (minute progress; --verbose restores detailed diagnostics), current progress JSON and final frame-gap/sensor-availability metrics. QuickEdit disabled only for the active console session. Settings-based Monitor and Stability shortcuts request elevation interactively; no scheduled task/autostart or power configuration changes. Installer checked in a separate workspace copy; shortcut target and arguments verified. Six launcher verdict checks passed in both PowerShell 7 and Windows PowerShell 5.1 (with explicit process-local ExecutionPolicy Bypass). 59 C# checks and published Windows ACL runtime checks passed.

Finite smoke: 47 frames / 8.02s / 5.87 FPS, completed. Continuous hardware run: 412 frames / 71.54s / 5.76 FPS, then Ctrl+C; summary outcome cancelled and no >2s frame gaps. This test deliberately omitted CPU sensors because agent execution is non-elevated. It verifies indefinite-mode behavior beyond the former default 60 seconds and graceful Ctrl+C reporting, not 30-minute stability.

The requested 30-minute run with CPU/GPU temperatures is PREPARED BUT NOT YET CONFIRMED. User must install v0.0.7 and open Trofeo Stability Test.lnk, approve the UAC prompt and leave the PC awake/TRCC closed. Result is in logs/daily-*/stability-result.txt with detailed summary JSON. PASS requires completed duration, >=80% target FPS, no gaps >2 seconds and sensor availability after warmup; cancellation cannot pass.

Prior user v0.0.6 evidence: elevated PawnIO 2.2.0 read CPU Package 44 C; subsequent 180.04s run completed 1036 frames / 5.75 FPS with CPU 47 C and GPU 35 C in the final sensor sample, no reported USB errors.

User v0.0.7 elevated Stability launcher run, 2026-09-29 11:06–11:36: completed 10378 frames / 1800.03 seconds / 5.77 FPS; verdict PASS, exit code 0, no frame gaps >2 seconds, enabled CPU/GPU temperatures met availability criteria. Evidence: C:\Windows System Monitor Trofeo\logs\daily-20260929-110642-510-17480\trofeo-20260929-110642-589-460-summary.json and user console log. The requested 30-minute stability run is now confirmed on the current USB connection. Sleep/reconnect recovery and longer unattended runs remain untested.

## v0.0.8 — dashboard and extra sensors

Five-card layout with real 60-second CPU/GPU/network history, memory/disk bars, CPU average core clock, system-volume disk I/O and SMART temperature when the Windows drive maps unambiguously to a non-dynamic disk. Technical footer removed. Compact image-mode logs now retain errors/final summary only; minute progress JSON remains.

Build: zero warnings/errors; 63 C# tests + 6 launcher-result checks passed. Added history window/eviction, new-sensor staleness and full-graph JPEG payload tests. Synthetic graph preview visually inspected (test values only). Actual non-elevated preview read GPU, CPU load, RAM, network and disk I/O; CPU clock/temperature and SMART temperature unavailable in this restricted process and await elevated user verification. Existing CPU Package access was already confirmed in v0.0.7; additional sensors are not yet claimed verified.

Installer tested on isolated copy of installed v0.0.7; settings hash unchanged, shortcuts created, published ACL check and monitor preview passed from installed copy. A Trofeo process (PID 9280) was already running, so it was not interrupted and no competing USB session was started. New layout/extra-sensor USB smoke and long stability test remain pending user run. v0.0.7's prior 30-minute PASS does not establish v0.0.8 stability.

## v0.0.9 — equal-width dashboard cards

All five cards are 358 pixels wide, with 16-pixel gaps and symmetric 33-pixel outer margins. Contents and graphs repositioned to fit. Build completed with zero warnings/errors; 63 C# checks passed. Synthetic preview visually inspected. Physical display confirmation remains pending user installation.


## v0.0.10 — reconnect and startup
Automated checks cover missing device then transient failure then success, bounded retry delays, terminal driver/access failures, no retries in stability mode and cancellation while waiting. Scheduled-task registration script parsed but task not registered in this restricted workspace. USB disconnect/sleep/logon tests require user installation and remain unverified. Recovery retains a single sampler across attempts, disposes each USB session, pins the first device instance and uses a lifetime supervisor mutex to reject duplicate recovery loops.

## v0.0.11 — device labels and version
CPU registry name below CPU; GPU name below GPU; assembly version at bottom right. Labels shrink to 13px then ellipsize within their own 358px column. Preview visually inspected. Build and existing 68 checks passed; physical display awaits installation. Installer preserves the hidden Monitor shortcut when present.

## v0.0.12 — observed USB error 22
Installed v0.0.11 log daily-20261006-102728-103-17468 recorded OUT error 22 at 12:07:47 and exited. Cause not established by user. Added this native error to reconnect policy. New session daily-20261006-120838-149-4628 reported 156205 frames in 26982 seconds with no >2s gaps and no CPU/GPU temperature dropouts; this is ongoing-run evidence, not completed recovery verification. Physical USB/sleep checks pending.

## v0.0.12 recovery confirmation
User confirmed USB disconnect/reconnect resumed clock automatically; subsequently confirmed sleep for 60 seconds and wake resumed clock automatically. Both physical scenarios confirmed by user.
## v0.0.13 tray
Windows PowerShell 5.1 constructs NotifyIcon/menu and checks duplicate start suppression, pending child suppression, restart and stop with fake processes; no USB/task mutation in these checks. Real tray interaction awaits installed user run.

## v0.0.14 icons and live tray state
Application ICO embeds approved opaque-center artwork. Four code-drawn tray icons follow the approved pulse concept, sized 16/20/24/32/48/64/128/256. Status JSON is updated atomically after acknowledged frames (at most once per second), on waiting and terminal outcomes. Tray checks PID and a 5-second running freshness limit. Eight state checks cover active, stale, wrong PID, waiting, stopped, failure and relaunch; tray smoke checks load real icons. Physical color transition checks await installation.

v0.0.14 launcher hotfix: missing PSScriptRoot in status-file Join-Path caused a hidden interactive prompt before executable launch. Corrected path and added NonInteractive to tray child launch. Status path expression and installed-copy tray self-test passed. Repair closes only matching installation launcher/tray PowerShell processes when no monitor is active.

## v0.0.15 settings and retention
Added tray Settings dialog, FPS/rotation/network interface/disk/CPU sensors/autostart, persisted with validation, atomic replace and backup. Disk selection flows to capacity, SMART association and disk I/O. Existing settings gain defaults without being overwritten by installer. Seven Windows PowerShell 5.1 settings/retention checks passed outside the sandbox (File.Replace is denied by sandbox); tests use isolated generated data. UI rendered and Apply saved FPS in an isolated copy without changing real settings/autostart. Retention runs at launch/hourly, deletes only recognized generated session files under direct daily folders, skips links and active/newest sessions; configured size is a soft cap for old logs. Disk/network check uses no hardware sensors or USB. Physical use of the new settings remains pending installation.

## v0.0.16 temperature colors
CPU/GPU temperature text now uses independently configurable yellow/red thresholds. Defaults CPU 75/90 and GPU 70/85 C are display preferences, not hardware maximum ratings. Inclusive boundaries; missing/non-finite data is muted. 76 C# checks and settings round-trip/validation/UI Apply checks passed. Synthetic yellow CPU/red GPU preview and settings dialog visually inspected; no actual heating or USB test performed.

## v0.0.17 preview/status
Tests verify no JPEG without a preview request, first connection excluded from reconnect count, successful reconnect increment, last error retained and frame rotation retained after stop. Preview window rendered from an isolated fixture without touching USB. Timestamp display converted to local time. Hardware-integrated preview awaits user installation.

## v0.0.18 import/export/reset
Export/import round trip, partial/invalid and oversized JSON rejection passed. UI test verifies reset changes controls without writing the real configuration, then Apply persists edited values in an isolated copy. Settings window visually checked. Build passes with no warnings/errors.

## Unified setup for v0.0.18
Self-contained win-x64 payload includes .NET 8.0.31; native .NET Framework bootstrap with embedded ZIP. Clean install and repeat update in isolated workspace directory passed, custom FPS hash preserved, embedded-runtime check and shortcut passed. Setup window visually inspected. Driver changes are not performed; clean second-PC execution not yet tested. Setup size approximately 71 MiB. Files are backed up before replacement with rollback on failure.

## v0.0.19 dark UI
Settings form and Windows 10 style tray menu rendered and visually inspected under Windows PowerShell 5.1. Settings UI reset/Apply passed in an isolated copy without changing production settings or autostart. Six launcher and eight tray-state checks passed. Clean setup and repeat update preserved a custom settings hash; packaged theme and embedded .NET runtime verified. Setup success now closes the form (code change). The user reports the tray remains after sleep while the screen stops updating; this recovery issue has not been reproduced or fixed by this UI release. Live status at 09:01 on 8 October showed fresh running telemetry, 5.78 FPS and no recorded reconnect/error.

## v0.0.20 resume interface recovery
Observed installed logs on 8 October: at 09:51:46 OUT failed with native 1167; at 09:51:51 discovery found WINUSB with zero interface paths and exited with terminal code 5. Added narrow classification of WINUSB/zero paths as retryable code 9 only with recovery enabled. No interface is opened until exactly one path is present; discovery is repeated, handles are recreated and the driver is unchanged. Regression simulates two missing-interface attempts followed by a ready interface, verifies 5/10 second waits, strict non-recovery mode, wrong-driver and ambiguous-path failures. 84 C# checks, six launcher and eight tray-state checks passed. Physical sleep/wake verification pending installation of v0.0.20; v0.0.19 baseline retained.

## v0.1.0 main release promotion
On 8 October the user reported that the v0.0.20 sleep/wake test worked. Promoted the same behavior to v0.1.0 at the user's request. Updated executable, tray, launch paths and setup version identifiers. Sleep recovery is user-confirmed for v0.0.20; this release promotion does not change recovery logic. Earlier pending-verification entries describe the state at those earlier checkpoints.

Установщик 0.1.0: чистая установка и повторное обновление с сохранением настроек прошли; встроенная .NET, SelfTest трея, 6 проверок запуска и 8 проверок состояния прошли.

## v0.1.1 — screen settings (8 October 2026)

125 C# checks passed, including all 31 nonempty block combinations, missing telemetry, accent colors, hidden graphs, text bounds and invalid display options. Settings round trip/import/export and launch forwarding checks passed. The isolated settings UI test verifies both tabs, rejects zero visible blocks, restores defaults and saves custom appearance. The self-contained installer passed clean installation, packaged runtime and tray SelfTest, and reinstall preserved custom display settings. Screenshot QA completed for general/screen settings and five/two/single block dashboards. No physical USB transfer was performed for this update; user verification on Trofeo remains pending.

## v0.1.2 — settings and installation

Settings window tests passed at 100% and simulated 150% scale: appearance labels never intersect inputs, invalid selections are rejected, repeated Apply persists and invokes its callback without closing, and Close closes separately. Successful compilation and isolated installation with packaged runtime/tray SelfTest passed. Interactive post-install launch prompt is implemented through the existing hidden launcher; real launch verification is pending.

## v0.1.3 — visual alignment

125 program checks passed. Settings tests at 100% and simulated 150% verify a painted color swatch and equal footer button sizes/positions. Screenshot QA completed for load, temperature and CPU clock with secondary values sharing the baseline and card edges. Isolated installer, packaged runtime and tray SelfTest passed. Physical Trofeo verification pending.

## v0.1.4 — spacing

125 program checks passed; isolated settings UI test at simulated 150% passed. Screenshots reviewed: lower readings remain clear of charts and settings buttons visually form two groups. Self-contained installer built. Physical verification pending.

## v0.1.5 — integrated preview

129 C# checks passed, including draft rendering, immutable live status, missing/stale telemetry. The integrated settings test proves image changes while applied settings remain unchanged, Apply saves and notifies the tray while staying open, the renderer has a distinct process name, and closing the window stops it. The 150% UI test and packaged tray SelfTest passed. Mock telemetry was used; no USB monitor was started. Physical Apply verification remains pending.

## v0.1.6 — single-page layout and installer shutdown

100% and simulated 150% UI checks passed: no tabs, proportional top preview, status below settings, aligned footer, Apply and Close. Live preview lifecycle and packaged tray SelfTest passed. Mock installer shutdown waited for monitor safe-stop, terminated only its matching legacy tray and preserved an unrelated host. Mock signals have a separate namespace from TrofeoStop/TrofeoExit. Physical installer shutdown/update verification pending.

## v0.1.7 — memory and network labels

- 134 protocol, rendering, metadata and draft-preview checks passed. Identical modules deduplicate; unknown configured speeds remain unavailable; mixed modules retain their information; JSON telemetry preserves both labels.
- Settings window verified at 100% and 150% scale. Status height is 132 logical pixels, with no scrollbar and subdued foreground. Dashboard and settings screenshots inspected.
- Windows inventory on this PC reports four DDR3 modules configured at 1600. DDR speed is displayed in MT/s. No USB transfer used during validation.
- Self-contained installer tested in artifacts/setup-check-017; bundled .NET runtime check and live draft-preview/Apply/shutdown checks passed.
- Physical LCD confirmation after installation is pending. GitHub main/Latest stays unchanged.
