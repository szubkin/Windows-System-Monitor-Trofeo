# v0.1.2 — installer and settings fixes

Successful interactive installation offers to start Trofeo immediately through the existing hidden launcher, then closes. Test installation never launches the monitor.
Appearance labels now occupy only the left column, fixing their overlap with dropdowns and the color button at increased Windows scale.
Apply saves settings and notifies the tray to restart the running monitor while the dialog remains open. The tray timer keeps running during the modal settings window. Repeated Apply tracks the last applied autostart value. Close is separate and discards changes not yet applied.

Validated: isolated settings tests at 100% and simulated 150% scale, no overlapping input labels, repeated Apply notifications and persistence, Close; self-contained build, isolated setup, packaged runtime and tray SelfTest. Physical post-install launch and screen verification remain for the user.
