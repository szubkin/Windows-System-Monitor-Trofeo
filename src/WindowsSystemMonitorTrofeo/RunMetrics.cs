using WindowsSystemMonitorTrofeo.Monitoring;

namespace WindowsSystemMonitorTrofeo;

public sealed class RunMetrics
{
    private double? previousFrameMs;
    public double MaxFrameGapMs { get; private set; }
    public int GapsOver2Seconds { get; private set; }
    public int SensorChecks { get; private set; }
    public int MissingCpuTemperature { get; private set; }
    public int MissingGpuTemperature { get; private set; }
    public void Frame(double elapsedMs)
    {
        if (previousFrameMs.HasValue)
        {
            double gap = elapsedMs - previousFrameMs.Value;
            MaxFrameGapMs = Math.Max(MaxFrameGapMs, gap);
            if (gap > 2000) GapsOver2Seconds++;
        }
        previousFrameMs = elapsedMs;
    }
    public void Sensors(double elapsedSeconds, HardwareSnapshot? data)
    {
        if (elapsedSeconds < 10) return; // Allow native sensor initialization.
        SensorChecks++;
        if (data?.CpuTemperature == null) MissingCpuTemperature++;
        if (data?.GpuTemperature == null) MissingGpuTemperature++;
    }
    public static bool Finished(bool continuous, int seconds, double elapsed) => !continuous && (seconds == 0 || elapsed >= seconds);
}
