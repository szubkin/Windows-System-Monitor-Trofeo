using System.Runtime.InteropServices;

namespace WindowsSystemMonitorTrofeo;

// Classic console text selection can suspend writes. Disable QuickEdit for this run.
internal sealed class ConsoleInputMode : IDisposable
{
    [DllImport("kernel32.dll")] private static extern IntPtr GetStdHandle(int kind);
    [DllImport("kernel32.dll")] private static extern bool GetConsoleMode(IntPtr handle, out uint mode);
    [DllImport("kernel32.dll")] private static extern bool SetConsoleMode(IntPtr handle, uint mode);
    private readonly IntPtr handle = GetStdHandle(-10);
    private readonly uint previous;
    private readonly bool changed;
    public ConsoleInputMode()
    {
        if (GetConsoleMode(handle, out previous)) changed = SetConsoleMode(handle, (previous | 0x80u) & ~0x40u);
    }
    public void Dispose() { if (changed) SetConsoleMode(handle, previous); }
}
