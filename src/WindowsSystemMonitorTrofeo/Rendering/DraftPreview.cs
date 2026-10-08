using System.Diagnostics;
using System.Text.Json;
using WindowsSystemMonitorTrofeo.Monitoring;
namespace WindowsSystemMonitorTrofeo.Rendering;

// Separate renderer process: no USB discovery, sensor handles or monitor stop event.
public static class DraftPreview
{
    public static byte[] Render(string settingsPath, string statusPath, Action<string>? rendered = null)
    {
        using var settings = JsonDocument.Parse(File.ReadAllText(settingsPath));
        var s = settings.RootElement;
        var display = new DisplayOptions(s.GetProperty("DisplayBlocks").GetString()!, s.GetProperty("AccentColor").GetString()!,
            s.GetProperty("TextPercent").GetInt32(), s.GetProperty("CpuMetric").GetString()!, s.GetProperty("GpuMetric").GetString()!,
            s.GetProperty("ShowGraphs").GetBoolean(), s.GetProperty("ShowDeviceNames").GetBoolean());
        var thresholds = new TemperatureThresholds(s.GetProperty("CpuYellow").GetInt32(),s.GetProperty("CpuRed").GetInt32(),
            s.GetProperty("GpuYellow").GetInt32(),s.GetProperty("GpuRed").GetInt32());
        Snapshot data = new(null,null,null,null,null,null,null,null,s.GetProperty("Drive").GetString() is {Length:>0} drive ? drive : "C:");
        try {
            using var status = JsonDocument.Parse(File.ReadAllText(statusPath));
            var record = status.RootElement;
            if(DateTime.UtcNow-record.GetProperty("updatedUtc").GetDateTime() < TimeSpan.FromSeconds(5)
                && record.GetProperty("state").GetString()=="running"
                && record.TryGetProperty("snapshot",out var snapshot) && snapshot.ValueKind==JsonValueKind.Object)
            {
                using var owner=Process.GetProcessById(record.GetProperty("pid").GetInt32());
                if(!owner.HasExited) data=snapshot.Deserialize<Snapshot>() ?? data;
            }
        } catch(Exception e) when(e is IOException or JsonException or ArgumentException or InvalidOperationException or System.ComponentModel.Win32Exception or FormatException or KeyNotFoundException) { }
        // Display the layout upright. Rotation affects only USB after Apply.
        var jpeg = Dashboard.Create(data,null,0,thresholds,display);
        rendered?.Invoke(s.GetRawText());
        return jpeg;
    }
    public static int Run(string directory,string statusPath,int parentPid)
    {
        try {
            using var parent=Process.GetProcessById(parentPid);
            string settings=Path.Combine(directory,"draft.json"), output=Path.Combine(directory,"preview.jpg");
            while(!parent.HasExited && !File.Exists(Path.Combine(directory,"stop"))) {
                try {
                    string? renderedSettings=null;
                    var jpeg=Render(settings,statusPath, value=>renderedSettings=value);
                    File.WriteAllBytes(output+".tmp",jpeg);File.Move(output+".tmp",output,true);
                    File.WriteAllText(Path.Combine(directory,"rendered-draft.json"),renderedSettings);
                    File.WriteAllText(Path.Combine(directory,"error.txt"),"");
                } catch(Exception e) when(e is IOException or JsonException or ArgumentException or InvalidOperationException) {
                    try{File.WriteAllText(Path.Combine(directory,"error.txt"),e.Message);}catch(IOException){}
                }
                Thread.Sleep(200);parent.Refresh();
            }
            return 0;
        } catch(Exception e) when(e is ArgumentException or InvalidOperationException){return 2;}
    }
}
