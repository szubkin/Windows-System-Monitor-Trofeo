using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;

namespace WindowsSystemMonitorTrofeo.Rendering;

public static class TestPattern
{
    public const int Width = 1920, Height = 462;
    public static byte[] Create(string? previewPath, int rotation, int? demoFrame = null, double elapsed = 0)
    {
        if (rotation != 0 && rotation != 180) throw new ArgumentOutOfRangeException(nameof(rotation));
        using var canvas = new Bitmap(Width, Height, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(canvas))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.Clear(Color.FromArgb(10, 19, 30));
            using var accent = new SolidBrush(Color.FromArgb(61, 222, 197));
            using var muted = new SolidBrush(Color.FromArgb(156, 177, 197));
            using var title = new Font("Segoe UI", 46, FontStyle.Bold, GraphicsUnit.Pixel);
            using var subtitle = new Font("Segoe UI", 28, FontStyle.Regular, GraphicsUnit.Pixel);
            using var small = new Font("Consolas", 20, FontStyle.Regular, GraphicsUnit.Pixel);
            using var outline = new Pen(Color.FromArgb(61, 222, 197), 3);
            g.DrawRectangle(outline, 3, 3, Width - 7, Height - 7);
            g.FillRectangle(accent, 40, 50, 8, 112);
            g.DrawString("WINDOWS SYSTEM MONITOR", title, Brushes.White, 72, 48);
            g.DrawString("TROFEO  /  FIRST LIGHT", subtitle, accent, 74, 112);
            g.DrawString("v0.1.0     1920 x 462     DIRECT WINUSB", small, muted, 76, 159);
            if (demoFrame is int frame)
            {
                g.DrawString("DYNAMIC FRAME TEST", subtitle, accent, 1130, 53);
                g.DrawString($"FRAME {frame:D6}   TIME {elapsed:000.0}s", small, Brushes.White, 1134, 97);
                g.DrawString(DateTime.Now.ToString("HH:mm:ss"), subtitle, Brushes.White, 1650, 53);
                using var track = new SolidBrush(Color.FromArgb(21, 36, 51));
                g.FillRectangle(track, 1135, 144, 665, 14);
                g.FillRectangle(accent, 1135 + (int)(elapsed * 180 % 605), 144, 60, 14);
            }
            g.DrawString("TOP LEFT", small, accent, 28, 14);
            g.DrawString("TOP RIGHT", small, accent, 1760, 14);
            string[] labels = ["CPU", "GPU", "RAM", "NET", "DISK"];
            for (int i = 0; i < labels.Length; i++)
            {
                int x = 76 + i * 355;
                using var card = new SolidBrush(Color.FromArgb(21, 36, 51));
                g.FillRectangle(card, x, 221, 327, 94);
                g.DrawString(labels[i], subtitle, Brushes.White, x + 18, 235);
                g.DrawString("TEST PATTERN", small, muted, x + 18, 277);
            }
            Color[] colors = [Color.Red, Color.Lime, Color.Blue, Color.Cyan, Color.Magenta, Color.Yellow, Color.White];
            for (int i = 0; i < colors.Length; i++)
            {
                using var brush = new SolidBrush(colors[i]);
                g.FillRectangle(brush, 76 + i * 252, 351, 252, 49);
            }
            g.DrawString("BOTTOM LEFT", small, muted, 28, 427);
            g.DrawString(demoFrame.HasValue ? "DYNAMIC TEST - NO LIVE SENSOR DATA" : "STATIC IMAGE - NO LIVE SENSOR DATA", small, muted, 710, 423);
            g.DrawString("BOTTOM RIGHT", small, muted, 1730, 427);
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






