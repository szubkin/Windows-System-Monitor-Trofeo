using WindowsSystemMonitorTrofeo;
using System.ComponentModel;
using System.Diagnostics;
using System.Text;
using WindowsSystemMonitorTrofeo.Usb;
using WindowsSystemMonitorTrofeo.Rendering;
using WindowsSystemMonitorTrofeo.Monitoring;

if(args.Length == 4 && args[0] == "--settings-preview-worker" && int.TryParse(args[3],out var previewParent))
    return DraftPreview.Run(args[1],args[2],previewParent);
Console.OutputEncoding = Encoding.UTF8;
if (args.Length == 0 || args.Contains("--help"))
{
    Console.WriteLine("Windows System Monitor Trofeo 0.1.7\nUsage: --list | --probe | --test-pattern | --demo | --monitor | --monitor-preview | --preview | --check-runtime\nOptions: --device <instance-id> --timeout-ms 3000 --log-dir <folder> --rotation 0|180 --hold-seconds 0..3600 --fps 1..10 --reset-pipes --continuous --recover --verbose\nCompact log is default (errors and final summary only; progress JSON updated each minute); --verbose enables hex dumps. --continuous runs until Ctrl+C and excludes --hold-seconds.\nDisplay: --display-blocks CPU,GPU,MEMORY,NETWORK,DISK --accent-color #44E2C6 --text-percent 90..110 --cpu-metric load|temperature|clock --gpu-metric load|temperature|vram --hide-graphs --hide-device-names\nSensors: --cpu-sensors (LibreHardwareMonitor CPU temperatures; requires PawnIO and may require administrator). NVIDIA GPU via NVML.\nDiagnostics: --usb-block-size 2048|4096 --block-delay-ms 0..10\n--monitor shows CPU, RAM, network rates and system disk capacity; --monitor-preview saves live data without USB. --demo shows a moving marker, clock and frame counter. --test-pattern holds a static image. Default 60s, target cap 4 FPS, USB 2048-byte blocks + 1ms pause (measured ~1.26 FPS); Ctrl+C stops BETWEEN complete frames. Close TRCC first.\n--preview saves a static test image without USB. Rotation follows panel SUB (preview: 180).\nExit: 0 completed/cancelled, 2 arguments, 3 not found, 4 ambiguous, 5 driver/profile, 6 native/I/O error, 7 invalid handshake. See summary JSON for cancellation/failure details.");
    return 0;
}
string? selected = null, statusFile = null, networkId = null, driveRoot = null;
string logDir = Path.Combine(AppContext.BaseDirectory, "logs");
uint timeout = 3000;
bool probe = false, list = false, pattern = false, preview = false, recover = false;
int? rotation = null;
var thresholds = new TemperatureThresholds();
var display = new DisplayOptions();
int holdSeconds = 60;
bool holdSpecified = false;
bool resetPipes = false;
bool demo = false, monitor = false, monitorPreview = false, fpsSpecified = false;
int fps = 4;
int usbBlockSize = 2048, blockDelayMs = 1;
bool transportSpecified = false, cpuSensors = false, checkRuntime = false, continuous = false, verbose = false;
try
{
    for (int i = 0; i < args.Length; i++)
        switch (args[i])
        {
            case "--display-blocks": display = display with { Blocks = args[++i] }; break;
            case "--accent-color": display = display with { Accent = args[++i] }; break;
            case "--text-percent": display = display with { TextPercent = int.Parse(args[++i]) }; break;
            case "--cpu-metric": display = display with { CpuMetric = args[++i] }; break;
            case "--gpu-metric": display = display with { GpuMetric = args[++i] }; break;
            case "--hide-graphs": display = display with { Graphs = false }; break;
            case "--hide-device-names": display = display with { DeviceNames = false }; break;
            case "--cpu-yellow": thresholds = thresholds with { CpuYellow = int.Parse(args[++i]) }; break;
            case "--cpu-red": thresholds = thresholds with { CpuRed = int.Parse(args[++i]) }; break;
            case "--gpu-yellow": thresholds = thresholds with { GpuYellow = int.Parse(args[++i]) }; break;
            case "--gpu-red": thresholds = thresholds with { GpuRed = int.Parse(args[++i]) }; break;
            case "--network-id": networkId = args[++i]; break;
            case "--drive": driveRoot = args[++i]; break;
            case "--status-file": statusFile = args[++i]; break;
            case "--recover": recover = true; break;
            case "--continuous": continuous = true; break;
            case "--verbose": verbose = true; break;
            case "--probe": probe = true; break;
            case "--check-runtime": checkRuntime = true; break;
            case "--cpu-sensors": cpuSensors = true; break;
            case "--monitor": monitor = true; break;
            case "--monitor-preview": monitorPreview = true; break;
            case "--demo": demo = true; break;
            case "--fps": fps = int.Parse(args[++i]); fpsSpecified = true; break;
            case "--usb-block-size": usbBlockSize = int.Parse(args[++i]); transportSpecified = true; break;
            case "--block-delay-ms": blockDelayMs = int.Parse(args[++i]); transportSpecified = true; break;
            case "--reset-pipes": resetPipes = true; break;
            case "--list": list = true; break;
            case "--test-pattern": pattern = true; break;
            case "--preview": preview = true; break;
            case "--rotation": rotation = int.Parse(args[++i]); break;
            case "--hold-seconds": holdSeconds = int.Parse(args[++i]); holdSpecified = true; break;
            case "--device": selected = args[++i]; break;
            case "--log-dir": logDir = args[++i]; break;
            case "--timeout-ms": timeout = uint.Parse(args[++i]); break;
            default: throw new ArgumentException($"Unknown option: {args[i]}");
        }
    if (new[] { probe, list, pattern, demo, preview, monitor, monitorPreview, checkRuntime }.Count(x => x) != 1 || timeout < 100 || timeout > 30000)
        throw new ArgumentException("Choose one mode; timeout range 100..30000 ms.");
    thresholds.Validate(); display.Validate();
    if ((networkId != null || driveRoot != null) && !monitor && !monitorPreview) throw new ArgumentException("Network/drive selection requires monitor mode.");
    if (driveRoot != null && !System.Text.RegularExpressions.Regex.IsMatch(driveRoot, @"^[A-Za-z]:\\$")) throw new ArgumentException("Drive must be a root such as C:\\");
    if (statusFile != null && (!monitor || !continuous)) throw new ArgumentException("--status-file requires --monitor --continuous.");
    if (recover && (!monitor || !continuous)) throw new ArgumentException("--recover requires --monitor --continuous.");
    if (continuous && (holdSpecified || !monitor && !demo && !pattern)) throw new ArgumentException("--continuous requires an image mode and cannot combine with --hold-seconds.");
    if (cpuSensors && !monitor && !monitorPreview) throw new ArgumentException("--cpu-sensors requires --monitor or --monitor-preview.");
    if (rotation is not null && (rotation != 0 && rotation != 180 || !pattern && !demo && !monitor && !monitorPreview && !preview))
        throw new ArgumentException("--rotation 0|180 requires --test-pattern or --preview.");
    if (holdSeconds < 0 || holdSeconds > 3600 || holdSpecified && !pattern && !demo && !monitor)
        throw new ArgumentException("--hold-seconds 0..3600 requires --test-pattern or --demo (default 60; 0=one shot).");
    if (fps < 1 || fps > 10 || fpsSpecified && !pattern && !demo && !monitor) throw new ArgumentException("--fps 1..10 requires --test-pattern or --demo.");
    if (resetPipes && !probe && !pattern && !demo && !monitor) throw new ArgumentException("--reset-pipes requires a USB transfer mode.");
    if (usbBlockSize is not (2048 or 4096) || blockDelayMs < 0 || blockDelayMs > 10 || transportSpecified && !pattern && !demo && !monitor)
        throw new ArgumentException("Image modes accept --usb-block-size 2048|4096 and --block-delay-ms 0..10.");
}
catch (Exception e) { Console.Error.WriteLine(e.Message); return 2; }

var liveStatus = new MonitorStatus(statusFile);
using var sampler = new SystemSampler(monitor || monitorPreview, cpuSensors, networkId, driveRoot);
using var cancellation = new CancellationTokenSource();
ConsoleCancelEventHandler cancel = (_, e) => { e.Cancel = true; cancellation.Cancel(); };
Console.CancelKeyPress += cancel;
using var stopSignal = new EventWaitHandle(false, EventResetMode.ManualReset, @"Local\TrofeoStop");
RegisteredWaitHandle? registration = null;
try
{
    using var owner = recover ? new DeviceLease("RecoverySupervisor") : null;
    if (recover) stopSignal.Reset();
    registration = ThreadPool.RegisterWaitForSingleObject(stopSignal, (_, _) => cancellation.Cancel(), null, Timeout.Infinite, true);
    int result = RecoveryPolicy.Run(() => {
        liveStatus.Report("waiting");
        int code = RunSession();
        liveStatus.Report(code == 0 ? "stopped" : recover && code is 3 or 9 ? "waiting" : "error");
        return code;
    }, recover, cancellation.Token);
    if (cancellation.IsCancellationRequested) liveStatus.Report("stopped");
    return result;
}
catch (IOException e) { Console.Error.WriteLine(e.Message); return 6; }
finally { registration?.Unregister(null); Console.CancelKeyPress -= cancel; }

int RunSession()
{
try
{
    Directory.CreateDirectory(logDir);
    var stem = Path.Combine(logDir, $"trofeo-{DateTime.Now:yyyyMMdd-HHmmss-fff}-{Environment.ProcessId}");
    using var writer = new StreamWriter(stem + ".log", false, new UTF8Encoding(false)) { AutoFlush = true };
    var watch = Stopwatch.StartNew();
    void Log(string s) { if (s.StartsWith("FAIL:") || s.StartsWith("NOT FOUND:") || s.StartsWith("Cannot probe:") || s.StartsWith("Win32 error=") || s.StartsWith("Unsupported panel") || s.StartsWith("Multiple devices:")) liveStatus.Error(s); if (!verbose && (monitor || demo || pattern) && !new[] { "SESSION ", "FAIL:", "FRAME FAILED:", "NOT FOUND:", "Multiple devices:", "Cannot probe:", "Unsupported panel", "Win32 error=" }.Any(prefix => s.StartsWith(prefix, StringComparison.Ordinal))) return; var line = $"{DateTimeOffset.Now:O} +{watch.ElapsedMilliseconds,6}ms {s}"; Console.WriteLine(line); writer.WriteLine(line); }
    void Dump(string label, byte[] bytes)
    {
        Log($"{label}: {bytes.Length} bytes");
        if (!verbose) return;
        for (int i = 0; i < bytes.Length; i += 16) Log($"{i:X4}  {Convert.ToHexString(bytes.AsSpan(i, Math.Min(16, bytes.Length - i)))}");
    }
    byte[] Render(int angle)
    {
        var jpeg = TestPattern.Create(stem + "-preview.png", angle);
        File.WriteAllBytes(stem + "-wire.jpg", jpeg);
        Log($"JPEG: {TestPattern.Width}x{TestPattern.Height}, {jpeg.Length} bytes, wire rotation={angle}; preview={stem}-preview.png");
        return jpeg;
    }
    try
    {
        Log($"Windows System Monitor Trofeo v0.1.7; OS={Environment.OSVersion}; .NET={Environment.Version}; 64bit={Environment.Is64BitProcess}; PID={Environment.ProcessId}; mode={(checkRuntime ? "check-runtime" : monitor ? "monitor" : monitorPreview ? "monitor-preview" : demo ? "demo" : pattern ? "test-pattern" : preview ? "preview" : probe ? "probe" : "list")}");
        Log($"Log: {stem}.log");
        if (checkRuntime)
        {
            var security = new System.Security.AccessControl.MutexSecurity();
            security.AddAccessRule(new System.Security.AccessControl.MutexAccessRule(
                new System.Security.Principal.SecurityIdentifier(System.Security.Principal.WellKnownSidType.WorldSid, null),
                System.Security.AccessControl.MutexRights.FullControl, System.Security.AccessControl.AccessControlType.Allow));
            using var mutex = System.Threading.MutexAcl.Create(false, "Local\\TrofeoRuntimeCheck-" + Guid.NewGuid(), out _, security);
            Log("PASS: published Windows Mutex ACL runtime works; no sensors or USB accessed.");
            return 0;
        }
        if (cpuSensors) Log("CPU sensor context: elevated=" + new System.Security.Principal.WindowsPrincipal(System.Security.Principal.WindowsIdentity.GetCurrent()).IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator) + "; PawnIO=" + LibreHardwareMonitor.PawnIo.PawnIo.Version);

        if (monitorPreview) { sampler.Read(); Thread.Sleep(2500); var data = sampler.Read(); File.WriteAllBytes(stem + "-wire.jpg", Dashboard.Create(data, stem + "-preview.png", rotation ?? 180, thresholds, display)); Log(System.Text.Json.JsonSerializer.Serialize(data)); Log("Monitor preview saved; USB not accessed."); return 0; }
        if (preview) { Render(rotation ?? 180); Log("Preview saved; USB not accessed."); return 0; }
        var devices = DeviceDiscovery.Find(Log);
        if (selected != null) devices = devices.Where(d => d.InstanceId.Equals(selected, StringComparison.OrdinalIgnoreCase)).ToList();
        if (devices.Count == 0) { Log("NOT FOUND: present USB VID_0416&PID_5408 device."); return 3; }
        if (list) { Log($"Discovery complete: {devices.Count} matching device(s). No USB transfer performed."); return 0; }
        if (devices.Count != 1) { Log("Multiple devices: select one using --device <instance-id>."); return 4; }
        var device = devices[0];
        if (recover) selected ??= device.InstanceId;
        int interfaceResult = RecoveryPolicy.InterfaceResult(device.Service, device.Paths.Count, recover);
        if (interfaceResult == 9)
        { Log("NOT FOUND: WinUSB device interface is not ready; waiting for Windows to restore USB after resume/disconnect. Driver unchanged."); return 9; }
        if (interfaceResult != 0)
        { Log($"Cannot probe: Service={device.Service}, path count={device.Paths.Count}; expected WINUSB and one interface. Driver unchanged."); return interfaceResult; }
        using var inputMode = new ConsoleInputMode();
        using var lease = new DeviceLease(device.InstanceId);
        using var usb = new WinUsbTransport(device.Paths[0], timeout, Log);
        if (resetPipes) { usb.ResetPipes(); Log("WinUSB pipe stalls cleared at explicit request; driver unchanged."); }
        var request = LyProtocol.CreateProbe();
        File.WriteAllBytes(stem + "-tx.bin", request);
        Dump("TX prepared (device info)", request);
        usb.Write(request); Log("TX complete: 2048 bytes");
        var response = usb.Read();
        File.WriteAllBytes(stem + "-rx.bin", response);
        Dump("RX", response);
        if (!LyProtocol.IsValidResponse(response)) { Log("FAIL: expected 512 bytes, [0]=03 [1]=FF [8]=01."); return recover ? 9 : 7; }
        Log($"PASS: LY handshake confirmed. Raw ID[16..19]={Convert.ToHexString(response.AsSpan(16, 4))}; raw[20]={response[20]}; raw[22]={response[22]}.");
        if (pattern || demo || monitor)
        {
            int pm = 64 + (response[20] <= 3 ? 1 : response[20]);
            int sub = response[22] + 1;
            if (pm != 65 && pm != 66) { Log($"Unsupported panel PM={pm}, SUB={sub}; no image sent."); return 5; }
            int angle = rotation ?? (sub is 2 or 3 or 4 ? 0 : 180);
            Log($"Panel profile PM={pm}, SUB={sub}: test canvas 1920x462, rotation={angle}");
            Snapshot? currentSnapshot = null;
            byte[] RenderLive(string? path) {
                currentSnapshot = sampler.Read();
                return Dashboard.Create(currentSnapshot, path, angle, thresholds, display);
            }
            var jpeg = monitor ? RenderLive(stem + "-preview.png") : TestPattern.Create(stem + "-preview.png", angle, demo ? 1 : null, 0);
            File.WriteAllBytes(stem + "-first.jpg", jpeg);
            var frame = LyFrame.Pack(jpeg);
            File.WriteAllBytes(stem + "-frame.bin", frame);
            var transfers = LyFrame.Transfers(frame, usbBlockSize).ToArray();
            var sessionTime = Stopwatch.StartNew();
            int frameNumber = 0;
            var lastFrameUtc = DateTime.UtcNow;
            long totalBytes = 0;
            double maxTransferMs = 0, maxRenderMs = 0;
            var metrics = new RunMetrics();
            double nextReport = 0, nextSensorCheck = 0;
            HardwareSnapshot? lastSensors = null;
            string outcome = "failed";
            string? failure = null;
            byte[]? lastAck = null;

            Log($"Display session: {(monitor ? "live monitor" : demo ? "dynamic demo" : "static pattern")}, {(continuous ? "until Ctrl+C" : holdSeconds + "s")}, target={fps} FPS; Ctrl+C stops between frames. JPEG={jpeg.Length} bytes, rotation={angle}.");
            Log($"USB transfer settings: block={usbBlockSize} bytes; inter-block pause={blockDelayMs} ms. Paced default passed a 180s test; faster overrides remain experimental.");
            try
            {
            do
            {
                if (cancellation.IsCancellationRequested) break;
                if (recover && frameNumber > 0 && DateTime.UtcNow - lastFrameUtc > TimeSpan.FromSeconds(10)) throw new TimeoutException("Long pause/sleep: reopening USB.");
                var cycle = Stopwatch.StartNew();
                if ((demo || monitor) && frameNumber > 0)
                {
                    jpeg = monitor ? RenderLive(null) : TestPattern.Create(null, angle, frameNumber + 1, sessionTime.Elapsed.TotalSeconds);
                    frame = LyFrame.Pack(jpeg);
                    transfers = LyFrame.Transfers(frame, usbBlockSize).ToArray();
                    maxRenderMs = Math.Max(maxRenderMs, cycle.Elapsed.TotalMilliseconds);
                }
                int block = 0;
                var transferTime = Stopwatch.StartNew();
                FrameReceipt receipt;
                try
                {
                    receipt = FrameSender.Send(transfers, bytes => { if (block > 0 && blockDelayMs > 0) Thread.Sleep(blockDelayMs); block++; usb.Write(bytes); }, usb.Read,
                        verbose && frameNumber == 0 ? (index, bytes) => Log($"FRAME TX block={index + 1}/{transfers.Length}, bytes={bytes.Length}") : null);
                }
                catch
                {
                    File.WriteAllBytes(stem + "-failed.jpg", jpeg);
                    File.WriteAllBytes(stem + "-failed-frame.bin", frame);
                    Log($"FRAME FAILED: number={frameNumber + 1}, last attempted OUT block={block}/{transfers.Length}, JPEG={jpeg.Length}, elapsed={sessionTime.Elapsed.TotalSeconds:F3}s; no retry.");
                    throw;
                }
                maxTransferMs = Math.Max(maxTransferMs, transferTime.Elapsed.TotalMilliseconds);
                lastAck = receipt.Ack;
                totalBytes += receipt.Bytes;
                frameNumber++; lastFrameUtc = DateTime.UtcNow; liveStatus.Frame(jpeg, angle, currentSnapshot);
                if (frameNumber == 1) { Dump("FRAME ACK", receipt.Ack); if (recover) Log("SESSION connected: frames flowing."); }
                metrics.Frame(sessionTime.Elapsed.TotalMilliseconds);
                if (monitor && sessionTime.Elapsed.TotalSeconds >= nextSensorCheck)
                {
                    lastSensors = sampler.Read().Hardware;
                    metrics.Sensors(sessionTime.Elapsed.TotalSeconds, lastSensors);
                    nextSensorCheck = sessionTime.Elapsed.TotalSeconds + 1;
                }
                if (sessionTime.Elapsed.TotalSeconds >= nextReport)
                {
                    Log($"PROGRESS: frames={frameNumber}, elapsed={sessionTime.Elapsed.TotalSeconds:F1}s, avg={frameNumber / Math.Max(.001, sessionTime.Elapsed.TotalSeconds):F2} FPS, gaps>2s={metrics.GapsOver2Seconds}; CPU={lastSensors?.CpuTemperature} C, GPU={lastSensors?.GpuTemperature} C");
                    if (verbose && monitor) Log("SENSORS " + System.Text.Json.JsonSerializer.Serialize(lastSensors));
                    var progress = new { outcome = "running", frameNumber, elapsedSeconds = sessionTime.Elapsed.TotalSeconds, metrics, lastSensors };
                    File.WriteAllText(stem + "-progress.json.tmp", System.Text.Json.JsonSerializer.Serialize(progress));
                    File.Move(stem + "-progress.json.tmp", stem + "-progress.json", true);
                    nextReport = sessionTime.Elapsed.TotalSeconds + (verbose ? 5 : 60);
                }
                if (RunMetrics.Finished(continuous, holdSeconds, sessionTime.Elapsed.TotalSeconds)) break;
                int wait = (int)Math.Max(0, 1000.0 / fps - cycle.Elapsed.TotalMilliseconds);
                if (!continuous && holdSeconds > 0) wait = Math.Min(wait, (int)Math.Max(0, holdSeconds * 1000 - sessionTime.Elapsed.TotalMilliseconds));
                cancellation.Token.WaitHandle.WaitOne(wait);
            } while (!cancellation.IsCancellationRequested && !RunMetrics.Finished(continuous, holdSeconds, sessionTime.Elapsed.TotalSeconds));
            outcome = cancellation.IsCancellationRequested ? "cancelled" : "completed";
            }
            catch (Exception e) { failure = e.Message; throw; }
            finally
            {

                if (lastAck != null) File.WriteAllBytes(stem + "-frame-ack.bin", lastAck);
                File.WriteAllBytes(stem + "-last.jpg", jpeg);
                var summary = new { version = "0.1.7", mode = monitor ? "monitor" : demo ? "demo" : "test-pattern", outcome, failure,
                    completedFrames = frameNumber, elapsedSeconds = sessionTime.Elapsed.TotalSeconds, targetFps = fps, usbBlockSize, blockDelayMs,
                    averageFps = frameNumber / Math.Max(0.001, sessionTime.Elapsed.TotalSeconds), totalBytes, maxTransferMs, maxRenderMs, continuous, requestedSeconds = continuous ? (int?)null : holdSeconds, metrics, lastSensors };
                File.WriteAllText(stem + "-summary.json", System.Text.Json.JsonSerializer.Serialize(summary, new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
                if (File.Exists(stem + "-progress.json")) File.Delete(stem + "-progress.json");
                Log($"SESSION {outcome}: {frameNumber} completed frames, {sessionTime.Elapsed.TotalSeconds:F2}s, avg {summary.averageFps:F2} FPS. Summary: {stem}-summary.json");
            }
        }
        return 0;
    }
    catch (Exception e)
    {
        Log($"FAIL: {(verbose ? e.ToString() : e.Message)}");
        if (e is Win32Exception w) Log($"Win32 error={w.NativeErrorCode} (0x{w.NativeErrorCode:X8}); 5=access denied, 32=busy, 121=timeout, 1167=disconnected.");
        return recover && RecoveryPolicy.IsTransient(e) ? 9 : 6;
    }
}
catch (Exception e) { Console.Error.WriteLine($"Cannot initialize log: {e.Message}"); return 6; }













}
