@echo off
:: 船 Fune (fase 12): run once by dockur at the first logon. WinApps' own setup first (RemoteApp registry, RDP
:: firewall rule, UTC clock, network-profile and time-sync tasks), then OcarinaShell's tweaks (fune.ps1).
:: `ocarina fune create` copies WinApps' install.bat here as winapps-install.bat.
call "%~dp0winapps-install.bat"
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0fune.ps1" > "%~dp0fune.log" 2>&1
exit /b 0
