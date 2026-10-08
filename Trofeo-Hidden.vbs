Option Explicit
Dim fso, shell, root, exe, arguments, mode
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("Shell.Application")
root = fso.GetParentFolderName(WScript.ScriptFullName)
exe = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
mode = "start"
If WScript.Arguments.Count > 0 Then mode = LCase(WScript.Arguments(0))
If mode = "stop" Then
    arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & root & "\Manage-Autostart.ps1"" -Action Stop"
Else
    arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & root & "\Trofeo-Tray.ps1"""
End If
On Error Resume Next
shell.ShellExecute exe, arguments, root, "runas", 0
If Err.Number <> 0 Then
    MsgBox "Trofeo could not start: " & Err.Description, 48, "Trofeo"
End If
