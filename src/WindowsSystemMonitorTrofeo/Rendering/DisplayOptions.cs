using System.Drawing;
using System.Text.RegularExpressions;

namespace WindowsSystemMonitorTrofeo.Rendering;

public sealed record DisplayOptions(string Blocks = "CPU,GPU,MEMORY,NETWORK,DISK", string Accent = "#44E2C6",
    int TextPercent = 100, string CpuMetric = "load", string GpuMetric = "load", bool Graphs = true, bool DeviceNames = true)
{
    public static readonly string[] AvailableBlocks = ["CPU", "GPU", "MEMORY", "NETWORK", "DISK"];
    public string[] VisibleBlocks => Blocks.Split(',');
    public Color AccentColor => ColorTranslator.FromHtml(Accent);
    public void Validate()
    {
        var blocks = VisibleBlocks;
        if (blocks.Length == 0 || blocks.Distinct().Count() != blocks.Length ||
            blocks.Any(b => !AvailableBlocks.Contains(b))) throw new ArgumentException("Choose at least one unique display block.");
        if (!Regex.IsMatch(Accent, "^#[0-9A-Fa-f]{6}$") || TextPercent is < 90 or > 110)
            throw new ArgumentException("Display color must be #RRGGBB; text range 90..110.");
        if (CpuMetric is not ("load" or "temperature" or "clock") || GpuMetric is not ("load" or "temperature" or "vram"))
            throw new ArgumentException("Unsupported CPU/GPU display metric.");
    }
}
