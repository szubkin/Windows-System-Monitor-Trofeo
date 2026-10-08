using System.Diagnostics;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;

namespace WindowsSystemMonitorTrofeo.Monitoring;

public sealed record Snapshot(double? Cpu, double? MemoryPercent, double? UsedGiB, double? TotalGiB,
    double? ReceiveBytes, double? SendBytes, double? DiskUsedPercent, double? DiskFreeGiB, string DiskName, HardwareSnapshot? Hardware = null, HistoryPoint[]? History = null, string? MemoryName = null, string? NetworkName = null);

public sealed class SystemSampler : IDisposable
{
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetSystemTimes(out ulong idle, out ulong kernel, out ulong user);
    [StructLayout(LayoutKind.Sequential)]
    private struct MemoryStatus
    {
        public uint Length, Load;
        public ulong TotalPhysical, AvailablePhysical, TotalPageFile, AvailablePageFile, TotalVirtual, AvailableVirtual, Extended;
    }
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GlobalMemoryStatusEx(ref MemoryStatus status);
    private (ulong idle, ulong kernel, ulong user)? previousCpu;
    private Dictionary<string, (long rx, long tx)> previousNetwork = new();
    private readonly Stopwatch timer = Stopwatch.StartNew();
    private double previousTime = -1;
    private Snapshot? cached;
    private readonly ChartHistory history = new();
    private readonly HardwareSampler? hardware;
    private readonly string? networkId;
    private readonly string driveRoot;
    public SystemSampler(bool enableHardware = false, bool cpuSensors = false, string? networkId = null, string? driveRoot = null)
    {
        this.networkId = networkId;
        this.driveRoot = driveRoot ?? Path.GetPathRoot(Environment.SystemDirectory)!;
        if (enableHardware) hardware = new HardwareSampler(cpuSensors, this.driveRoot);
    }
    public void Dispose() => hardware?.Dispose();

    public static double? CpuPercent(ulong idle, ulong kernel, ulong user, ulong oldIdle, ulong oldKernel, ulong oldUser)
    {
        if (idle < oldIdle || kernel < oldKernel || user < oldUser) return null;
        double total = (double)(kernel - oldKernel) + (user - oldUser);
        double idleDelta = idle - oldIdle;
        return total <= 0 || idleDelta > total ? null : 100 * (total - idleDelta) / total;
    }
    public static double? Rate(long current, long previous, double seconds) =>
        seconds > 0 && current >= previous ? (current - previous) / seconds : null;

    public Snapshot Read()
    {
        double now = timer.Elapsed.TotalSeconds;
        if (cached != null && now - previousTime < 1) return cached;
        double? cpu = null;
        if (GetSystemTimes(out var idle, out var kernel, out var user))
        {
            if (previousCpu is { } old) cpu = CpuPercent(idle, kernel, user, old.idle, old.kernel, old.user);
            previousCpu = (idle, kernel, user);
        }
        else previousCpu = null;
        var memory = new MemoryStatus { Length = (uint)Marshal.SizeOf<MemoryStatus>() };
        bool memoryOk = GlobalMemoryStatusEx(ref memory) && memory.TotalPhysical > 0;
        double? rx = null, tx = null;
        string networkName = networkId == null ? "Все активные адаптеры" : "Адаптер недоступен";
        var current = new Dictionary<string, (long rx, long tx)>();
        try
        {
            foreach (var adapter in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (networkId != null && !adapter.Id.Equals(networkId, StringComparison.OrdinalIgnoreCase)) continue;
                if (networkId != null) networkName = adapter.Name;
                if (adapter.OperationalStatus != OperationalStatus.Up || adapter.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
                try
                {
                    var stats = adapter.GetIPStatistics();
                    current[adapter.Id] = (stats.BytesReceived, stats.BytesSent);
                    if (previousNetwork.TryGetValue(adapter.Id, out var old))
                    {
                        var receive = Rate(stats.BytesReceived, old.rx, now - previousTime);
                        var send = Rate(stats.BytesSent, old.tx, now - previousTime);
                        if (receive.HasValue && send.HasValue) { rx = (rx ?? 0) + receive; tx = (tx ?? 0) + send; }
                    }
                }
                catch (NetworkInformationException) { }
            }
        }
        catch (NetworkInformationException) { }
        previousNetwork = current;
        double? diskPercent = null, diskFree = null;
        string diskName = driveRoot;
        try
        {
            var disk = new DriveInfo(diskName);
            if (disk.IsReady && disk.TotalSize > 0)
            {
                diskPercent = 100.0 * (disk.TotalSize - disk.TotalFreeSpace) / disk.TotalSize;
                diskFree = disk.TotalFreeSpace / 1073741824.0;
            }
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
        previousTime = now;
        var currentSample = new Snapshot(cpu, memoryOk ? 100.0 * (memory.TotalPhysical - memory.AvailablePhysical) / memory.TotalPhysical : null,
            memoryOk ? (memory.TotalPhysical - memory.AvailablePhysical) / 1073741824.0 : null,
            memoryOk ? memory.TotalPhysical / 1073741824.0 : null, rx, tx, diskPercent, diskFree, diskName, hardware?.Read(), MemoryName: MachineIdentity.MemoryName, NetworkName: networkName);
        return cached = currentSample with { History = history.Add(now, currentSample) };
    }
}


