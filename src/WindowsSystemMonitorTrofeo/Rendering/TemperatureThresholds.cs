namespace WindowsSystemMonitorTrofeo.Rendering;
public sealed record TemperatureThresholds(int CpuYellow = 75, int CpuRed = 90, int GpuYellow = 70, int GpuRed = 85)
{
    public void Validate()
    {
        if (CpuYellow < 1 || CpuRed > 130 || CpuYellow >= CpuRed || GpuYellow < 1 || GpuRed > 130 || GpuYellow >= GpuRed)
            throw new ArgumentException("Temperature thresholds: 1 <= yellow < red <= 130.");
    }
    public static Color ColorFor(double? value, int yellow, int red) =>
        !value.HasValue || !double.IsFinite(value.Value) ? Color.FromArgb(145,164,182) :
        value >= red ? Color.FromArgb(240,90,100) :
        value >= yellow ? Color.FromArgb(245,197,66) : Color.FromArgb(68,226,198);
}
