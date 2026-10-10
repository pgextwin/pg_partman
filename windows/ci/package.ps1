[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$UpstreamDir,
[Parameter(Mandatory=$true)][string]$UpstreamRepository,
[Parameter(Mandatory=$true)][string]$UpstreamRef,
[Parameter(Mandatory=$true)][string]$UpstreamVersion,
[Parameter(Mandatory=$true)][int]$PostgreSqlMajor,
[Parameter(Mandatory=$true)][string]$PostgreSqlMinor,
[string]$DistDir='dist')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$asset="pg_partman-$UpstreamRef-pg$PostgreSqlMajor-windows-x64"
$stage=Join-Path $DistDir $asset
$zip=Join-Path $DistDir "$asset.zip"
if(Test-Path $stage){Remove-Item $stage -Recurse -Force}
if(Test-Path $zip){Remove-Item $zip -Force}
$share=Join-Path $stage 'share/extension'
New-Item -ItemType Directory -Force $share | Out-Null
Copy-Item (Join-Path $UpstreamDir 'pg_partman.control') $share
Copy-Item (Join-Path $UpstreamDir 'sql/pg_partman--5.5.0.sql') $share
Get-ChildItem (Join-Path $UpstreamDir 'updates') -Filter 'pg_partman--*.sql' -File | ForEach-Object {Copy-Item $_.FullName $share}
# Keep the verified SQL-only payload independent from the optional BGW.
# PGROOT is the same major-specific installation used by Build + smoke CI.
if([string]::IsNullOrWhiteSpace($env:PGROOT)){throw 'PGROOT not set for BGW packaging'}
$bgwSource=Join-Path $env:PGROOT 'lib/pg_partman_bgw.dll'
if(-not(Test-Path $bgwSource) -or (Get-Item $bgwSource).Length -lt 10000){
    throw 'Expected tested optional BGW DLL is missing or too small'
}
$lib=Join-Path $stage 'lib'
New-Item -ItemType Directory -Force $lib | Out-Null
Copy-Item $bgwSource (Join-Path $lib 'pg_partman_bgw.dll')
$sourceDigest=(Get-FileHash $bgwSource -Algorithm SHA256).Hash
$packageDigest=(Get-FileHash (Join-Path $lib 'pg_partman_bgw.dll') -Algorithm SHA256).Hash
if($sourceDigest -ne $packageDigest){throw 'Packaged BGW DLL differs from runtime-tested DLL'}
Copy-Item (Join-Path $UpstreamDir 'LICENSE.txt') (Join-Path $stage 'LICENSE.txt')
Copy-Item (Join-Path $UpstreamDir 'README.md') (Join-Path $stage 'UPSTREAM-README.md')
Copy-Item (Join-Path $PSScriptRoot '../../docs/windows.md') (Join-Path $stage 'WINDOWS-INSTALL.md')
Copy-Item (Join-Path $PSScriptRoot '../../docs/windows_ja.md') (Join-Path $stage 'WINDOWS-INSTALL-ja.md')
$commit=(& git -C $UpstreamDir rev-parse HEAD).Trim().ToLowerInvariant()
if($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$'){throw 'Bad upstream SHA'}
@"
pg_partman Windows SQL + optional native BGW package
Upstream repository: $UpstreamRepository
Upstream ref: $UpstreamRef
Upstream commit: $commit
Version: $UpstreamVersion
PostgreSQL major: $PostgreSqlMajor
PostgreSQL tested: $PostgreSqlMinor
Architecture: Windows x64
Packaging mode: SQL-only by default, optional native BGW (preload opt-in)
Compiler: MSVC (BGW); SQL functions remain pure SQL/PLpgSQL
License: PostgreSQL; see LICENSE.txt
BGW: optional lib/pg_partman_bgw.dll; only configured databases run scheduled maintenance.
"@ | Set-Content (Join-Path $stage 'PACKAGE-INFO.txt') -Encoding utf8
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
if(-not(Test-Path $zip)){throw 'ZIP missing'}
