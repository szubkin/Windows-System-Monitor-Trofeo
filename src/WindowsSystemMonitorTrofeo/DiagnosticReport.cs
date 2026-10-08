using System.Diagnostics;
using System.Text;
using System.Text.Json;
using WindowsSystemMonitorTrofeo.Usb;
namespace WindowsSystemMonitorTrofeo;

public sealed record UsbSummary(string Service,int InterfaceCount);
public static class DiagnosticReport
{
    public static string Build(string? statusJson,IEnumerable<UsbSummary> devices,string? discoveryError,string language,DateTime utcNow,Func<int,bool>? alive=null)
    {
        string L(string en,string ru)=>language=="en"?en:ru;
        string Clean(string? value,int max=400)=>string.IsNullOrWhiteSpace(value)?"—":value.Replace('\r',' ').Replace('\n',' ')[..Math.Min(value.Replace('\r',' ').Replace('\n',' ').Length,max)];
        var text=new StringBuilder();
        text.AppendLine(L("Trofeo diagnostic report","Диагностика Trofeo"));
        text.AppendLine(L("Version: ","Версия: ")+typeof(DiagnosticReport).Assembly.GetName().Version?.ToString(3));
        text.AppendLine("UTC: "+utcNow.ToString("O"));
        text.AppendLine("Windows: "+Environment.OSVersion+"; .NET: "+Environment.Version+"; x64: "+Environment.Is64BitProcess);
        var usb=devices.ToArray();
        text.AppendLine("USB VID_0416&PID_5408: "+L("detected ","найдено ")+usb.Length);
        foreach(var d in usb)text.AppendLine("  Service="+Clean(d.Service)+"; "+L("interfaces=","интерфейсов=")+d.InterfaceCount);
        if(discoveryError!=null)text.AppendLine(L("USB discovery error: ","Ошибка обнаружения USB: ")+Clean(discoveryError));
        text.AppendLine(L("Discovery only: no USB transfers or driver changes.","Только обнаружение: USB-передачи и изменение драйверов не выполнялись."));
        try {
            using var doc=JsonDocument.Parse(statusJson??"{}");var s=doc.RootElement;
            string Get(string key)=>s.TryGetProperty(key,out var value)?Clean(value.ToString()):"—";
            bool fresh=s.TryGetProperty("updatedUtc",out var updated) && utcNow-updated.GetDateTime()>=TimeSpan.Zero && utcNow-updated.GetDateTime()<TimeSpan.FromSeconds(5)
                && s.TryGetProperty("pid",out var pid) && (alive??IsAlive)(pid.GetInt32());
            text.AppendLine(L("Connection: ","Подключение: ")+(fresh?Get("state"):L("stopped / stale status","остановлено / старые данные")));
            text.AppendLine(L("Status timestamp: ","Время статуса: ")+Get("updatedUtc"));
            text.AppendLine("FPS="+Get("fps")+"; "+L("frames=","кадров=")+Get("frames")+"; "+L("reconnects=","переподключений=")+Get("reconnects"));
            text.AppendLine(L("Last error: ","Последняя ошибка: ")+Get("lastError")+"; UTC="+Get("lastErrorUtc"));
            if(fresh && s.TryGetProperty("snapshot",out var snapshot) && snapshot.ValueKind==JsonValueKind.Object && snapshot.TryGetProperty("Hardware",out var hw) && hw.ValueKind==JsonValueKind.Object){
                string Sensor(string key)=>hw.TryGetProperty(key,out var value)?Clean(value.ToString()):"—";
                text.AppendLine("GPU: "+Sensor("GpuName"));
                text.AppendLine("CPU W="+Sensor("CpuPowerWatts")+"; GPU W="+Sensor("GpuPowerWatts"));
                text.AppendLine("CPU RPM="+Sensor("CpuFanRpm")+"; GPU RPM="+Sensor("GpuFanRpm")+"; GPU fan %="+Sensor("GpuFanPercent"));
                text.AppendLine(L("Sensor status: ","Состояние датчиков: ")+Sensor("Status"));
            }
        } catch(Exception e) when(e is JsonException or InvalidOperationException or FormatException or ArgumentException){text.AppendLine(L("Status unavailable: ","Статус недоступен: ")+Clean(e.Message));}
        return text.ToString();
    }
    private static bool IsAlive(int id){try{using var p=Process.GetProcessById(id);return !p.HasExited;}catch(ArgumentException){return false;}catch(System.ComponentModel.Win32Exception){return false;}}
    public static int Run(string output,string statusPath,string language)
    {
        try {
            string? status=null,error=null;var devices=new List<UsbSummary>();
            try{if(new FileInfo(statusPath).Length<=1024*1024)status=File.ReadAllText(statusPath);}catch(Exception e) when(e is IOException or UnauthorizedAccessException){}
            try{devices=DeviceDiscovery.Find(_=>{}).Select(d=>new UsbSummary(d.Service,d.Paths.Count)).ToList();}catch(Exception e){error=e.Message;}
            var text=Build(status,devices,error,language,DateTime.UtcNow);
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output))!);
            File.WriteAllText(output+".tmp",text,new UTF8Encoding(true));File.Move(output+".tmp",output,true);
            return 0;
        }catch(Exception e) when(e is IOException or UnauthorizedAccessException or ArgumentException){Console.Error.WriteLine(e.Message);return 1;}
    }
}
