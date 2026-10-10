[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PgRoot,[Parameter(Mandatory=$true)][string]$UpstreamDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$dest=Join-Path $PgRoot 'share/extension'
foreach($path in @('pg_partman.control','sql/pg_partman--5.5.0.sql')){
    $file=Join-Path $UpstreamDir $path
    if(-not(Test-Path $file)){throw "Missing file $file"}
    Copy-Item $file $dest -Force
}
$updates=@(Get-ChildItem (Join-Path $UpstreamDir 'updates') -File -Filter 'pg_partman--*.sql')
if($updates.Count -lt 1){throw 'No upstream upgrade SQL'}
foreach($script in $updates){Copy-Item $script.FullName $dest -Force}
$bgw = Join-Path $PgRoot 'lib/pg_partman_bgw.dll'
if(-not(Test-Path $bgw) -or (Get-Item $bgw).Length -lt 10000){
    throw 'Missing or truncated native pg_partman_bgw.dll after build'
}
Write-Host 'SQL installation completed. Native BGW DLL is available; preload is optional.'
