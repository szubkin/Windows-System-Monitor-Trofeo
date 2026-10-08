using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using LibreHardwareMonitor.Hardware;

namespace WindowsSystemMonitorTrofeo.Monitoring;

public sealed record HardwareSnapshot(string GpuName, double? GpuLoad, double? GpuTemperature,
    double? VramUsedMiB, double? VramTotalMiB, double? CpuTemperature, string CpuSensor, string Status, double? CpuClockMHz = null, double? DiskTemperature = null, double? DiskReadBytes = null, double? DiskWriteBytes = null);

// One worker owns native sensor resources. Slow sensor calls never block USB keepalive.
public sealed class HardwareSampler : IDisposable
{
    private readonly CancellationTokenSource stop = new();
    private readonly Task worker;
    private sealed record Sample(HardwareSnapshot Data, long Tick);
    private Sample? latest;
    public HardwareSampler(bool cpuSensors, string? driveRoot = null) => worker = Task.Run(() => Run(cpuSensors, driveRoot ?? Path.GetPathRoot(Environment.SystemDirectory)!));
    public HardwareSnapshot Read()
    {
        var sample = Volatile.Read(ref latest);
        if (sample == null) return new("NVIDIA GPU", null, null, null, null, null, "", "Sensors warming up");
        return Fresh(sample.Data, Stopwatch.GetElapsedTime(sample.Tick).TotalSeconds);
    }
    public static HardwareSnapshot Fresh(HardwareSnapshot data, double age) => age <= 5 ? data :
        data with { GpuLoad = null, GpuTemperature = null, VramUsedMiB = null, VramTotalMiB = null,
            CpuTemperature = null, CpuClockMHz = null, DiskTemperature = null, DiskReadBytes = null, DiskWriteBytes = null, Status = "Sensor data stale (>5s)" };

    public static (double? value, string name) SelectCpu(IEnumerable<(string name, double? value)> sensors)
    {
        var valid = sensors.Where(s => s.value.HasValue && double.IsFinite(s.value.Value) && s.value >= -20 && s.value <= 130).ToArray();
        foreach (var name in new[] { "CPU Package", "Core (Tctl/Tdie)", "Core (Tdie)", "CPU (Tctl/Tdie)", "CPU Core Max", "Core Max" })
        {
            var selected = valid.Where(s => s.name.Equals(name, StringComparison.OrdinalIgnoreCase)).OrderByDescending(s => s.value).FirstOrDefault();
            if (selected.value.HasValue) return (selected.value, selected.name);
        }
        var core = valid.Where(s => s.name.StartsWith("CPU Core #", StringComparison.OrdinalIgnoreCase)
            && !s.name.Contains("Distance", StringComparison.OrdinalIgnoreCase)).OrderByDescending(s => s.value).FirstOrDefault();
        return core.value.HasValue ? (core.value, "Hottest core") : (null, "Unavailable");
    }

    private void Run(bool cpuSensors, string driveRoot)
    {
        Computer? computer = null;
        bool nvml = false;
        var diskRates = new DiskRates(driveRoot);
        string cpuStatus = cpuSensors ? "CPU temperature unavailable" : "CPU temperature disabled (--cpu-sensors)";
        try
        {
            try { nvml = Nvml.Init() == 0; } catch (Exception e) when (e is DllNotFoundException or EntryPointNotFoundException or BadImageFormatException) { }
            try
            {
                bool canReadCpu = cpuSensors && LibreHardwareMonitor.PawnIo.PawnIo.IsInstalled;
                if (cpuSensors && !canReadCpu) cpuStatus = "CPU temperature requires PawnIO driver";
                computer = new Computer { IsCpuEnabled = canReadCpu, IsStorageEnabled = true };
                computer.Open();
            }
            catch (Exception e) { cpuStatus = "Sensor init: " + e; }
            while (!stop.IsCancellationRequested)
            {
                string gpuName = "NVIDIA GPU";
                double? load = null, temperature = null, used = null, total = null, cpuTemp = null, cpuClock = null, diskTemp = null;
                string cpuSensor = cpuSensors ? (computer == null ? "PawnIO unavailable" : "Unavailable") : "Disabled";
                var status = new List<string>();
                try
                {
                    if (nvml && Nvml.Handle(0, out var device) == 0)
                    {
                        var name = new StringBuilder(96);
                        if (Nvml.Name(device, name, 96) == 0) gpuName = name.ToString();
                        if (Nvml.Utilization(device, out var utilization) == 0 && utilization.Gpu <= 100) load = utilization.Gpu;
                        if (Nvml.Temperature(device, 0, out var temp) == 0 && temp <= 130) temperature = temp;
                        if (Nvml.Memory(device, out var memory) == 0 && memory.Used <= memory.Total && memory.Total > 0)
                        { used = memory.Used / 1048576.0; total = memory.Total / 1048576.0; }
                        if (load == null || temperature == null || used == null) status.Add("Some GPU sensors unavailable");
                    }
                    else status.Add("NVIDIA NVML unavailable");
                }
                catch (Exception e) { status.Add("GPU: " + e.Message); }
                if (computer != null)
                {
                    try
                    {
                        var clocks = new List<double>();
                        var sensors = new List<(string, double?)>();
                        foreach (var hardware in computer.Hardware.Where(h => h.HardwareType == HardwareType.Cpu))
                        {
                            hardware.Update();
                            clocks.AddRange(hardware.Sensors.Where(s => s.SensorType == SensorType.Clock && s.Name.StartsWith("CPU Core", StringComparison.OrdinalIgnoreCase) && s.Value > 0 && s.Value < 10000).Select(s => (double)s.Value!.Value));
                            sensors.AddRange(hardware.Sensors.Where(s => s.SensorType == SensorType.Temperature)
                                .Select(s => (s.Name, (double?)s.Value)));
                        }
                        (cpuTemp, cpuSensor) = SelectCpu(sensors);
                        if (clocks.Count > 0) cpuClock = clocks.Average();
                    }
                    catch (Exception e) { cpuStatus = "CPU sensor read: " + e.Message; }
                }
                try
                {
                    string systemLetter = driveRoot.TrimEnd('\\', ':');
                    var disks = computer?.Hardware.OfType<LibreHardwareMonitor.Hardware.Storage.StorageDevice>()
                        .Where(d => !d.Storage.IsDynamicDisk && d.Storage.Partitions.Any(p => Convert.ToString(p.DriveLetter)?.TrimEnd('\\', ':').Equals(systemLetter, StringComparison.OrdinalIgnoreCase) == true)).ToArray();
                    if (disks?.Length == 1)
                    {
                        disks[0].Update();
                        var value = disks[0].Storage.Smart.Temperature;
                        if (value.HasValue && value.Value > 0 && value.Value < 130) diskTemp = value.Value;
                    }
                }
                catch (Exception e) { status.Add("Disk sensor: " + e.Message); }
                (double? read, double? write) diskIo = (null, null);
                try { diskIo = diskRates.Read(); } catch (Exception e) { status.Add("Disk I/O: " + e.Message); }
                if (!cpuTemp.HasValue) status.Add(cpuStatus);
                Volatile.Write(ref latest, new Sample(new(gpuName, load, temperature, used, total, cpuTemp, cpuSensor, string.Join("; ", status), cpuClock, diskTemp, diskIo.read, diskIo.write), Stopwatch.GetTimestamp()));
                if (stop.Token.WaitHandle.WaitOne(1000)) break;
            }
        }
        finally
        {
            try { computer?.Close(); } catch { }
            if (nvml) { try { Nvml.Shutdown(); } catch { } }
        }
    }
    public void Dispose()
    {
        stop.Cancel();
        // Keep resources alive for the worker if a vendor call is hung; process exit ends it.
        if (worker.Wait(2000)) stop.Dispose();
    }

    private static class Nvml
    {
        [StructLayout(LayoutKind.Sequential)] public struct Util { public uint Gpu, Memory; }
        [StructLayout(LayoutKind.Sequential)] public struct Mem { public ulong Total, Free, Used; }
        [DllImport("nvml.dll", EntryPoint = "nvmlInit_v2", CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)] public static extern int Init();
        [DllImport("nvml.dll", EntryPoint = "nvmlShutdown", CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)] public static extern int Shutdown();
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetHandleByIndex_v2", CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)] public static extern int Handle(uint index, out IntPtr device);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetName", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)] public static extern int Name(IntPtr device, StringBuilder name, uint length);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetUtilizationRates", CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)] public static extern int Utilization(IntPtr device, out Util value);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetTemperature", CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)] public static extern int Temperature(IntPtr device, uint sensor, out uint value);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetMemoryInfo", CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)] public static extern int Memory(IntPtr device, out Mem value);
    }
}




