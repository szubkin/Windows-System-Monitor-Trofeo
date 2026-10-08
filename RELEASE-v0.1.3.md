# v0.1.3 — visual alignment

Accent selection paints the actual color instead of displaying its hexadecimal string. Export, Import, Defaults, Apply and Close share a single row with equal button sizes and gaps.
CPU/GPU secondary readings share one text baseline and align to the left/right card padding for load, temperature, CPU clock and GPU VRAM modes. Secondary load readings omit the LOAD label. Temperature warning colors are preserved.

125 existing program checks passed. Settings UI checks passed at 100% and simulated 150% scale, including swatch pixels, button alignment, repeated Apply and Close. Screenshot inspection covered load/temperature/clock layouts. Self-contained installation, runtime and packaged tray SelfTest passed in an isolated directory. Physical screen verification remains pending.
