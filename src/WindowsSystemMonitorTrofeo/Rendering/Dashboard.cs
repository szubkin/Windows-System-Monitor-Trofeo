using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using WindowsSystemMonitorTrofeo.Monitoring;

namespace WindowsSystemMonitorTrofeo.Rendering;

public static class Dashboard
{
    public static byte[] Create(Snapshot data, string? previewPath, int rotation, TemperatureThresholds? thresholds = null)
    {
        if (rotation is not (0 or 180)) throw new ArgumentOutOfRangeException(nameof(rotation));
        thresholds ??= new TemperatureThresholds(); thresholds.Validate();
        using var canvas = new Bitmap(1920, 462, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(canvas))
        {
            g.Clear(Color.FromArgb(9, 15, 23));
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            using var heading = new Font("Segoe UI", 25, FontStyle.Bold, GraphicsUnit.Pixel);
            using var large = new Font("Segoe UI", 64, FontStyle.Bold, GraphicsUnit.Pixel);
            using var medium = new Font("Segoe UI", 30, FontStyle.Regular, GraphicsUnit.Pixel);
            using var small = new Font("Segoe UI", 21, FontStyle.Regular, GraphicsUnit.Pixel);
            using var tiny = new Font("Segoe UI", 17, FontStyle.Regular, GraphicsUnit.Pixel);
            using var accent = new SolidBrush(Color.FromArgb(68, 226, 198));
            using var blue = new SolidBrush(Color.FromArgb(105, 166, 255));
            using var muted = new SolidBrush(Color.FromArgb(145, 164, 182));
            using var panel = new SolidBrush(Color.FromArgb(17, 27, 39));
            using var track = new SolidBrush(Color.FromArgb(34, 49, 65));
            using var grid = new Pen(Color.FromArgb(34, 49, 65));
            g.FillEllipse(accent, 32, 29, 9, 9);
            g.DrawString("TROFEO", heading, Brushes.White, 53, 16);
            g.DrawString("SYSTEM MONITOR", tiny, muted, 175, 25);
            g.DrawString(DateTime.Now.ToString("HH:mm:ss"), medium, Brushes.White, 1755, 13);
            const int cardWidth = 358, gap = 16, margin = 33;
            int[] xs = Enumerable.Range(0, 5).Select(i => margin + i * (cardWidth + gap)).ToArray();

            string[] labels = ["CPU", "GPU", "MEMORY", "NETWORK", "DISK " + data.DiskName.TrimEnd('\\')];
            for (int i = 0; i < xs.Length; i++)
            {
                g.FillRectangle(panel, xs[i], 78, cardWidth, 329);
                g.FillRectangle(accent, xs[i] + 20, 98, 24, 3);
                g.DrawString(labels[i], small, muted, xs[i] + 20, 108);
            }
            string N(double? n, string format = "F1") => n.HasValue && double.IsFinite(n.Value) ? n.Value.ToString(format) : "—";
            string P(double? n) => n.HasValue ? N(n, "F0") + "%" : "—";
            string T(double? n) => n.HasValue ? N(n, "F0") + " °C" : "— °C";
            var hw = data.Hardware;
            using var cpuTemperatureBrush = new SolidBrush(TemperatureThresholds.ColorFor(hw?.CpuTemperature, thresholds.CpuYellow, thresholds.CpuRed));
            using var gpuTemperatureBrush = new SolidBrush(TemperatureThresholds.ColorFor(hw?.GpuTemperature, thresholds.GpuYellow, thresholds.GpuRed));
            g.DrawString(P(data.Cpu), large, Brushes.White, xs[0] + 18, 140);
            g.DrawString(T(hw?.CpuTemperature), medium, cpuTemperatureBrush, xs[0] + 20, 218);
            g.DrawString(N(hw?.CpuClockMHz / 1000, "F2") + " GHz", small, muted, xs[0] + 196, 227);
            g.DrawString(P(hw?.GpuLoad), large, Brushes.White, xs[1] + 18, 140);
            g.DrawString(T(hw?.GpuTemperature), medium, gpuTemperatureBrush, xs[1] + 20, 218);
            g.DrawString("VRAM " + N(hw?.VramUsedMiB / 1024) + " / " + N(hw?.VramTotalMiB / 1024) + " GiB", tiny, muted, xs[1] + 144, 229);
            var points = data.History ?? [];
            void Chart(int x, int y, int width, int height, Func<HistoryPoint, double?> select, double max, Color color, bool background = true)
            {
                if (background) for (int line = 0; line < 3; line++) g.DrawLine(grid, x, y + line * height / 2, x + width, y + line * height / 2);
                if (points.Length < 2) return;
                double now = points[^1].Seconds;
                PointF? prior = null;
                double priorTime = 0;
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
            Chart(xs[0] + 20, 278, cardWidth - 40, 88, p => p.Cpu, 100, accent.Color);
            Chart(xs[1] + 20, 278, cardWidth - 40, 88, p => p.Gpu, 100, accent.Color);
            g.DrawString("60s", tiny, muted, xs[0] + 20, 377);
            g.DrawString("0–100%", tiny, muted, xs[0] + cardWidth - 85, 377);
            g.DrawString("60s", tiny, muted, xs[1] + 20, 377);
            g.DrawString("0–100%", tiny, muted, xs[1] + cardWidth - 85, 377);
            void Bar(int x, int y, int width, double? percent)
            {
                g.FillRectangle(track, x, y, width, 8);
                if (percent.HasValue) g.FillRectangle(accent, x, y, width * (float)Math.Clamp(percent.Value / 100, 0, 1), 8);
            }
            g.DrawString(P(data.MemoryPercent), large, Brushes.White, xs[2] + 18, 140);
            Bar(xs[2] + 20, 239, cardWidth - 40, data.MemoryPercent);
            g.DrawString(N(data.UsedGiB) + " GiB", medium, Brushes.White, xs[2] + 20, 280);
            g.DrawString("of " + N(data.TotalGiB) + " GiB", small, muted, xs[2] + 20, 323);
            g.DrawString("IN", tiny, accent, xs[3] + 20, 157);
            g.DrawString(N(data.ReceiveBytes / 1048576, "F2"), medium, Brushes.White, xs[3] + 70, 145);
            g.DrawString("MiB/s", tiny, muted, xs[3] + cardWidth - 80, 157);
            g.DrawString("OUT", tiny, blue, xs[3] + 20, 208);
            g.DrawString(N(data.SendBytes / 1048576, "F2"), medium, Brushes.White, xs[3] + 70, 196);
            g.DrawString("MiB/s", tiny, muted, xs[3] + cardWidth - 80, 208);
            double networkMax = Math.Max(1048576, points.SelectMany(p => new[] { p.Receive ?? 0, p.Send ?? 0 }).DefaultIfEmpty(0).Max());
            Chart(xs[3] + 20, 278, cardWidth - 40, 88, p => p.Receive, networkMax, accent.Color);
            Chart(xs[3] + 20, 278, cardWidth - 40, 88, p => p.Send, networkMax, blue.Color, false);
            g.DrawString("60s", tiny, muted, xs[3] + 20, 377);
            g.DrawString("max " + (networkMax / 1048576).ToString("F1") + " MiB/s", tiny, muted, xs[3] + 170, 377);
            g.DrawString(N(data.DiskFreeGiB), large, Brushes.White, xs[4] + 18, 140);
            g.DrawString("GiB free", tiny, muted, xs[4] + 252, 185);
            Bar(xs[4] + 20, 239, cardWidth - 40, data.DiskUsedPercent);
            g.DrawString(P(data.DiskUsedPercent) + " used", small, muted, xs[4] + 20, 260);
            g.DrawString(T(hw?.DiskTemperature), small, accent, xs[4] + cardWidth - 90, 260);
            g.DrawString("READ", tiny, muted, xs[4] + 20, 307);
            g.DrawString(N(hw?.DiskReadBytes / 1048576, "F2") + " MiB/s", small, Brushes.White, xs[4] + 142, 301);
            g.DrawString("WRITE", tiny, muted, xs[4] + 20, 354);
            g.DrawString(N(hw?.DiskWriteBytes / 1048576, "F2") + " MiB/s", small, Brushes.White, xs[4] + 142, 348);
            var name = hw?.GpuName ?? "GPU unavailable";
            using var format = new StringFormat { Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap };
            void DeviceLabel(string text, int x)
            {
                float size = 17;
                while (size > 13)
                {
                    using var candidate = new Font("Segoe UI", size, FontStyle.Regular, GraphicsUnit.Pixel);
                    if (g.MeasureString(text, candidate).Width <= cardWidth) break;
                    size--;
                }
                using var font = new Font("Segoe UI", size, FontStyle.Regular, GraphicsUnit.Pixel);
                g.DrawString(text, font, muted, new RectangleF(x, 428, cardWidth, 26), format);
            }
            DeviceLabel(MachineIdentity.CpuName, xs[0]);
            DeviceLabel(name, xs[1]);
            using var right = new StringFormat { Alignment = StringAlignment.Far, FormatFlags = StringFormatFlags.NoWrap };
            string version = typeof(Dashboard).Assembly.GetName().Version?.ToString(3) ?? "unknown";
            g.DrawString("v" + version, tiny, muted, new RectangleF(xs[4], 428, cardWidth, 25), right);
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

