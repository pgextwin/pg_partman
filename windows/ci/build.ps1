[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PgRoot,[Parameter(Mandatory=$true)][string]$UpstreamDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$control=Get-Content (Join-Path $UpstreamDir 'pg_partman.control') -Raw
if($control -notmatch "default_version\s*=\s*'5\.5\.0'"){throw 'Unexpected upstream version'}
$chunks=[System.Collections.Generic.List[string]]::new()
foreach($group in @('sql/types','sql/tables','sql/functions','sql/procedures')){
    $files=@(Get-ChildItem (Join-Path $UpstreamDir $group) -File -Filter '*.sql' | Sort-Object Name)
    if($files.Count -eq 0){throw "Missing SQL components in $group"}
    foreach($file in $files){
        $chunks.Add([IO.File]::ReadAllText($file.FullName,[Text.Encoding]::UTF8).TrimEnd([char[]]@(13,10)))
    }
}
$path=Join-Path $UpstreamDir 'sql/pg_partman--5.5.0.sql'
[IO.File]::WriteAllText($path,($chunks -join [Environment]::NewLine) + [Environment]::NewLine,[Text.UTF8Encoding]::new($false))
if((Get-Item $path).Length -lt 100000){throw 'Generated SQL unexpectedly small'}
# Optional BGW is compiled from the same SHA-pinned upstream source, but
# SQL-only installations continue to work without shared_preload_libraries.
$bgwBuild = Join-Path $PSScriptRoot '../../pilot/bgw/build.ps1'
& $bgwBuild -PgRoot $PgRoot -UpstreamDir $UpstreamDir
if(-not(Test-Path (Join-Path $PgRoot 'lib/pg_partman_bgw.dll'))){
    throw 'Optional BGW DLL build did not produce a deployable Windows module'
}
Write-Host 'SQL package and opt-in native BGW compiled from pinned upstream source.'
