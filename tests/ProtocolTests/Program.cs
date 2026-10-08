using WindowsSystemMonitorTrofeo.Usb;
using WindowsSystemMonitorTrofeo.Rendering;
using System.Buffers.Binary;

int checks = 0;
void Check(bool condition, string name)
{
    if (!condition) throw new Exception(name);
    Console.WriteLine($"PASS {name}"); checks++;
}
var response = new byte[512];
response[0] = 3; response[1] = 255; response[8] = 1;
Check(LyProtocol.IsValidResponse(response), "valid device response");
for (int length = 0; length < 512; length++)
    if (LyProtocol.IsValidResponse(response.AsSpan(0, length))) throw new Exception($"Accepted truncated response {length}");
Check(true, "all truncated responses rejected");
foreach (int offset in new[] { 0, 1, 8 })
{
    var corrupt = (byte[])response.Clone(); corrupt[offset] ^= 1;
    Check(!LyProtocol.IsValidResponse(corrupt), $"invalid signature at {offset}");
}
Check(!LyProtocol.IsValidResponse(new byte[513]), "oversized response rejected");
Check(!LyProtocol.IsValidResponse(LyProtocol.CreateProbe()), "request echo rejected");
var request = LyProtocol.CreateProbe();
var expected = new byte[2048]; expected[0] = 2; expected[1] = 255; expected[8] = 1;
Check(request.SequenceEqual(expected), "request matches documented wire format");
foreach (int length in new[] { 1, 495, 496, 497, 1488, 1983, 1984, 3967, 3968, 3969, LyFrame.MaxJpegBytes })
{
    var payload = Enumerable.Range(0, length).Select(i => (byte)(i * 37)).ToArray();
    var frame = LyFrame.Pack(payload);
    int count = BinaryPrimitives.ReadUInt16LittleEndian(frame.AsSpan(9));
    using var recovered = new MemoryStream();
    for (int i = 0; i < count; i++)
    {
        var chunk = frame.AsSpan(i * 512, 512);
        int size = BinaryPrimitives.ReadUInt16LittleEndian(chunk[6..]);
        if (chunk[0] != 1 || chunk[1] != 255 || chunk[8] != 1 || size > 496 ||
            BinaryPrimitives.ReadUInt32LittleEndian(chunk[2..]) != length ||
            BinaryPrimitives.ReadUInt16LittleEndian(chunk[9..]) != count ||
            BinaryPrimitives.ReadUInt16LittleEndian(chunk[11..]) != i)
            throw new Exception($"Bad header length={length}, index={i}");
        if (chunk[13..16].IndexOfAnyExcept((byte)0) >= 0 || chunk[(16 + size)..].IndexOfAnyExcept((byte)0) >= 0)
            throw new Exception("Nonzero chunk padding");
        recovered.Write(chunk.Slice(16, size));
    }
    if (frame.AsSpan(count * 512).IndexOfAnyExcept((byte)0) >= 0) throw new Exception("Nonzero alignment padding");
    var transfers = LyFrame.Transfers(frame).ToArray();
    Check(frame.Length % 2048 == 0 && transfers.All(t => t.Length is 2048 or 4096) &&
        transfers.SelectMany(t => t).SequenceEqual(frame) && recovered.ToArray().SequenceEqual(payload), $"wire round trip {length} bytes");
}
var exact = LyFrame.Pack(new byte[496]);
Check(BinaryPrimitives.ReadUInt16LittleEndian(exact.AsSpan(9)) == 2 && exact[512] == 1 && exact[518] == 0 && exact[519] == 0, "exact boundary has terminal empty chunk");
foreach (int length in new[] { 0, 450000 })
{
    bool rejected = false;
    try { LyFrame.Pack(new byte[length]); } catch (ArgumentOutOfRangeException) { rejected = true; }
    Check(rejected, $"invalid size {length} rejected");
}
Directory.CreateDirectory("artifacts/qa");
foreach (int angle in new[] { 0, 180 })
{
    var jpeg = TestPattern.Create($"artifacts/qa/preview-{angle}.png", angle);
    File.WriteAllBytes($"artifacts/qa/wire-{angle}.jpg", jpeg);
    bool baseline = false;
    for (int p = 2; p + 4 < jpeg.Length;)
    {
        if (jpeg[p] != 255) throw new Exception("Invalid JPEG marker");
        byte marker = jpeg[p + 1];
        int size = BinaryPrimitives.ReadUInt16BigEndian(jpeg.AsSpan(p + 2));
        if (marker == 0xC2) throw new Exception("Progressive JPEG is unsupported");
        if (marker == 0xC0)
        {
            baseline = jpeg[p + 4] == 8 && BinaryPrimitives.ReadUInt16BigEndian(jpeg.AsSpan(p + 5)) == 462 &&
                BinaryPrimitives.ReadUInt16BigEndian(jpeg.AsSpan(p + 7)) == 1920 && jpeg[p + 9] == 3 &&
                jpeg[p + 11] == 0x22 && jpeg[p + 14] == 0x11 && jpeg[p + 17] == 0x11;
        }
        if (marker == 0xDA) break;
        p += 2 + size;
    }
    Check(baseline && jpeg.Length < 450000 && jpeg[^2] == 255 && jpeg[^1] == 217, $"JPEG {angle}: baseline 1920x462 4:2:0, within size limit");
}
Console.WriteLine($"{checks} checks passed; no hardware accessed.");
var ackOk = new byte[512]; ackOk[0] = 3; ackOk[1] = 255;
var plan = LyFrame.Transfers(LyFrame.Pack(new byte[6000])).ToArray();
var events = new List<string>();
var receipt = FrameSender.Send(plan, b => events.Add("write"), () => { events.Add("read"); return ackOk; });
Check(receipt.Writes == plan.Length && receipt.Bytes == plan.Sum(p => p.Length) && events[^1] == "read" && events.Count(e => e == "read") == 1, "frame read occurs only after all writes");
int attempted = 0, reads = 0;
bool failed = false;
try { FrameSender.Send(plan, _ => { attempted++; throw new IOException("injected short/failed write"); }, () => { reads++; return ackOk; }); }
catch (IOException) { failed = true; }
Check(failed && attempted == 1 && reads == 0, "failed OUT stops immediately without retry or ACK read");
foreach (var invalid in new[] { Array.Empty<byte>(), new byte[511], new byte[512], new byte[513] })
{
    failed = false;
    try { FrameSender.Send(plan, _ => { }, () => invalid); } catch (InvalidDataException) { failed = true; }
    Check(failed, $"bad ACK rejected ({invalid.Length} bytes)");
}
using var stop = new CancellationTokenSource();
attempted = 0;
FrameSender.Send(plan, _ => { attempted++; stop.Cancel(); }, () => ackOk);
Check(stop.IsCancellationRequested && attempted == plan.Length, "cancellation request does not truncate in-flight frame");
var dynamic1 = TestPattern.Create("artifacts/qa/demo.png", 180, 1, 0);
var dynamic2 = TestPattern.Create(null, 180, 2, 0.5);
Check(!dynamic1.SequenceEqual(dynamic2) && dynamic2.Length < LyFrame.MaxJpegBytes, "successive demo frames change within size cap");
Console.WriteLine($"TOTAL: {checks} checks passed; no hardware accessed.");
string leaseId = "test-" + Guid.NewGuid();
bool secondBlocked = false;
using (var owner = new DeviceLease(leaseId))
{
    var contender = new Thread(() =>
    {
        try { using var duplicate = new DeviceLease(leaseId); }
        catch (IOException) { secondBlocked = true; }
    });
    contender.Start();
    if (!contender.Join(5000)) throw new Exception("Device lease blocked instead of failing promptly");
}
Check(secondBlocked, "second device owner rejected promptly");
using (var reopened = new DeviceLease(leaseId)) Check(true, "device lease released on dispose");
Console.WriteLine($"FINAL: {checks} checks passed; no hardware accessed.");
foreach (int length in new[] { 1, 1984, 3968, 98800, LyFrame.MaxJpegBytes })
{
    var packed = LyFrame.Pack(new byte[length]);
    var smaller = LyFrame.Transfers(packed, 2048).ToArray();
    Check(smaller.All(b => b.Length == 2048) && smaller.SelectMany(b => b).SequenceEqual(packed), $"2048-byte transfers preserve frame {length}");
}
failed = false;
try { LyFrame.Transfers(new byte[2048], 512).ToArray(); } catch (ArgumentOutOfRangeException) { failed = true; }
Check(failed, "unsupported USB block size rejected");
Console.WriteLine($"FINAL DIAGNOSTIC: {checks} checks passed; no hardware accessed.");
var idleCpu = WindowsSystemMonitorTrofeo.Monitoring.SystemSampler.CpuPercent(200, 300, 100, 100, 200, 100);
Check(idleCpu == 0, "CPU kernel includes idle time");
Check(WindowsSystemMonitorTrofeo.Monitoring.SystemSampler.CpuPercent(150, 300, 200, 100, 200, 100) == 75, "CPU busy delta");
Check(WindowsSystemMonitorTrofeo.Monitoring.SystemSampler.CpuPercent(1, 2, 3, 2, 3, 4) == null, "CPU reset unavailable");
Check(WindowsSystemMonitorTrofeo.Monitoring.SystemSampler.Rate(100, 200, 1) == null, "network counter reset unavailable");
Check(WindowsSystemMonitorTrofeo.Monitoring.SystemSampler.Rate(300, 100, 2) == 100, "network elapsed interval");
var sample = new WindowsSystemMonitorTrofeo.Monitoring.Snapshot(75, 50, 16, 32, 1048576, 2097152, 40, 200, "C:\\");
var dashboard = Dashboard.Create(sample, "artifacts/qa/dashboard.png", 180);
Check(dashboard.Length < LyFrame.MaxJpegBytes, "live dashboard fits LY payload");
using (var bitmap = new System.Drawing.Bitmap(new MemoryStream(dashboard))) Check(bitmap.Width == 1920 && bitmap.Height == 462, "dashboard panel dimensions");
var unavailable = Dashboard.Create(new(null, null, null, null, null, null, null, null, "C:"), "artifacts/qa/dashboard-unavailable.png", 0);
Check(unavailable.Length > 0, "unavailable telemetry renders");
Console.WriteLine($"FINAL MONITOR: {checks} checks passed; no hardware accessed.");
var selectedCpu = WindowsSystemMonitorTrofeo.Monitoring.HardwareSampler.SelectCpu(new (string, double?)[] { ("CPU Package", 65), ("CPU Core #1", 70), ("CPU Core #1 Distance to TjMax", 35) });
Check(selectedCpu.value == 65 && selectedCpu.name == "CPU Package", "CPU package preferred over core");
Check(WindowsSystemMonitorTrofeo.Monitoring.HardwareSampler.SelectCpu(new (string, double?)[] { ("CPU Core #1 Distance to TjMax", 35), ("CPU Core #2", 66), ("CPU Core #1", 63) }).value == 66, "hottest core fallback excludes distance to TjMax");
Check(WindowsSystemMonitorTrofeo.Monitoring.HardwareSampler.SelectCpu(new (string, double?)[] { ("CPU Package", double.NaN), ("Core Max", 999) }).value == null, "invalid CPU temperatures unavailable");
var hw = new WindowsSystemMonitorTrofeo.Monitoring.HardwareSnapshot("NVIDIA GeForce RTX 2080 SUPER", 98, 72, 7000, 8192, 65, "CPU Package", "");
Check(WindowsSystemMonitorTrofeo.Monitoring.HardwareSampler.Fresh(hw, 6).GpuLoad == null && WindowsSystemMonitorTrofeo.Monitoring.HardwareSampler.Fresh(hw, 6).CpuTemperature == null, "stale hardware readings cleared");
Check(WindowsSystemMonitorTrofeo.Monitoring.HardwareSampler.Fresh(hw, 1).GpuLoad == 98, "fresh hardware readings preserved");
var gpuDashboard = Dashboard.Create(sample with { Hardware = hw }, "artifacts/qa/dashboard-gpu.png", 180);
Check(gpuDashboard.Length < LyFrame.MaxJpegBytes, "GPU dashboard fits wire payload");
Console.WriteLine($"FINAL SENSORS: {checks} checks passed; no hardware accessed.");
Check(!WindowsSystemMonitorTrofeo.RunMetrics.Finished(true, 60, 100000), "continuous mode has no elapsed deadline");
Check(WindowsSystemMonitorTrofeo.RunMetrics.Finished(false, 0, 0), "zero duration retains one-shot stop");
Check(!WindowsSystemMonitorTrofeo.RunMetrics.Finished(false, 1800, 1799) && WindowsSystemMonitorTrofeo.RunMetrics.Finished(false, 1800, 1800), "stability test deadline boundary");
var runMetrics = new WindowsSystemMonitorTrofeo.RunMetrics();
runMetrics.Frame(100); runMetrics.Frame(270); runMetrics.Frame(3500);
Check(runMetrics.GapsOver2Seconds == 1 && runMetrics.MaxFrameGapMs == 3230, "detect long frame interruption");
runMetrics.Sensors(1, null); runMetrics.Sensors(11, hw); runMetrics.Sensors(12, hw with { CpuTemperature = null });
Check(runMetrics.SensorChecks == 2 && runMetrics.MissingCpuTemperature == 1 && runMetrics.MissingGpuTemperature == 0, "sensor availability excludes startup warmup");
Console.WriteLine($"FINAL DAILY: {checks} checks passed; no hardware accessed.");
var chartHistory = new WindowsSystemMonitorTrofeo.Monitoring.ChartHistory();
WindowsSystemMonitorTrofeo.Monitoring.HistoryPoint[] points = [];
for (int i = 0; i <= 90; i++) points = chartHistory.Add(i, sample with { Cpu = 45 + 25 * Math.Sin(i / 4.0), ReceiveBytes = 4e6 + 3e6 * Math.Sin(i / 7.0), SendBytes = 1e6 + 8e5 * Math.Cos(i / 8.0), Hardware = hw with { GpuLoad = 60 + 20 * Math.Cos(i / 5.0) } });
Check(points.Length == 61 && points[0].Seconds == 30 && points[^1].Seconds == 90, "history bounded to last sixty seconds");
var afterPause = chartHistory.Add(200, sample);
Check(afterPause.Length == 1, "history evicts pre-sleep samples without fabricated fill");
var extendedHw = hw with { CpuClockMHz = 4200, DiskTemperature = 40, DiskReadBytes = 24e6, DiskWriteBytes = 8e6 };
var expired = WindowsSystemMonitorTrofeo.Monitoring.HardwareSampler.Fresh(extendedHw, 6);
Check(expired.CpuClockMHz == null && expired.DiskTemperature == null && expired.DiskReadBytes == null && expired.DiskWriteBytes == null, "new sensor values cleared when stale");
var graphs = Dashboard.Create(sample with { Hardware = extendedHw, History = points }, "artifacts/qa/dashboard-graphs.png", 180);
Check(graphs.Length < LyFrame.MaxJpegBytes, "sixty-second graphs fit JPEG wire limit");
Console.WriteLine($"FINAL GRAPHS: {checks} checks passed; no hardware accessed.");

var sequence = new Queue<int>(new[] {3, 9, 0});
var waits = new List<int>();
Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.Run(() => sequence.Dequeue(), true, CancellationToken.None, waits.Add) == 0 && waits.SequenceEqual(new[] {5,10}), "missing device and transient fault reopen with backoff");
Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.Run(() => 5, true, CancellationToken.None, _ => throw new Exception()) == 5, "driver failure never retried");
Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.Run(() => 9, false, CancellationToken.None, _ => throw new Exception()) == 9, "stability mode never hides a failure");
var resumeInterfaces = new Queue<int>(new[] { 0, 0, 1 });
var resumeWaits = new List<int>();
Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.Run(() => WindowsSystemMonitorTrofeo.RecoveryPolicy.InterfaceResult("WINUSB", resumeInterfaces.Dequeue(), true), true, CancellationToken.None, resumeWaits.Add) == 0 && resumeWaits.SequenceEqual(new[] {5,10}), "resume waits for missing WinUSB interface, then opens restored interface");
Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.InterfaceResult("WINUSB", 0, false) == 5, "probe/stability reports missing interface without recovery");
Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.InterfaceResult("usbser", 0, true) == 5 && WindowsSystemMonitorTrofeo.RecoveryPolicy.InterfaceResult("WINUSB", 2, true) == 5, "wrong driver and ambiguous interface remain terminal");
using var cancelled = new CancellationTokenSource();
int calls = 0;
Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.Run(() => { calls++; return 3; }, true, cancelled.Token, _ => cancelled.Cancel()) == 0 && calls == 1, "stop during reconnect prevents another session");
Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.IsTransient(new System.ComponentModel.Win32Exception(1167)) && !WindowsSystemMonitorTrofeo.RecoveryPolicy.IsTransient(new System.ComponentModel.Win32Exception(5)) && !WindowsSystemMonitorTrofeo.RecoveryPolicy.IsTransient(new IOException()), "disconnect is transient; permissions and file errors are terminal");
Console.WriteLine($"FINAL RECOVERY: {checks} checks passed; no hardware accessed.");

Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.IsTransient(new System.ComponentModel.Win32Exception(22)), "observed USB error 22 permits a new connection");
var usbFault = new Queue<int>(new[] {9,3,0});
var recoveryWaits = new List<int>();
Check(WindowsSystemMonitorTrofeo.RecoveryPolicy.Run(() => usbFault.Dequeue(), true, CancellationToken.None, recoveryWaits.Add) == 0 && recoveryWaits.SequenceEqual(new[] {5,10}), "USB fault then absent device then restored connection");
Console.WriteLine($"FINAL RECOVERY FIX: {checks} checks passed; no hardware accessed.");

using (var selection = new WindowsSystemMonitorTrofeo.Monitoring.SystemSampler(false, false, "nonexistent-adapter-for-test", @"Z:\"))
{
    var selectedSample = selection.Read();
    Check(selectedSample.DiskName == @"Z:\" && selectedSample.ReceiveBytes == null && selectedSample.SendBytes == null, "selected drive retained and missing adapter does not fall back to all");
}
Console.WriteLine($"FINAL SETTINGS: {checks} checks passed; no USB accessed.");

Check(TemperatureThresholds.ColorFor(74.9,75,90) == System.Drawing.Color.FromArgb(68,226,198), "temperature below yellow");
Check(TemperatureThresholds.ColorFor(75,75,90) == System.Drawing.Color.FromArgb(245,197,66), "temperature yellow inclusive");
Check(TemperatureThresholds.ColorFor(90,75,90) == System.Drawing.Color.FromArgb(240,90,100), "temperature red inclusive");
Check(TemperatureThresholds.ColorFor(null,75,90) == TemperatureThresholds.ColorFor(double.NaN,75,90), "missing temperature muted");
bool invalidThresholds=false;
try {new TemperatureThresholds(90,75).Validate();} catch(ArgumentException){invalidThresholds=true;}
Check(invalidThresholds,"inverted thresholds rejected");
Dashboard.Create(sample with {Hardware=extendedHw with {CpuTemperature=80,GpuTemperature=90}}, "artifacts/qa/dashboard-temperature-colors.png",180);
Console.WriteLine($"FINAL TEMPERATURE: {checks} checks passed.");

var statusRoot=Path.Combine("artifacts","qa","status-"+Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(statusRoot);
var statusPath=Path.Combine(statusRoot,"monitor-status.json");
var publisher=new WindowsSystemMonitorTrofeo.MonitorStatus(statusPath);
publisher.Report("waiting");
publisher.Frame(graphs,180);
using(var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(statusPath))) {
    Check(doc.RootElement.GetProperty("frames").GetInt64()==1 && doc.RootElement.GetProperty("reconnects").GetInt32()==0,"initial connection not a reconnect");
}
Check(!Directory.GetFiles(statusRoot,"*.jpg").Any(),"closed preview creates no JPEG");
publisher.Error("Test disconnect");
publisher.Report("waiting");
File.WriteAllText(Path.Combine(statusRoot,"preview-request"),"open");
publisher.Frame(graphs,180);
publisher.Report("stopped");
using(var doc=System.Text.Json.JsonDocument.Parse(File.ReadAllText(statusPath))) {
    Check(doc.RootElement.GetProperty("reconnects").GetInt32()==1 && doc.RootElement.GetProperty("lastError").GetString()=="Test disconnect","successful reconnect counted and error retained");
    Check(doc.RootElement.GetProperty("rotation").GetInt32()==180 && doc.RootElement.GetProperty("previewUtc").ValueKind!=System.Text.Json.JsonValueKind.Null,"last frame rotation preserved after stop");
}
Check(Directory.GetFiles(statusRoot,"*.jpg").Length==1,"open preview publishes acknowledged JPEG");
Console.WriteLine($"FINAL PREVIEW: {checks} checks passed.");
