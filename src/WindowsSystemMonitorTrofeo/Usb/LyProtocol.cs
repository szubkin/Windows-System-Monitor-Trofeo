namespace WindowsSystemMonitorTrofeo.Usb;

public static class LyProtocol
{
    public static byte[] CreateProbe()
    {
        var data = new byte[2048];
        data[0] = 0x02; data[1] = 0xFF; data[8] = 0x01;
        return data;
    }

    public static bool IsValidResponse(ReadOnlySpan<byte> data) =>
        data.Length == 512 && data[0] == 0x03 && data[1] == 0xFF && data[8] == 0x01;
}
