Option Explicit
Dim fso, shell, root, exe, arguments, mode, errorText, message, stream, settingsText, matcher
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
    errorText = Err.Description
    message = ChrW(1053) & ChrW(1077) & ChrW(32) & ChrW(1091) & ChrW(1076) & ChrW(1072) & ChrW(1083) & ChrW(1086) & ChrW(1089) & ChrW(1100) & ChrW(32) & ChrW(1079) & ChrW(1072) & ChrW(1087) & ChrW(1091) & ChrW(1089) & ChrW(1090) & ChrW(1080) & ChrW(1090) & ChrW(1100) & ChrW(32) & ChrW(84) & ChrW(114) & ChrW(111) & ChrW(102) & ChrW(101) & ChrW(111) & ChrW(58) & ChrW(32)
    Set stream = CreateObject("ADODB.Stream")
    stream.Type = 2
    stream.Charset = "utf-8"
    stream.Open
    stream.LoadFromFile root & "\trofeo-settings.json"
    settingsText = stream.ReadText
    stream.Close
    Set matcher = New RegExp
    matcher.Pattern = """Language""\s*:\s*""en"""
    matcher.IgnoreCase = True
    If matcher.Test(settingsText) Then message = "Trofeo could not start: "
    MsgBox message & errorText, 48, "Trofeo"
End If
