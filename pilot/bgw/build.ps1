[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PgRoot,[Parameter(Mandatory=$true)][string]$UpstreamDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$source=Join-Path $UpstreamDir 'src/pg_partman_bgw.c'
$expected='f7e83b9c441c7e97066d815bbe14e02a9dc5ff94'
$actual=(& git -C $UpstreamDir rev-parse HEAD).Trim().ToLowerInvariant()
if($LASTEXITCODE -ne 0 -or $actual -ne $expected){throw 'Pinned upstream source mismatch'}
$vswhere=Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Microsoft Visual Studio/Installer/vswhere.exe'
$root=[string](& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
if(-not $root.Trim()){throw 'MSVC not found'}
$devcmd=Join-Path $root.Trim() 'Common7/Tools/VsDevCmd.bat'
$dir=if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}
$def=Join-Path $dir 'pg_partman_bgw.def'
@('LIBRARY pg_partman_bgw','EXPORTS','    Pg_magic_func','    _PG_init','    pg_partman_bgw_main','    pg_partman_bgw_run_maint') | Set-Content $def -Encoding ascii
$output=Join-Path $dir 'pg_partman_bgw.dll'
$cmd=Join-Path $dir 'pgextwin-bgw-msvc.cmd'
@"
@echo off
call "$devcmd" -arch=x64 -host_arch=x64
if errorlevel 1 exit /b 1
cl /nologo /LD /MD /O2 /W2 /DWIN32 /I"$PgRoot\include\server\port\win32_msvc" /I"$PgRoot\include\server\port\win32" /I"$PgRoot\include\server" /I"$PgRoot\include" "$source" /link /DLL /DEF:"$def" /LIBPATH:"$PgRoot\lib" postgres.lib /OUT:"$output"
if errorlevel 1 exit /b 1
dumpbin /nologo /exports "$output"
if errorlevel 1 exit /b 1
dumpbin /nologo /dependents "$output"
"@ | Set-Content $cmd -Encoding ascii
$outputLog=@(& cmd.exe /d /c $cmd)
$outputLog | ForEach-Object {Write-Host $_}
if($LASTEXITCODE -ne 0){throw 'Native BGW MSVC build/export/dependency audit failed'}
foreach($name in @('Pg_magic_func','_PG_init','pg_partman_bgw_main','pg_partman_bgw_run_maint')){
    if(($outputLog -join "`n") -notmatch [regex]::Escape($name)){throw "Missing DLL symbol: $name"}
}
if(-not(Test-Path $output)){throw 'No BGW DLL'}
Copy-Item $output (Join-Path $PgRoot 'lib/pg_partman_bgw.dll') -Force
Write-Host 'BGW PG17 pilot DLL installed into disposable runner PostgreSQL only'
