$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$scenario = Join-Path $workspace '.superpowers/mobile-scenario'
$apiRoot = Join-Path $workspace 'apps/api'
$java = 'C:\Users\minjoun\Documents\Codex\tools\java25\jdk-25.0.4.1+1\bin\java.exe'
$originalClasspath = (Get-Content -LiteralPath (Join-Path $scenario 'runtime-classpath.txt') -Raw).Trim()
$snapshot = Join-Path $scenario ('snapshots/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff'))
New-Item -ItemType Directory -Path $snapshot -Force | Out-Null
$entries = $originalClasspath.Split([System.IO.Path]::PathSeparator)
for ($index = 0; $index -lt $entries.Length; $index++) {
    $entry = $entries[$index]
    if (Test-Path -LiteralPath $entry -PathType Container) {
        $resolved = (Resolve-Path -LiteralPath $entry).Path
        if (-not $resolved.StartsWith((Join-Path $apiRoot 'build'), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unexpected runtime classes directory outside this API build'
        }
        $target = Join-Path $snapshot "classes-$index"
        Copy-Item -LiteralPath $resolved -Destination $target -Recurse
        $entries[$index] = $target
    }
}
$classpath = ($entries -join [System.IO.Path]::PathSeparator).Replace('\', '/')
$argFile = Join-Path $scenario 'host-args.txt'
[System.IO.File]::WriteAllText($argFile, "-Xmx768m`n-cp`n`"$classpath`"`ncom.moishow.identity.MobileScenarioHost`n", [System.Text.UTF8Encoding]::new($false))
$process = Start-Process -FilePath $java -ArgumentList "@$argFile" -WorkingDirectory $apiRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $scenario 'host.log') -RedirectStandardError (Join-Path $scenario 'host-error.log') -PassThru
$process.Id | Set-Content -LiteralPath (Join-Path $scenario 'host.pid')
Write-Output "Loopback test host process started: PID $($process.Id). No credentials are printed."
