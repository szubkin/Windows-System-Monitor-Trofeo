using System.Text.Json;
using System.Diagnostics;
namespace WindowsSystemMonitorTrofeo;

public sealed class MonitorStatus(string? path)
{
    private readonly DateTime startedUtc = DateTime.UtcNow;
    private readonly Stopwatch uptime = Stopwatch.StartNew();
    private DateTime lastWrite = DateTime.MinValue;
    private string state = "";
    private long frames, lastFrames;
    private double lastSeconds, fps;
    private int connections, lastRotation;
    private bool connected;
    private string? lastError;
    private DateTime? lastErrorUtc, previewUtc;
    public void Error(string message) { lastError = message; lastErrorUtc = DateTime.UtcNow; }
    public void Frame(byte[] jpeg, int rotation)
    {
        if (!connected) { connected = true; connections++; }
        frames++; lastRotation = rotation;
        Report("running", jpeg, rotation);
    }
    public void Report(string next, byte[]? jpeg = null, int rotation = 0)
    {
        if (next != "running") connected = false;
        bool changed = state != next;
        state = next;
        if (path == null) return;
        var now = DateTime.UtcNow;
        if (!changed && now - lastWrite < TimeSpan.FromSeconds(1)) return;
        double seconds = uptime.Elapsed.TotalSeconds;
        fps = next == "running" && seconds > lastSeconds ? (frames - lastFrames) / (seconds - lastSeconds) : 0;
        try
        {
            string folder = Path.GetDirectoryName(Path.GetFullPath(path))!;
            Directory.CreateDirectory(folder);
            string previewName = $"monitor-preview-{Environment.ProcessId}.jpg";
            var request = Path.Combine(folder, "preview-request");
            if (jpeg != null && File.Exists(request) && now - File.GetLastWriteTimeUtc(request) < TimeSpan.FromSeconds(5))
            {
                string previewPath = Path.Combine(folder, previewName);
                File.WriteAllBytes(previewPath + ".tmp", jpeg);
                File.Move(previewPath + ".tmp", previewPath, true);
                previewUtc = now;
            }
            string temp = path + "." + Environment.ProcessId + ".tmp";
            File.WriteAllText(temp, JsonSerializer.Serialize(new {
                state, pid = Environment.ProcessId, updatedUtc = now, startedUtc,
                uptimeSeconds = seconds, frames, fps, reconnects = Math.Max(0, connections - 1),
                lastError, lastErrorUtc, previewUtc, previewFile = previewName, rotation = lastRotation
            }));
            File.Move(temp, path, true);
            lastWrite = now; lastFrames = frames; lastSeconds = seconds;
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
