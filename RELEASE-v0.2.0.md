# Windows System Monitor Trofeo v0.2.0

- Dark and light LCD appearance; draft preview changes immediately, Apply updates the device.
- Compact, large-temperature and detailed-graph presets. Runtime settings remain unchanged when selecting a preset.
- Independently selected CPU/GPU bottom-left and bottom-right readings; automatic and hidden slots.
- CPU package/PPT power and an explicitly named CPU fan from supported hardware; NVIDIA GPU power and fan speed. RPM and percentage are labeled separately; absent sensors show —.
- Diagnostics button saves and opens a compact report with version, read-only USB discovery, connection state, counters and last recorded error.
- Manual GitHub update check reports newer stable releases and offers their release page.
- New settings and tools are translated into Russian and English. Old configuration files acquire defaults; installer preserves saved settings.

The monitor's Microsoft WinUSB driver and existing USB recovery behavior remain unchanged. Additional sensor availability depends on hardware and driver support. No driver is installed or changed.

Install: artifacts/Trofeo-Setup-0.2.0.exe. This development build has offline rendering, UI and package validation; a physical display check of new features is still required.

Sensor units: [NVIDIA NVML device queries](https://docs.nvidia.com/deploy/nvml-api/latest/api/group__nvmlDeviceQueries.html).
