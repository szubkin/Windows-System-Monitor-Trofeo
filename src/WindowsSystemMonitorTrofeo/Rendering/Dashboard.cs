using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using WindowsSystemMonitorTrofeo.Monitoring;

namespace WindowsSystemMonitorTrofeo.Rendering;

public static class Dashboard
{
    public static byte[] Create(Snapshot data, string? previewPath, int rotation, TemperatureThresholds? thresholds = null, DisplayOptions? display = null)
    {
        if (rotation is not (0 or 180)) throw new ArgumentOutOfRangeException(nameof(rotation));
        thresholds ??= new(); thresholds.Validate();
        display ??= new(); display.Validate();
        string L(string en, string ru) => display.Language == "en" ? en : ru;
        var culture = System.Globalization.CultureInfo.GetCultureInfo(display.Language == "en" ? "en-US" : "ru-RU");
        string gib = L("GiB", "ГиБ"), mibps = L("MiB/s", "МиБ/с"), ghz = L("GHz", "ГГц");
        bool light = display.Theme == "light";
        using var foreground = new SolidBrush(light ? Color.FromArgb(25,42,55) : Color.White);
        using var canvas = new Bitmap(1920, 462, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(canvas))
        {
            g.Clear(light ? Color.FromArgb(237,242,246) : Color.FromArgb(9,15,23));
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            float scale = display.TextPercent / 100f;
            using var heading = new Font("Segoe UI", 25, FontStyle.Bold, GraphicsUnit.Pixel);
            using var large = new Font("Segoe UI", 64 * scale, FontStyle.Bold, GraphicsUnit.Pixel);
            using var medium = new Font("Segoe UI", 30 * scale, FontStyle.Regular, GraphicsUnit.Pixel);
            using var small = new Font("Segoe UI", 21 * scale, FontStyle.Regular, GraphicsUnit.Pixel);
            using var tiny = new Font("Segoe UI", 17 * scale, FontStyle.Regular, GraphicsUnit.Pixel);
            using var accent = new SolidBrush(light ? Color.FromArgb((int)(display.AccentColor.R*.65),(int)(display.AccentColor.G*.65),(int)(display.AccentColor.B*.65)) : display.AccentColor);
            using var blue = new SolidBrush(light ? Color.FromArgb(45,96,170) : Color.FromArgb(105,166,255));
            using var muted = new SolidBrush(light ? Color.FromArgb(78,99,117) : Color.FromArgb(145,164,182));
            using var panel = new SolidBrush(light ? Color.White : Color.FromArgb(17,27,39));
            using var track = new SolidBrush(light ? Color.FromArgb(210,221,230) : Color.FromArgb(34,49,65));
            using var grid = new Pen(track.Color);
            using var format = new StringFormat { Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap };
            void Text(string text, Font font, Brush brush, float x, float y, float width, float height = 40)
            {
                // Fit large readings inside their slot, including wide values and larger text settings.
                float size = font.Size;
                while (size > 12 && g.MeasureString(text, font).Width * size / font.Size > width) size--;
                using var fitted = new Font(font.FontFamily, size, font.Style, GraphicsUnit.Pixel);
                g.DrawString(text, fitted, brush, new RectangleF(x, y, width, height), format);
            }
            void Secondary(string text, Font font, Brush brush, float x, float width, bool alignRight = false)
            {
                using var rowFormat = new StringFormat(StringFormat.GenericTypographic) { Alignment = alignRight ? StringAlignment.Far : StringAlignment.Near, FormatFlags = StringFormatFlags.NoWrap, Trimming = StringTrimming.EllipsisCharacter };
                float size = font.Size;
                while (size > 12 && g.MeasureString(text, font, int.MaxValue, rowFormat).Width * size / font.Size > width) size--;
                using var fitted = new Font(font.FontFamily, size, font.Style, GraphicsUnit.Pixel);
                float ascent = fitted.Size * fitted.FontFamily.GetCellAscent(fitted.Style) / fitted.FontFamily.GetEmHeight(fitted.Style);
                g.DrawString(text, fitted, brush, new RectangleF(x, 262 - ascent, width, 45), rowFormat);
            }
            const int gap = 16, margin = 33;
            g.FillEllipse(accent, 32, 29, 9, 9);
            g.DrawString("TROFEO", heading, foreground, 53, 16);
            g.DrawString(L("SYSTEM MONITOR", "СИСТЕМНЫЙ МОНИТОР"), tiny, muted, 175, 25);
            using var clockFormat = new StringFormat(StringFormat.GenericTypographic) { Alignment = StringAlignment.Far, FormatFlags = StringFormatFlags.NoWrap };
            g.DrawString(DateTime.Now.ToString("HH:mm:ss"), medium, foreground, new RectangleF(margin, 13, 1920 - 2 * margin, 45), clockFormat);
            var blocks = display.VisibleBlocks;
            float cardWidth = (1920 - margin * 2 - gap * (blocks.Length - 1)) / (float)blocks.Length;
            string N(double? n, string f = "F1") => n.HasValue && double.IsFinite(n.Value) ? n.Value.ToString(f, culture) : "—";
            string P(double? n) => n.HasValue && double.IsFinite(n.Value) ? N(n, "F0") + "%" : "—";
            string T(double? n) => n.HasValue && double.IsFinite(n.Value) ? N(n, "F0") + " °C" : "— °C";
            var hw = data.Hardware;
            using var cpuTemperature = new SolidBrush(TemperatureThresholds.ColorFor(hw?.CpuTemperature, thresholds.CpuYellow, thresholds.CpuRed, light));
            using var gpuTemperature = new SolidBrush(TemperatureThresholds.ColorFor(hw?.GpuTemperature, thresholds.GpuYellow, thresholds.GpuRed, light));
            string Reading(bool cpu,string metric,bool main = false) => metric switch {
                "none"=>"",
                "load"=>P(cpu?data.Cpu:hw?.GpuLoad),
                "temperature"=>T(cpu?hw?.CpuTemperature:hw?.GpuTemperature),
                "clock"=>N(hw?.CpuClockMHz/1000,"F2")+" "+ghz,
                "vram"=>main ? N(hw?.VramUsedMiB/1024)+" "+gib : "VRAM "+N(hw?.VramUsedMiB/1024)+" / "+N(hw?.VramTotalMiB/1024)+" "+gib,
                "power"=>N(cpu?hw?.CpuPowerWatts:hw?.GpuPowerWatts,"F0")+L(" W"," Вт"),
                "fan"=>!cpu && hw?.GpuFanRpm==null && hw?.GpuFanPercent!=null ? L("FAN ","ВЕНТ. ")+P(hw.GpuFanPercent) : N(cpu?hw?.CpuFanRpm:hw?.GpuFanRpm,"F0")+L(" RPM"," об/мин"),
                _=>"—"
            };
            Brush Tone(bool cpu,string metric) => metric=="temperature"?(cpu?cpuTemperature:gpuTemperature):metric=="load"?foreground:muted;
            var points = data.History ?? [];
            void Chart(float x, Func<HistoryPoint, double?> select, double max, Color color, bool background = true)
            {
                if (!display.Graphs) return;
                const float y = 278, height = 88;
                float width = cardWidth - 40;
                if (background) for (int line = 0; line < 3; line++) g.DrawLine(grid, x, y + line * height / 2, x + width, y + line * height / 2);
                if (points.Length < 2) return;
                double now = points[^1].Seconds;
                PointF? prior = null; double priorTime = 0;
                using var pen = new Pen(color, 2.5f) { LineJoin = LineJoin.Round };
                foreach (var point in points)
                {
                    double? number = select(point);
                    if (!number.HasValue || !double.IsFinite(number.Value) || now - point.Seconds > 60) { prior = null; continue; }
                    var at = new PointF(x + (float)((point.Seconds - now + 60) / 60 * width), y + height * (float)(1 - Math.Clamp(number.Value / max, 0, 1)));
                    if (prior.HasValue && point.Seconds - priorTime <= 2.5) g.DrawLine(pen, prior.Value, at);
                    prior = at; priorTime = point.Seconds;
                }
            }
            void Bar(float x, double? percent)
            {
                g.FillRectangle(track, x, 239, cardWidth - 40, 8);
                if (percent.HasValue && double.IsFinite(percent.Value)) g.FillRectangle(accent, x, 239, (cardWidth - 40) * (float)Math.Clamp(percent.Value / 100, 0, 1), 8);
            }
            for (int i = 0; i < blocks.Length; i++)
            {
                float x = margin + i * (cardWidth + gap), inner = cardWidth - 40;
                g.FillRectangle(panel, x, 78, cardWidth, 329);
                g.FillRectangle(accent, x + 20, 98, 24, 3);
                Text((blocks[i] switch { "DISK" => L("DISK ", "ДИСК ") + data.DiskName.TrimEnd((char)92), "MEMORY" => L("MEMORY", "ПАМЯТЬ"), "NETWORK" => L("NETWORK", "СЕТЬ"), _ => blocks[i] }), small, muted, x + 20, 108, inner);
                switch (blocks[i])
                {
                    case "CPU":
                        Text(Reading(true,display.CpuMetric,true),large,display.CpuMetric=="temperature"?cpuTemperature:foreground,x+18,140,inner,78);
                        string cpuLeft=display.CpuSecondaryLeft=="auto"?(display.CpuMetric=="temperature"?"load":"temperature"):display.CpuSecondaryLeft;
                        string cpuRight=display.CpuSecondaryRight=="auto"?(display.CpuMetric=="clock"?"load":"clock"):display.CpuSecondaryRight;
                        Secondary(Reading(true,cpuLeft),cpuLeft=="fan"?tiny:medium,Tone(true,cpuLeft),x+20,inner*.48f);
                        Secondary(Reading(true,cpuRight),cpuRight=="fan"?tiny:small,Tone(true,cpuRight),x+20+inner*.52f,inner*.48f,true);
                        Chart(x + 20, p => p.Cpu, 100, accent.Color);
                        if (display.Graphs) { Text(L("60s", "60с"), tiny, muted, x + 20, 377, 60); Text(L("LOAD 0–100%", "ЗАГРУЗКА 0–100%"), tiny, muted, x + cardWidth - 160, 377, 140); }
                        if (display.DeviceNames) Text(MachineIdentity.CpuName == "CPU unavailable" ? L("CPU unavailable", "CPU недоступен") : MachineIdentity.CpuName, tiny, muted, x, 428, cardWidth - (i == blocks.Length - 1 ? 155 : 0), 26);
                        break;
                    case "GPU":
                        Text(Reading(false,display.GpuMetric,true),large,display.GpuMetric=="temperature"?gpuTemperature:foreground,x+18,140,inner,78);
                        string gpuLeft=display.GpuSecondaryLeft=="auto"?(display.GpuMetric=="temperature"?"load":"temperature"):display.GpuSecondaryLeft;
                        string gpuRight=display.GpuSecondaryRight=="auto"?(display.GpuMetric=="vram"?"load":"vram"):display.GpuSecondaryRight;
                        Secondary(Reading(false,gpuLeft),gpuLeft is "fan" or "vram"?tiny:medium,Tone(false,gpuLeft),x+20,inner*.40f);
                        Secondary(Reading(false,gpuRight),gpuRight is "vram" or "fan"?tiny:small,Tone(false,gpuRight),x+20+inner*.44f,inner*.56f,true);
                        Chart(x + 20, p => p.Gpu, 100, accent.Color);
                        if (display.Graphs) { Text(L("60s", "60с"), tiny, muted, x + 20, 377, 60); Text(L("LOAD 0–100%", "ЗАГРУЗКА 0–100%"), tiny, muted, x + cardWidth - 160, 377, 140); }
                        if (display.DeviceNames) Text(hw?.GpuName ?? L("GPU unavailable", "GPU недоступен"), tiny, muted, x, 428, cardWidth - (i == blocks.Length - 1 ? 155 : 0), 26);
                        break;
                    case "MEMORY":
                        Text(P(data.MemoryPercent), large, foreground, x + 18, 140, inner, 78);
                        Bar(x + 20, data.MemoryPercent);
                        Text(N(data.UsedGiB) + " " + gib, medium, foreground, x + 20, 280, inner);
                        Text(L("of ", "из ") + N(data.TotalGiB) + " " + gib, small, muted, x + 20, 323, inner);
                        if (display.DeviceNames) Text((data.MemoryName ?? "RAM · —").Replace(" MT/s", L(" MT/s", " МТ/с")), tiny, muted, x, 428, cardWidth - (i == blocks.Length - 1 ? 155 : 0), 26);
                        break;
                    case "NETWORK":
                        Text(L("IN", "ВХОД"), tiny, accent, x + 20, 157, 65);
                        Text(N(data.ReceiveBytes / 1048576, "F2"), medium, foreground, x + 90, 145, inner - 140);
                        Text(mibps, tiny, muted, x + cardWidth - 80, 157, 60);
                        Text(L("OUT", "ВЫХОД"), tiny, blue, x + 20, 208, 65);
                        Text(N(data.SendBytes / 1048576, "F2"), medium, foreground, x + 90, 196, inner - 140);
                        Text(mibps, tiny, muted, x + cardWidth - 80, 208, 60);
                        double max = Math.Max(1048576, points.SelectMany(p => new[] { p.Receive ?? 0, p.Send ?? 0 }).DefaultIfEmpty(0).Max());
                        Chart(x + 20, p => p.Receive, max, accent.Color);
                        Chart(x + 20, p => p.Send, max, blue.Color, false);
                        if (display.Graphs) { Text(L("60s", "60с"), tiny, muted, x + 20, 377, 60); Text(L("max ", "макс. ") + (max / 1048576).ToString("F1", culture) + " " + mibps, tiny, muted, x + 110, 377, inner - 90); }
                        if (display.DeviceNames) Text((data.NetworkName switch { "Все активные адаптеры" => L("All active adapters", "Все активные адаптеры"), null or "Адаптер недоступен" => L("Adapter unavailable", "Адаптер недоступен"), _ => data.NetworkName }), tiny, muted, x, 428, cardWidth - (i == blocks.Length - 1 ? 155 : 0), 26);
                        break;
                    case "DISK":
                        Text(N(data.DiskFreeGiB), large, foreground, x + 18, 140, inner - 90, 78);
                        Text(gib + L(" free", " своб."), tiny, muted, x + cardWidth - 100, 185, 80);
                        Bar(x + 20, data.DiskUsedPercent);
                        Text(P(data.DiskUsedPercent) + L(" used", " занято"), small, muted, x + 20, 260, inner - 95);
                        Text(T(hw?.DiskTemperature), small, accent, x + cardWidth - 110, 260, 90);
                        Text(L("READ", "ЧТЕНИЕ"), tiny, muted, x + 20, 307, 85);
                        Text(N(hw?.DiskReadBytes / 1048576, "F2") + " " + mibps, small, foreground, x + 142, 301, cardWidth - 162);
                        Text(L("WRITE", "ЗАПИСЬ"), tiny, muted, x + 20, 354, 85);
                        Text(N(hw?.DiskWriteBytes / 1048576, "F2") + " " + mibps, small, foreground, x + 142, 348, cardWidth - 162);
                        break;
                }
            }
            using var right = new StringFormat { Alignment = StringAlignment.Far, FormatFlags = StringFormatFlags.NoWrap };
            string version = typeof(Dashboard).Assembly.GetName().Version?.ToString(3) ?? "unknown";
            g.DrawString("v" + version, tiny, muted, new RectangleF(1710, 428, 175, 25), right);
        }
        if (previewPath != null) canvas.Save(previewPath, ImageFormat.Png);
        if (rotation == 180) canvas.RotateFlip(RotateFlipType.Rotate180FlipNone);
        var codec = ImageCodecInfo.GetImageEncoders().Single(c => c.FormatID == ImageFormat.Jpeg.Guid);
        using var options = new EncoderParameters(1);
        options.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 90L);
        using var stream = new MemoryStream();
        canvas.Save(stream, codec, options);
        var jpeg = stream.ToArray();
        if (jpeg.Length > Usb.LyFrame.MaxJpegBytes) throw new InvalidOperationException("JPEG exceeds LY limit");
        return jpeg;
    }
}
