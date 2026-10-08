namespace WindowsSystemMonitorTrofeo.Rendering;
public sealed record TemperatureThresholds(int CpuYellow = 75, int CpuRed = 90, int GpuYellow = 70, int GpuRed = 85)
{
    public void Validate()
    {
        if (CpuYellow < 1 || CpuRed > 130 || CpuYellow >= CpuRed || GpuYellow < 1 || GpuRed > 130 || GpuYellow >= GpuRed)
            throw new ArgumentException("Temperature thresholds: 1 <= yellow < red <= 130.");
    }
    public static Color ColorFor(double? value, int yellow, int red, bool light = false) =>
        !value.HasValue || !double.IsFinite(value.Value) ? (light ? Color.FromArgb(78,99,117) : Color.FromArgb(145,164,182)) :
        value >= red ? (light ? Color.FromArgb(190,38,51) : Color.FromArgb(240,90,100)) :
        value >= yellow ? (light ? Color.FromArgb(155,96,0) : Color.FromArgb(245,197,66)) : (light ? Color.FromArgb(0,112,96) : Color.FromArgb(68,226,198));
}
