Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1Path = scriptDir & "\Protocol-Popup.ps1"

urlArg = ""
If WScript.Arguments.Count > 0 Then
    urlArg = WScript.Arguments(0)
End If

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & ps1Path & """ -Url """ & urlArg & """"
WshShell.Run cmd, 0, False
