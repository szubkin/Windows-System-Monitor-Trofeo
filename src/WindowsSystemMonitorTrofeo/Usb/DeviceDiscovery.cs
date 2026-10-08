using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;

namespace WindowsSystemMonitorTrofeo.Usb;

internal record TrofeoDevice(string InstanceId, string Service, List<string> Paths);

internal static class DeviceDiscovery
{
    internal static List<TrofeoDevice> Find(Action<string> log)
    {
        var result = new List<TrofeoDevice>();
        var set = Native.SetupDiGetClassDevsW(IntPtr.Zero, "USB", IntPtr.Zero, 6); // PRESENT | ALLCLASSES
        if (set == new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error());
        try
        {
            for (uint i = 0; ; i++)
            {
                var device = Native.DeviceData.New();
                if (!Native.SetupDiEnumDeviceInfo(set, i, ref device))
                {
                    if (Marshal.GetLastWin32Error() == 259) break;
                    Native.Check(false, "SetupDiEnumDeviceInfo");
                }
                var id = new StringBuilder(1024);
                Native.Check(Native.SetupDiGetDeviceInstanceIdW(set, ref device, id, 1024, out _), "Get instance ID");
                if (!id.ToString().Contains("VID_0416&PID_5408", StringComparison.OrdinalIgnoreCase)) continue;
                var buffer = new byte[4096];
                Native.Check(Native.SetupDiGetDeviceRegistryPropertyW(set, ref device, 4, out _, buffer, (uint)buffer.Length, out var length), "Read driver service");
                var service = Encoding.Unicode.GetString(buffer, 0, (int)length).TrimEnd('\0');
                log($"DEVICE {id}; Service={service}");
                var paths = new List<string>();
                var keyHandle = Native.SetupDiOpenDevRegKey(set, ref device, 1, 0, 1, 0x20019); // read only
                if (keyHandle == new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error(), "Read device registry key");
                using var safeKey = new SafeRegistryHandle(keyHandle, true);
                using var key = RegistryKey.FromHandle(safeKey);
                var raw = key.GetValue("DeviceInterfaceGUIDs") ?? key.GetValue("DeviceInterfaceGUID");
                var guids = raw switch { string[] values => values, string value => new[] { value }, _ => Array.Empty<string>() };
                foreach (var text in guids)
                {
                    if (!Guid.TryParse(text, out var guid)) { log($"Invalid interface GUID: {text}"); continue; }
                    log($"Interface GUID: {guid:B}");
                    var interfaceSet = Native.SetupDiGetClassDevsW(ref guid, id.ToString(), IntPtr.Zero, 18); // PRESENT | DEVICEINTERFACE
                    if (interfaceSet == new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error(), "Get interface set");
                    try
                    {
                    for (uint n = 0; ; n++)
                    {
                        var iface = Native.InterfaceData.New();
                        if (!Native.SetupDiEnumDeviceInterfaces(interfaceSet, IntPtr.Zero, ref guid, n, ref iface))
                        {
                            if (Marshal.GetLastWin32Error() == 259) break;
                            Native.Check(false, "Enum device interfaces");
                        }
                        Native.SetupDiGetDeviceInterfaceDetailW(interfaceSet, ref iface, IntPtr.Zero, 0, out var needed, IntPtr.Zero);
                        if (Marshal.GetLastWin32Error() != 122 || needed < 8) throw new Win32Exception(Marshal.GetLastWin32Error(), "Get interface detail size");
                        var detail = Marshal.AllocHGlobal((int)needed);
                        try
                        {
                            Marshal.WriteInt32(detail, IntPtr.Size == 8 ? 8 : 6);
                            Native.Check(Native.SetupDiGetDeviceInterfaceDetailW(interfaceSet, ref iface, detail, needed, out _, IntPtr.Zero), "Get interface path");
                            var path = Marshal.PtrToStringUni(detail + 4)!;
                            paths.Add(path); log($"PATH {path}");
                        }
                        finally { Marshal.FreeHGlobal(detail); }
                    }
                    }
                    finally { Native.SetupDiDestroyDeviceInfoList(interfaceSet); }
                }
                if (paths.Count == 0) log("No registered interface paths; driver/registry will not be modified.");
                result.Add(new(id.ToString(), service, paths.Distinct(StringComparer.OrdinalIgnoreCase).ToList()));
            }
        }
        finally { Native.SetupDiDestroyDeviceInfoList(set); }
        return result;
    }
}
