using Microsoft.Win32;
using System.Management;
namespace WindowsSystemMonitorTrofeo.Monitoring;
public static class MachineIdentity
{
    private static readonly Lazy<string> cpu = new(() =>
    {
        try
        {
            using var key = Registry.LocalMachine.OpenSubKey(@"HARDWARE\DESCRIPTION\System\CentralProcessor\0");
            var name = key?.GetValue("ProcessorNameString") as string;
            return string.IsNullOrWhiteSpace(name) ? "CPU unavailable" : string.Join(" ", name.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        }
        catch { return "CPU unavailable"; }
    });
    // Inventory runs once in the background so WMI cannot delay USB frames or the settings UI.
    private static readonly Lazy<Task<string>> memory = new(() => Task.Run(() =>
    {
        try
        {
            using var searcher = new ManagementObjectSearcher("SELECT SMBIOSMemoryType, MemoryType, ConfiguredClockSpeed FROM Win32_PhysicalMemory");
            searcher.Options.Timeout = TimeSpan.FromSeconds(3);
            using var rows = searcher.Get();
            var modules = new List<(uint Type, uint Speed)>();
            foreach (ManagementObject row in rows)
            {
                using (row)
                {
                    uint type = Convert.ToUInt32(row["SMBIOSMemoryType"] ?? 0);
                    if (type is 0 or 2) type = Convert.ToUInt32(row["MemoryType"] ?? 0);
                    modules.Add((type, Convert.ToUInt32(row["ConfiguredClockSpeed"] ?? 0)));
                }
            }
            return FormatMemory(modules);
        }
        catch { return "RAM · —"; }
    }));
    public static string FormatMemory(IEnumerable<(uint Type, uint Speed)> modules)
    {
        string TypeName(uint type) => type switch
        {
            17 => "SDRAM", 20 => "DDR", 21 or 22 => "DDR2", 24 => "DDR3", 26 => "DDR4",
            27 => "LPDDR", 28 => "LPDDR2", 29 => "LPDDR3", 30 => "LPDDR4",
            34 => "DDR5", 35 => "LPDDR5", _ => "RAM"
        };
        var labels = modules.Select(m => TypeName(m.Type) + " · " + (m.Speed > 0 ? m.Speed + " MT/s" : "—"))
            .Distinct().OrderBy(label => label).ToArray();
        return labels.Length == 0 ? "RAM · —" : string.Join(" / ", labels);
    }
    public static string MemoryName => memory.Value.IsCompletedSuccessfully ? memory.Value.Result : "RAM · —";
    public static string CpuName => cpu.Value;
}
