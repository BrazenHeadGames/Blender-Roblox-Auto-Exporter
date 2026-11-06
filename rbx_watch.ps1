# Watches the export folder and prints one line per event, for an MCP client to act on.
#
#   -Mode push (default): prints "PUSH_REQUESTED <json>" when you click "Push to Roblox" in Blender.
#   -Mode fbx           : prints "CHANGED <name>.fbx" whenever an FBX file changes (every save).
#
# Usage: powershell -NoProfile -File rbx_watch.ps1 -Dir D:\RobloxExports [-Mode push|fbx]
# The state at start is the baseline, so existing files don't trigger anything.
param(
    [Parameter(Mandatory = $true)][string]$Dir,
    [ValidateSet("push", "fbx")][string]$Mode = "push"
)

if ($Mode -eq "push") {
    $marker = Join-Path $Dir ".push_request.json"
    $last = if (Test-Path $marker) { (Get-Item $marker).LastWriteTimeUtc.Ticks } else { 0 }
    Write-Output "WATCHING $marker (push mode)"
    [Console]::Out.Flush()
    while ($true) {
        Start-Sleep -Seconds 1
        if (Test-Path $marker) {
            $t = (Get-Item $marker).LastWriteTimeUtc.Ticks
            if ($t -ne $last) {
                Start-Sleep -Milliseconds 500   # let the writer finish
                $last = (Get-Item $marker).LastWriteTimeUtc.Ticks
                $body = (Get-Content $marker -Raw -Encoding UTF8) -replace "\s+", " "
                Write-Output "PUSH_REQUESTED $body"
                [Console]::Out.Flush()
            }
        }
    }
}

$seen = @{}
Get-ChildItem $Dir -Filter *.fbx | ForEach-Object { $seen[$_.Name] = $_.LastWriteTimeUtc.Ticks }
Write-Output "WATCHING $Dir ($($seen.Count) files, fbx mode)"
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
