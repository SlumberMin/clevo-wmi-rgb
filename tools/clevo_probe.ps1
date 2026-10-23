# Clevo keyboard backlight probe (root\WMI CLEVO_GET.SetKBLED)
# Default: read-only (list the WMI class). With -Apply it writes ONE colour.
# Requires an elevated PowerShell for -Apply.
param(
    [switch]$Apply,
    [string]$Color = "FF0000",
    [ValidateSet("left", "mid", "right", "lightbar")]
    [string]$Part = "left",
    [ValidateSet("off", "low", "mid", "high")]
    [string]$Brightness = ""
)

$ErrorActionPreference = "Stop"

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host "== CLEVO_GET =="
try {
    $o = Get-CimInstance -Namespace root\WMI -Class CLEVO_GET -ErrorAction Stop
    Write-Host ("class found: {0}" -f ($o | Select-Object -ExpandProperty InstanceName))
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match '拒绝访问|Access|denied') { Write-Host "class exists, but needs an elevated shell." }
    else { Write-Host "class not found: $msg"; exit 1 }
}

if (-not $Apply) {
    Write-Host "read-only mode. add -Apply -Color RRGGBB [-Part left] to write one colour."
    Write-Host "example: .\clevo_probe.ps1 -Apply -Color 00A0FF"
    exit 0
}

if (-not (Test-Admin)) { throw "SetKBLED requires an elevated PowerShell." }
if ($Color -notmatch '^[0-9A-Fa-f]{6}$') { throw "Color must be RRGGBB" }

$r = [Convert]::ToInt32($Color.Substring(0, 2), 16)
$g = [Convert]::ToInt32($Color.Substring(2, 2), 16)
$b = [Convert]::ToInt32($Color.Substring(4, 2), 16)
$packed = ($b -shl 16) -bor ($r -shl 8) -bor $g

$parts = @{ left = 0xF0000000; mid = 0xF1000000; right = 0xF2000000; lightbar = 0xF3000000 }
$levels = @{ off = 0; low = 63; mid = 127; high = 255 }

$wmi = Get-WmiObject -Namespace root\WMI -Class CLEVO_GET

if ($Brightness -ne "") {
    $bval = 0xF4000000 -bor $levels[$Brightness]
    Write-Host ("SetKBLED(0x{0:X8})  brightness={1}" -f $bval, $Brightness)
    $wmi.SetKBLED([uint32]$bval) | Out-Null
}

$val = [uint32]($parts[$Part] -bor $packed)
Write-Host ("SetKBLED(0x{0:X8})  part={1} color={2}" -f $val, $Part, $Color)
$wmi.SetKBLED($val) | Out-Null
Write-Host "done. if the whole keyboard changed, this model is single-zone (same as X15 AT23)."
