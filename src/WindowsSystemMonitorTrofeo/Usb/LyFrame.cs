using System.Buffers.Binary;

namespace WindowsSystemMonitorTrofeo.Usb;

public static class LyFrame
{
    public const int MaxJpegBytes = 449999;

    // LY has a terminal partial chunk, including a zero-length one at exact boundaries.
    // Header count excludes the all-zero alignment blocks.
    public static byte[] Pack(ReadOnlySpan<byte> payload)
    {
        if (payload.Length == 0 || payload.Length > MaxJpegBytes)
            throw new ArgumentOutOfRangeException(nameof(payload));
        int count = payload.Length / 496 + 1;
        var frame = new byte[((count + 3) / 4 * 4) * 512];
        for (int i = 0; i < count; i++)
        {
            var chunk = frame.AsSpan(i * 512, 512);
            int length = Math.Min(496, payload.Length - i * 496);
            chunk[0] = 1; chunk[1] = 255; chunk[8] = 1;
            BinaryPrimitives.WriteUInt32LittleEndian(chunk[2..], (uint)payload.Length);
            BinaryPrimitives.WriteUInt16LittleEndian(chunk[6..], (ushort)length);
            BinaryPrimitives.WriteUInt16LittleEndian(chunk[9..], (ushort)count);
            BinaryPrimitives.WriteUInt16LittleEndian(chunk[11..], (ushort)i);
            payload.Slice(i * 496, length).CopyTo(chunk[16..]);
        }
        return frame;
    }

    public static IEnumerable<byte[]> Transfers(byte[] frame, int blockSize = 4096)
    {
        if (blockSize is not (2048 or 4096)) throw new ArgumentOutOfRangeException(nameof(blockSize));
        if (frame.Length == 0 || frame.Length % 2048 != 0) throw new ArgumentException("Unaligned LY frame");
        for (int offset = 0; offset < frame.Length; offset += blockSize)
            yield return frame.AsSpan(offset, Math.Min(blockSize, frame.Length - offset)).ToArray();
    }
}
