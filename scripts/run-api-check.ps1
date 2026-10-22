param([Parameter(Mandatory=$true)][string]$Label,[string[]]$Tests=@(),[switch]$Build)
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
if($Label -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid check label'}
$archive=Join-Path $repoRoot ".superpowers/checks/$Label"
New-Item -ItemType Directory -Force -Path $archive | Out-Null
Push-Location (Join-Path $repoRoot 'apps/api')
try {
 $task=if($Build){'build'}else{'test'}
 $arguments=@('--no-daemon','--max-workers=2',$task)
 foreach($test in $Tests){$arguments+=@('--tests',$test)}
 $ErrorActionPreference='Continue'
 & .\gradlew.bat @arguments *> (Join-Path $archive 'run.log')
 $result=$LASTEXITCODE
 $ErrorActionPreference='Stop'
 $reports=Join-Path (Get-Location) 'build/test-results/test'
 if(Test-Path $reports){Get-ChildItem -LiteralPath $reports -Filter 'TEST-*.xml' | Copy-Item -Destination $archive}
 Get-Content (Join-Path $archive 'run.log') -Tail 35
 Write-Output "Report archive: $archive; Gradle exit: $result"
} finally {Pop-Location}
exit $result
