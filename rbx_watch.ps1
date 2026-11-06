# Emits "CHANGED <name>.fbx" once per settled change to an FBX in the export folder.
# Usage: powershell -NoProfile -File rbx_watch.ps1 -Dir D:\RobloxExports
# Baseline is taken at start (existing files don't trigger). Debounce: 3 s of no further change.
param([Parameter(Mandatory = $true)][string]$Dir)
$seen = @{}
Get-ChildItem $Dir -Filter *.fbx | ForEach-Object { $seen[$_.Name] = $_.LastWriteTimeUtc.Ticks }
Write-Output "WATCHING $Dir ($($seen.Count) files)"
[Console]::Out.Flush()
while ($true) {
    Start-Sleep -Seconds 2
    $changed = @()
    Get-ChildItem $Dir -Filter *.fbx | ForEach-Object {
        if (-not $seen.ContainsKey($_.Name) -or $seen[$_.Name] -ne $_.LastWriteTimeUtc.Ticks) { $changed += $_.Name }
    }
    if ($changed.Count -gt 0) {
        do {
            Start-Sleep -Seconds 3
            $again = $false
            foreach ($n in $changed) {
                $t = (Get-Item (Join-Path $Dir $n)).LastWriteTimeUtc.Ticks
                if ($seen[$n] -ne $t -and ((Get-Date).ToUniversalTime().Ticks - $t) -lt 30000000) { $again = $true }
            }
        } while ($again)
        foreach ($n in $changed) {
            $seen[$n] = (Get-Item (Join-Path $Dir $n)).LastWriteTimeUtc.Ticks
            Write-Output "CHANGED $n"
        }
        [Console]::Out.Flush()
    }
}
