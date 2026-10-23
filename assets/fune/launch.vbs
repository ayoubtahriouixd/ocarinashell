' 船 Fune (fase 12, D-062): the first program of the RemoteApp connection. wscript has no window, and it starts the
' PowerShell launcher hidden from its first instant (a console created visible would stay on screen as a RemoteApp
' window), then waits for it: the connection's first program must stay alive for RemoteApp to keep showing the windows
' of the apps the agent opens later. Argument: the base64 payload for launch.ps1.
Set sh = CreateObject("WScript.Shell")
ps1 = sh.ExpandEnvironmentStrings("%ProgramData%") & "\Fune\launch.ps1"
sh.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & ps1 & """ -Payload " & WScript.Arguments(0), 0, True
