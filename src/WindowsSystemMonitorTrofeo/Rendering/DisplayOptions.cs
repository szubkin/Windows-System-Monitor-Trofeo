using System.Drawing;
using System.Text.RegularExpressions;

namespace WindowsSystemMonitorTrofeo.Rendering;

public sealed record DisplayOptions(string Blocks = "CPU,GPU,MEMORY,NETWORK,DISK", string Accent = "#44E2C6",
    int TextPercent = 100, string CpuMetric = "load", string GpuMetric = "load", bool Graphs = true, bool DeviceNames = true, string Language = "ru", string Theme = "dark",
    string CpuSecondaryLeft = "auto", string CpuSecondaryRight = "auto", string GpuSecondaryLeft = "auto", string GpuSecondaryRight = "auto")
{
    public static readonly string[] AvailableBlocks = ["CPU", "GPU", "MEMORY", "NETWORK", "DISK"];
    public static readonly string[] CpuMetrics = ["load","temperature","clock","power","fan"];
    public static readonly string[] GpuMetrics = ["load","temperature","vram","power","fan"];
    public string[] VisibleBlocks => Blocks.Split(',');
    public Color AccentColor => ColorTranslator.FromHtml(Accent);
    public void Validate()
    {
        if (Language is not ("ru" or "en")) throw new ArgumentException("Unsupported language. Choose ru or en.");
        if (Theme is not ("dark" or "light")) throw new ArgumentException("Unsupported screen theme.");
        if (!CpuMetrics.Contains(CpuMetric) || !GpuMetrics.Contains(GpuMetric) ||
            new[]{CpuSecondaryLeft,CpuSecondaryRight}.Any(m => m is not ("auto" or "none") && !CpuMetrics.Contains(m)) ||
            new[]{GpuSecondaryLeft,GpuSecondaryRight}.Any(m => m is not ("auto" or "none") && !GpuMetrics.Contains(m)))
            throw new ArgumentException("Unsupported display metric.");
        var blocks = VisibleBlocks;
        if (blocks.Length == 0 || blocks.Distinct().Count() != blocks.Length ||
            blocks.Any(b => !AvailableBlocks.Contains(b))) throw new ArgumentException("Choose at least one unique display block.");
        if (!Regex.IsMatch(Accent, "^#[0-9A-Fa-f]{6}$") || TextPercent is < 90 or > 110)
            throw new ArgumentException("Display color must be #RRGGBB; text range 90..110.");

    }
}
