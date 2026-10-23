# 船 Fune agent (fase 12, D-062). Runs hidden in the user's session (logon task «FuneAgent») and starts programs IN
# THAT SESSION, so every Windows app shares the one RemoteApp connection already open on Linux (a second RDP
# connection would steal the session from the first: windows that stop repainting and cannot be closed).
# Protocol: one JSON line per TCP connection on port 7148 — {"token":"…","program":"C:\\…\\x.exe","args":"…"} — and
# one line back: «ok» or «error: …». The token lives in C:\ProgramData\Fune\token (Administrators and the user only)
# and in the Linux keyring; the port is published on the host's 127.0.0.1 only.
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:ProgramData 'Fune'
$token = (Get-Content -Raw (Join-Path $dir 'token')).Trim()
# Win+F on a Windows window: maximize or restore it HERE (niri cannot resize a RemoteApp window). Physical pixels,
# so the process is DPI-aware.
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Text;
public static class FuneWin {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsZoomed(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int hh, uint f);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    // maximized → restored to w×h at the origin; anything else → maximized. Returns "max", "restored" or "none".
    public static string Toggle(string title, int w, int h) {
        string r = "none";
        EnumWindows(delegate (IntPtr hw, IntPtr l) {
            if (r != "none" || !IsWindowVisible(hw)) return true;
            var sb = new StringBuilder(512);
            GetWindowText(hw, sb, 512);
            if (sb.ToString() != title) return true;
            if (IsZoomed(hw)) {
                ShowWindow(hw, 9);                                        // SW_RESTORE
                SetWindowPos(hw, IntPtr.Zero, 0, 0, w, h, 0x0004);        // SWP_NOZORDER
                r = "restored";
            } else {
                ShowWindow(hw, 3);                                        // SW_MAXIMIZE
                r = "max";
            }
            return false;
        }, IntPtr.Zero);
        return r;
    }
}
"@
[FuneWin]::SetProcessDPIAware() | Out-Null

# token check in constant time (pattern from WinBoat's guest server, MIT © 2026 TibixDev; reimplemented here)
function Test-Token([string]$given) {
    if ($null -eq $given -or $given.Length -ne $token.Length) { return $false }
    $diff = 0
    for ($i = 0; $i -lt $token.Length; $i++) { $diff = $diff -bor ([int][char]$given[$i] -bxor [int][char]$token[$i]) }
    return $diff -eq 0
}
# one request line, at most 64 KiB: a stuck or hostile client cannot hold the agent or fill its memory
function Read-Request($stream) {
    $buf = New-Object System.Collections.Generic.List[byte]
    while ($buf.Count -lt 65536) {
        $b = $stream.ReadByte()
        if ($b -lt 0 -or $b -eq 10) { break }
        $buf.Add([byte]$b)
    }
    return [System.Text.Encoding]::UTF8.GetString($buf.ToArray())
}
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, 7148)
$listener.Start()
while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $client.ReceiveTimeout = 3000
        $stream = $client.GetStream()
        $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
        $writer.AutoFlush = $true
        $req = Read-Request $stream | ConvertFrom-Json
        if (-not (Test-Token ([string]$req.token))) {
            $writer.WriteLine('error: token')
        } elseif ($req.ping) {
            $writer.WriteLine('ok')
        } elseif ($req.time) {
            # after a pause or a suspend of the laptop Windows' clock is behind: Linux's clock, at once, no network
            Set-Date -Date ([DateTimeOffset]::FromUnixTimeMilliseconds([int64]$req.time).LocalDateTime) | Out-Null
            $writer.WriteLine('ok')
        } elseif ($req.toggle) {
            $writer.WriteLine('ok ' + [FuneWin]::Toggle([string]$req.toggle.title, [int]$req.toggle.w, [int]$req.toggle.h))
        } else {
            if ($req.args) {
                Start-Process -FilePath $req.program -ArgumentList $req.args -WindowStyle Maximized
            } else {
                Start-Process -FilePath $req.program -WindowStyle Maximized
            }
            $writer.WriteLine('ok')
        }
    } catch {
        try { $writer.WriteLine('error: ' + $_.Exception.Message) } catch {}
    } finally {
        $client.Close()
    }
}
