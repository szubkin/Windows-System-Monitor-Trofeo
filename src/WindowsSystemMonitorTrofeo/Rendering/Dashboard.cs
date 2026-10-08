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
        using var canvas = new Bitmap(1920, 462, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(canvas))
        {
            g.Clear(Color.FromArgb(9, 15, 23));
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            float scale = display.TextPercent / 100f;
            using var heading = new Font("Segoe UI", 25, FontStyle.Bold, GraphicsUnit.Pixel);
            using var large = new Font("Segoe UI", 64 * scale, FontStyle.Bold, GraphicsUnit.Pixel);
            using var medium = new Font("Segoe UI", 30 * scale, FontStyle.Regular, GraphicsUnit.Pixel);
            using var small = new Font("Segoe UI", 21 * scale, FontStyle.Regular, GraphicsUnit.Pixel);
            using var tiny = new Font("Segoe UI", 17 * scale, FontStyle.Regular, GraphicsUnit.Pixel);
            using var accent = new SolidBrush(display.AccentColor);
            using var blue = new SolidBrush(Color.FromArgb(105, 166, 255));
            using var muted = new SolidBrush(Color.FromArgb(145, 164, 182));
            using var panel = new SolidBrush(Color.FromArgb(17, 27, 39));
            using var track = new SolidBrush(Color.FromArgb(34, 49, 65));
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
            g.FillEllipse(accent, 32, 29, 9, 9);
            g.DrawString("TROFEO", heading, Brushes.White, 53, 16);
            g.DrawString("SYSTEM MONITOR", tiny, muted, 175, 25);
            g.DrawString(DateTime.Now.ToString("HH:mm:ss"), medium, Brushes.White, 1730, 13);
            var blocks = display.VisibleBlocks;
            const int gap = 16, margin = 33;
            float cardWidth = (1920 - margin * 2 - gap * (blocks.Length - 1)) / (float)blocks.Length;
            string N(double? n, string f = "F1") => n.HasValue && double.IsFinite(n.Value) ? n.Value.ToString(f) : "—";
            string P(double? n) => n.HasValue && double.IsFinite(n.Value) ? N(n, "F0") + "%" : "—";
            string T(double? n) => n.HasValue && double.IsFinite(n.Value) ? N(n, "F0") + " °C" : "— °C";
            var hw = data.Hardware;
            using var cpuTemperature = new SolidBrush(TemperatureThresholds.ColorFor(hw?.CpuTemperature, thresholds.CpuYellow, thresholds.CpuRed));
            using var gpuTemperature = new SolidBrush(TemperatureThresholds.ColorFor(hw?.GpuTemperature, thresholds.GpuYellow, thresholds.GpuRed));
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
                Text(blocks[i] == "DISK" ? "DISK " + data.DiskName.TrimEnd((char)92) : blocks[i], small, muted, x + 20, 108, inner);
                switch (blocks[i])
                {
                    case "CPU":
                        string cpuMain = display.CpuMetric switch { "temperature" => T(hw?.CpuTemperature), "clock" => N(hw?.CpuClockMHz / 1000, "F2") + " GHz", _ => P(data.Cpu) };
                        Text(cpuMain, large, display.CpuMetric == "temperature" ? cpuTemperature : Brushes.White, x + 18, 140, inner, 78);
                        Secondary(display.CpuMetric == "temperature" ? P(data.Cpu) : T(hw?.CpuTemperature), medium, display.CpuMetric == "temperature" ? muted : cpuTemperature, x + 20, inner * .48f);
                        Secondary(display.CpuMetric == "clock" ? P(data.Cpu) : N(hw?.CpuClockMHz / 1000, "F2") + " GHz", small, muted, x + 20 + inner * .52f, inner * .48f, true);
                        Chart(x + 20, p => p.Cpu, 100, accent.Color);
                        if (display.Graphs) { Text("60s", tiny, muted, x + 20, 377, 60); Text("LOAD 0–100%", tiny, muted, x + cardWidth - 160, 377, 140); }
                        if (display.DeviceNames) Text(MachineIdentity.CpuName, tiny, muted, x, 428, cardWidth - (i == blocks.Length - 1 ? 155 : 0), 26);
                        break;
                    case "GPU":
                        string gpuMain = display.GpuMetric switch { "temperature" => T(hw?.GpuTemperature), "vram" => N(hw?.VramUsedMiB / 1024) + " GiB", _ => P(hw?.GpuLoad) };
                        Text(gpuMain, large, display.GpuMetric == "temperature" ? gpuTemperature : Brushes.White, x + 18, 140, inner, 78);
                        Secondary(display.GpuMetric == "temperature" ? P(hw?.GpuLoad) : T(hw?.GpuTemperature), medium, display.GpuMetric == "temperature" ? muted : gpuTemperature, x + 20, inner * .37f);
                        Secondary(display.GpuMetric == "vram" ? P(hw?.GpuLoad) : "VRAM " + N(hw?.VramUsedMiB / 1024) + " / " + N(hw?.VramTotalMiB / 1024) + " GiB", tiny, muted, x + 20 + inner * .41f, inner * .59f, true);
                        Chart(x + 20, p => p.Gpu, 100, accent.Color);
                        if (display.Graphs) { Text("60s", tiny, muted, x + 20, 377, 60); Text("LOAD 0–100%", tiny, muted, x + cardWidth - 160, 377, 140); }
                        if (display.DeviceNames) Text(hw?.GpuName ?? "GPU unavailable", tiny, muted, x, 428, cardWidth - (i == blocks.Length - 1 ? 155 : 0), 26);
                        break;
                    case "MEMORY":
                        Text(P(data.MemoryPercent), large, Brushes.White, x + 18, 140, inner, 78);
                        Bar(x + 20, data.MemoryPercent);
                        Text(N(data.UsedGiB) + " GiB", medium, Brushes.White, x + 20, 280, inner);
                        Text("of " + N(data.TotalGiB) + " GiB", small, muted, x + 20, 323, inner);
                        if (display.DeviceNames) Text(data.MemoryName ?? "RAM · —", tiny, muted, x, 428, cardWidth - (i == blocks.Length - 1 ? 155 : 0), 26);
                        break;
                    case "NETWORK":
                        Text("IN", tiny, accent, x + 20, 157, 45);
                        Text(N(data.ReceiveBytes / 1048576, "F2"), medium, Brushes.White, x + 70, 145, inner - 120);
                        Text("MiB/s", tiny, muted, x + cardWidth - 80, 157, 60);
                        Text("OUT", tiny, blue, x + 20, 208, 45);
                        Text(N(data.SendBytes / 1048576, "F2"), medium, Brushes.White, x + 70, 196, inner - 120);
                        Text("MiB/s", tiny, muted, x + cardWidth - 80, 208, 60);
                        double max = Math.Max(1048576, points.SelectMany(p => new[] { p.Receive ?? 0, p.Send ?? 0 }).DefaultIfEmpty(0).Max());
                        Chart(x + 20, p => p.Receive, max, accent.Color);
                        Chart(x + 20, p => p.Send, max, blue.Color, false);
                        if (display.Graphs) { Text("60s", tiny, muted, x + 20, 377, 60); Text("max " + (max / 1048576).ToString("F1") + " MiB/s", tiny, muted, x + 110, 377, inner - 90); }
                        if (display.DeviceNames) Text(data.NetworkName ?? "Адаптер недоступен", tiny, muted, x, 428, cardWidth - (i == blocks.Length - 1 ? 155 : 0), 26);
                        break;
                    case "DISK":
                        Text(N(data.DiskFreeGiB), large, Brushes.White, x + 18, 140, inner - 90, 78);
                        Text("GiB free", tiny, muted, x + cardWidth - 100, 185, 80);
                        Bar(x + 20, data.DiskUsedPercent);
                        Text(P(data.DiskUsedPercent) + " used", small, muted, x + 20, 260, inner - 95);
                        Text(T(hw?.DiskTemperature), small, accent, x + cardWidth - 110, 260, 90);
                        Text("READ", tiny, muted, x + 20, 307, 85);
                        Text(N(hw?.DiskReadBytes / 1048576, "F2") + " MiB/s", small, Brushes.White, x + 142, 301, cardWidth - 162);
                        Text("WRITE", tiny, muted, x + 20, 354, 85);
                        Text(N(hw?.DiskWriteBytes / 1048576, "F2") + " MiB/s", small, Brushes.White, x + 142, 348, cardWidth - 162);
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
