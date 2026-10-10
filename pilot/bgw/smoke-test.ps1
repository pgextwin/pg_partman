[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PgRoot,[Parameter(Mandatory=$true)][int]$PgPort)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$bin=Join-Path $PgRoot 'bin'
$tmp=if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}
$data=Join-Path $tmp 'pgextwin-bgw-pg17-cluster'
$log=Join-Path $tmp 'pgextwin-bgw-pg17.log'
$sql=Join-Path $tmp 'pgextwin-bgw-prep.sql'
if(Test-Path $data){Remove-Item $data -Recurse -Force}
if(Test-Path $log){Remove-Item $log -Force}
try{
    & (Join-Path $bin 'initdb.exe') -D $data -U postgres -A trust --encoding=UTF8 --no-locale
    if($LASTEXITCODE -ne 0){throw 'initdb failed'}
    & (Join-Path $bin 'pg_ctl.exe') -D $data -l $log -o "-p $PgPort" start
    if($LASTEXITCODE -ne 0){throw 'initial server start failed'}
    @'
CREATE ROLE partman_maintainer LOGIN;
CREATE SCHEMA partman;
CREATE EXTENSION pg_partman SCHEMA partman;
GRANT CONNECT ON DATABASE postgres TO partman_maintainer;
GRANT USAGE ON SCHEMA partman TO partman_maintainer;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA partman TO partman_maintainer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA partman TO partman_maintainer;
GRANT CREATE ON SCHEMA public TO partman_maintainer;
CREATE TABLE public.pgextwin_bgw_parent(id int NOT NULL, ts timestamptz NOT NULL)
  PARTITION BY RANGE(ts);
ALTER TABLE public.pgextwin_bgw_parent OWNER TO partman_maintainer;
SET TIME ZONE 'UTC';
SELECT partman.create_parent(
  p_parent_table := 'public.pgextwin_bgw_parent',
  p_control := 'ts', p_interval := '1 day', p_premake := 1, p_jobmon := false
);
'@ | Set-Content $sql -Encoding utf8
    & (Join-Path $bin 'psql.exe') -h 127.0.0.1 -p $PgPort -U postgres -v ON_ERROR_STOP=1 -f $sql
    if($LASTEXITCODE -ne 0){throw 'least privilege setup failed'}
    & (Join-Path $bin 'pg_ctl.exe') -D $data -m fast stop
    if($LASTEXITCODE -ne 0){throw 'initial stop failed'}
    $opts="-p $PgPort -c shared_preload_libraries=pg_partman_bgw -c pg_partman_bgw.dbname=postgres -c pg_partman_bgw.role=partman_maintainer -c pg_partman_bgw.interval=2 -c pg_partman_bgw.jobmon=off -c log_min_messages=debug1"
    & (Join-Path $bin 'pg_ctl.exe') -D $data -l $log -o $opts start
    if($LASTEXITCODE -ne 0){throw 'BGW shared preload startup failed'}
    $success=$false
    for($i=0;$i -lt 40;$i++){
       Start-Sleep -Seconds 2
       $text=Get-Content $log -Raw
       if($text -match 'run_maintenance_proc' -and $text -match 'called by role partman_maintainer'){
          $success=$true
          break
       }
       if($text -match 'FATAL:|permission denied|could not load library'){
          throw 'BGW failed to start, connect or execute with non-superuser role'
       }
    }
    if(-not $success){throw 'No evidence of automated BGW maintenance by non-superuser after 80 seconds'}
    Write-Host 'PASS: preload, non-superuser dynamic BGW and scheduled maintenance invocation'
} catch{
    if(Test-Path $log){Get-Content $log -Tail 220}
    throw
} finally{
    if(Test-Path (Join-Path $data 'postmaster.pid')){& (Join-Path $bin 'pg_ctl.exe') -D $data -m immediate stop}
}
