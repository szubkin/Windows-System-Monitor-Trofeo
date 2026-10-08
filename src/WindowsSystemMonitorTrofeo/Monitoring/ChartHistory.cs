namespace WindowsSystemMonitorTrofeo.Monitoring;

public sealed record HistoryPoint(double Seconds, double? Cpu, double? Gpu, double? Receive, double? Send);
public sealed class ChartHistory
{
    private readonly List<HistoryPoint> points = new();
    public HistoryPoint[] Add(double seconds, Snapshot snapshot)
    {
        if (points.Count > 0 && seconds <= points[^1].Seconds) throw new ArgumentException("History time must increase");
        points.RemoveAll(p => p.Seconds < seconds - 60);
        points.Add(new(seconds, snapshot.Cpu, snapshot.Hardware?.GpuLoad, snapshot.ReceiveBytes, snapshot.SendBytes));
        if (points.Count > 61) points.RemoveRange(0, points.Count - 61);
        return points.ToArray();
    }
}
