# v0.1.1 — screen settings

Settings → Screen adds visible CPU/GPU/MEMORY/NETWORK/DISK blocks, accent color, 90/100/110% text, primary CPU reading (load/temperature/clock), primary GPU reading (load/temperature/VRAM), graphs and device-name switches.
Visible blocks automatically share equal width; at least one is required. Unavailable sensors show a dash. Temperature warning colors remain independent of the accent. Charts continue to show load even when temperature or VRAM is the primary reading.
Old JSON settings retain the existing defaults; import/export/reset include screen options. Apply restarts a running monitor, and its acknowledged-frame preview uses the same renderer.
Install over the existing folder after exiting from the tray. The current main release v0.1.0 remains available.
