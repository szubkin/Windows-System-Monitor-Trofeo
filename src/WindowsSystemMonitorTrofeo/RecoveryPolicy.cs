using System.ComponentModel;
namespace WindowsSystemMonitorTrofeo;
public static class RecoveryPolicy
{
    // During resume PnP can report the WinUSB device before its interface is ready.
    public static int InterfaceResult(string service, int pathCount, bool enabled) =>
        !service.Equals("WINUSB", StringComparison.OrdinalIgnoreCase) ? 5 :
        pathCount == 1 ? 0 : pathCount == 0 && enabled ? 9 : 5;
    public static bool IsTransient(Exception e) => e is TimeoutException or InvalidDataException ||
        e is Win32Exception w && w.NativeErrorCode is 6 or 22 or 31 or 121 or 995 or 1167;
    public static int Run(Func<int> session, bool enabled, CancellationToken token, Action<int>? wait = null)
    {
        int attempts = 0;
        while (!token.IsCancellationRequested)
        {
            int result = session();
            if (!enabled || result is not (3 or 9)) return result;
            attempts = Math.Min(6, attempts + 1);
            int seconds = attempts * 5;
            if (wait != null) wait(seconds); else token.WaitHandle.WaitOne(seconds * 1000);
        }
        return 0;
    }
}
