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
Copy-Item (Join-Path $UpstreamDir 'LICENSE.txt') (Join-Path $stage 'LICENSE.txt')
Copy-Item (Join-Path $UpstreamDir 'README.md') (Join-Path $stage 'UPSTREAM-README.md')
$commit=(& git -C $UpstreamDir rev-parse HEAD).Trim().ToLowerInvariant()
if($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$'){throw 'Bad upstream SHA'}
@"
pg_partman Windows SQL-only package
Upstream repository: $UpstreamRepository
Upstream ref: $UpstreamRef
Upstream commit: $commit
Version: $UpstreamVersion
PostgreSQL major: $PostgreSqlMajor
PostgreSQL tested: $PostgreSqlMinor
Architecture: Windows x64
Packaging mode: SQL-only (NO_BGW=1)
Compiler: Not applicable (no native DLL)
License: PostgreSQL; see LICENSE.txt
Warning: pg_partman_bgw is not supplied or supported.
"@ | Set-Content (Join-Path $stage 'PACKAGE-INFO.txt') -Encoding utf8
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
if(-not(Test-Path $zip)){throw 'ZIP missing'}
