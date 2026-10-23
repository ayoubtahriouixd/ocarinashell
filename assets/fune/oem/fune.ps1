# 船 Fune — Windows tweaks (fase 12). dockur copies /oem to C:\OEM and runs install.bat once, at the first logon of
# the Fune user, elevated; install.bat runs WinApps' setup (RemoteApp registry, RDP firewall, UTC clock) and then this.
# Every step is independent: one failure never stops the rest. Log: C:\OEM\fune.log
$ErrorActionPreference = 'Stop'

function Step([string]$name, [scriptblock]$body) {
    try { & $body | Out-Null; "OK    $name" } catch { "FALLO $name · $($_.Exception.Message)" }
}
function Set-Reg([string]$path, [string]$name, $value, [string]$type = 'DWord') {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -Path $path -Name $name -Value $value -PropertyType $type -Force | Out-Null
}

"Fune · $(Get-Date -Format s)"

Step 'zona horaria Africa/Casablanca' { Set-TimeZone -Id 'Morocco Standard Time' }

# RemoteApp sessions take the client's 175 % (/scale-desktop:175); this is only for the web console and the desktop
Step 'escala 175 % (168 ppp)' {
    Set-Reg 'HKCU:\Control Panel\Desktop' 'LogPixels' 168
    Set-Reg 'HKCU:\Control Panel\Desktop' 'Win8DpiScaling' 1
}

# «Ajustar para obtener el mejor rendimiento», but ClearType stays: text is what these apps are for
Step 'efectos visuales: mejor rendimiento (con ClearType)' {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3
    Set-Reg 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) 'Binary'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'FontSmoothing' '2' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'FontSmoothingType' 2
    Set-Reg 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
    Set-Reg 'HKCU:\Control Panel\Accessibility' 'DynamicScrollbars' 0
}

Step 'sin apps de inicio superfluas ni apps en segundo plano' {
    $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if (Test-Path $run) {
        (Get-Item $run).Property | Where-Object { $_ -match '^(OneDrive|OneDriveSetup|MicrosoftEdgeAutoLaunch.*|Teams|ms-teams)$' } |
            ForEach-Object { Remove-ItemProperty -Path $run -Name $_ }
    }
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2
}

# SysMain (prefetch) only warms caches the VM throws away on every pause/stop
Step 'SysMain apagado' { Stop-Service SysMain -Force -ErrorAction SilentlyContinue; Set-Service SysMain -StartupType Disabled }

# Updates install during `ocarina fune maintenance` (an hour on AC, then off). Active hours 07–01 keep any automatic
# restart out of the day, and never with a RemoteApp session open
Step 'Windows Update: horas activas 07–01, sin reinicio con sesión abierta' {
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'SmartActiveHoursState' 0
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursStart' 7
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursEnd' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1
}

# Fune pauses and stops the VM itself; a guest that sleeps on its own only breaks RDP
Step 'sin suspensión, hibernación ni salvapantallas' {
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
    powercfg /change monitor-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0
    powercfg /hibernate off
    Set-Reg 'HKCU:\Control Panel\Desktop' 'ScreenSaveActive' '0' 'String'
}

# dockur turns SIGTERM (logout/poweroff of the laptop) into the ACPI power button: it must mean «shut down»
Step 'botón de encendido = apagar' {
    powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3
    powercfg /setactive SCHEME_CURRENT
}

# Windows must not fight the RDP client over the keyboard layout (RDPApps.reg ignores the remote one): Spanish
Step 'teclado español' {
    $l = New-WinUserLanguageList 'es-ES'
    Set-WinUserLanguageList $l -Force
}

# WinApps' TimeSync logon task polls a marker Fune never writes; under Windows Terminal its hidden PowerShell shows up
# as a RemoteApp window at every logon. The classic console host keeps -WindowStyle Hidden hidden.
Step 'sin la tarea TimeSync y con la consola clásica' {
    schtasks /delete /tn TimeSync /f 2>$null | Out-Null
    $c = 'HKCU:\Console\%%Startup'
    Set-Reg $c 'DelegationConsole' '{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}' 'String'
    Set-Reg $c 'DelegationTerminal' '{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}' 'String'
}

# dockur's unattend logs the console in by itself with AutoLogonCount 65432; while that counter exists Windows turns
# AutoAdminLogon back on at every boot (WinApps' «AutoAdminLogon=0» alone does not hold), and a console session makes
# every RDP connection ask «otro usuario ya inició sesión». Fune needs no console session at all.
Step 'sin inicio de sesión automático en la consola' {
    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty $wl AutoAdminLogon '0'
    Remove-ItemProperty $wl -Name AutoLogonCount, DefaultPassword -ErrorAction SilentlyContinue
}

"Fin · $(Get-Date -Format s)"
