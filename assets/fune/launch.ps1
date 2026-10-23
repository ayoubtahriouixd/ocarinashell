# 船 Fune launcher (fase 12, D-062). The program of the ONE RemoteApp connection: it starts the app and then STAYS,
# hidden, as the Fune agent of this session. RemoteApp only shows the windows of new processes while the
# connection's first program is alive, so this process must outlive every app opened through the agent.
# -Payload: base64 of UTF-8 JSON {"program":"…","args":"…"} (no quoting problems with paths that carry spaces).
param([Parameter(Mandatory)][string]$Payload)
$ErrorActionPreference = 'Stop'
$req = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Payload)) | ConvertFrom-Json
# Linux's clock travels with the order: after a pause or a suspend Windows is behind (a few seconds of slack)
if ($req.time) {
    $now = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$req.time).LocalDateTime
    if ([Math]::Abs(((Get-Date) - $now).TotalSeconds) -gt 3) { try { Set-Date -Date $now | Out-Null } catch {} }
}
if ($req.args) {
    Start-Process -FilePath $req.program -ArgumentList $req.args -WindowStyle Maximized
} else {
    Start-Process -FilePath $req.program -WindowStyle Maximized
}
# an older agent of a previous connection may still hold the port: this connection's agent takes over
Get-NetTCPConnection -LocalPort 7148 -State Listen -ErrorAction SilentlyContinue |
    ForEach-Object { if ($_.OwningProcess -ne $PID) { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue } }
Start-Sleep -Milliseconds 300
try {
    . (Join-Path $env:ProgramData 'Fune\agent.ps1')
} catch {
    while ($true) { Start-Sleep -Seconds 3600 }    # keep the connection's first program alive whatever happens
}
