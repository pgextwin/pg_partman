[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PgRoot,[Parameter(Mandatory=$true)][int]$PgPort,[Parameter(Mandatory=$true)][int]$PostgreSqlMajor)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$bin=Join-Path $PgRoot 'bin'
$initdb=Join-Path $bin 'initdb.exe'
$pgctl=Join-Path $bin 'pg_ctl.exe'
$ready=Join-Path $bin 'pg_isready.exe'
$psql=Join-Path $bin 'psql.exe'
$tmp=if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}
$data=Join-Path $tmp "pgextwin-partman-pg$PostgreSqlMajor"
$log=Join-Path $tmp "pgextwin-partman-pg$PostgreSqlMajor.log"
$sql=Join-Path $tmp "pgextwin-partman-pg$PostgreSqlMajor.sql"
if(Test-Path $data){Remove-Item $data -Recurse -Force}
if(Test-Path $log){Remove-Item $log -Force}
try{
    & $initdb -D $data -U postgres -A trust --encoding=UTF8 --no-locale
    if($LASTEXITCODE -ne 0){throw 'initdb failed'}
    & $pgctl -D $data -l $log -o "-p $PgPort" start
    if($LASTEXITCODE -ne 0){throw 'PostgreSQL start failed'}
    $ok=$false
    for($i=0;$i -lt 45;$i++){
        & $ready -h 127.0.0.1 -p $PgPort -q
        if($LASTEXITCODE -eq 0){$ok=$true;break}
        Start-Sleep -Seconds 2
    }
    if(-not $ok){throw 'pg_isready timeout'}
    @'
SET TIME ZONE 'UTC';
CREATE SCHEMA partman;
CREATE EXTENSION pg_partman SCHEMA partman;
CREATE TABLE public.pgextwin_partman_test (
    id integer NOT NULL, ts timestamptz NOT NULL, amount integer NOT NULL
) PARTITION BY RANGE(ts);
DO $$
BEGIN
  IF NOT partman.create_parent(
    p_parent_table := 'public.pgextwin_partman_test',
    p_control := 'ts', p_interval := '1 day',
    p_premake := 3, p_jobmon := false
  ) THEN RAISE EXCEPTION 'create_parent returned false'; END IF;
END $$;
INSERT INTO public.pgextwin_partman_test VALUES(1,now(),10),(2,now(),20);
SELECT partman.run_maintenance(p_parent_table := 'public.pgextwin_partman_test',p_jobmon := false);
DO $$
DECLARE r integer; n integer; total integer;
BEGIN
  SELECT count(*),sum(amount) INTO r,total FROM public.pgextwin_partman_test;
  IF r<>2 OR total<>30 THEN RAISE EXCEPTION 'Partition row mismatch'; END IF;
  SELECT count(*) INTO n FROM pg_inherits WHERE inhparent='public.pgextwin_partman_test'::regclass;
  IF n<2 THEN RAISE EXCEPTION 'Missing child partitions'; END IF;
  SELECT count(*) INTO n FROM public.pgextwin_partman_test
   WHERE tableoid <> 'public.pgextwin_partman_test'::regclass;
  IF n<>2 THEN RAISE EXCEPTION 'Row routing failed'; END IF;
END $$;
DROP TABLE public.pgextwin_partman_test CASCADE;
DROP EXTENSION pg_partman CASCADE;
DROP SCHEMA partman CASCADE;
'@ | Set-Content -Path $sql -Encoding utf8
    & $psql -h 127.0.0.1 -p $PgPort -U postgres -d postgres -v ON_ERROR_STOP=1 -f $sql
    if($LASTEXITCODE -ne 0){throw 'pg_partman functional assertions failed'}
    Write-Host 'PASS partition maintenance, row routing and cleanup.'
} catch {
    if(Test-Path $log){Get-Content $log -Tail 250}
    throw
} finally {
    if(Test-Path (Join-Path $data 'postmaster.pid')){& $pgctl -D $data -m immediate stop}
}
