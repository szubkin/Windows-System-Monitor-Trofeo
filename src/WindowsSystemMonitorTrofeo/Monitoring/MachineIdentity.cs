using Microsoft.Win32;
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
    public static string CpuName => cpu.Value;
}
