using System.Diagnostics;

namespace WindowsSystemMonitorTrofeo.Usb;

public sealed record FrameReceipt(int Writes, int Bytes, byte[] Ack);

public static class FrameSender
{
    // Cancellation is observed by the caller BETWEEN frames. Once the first block is
    // written, finish the frame and its reply so the next session starts at a boundary.
    public static FrameReceipt Send(byte[][] transfers, Action<byte[]> write, Func<byte[]> read,
        Action<int, byte[]>? trace = null)
    {
        if (transfers.Length == 0 || transfers.Any(t => t.Length is not (2048 or 4096)))
            throw new ArgumentException("Invalid LY transfer plan");
        var timer = Stopwatch.StartNew();
        int bytes = 0;
        for (int i = 0; i < transfers.Length; i++)
        {
            if (timer.ElapsedMilliseconds > 30000) throw new TimeoutException("Frame deadline exceeded; no automatic replay.");
            write(transfers[i]);
            bytes += transfers[i].Length;
            trace?.Invoke(i, transfers[i]);
        }
        var ack = read();
        if (!ValidAck(ack)) throw new InvalidDataException($"Invalid frame ACK ({ack.Length} bytes): {Convert.ToHexString(ack)}");
        return new(transfers.Length, bytes, ack);
    }

    public static bool ValidAck(ReadOnlySpan<byte> ack) => ack.Length == 512 && ack[0] == 3 && ack[1] == 255;
}
