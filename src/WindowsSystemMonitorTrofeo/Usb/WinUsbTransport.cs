using Microsoft.Win32.SafeHandles;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace WindowsSystemMonitorTrofeo.Usb;

internal sealed class WinUsbTransport : IDisposable
{
    private readonly SafeFileHandle file;
    private IntPtr handle;
    internal WinUsbTransport(string path, uint timeout, Action<string> log)
    {
        file = Native.CreateFileW(path, 0xC0000000, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero);
        try
        {
            Native.Check(!file.IsInvalid, "CreateFile (close TRCC or other LCD software if busy)");
            Native.Check(Native.WinUsb_Initialize(file, out handle), "WinUsb_Initialize");
            Native.Check(Native.WinUsb_QueryInterfaceSettings(handle, 0, out var descriptor), "Query interface");
            log($"WinUSB opened. Interface={descriptor.Number}, alternate={descriptor.Alternate}, endpoints={descriptor.Endpoints}");
            var bulk = new HashSet<byte>();
            for (byte i = 0; i < descriptor.Endpoints; i++)
            {
                Native.Check(Native.WinUsb_QueryPipe(handle, 0, i, out var pipe), "Query pipe");
                log($"Endpoint 0x{pipe.Id:X2}: type={pipe.Type} (bulk=2), maxPacket={pipe.MaximumPacketSize}, interval={pipe.Interval}");
                if (pipe.Type == 2) bulk.Add(pipe.Id);
            }
            if (!bulk.Contains(0x09) || !bulk.Contains(0x81)) throw new InvalidOperationException("Expected bulk OUT 0x09 and IN 0x81 absent. No probe sent.");
            foreach (byte pipe in new byte[] { 0x09, 0x81 })
                Native.Check(Native.WinUsb_SetPipePolicy(handle, pipe, 3, 4, ref timeout), "Set PIPE_TRANSFER_TIMEOUT");
            log($"Read/write timeout={timeout} ms");
            foreach (var policy in new[] { (Id: 0x81u, Name: "AUTO_SUSPEND", Size: 1u), (Id: 0x83u, Name: "SUSPEND_DELAY_MS", Size: 4u) })
            {
                uint size = policy.Size;
                var value = new byte[size];
                if (Native.WinUsb_GetPowerPolicy(handle, policy.Id, ref size, value))
                    log($"Power policy (read only): {policy.Name}={(policy.Size == 1 ? value[0] : BitConverter.ToUInt32(value))}");
                else log($"Power policy {policy.Name}: unavailable, Win32={Marshal.GetLastWin32Error()}");
            }
        }
        catch { Dispose(); throw; }
    }
    internal void Write(byte[] data)
    {
        if (!Native.WinUsb_WritePipe(handle, 0x09, data, (uint)data.Length, out var sent, IntPtr.Zero))
            throw new Win32Exception(Marshal.GetLastWin32Error(), $"Bulk OUT 0x09: {sent}/{data.Length} bytes");
        if (sent != data.Length) throw new InvalidDataException($"Short write: {sent}/{data.Length}");
    }
    internal void ResetPipes()
    {
        Native.Check(Native.WinUsb_ResetPipe(handle, 0x09), "Reset stalled OUT pipe");
        Native.Check(Native.WinUsb_ResetPipe(handle, 0x81), "Reset stalled IN pipe");
    }
    internal byte[] Read()
    {
        var data = new byte[512];
        Native.Check(Native.WinUsb_ReadPipe(handle, 0x81, data, 512, out var received, IntPtr.Zero), "Bulk IN 0x81");
        return data[..(int)received];
    }
    public void Dispose()
    {
        if (handle != IntPtr.Zero) { Native.WinUsb_Free(handle); handle = IntPtr.Zero; }
        file.Dispose();
    }
}
