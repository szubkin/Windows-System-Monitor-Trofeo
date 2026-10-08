using System.Security.Cryptography;
using System.Text;

namespace WindowsSystemMonitorTrofeo.Usb;

internal sealed class DeviceLease : IDisposable
{
    private readonly Mutex mutex;
    internal DeviceLease(string instanceId)
    {
        string suffix = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(instanceId.ToUpperInvariant())));
        mutex = new Mutex(false, @"Local\WindowsSystemMonitorTrofeo-" + suffix);
        bool owned;
        try { owned = mutex.WaitOne(0); }
        catch (AbandonedMutexException) { owned = true; }
        if (!owned)
        {
            mutex.Dispose();
            throw new IOException("Another v0.0.3+ Trofeo process in this Windows session owns this device. Stop it first.");
        }
    }
    public void Dispose() { mutex.ReleaseMutex(); mutex.Dispose(); }
}
