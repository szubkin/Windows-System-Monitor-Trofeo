# v0.1.5 — integrated settings preview and connection status

The tray opens one Settings and Preview window. Settings stay in the left pane; draft rendering and all connection information (state, uptime, FPS, frame count, reconnects, last error and frame time) appear on the right.
Appearance edits update the preview immediately using the monitor's current readings. Apply is the only action that saves configuration and requests the running monitor restart; Close discards unapplied edits.
The renderer is a distinct TrofeoPreviewRenderer process without USB discovery or sensor ownership. It uses recently acknowledged snapshot data published only while preview is requested. Missing/stale telemetry shows dashes; the layout remains usable offline. On closing the window, the worker exits. The monitor's rotation is applied to USB, while preview remains upright.
Existing settings and USB recovery behavior remain intact. Exit from the tray before running Trofeo-Setup-0.1.5.exe into the existing installation directory.
Validation: 129 C# checks, integrated UI/worker lifecycle test proving draft image changes without updating applied configuration, repeated Apply/Close checks, simulated 150% UI check, isolated installation and packaged tray SelfTest. Physical monitor Apply verification remains pending.
