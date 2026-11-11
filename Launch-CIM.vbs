Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1Path = scriptDir & "\Claude-Instance-Manager.ps1"

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & ps1Path & """"
WshShell.Run cmd, 0, False
