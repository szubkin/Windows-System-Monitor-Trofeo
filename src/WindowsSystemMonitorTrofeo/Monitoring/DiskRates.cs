using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace WindowsSystemMonitorTrofeo.Monitoring;

internal sealed class DiskRates(string driveRoot)
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool DeviceIoControl(SafeFileHandle handle, uint code, IntPtr input, uint inputSize, byte[] output, uint outputSize, out uint returned, IntPtr overlapped);
    private (long read, long write, long tick)? previous;
    public (double? read, double? write) Read()
    {
        using var handle = CreateFile(@"\\.\" + driveRoot.TrimEnd('\\'), 0, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        var buffer = new byte[88]; // DISK_PERFORMANCE: first two fields are 64-bit byte counters.
        if (handle.IsInvalid || !DeviceIoControl(handle, 0x70020, IntPtr.Zero, 0, buffer, 88, out var returned, IntPtr.Zero) || returned < 16)
        { previous = null; return (null, null); }
        long read = BitConverter.ToInt64(buffer, 0), write = BitConverter.ToInt64(buffer, 8), tick = Stopwatch.GetTimestamp();
        var old = previous;
        previous = (read, write, tick);
        if (old == null) return (null, null);
        double seconds = Stopwatch.GetElapsedTime(old.Value.tick, tick).TotalSeconds;
        return (SystemSampler.Rate(read, old.Value.read, seconds), SystemSampler.Rate(write, old.Value.write, seconds));
    }
}
