using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace WindowsSystemMonitorTrofeo.Usb;

internal static class Native
{
    internal static void Check(bool ok, string operation)
    {
        if (!ok) throw new Win32Exception(Marshal.GetLastWin32Error(), operation);
    }
    [StructLayout(LayoutKind.Sequential)] internal struct DeviceData
    {
        public uint Size; public Guid ClassGuid; public uint DevInst; public IntPtr Reserved;
        public static DeviceData New() => new() { Size = (uint)Marshal.SizeOf<DeviceData>() };
    }
    [StructLayout(LayoutKind.Sequential)] internal struct InterfaceData
    {
        public uint Size; public Guid ClassGuid; public uint Flags; public IntPtr Reserved;
        public static InterfaceData New() => new() { Size = (uint)Marshal.SizeOf<InterfaceData>() };
    }
    [StructLayout(LayoutKind.Sequential, Pack = 1)] internal struct Descriptor
    {
        public byte Length, Type, Number, Alternate, Endpoints, Class, SubClass, Protocol, Index;
    }
    [StructLayout(LayoutKind.Sequential)] internal struct Pipe
    {
        public int Type; public byte Id; public ushort MaximumPacketSize; public byte Interval;
    }
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern IntPtr SetupDiGetClassDevsW(IntPtr guid, string? enumerator, IntPtr parent, uint flags);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern IntPtr SetupDiGetClassDevsW(ref Guid guid, string? enumerator, IntPtr parent, uint flags);
    [DllImport("setupapi.dll", SetLastError = true)] internal static extern bool SetupDiEnumDeviceInfo(IntPtr set, uint index, ref DeviceData data);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern bool SetupDiGetDeviceInstanceIdW(IntPtr set, ref DeviceData data, StringBuilder id, uint size, out uint required);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern bool SetupDiGetDeviceRegistryPropertyW(IntPtr set, ref DeviceData data, uint property, out uint type, byte[] buffer, uint size, out uint required);
    [DllImport("setupapi.dll", SetLastError = true)] internal static extern IntPtr SetupDiOpenDevRegKey(IntPtr set, ref DeviceData data, uint scope, uint profile, uint keyType, uint access);
    [DllImport("setupapi.dll", SetLastError = true)] internal static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, ref DeviceData device, ref Guid guid, uint index, ref InterfaceData data);
    [DllImport("setupapi.dll", SetLastError = true)] internal static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr device, ref Guid guid, uint index, ref InterfaceData data);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern bool SetupDiGetDeviceInterfaceDetailW(IntPtr set, ref InterfaceData data, IntPtr detail, uint size, out uint required, IntPtr device);
    [DllImport("setupapi.dll")] internal static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
    [DllImport("winusb.dll", SetLastError = true)] internal static extern bool WinUsb_Initialize(SafeFileHandle file, out IntPtr handle);
    [DllImport("winusb.dll")] internal static extern bool WinUsb_Free(IntPtr handle);
    [DllImport("winusb.dll", SetLastError = true)] internal static extern bool WinUsb_ResetPipe(IntPtr handle, byte pipe);
    [DllImport("winusb.dll", SetLastError = true)] internal static extern bool WinUsb_GetPowerPolicy(IntPtr handle, uint policy, ref uint length, [Out] byte[] value);
    [DllImport("winusb.dll", SetLastError = true)] internal static extern bool WinUsb_QueryInterfaceSettings(IntPtr handle, byte alternate, out Descriptor descriptor);
    [DllImport("winusb.dll", SetLastError = true)] internal static extern bool WinUsb_QueryPipe(IntPtr handle, byte alternate, byte index, out Pipe pipe);
    [DllImport("winusb.dll", SetLastError = true)] internal static extern bool WinUsb_SetPipePolicy(IntPtr handle, byte pipe, uint policy, uint length, ref uint value);
    [DllImport("winusb.dll", SetLastError = true)] internal static extern bool WinUsb_WritePipe(IntPtr handle, byte pipe, byte[] buffer, uint length, out uint transferred, IntPtr overlapped);
    [DllImport("winusb.dll", SetLastError = true)] internal static extern bool WinUsb_ReadPipe(IntPtr handle, byte pipe, [Out] byte[] buffer, uint length, out uint transferred, IntPtr overlapped);
}
