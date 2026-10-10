[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$PgRoot,[Parameter(Mandatory=$true)][int]$PgPort,[Parameter(Mandatory=$true)][int]$PostgreSqlMajor)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$bin=Join-Path $PgRoot 'bin'
$tmp=if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}
$data=Join-Path $tmp "pgextwin-bgw-pg$PostgreSqlMajor-cluster"
$log=Join-Path $tmp "pgextwin-bgw-pg$PostgreSqlMajor.log"
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
-- pg_partman intentionally skips empty partition sets; seed an actual routed row
-- so maintenance computes a non-NULL current_partition_timestamp.
INSERT INTO public.pgextwin_bgw_parent(id,ts) VALUES (1,now());
'@ | Set-Content $sql -Encoding utf8
    & (Join-Path $bin 'psql.exe') -h 127.0.0.1 -p $PgPort -U postgres -v ON_ERROR_STOP=1 -f $sql
    if($LASTEXITCODE -ne 0){throw 'least privilege setup failed'}
    # Deliberately remove the highest-numbered future child, then require
    # background maintenance to replenish the set without a manual call.
    $countCmd="SELECT count(*) FROM pg_inherits WHERE inhparent='public.pgextwin_bgw_parent'::regclass"
    $expected=[int]((& (Join-Path $bin 'psql.exe') -h 127.0.0.1 -p $PgPort -U postgres -At -c $countCmd | Select-Object -Last 1).Trim())
    if($expected -lt 2){throw "Expected multiple children before removal, found $expected"}
    @'
DO $$
DECLARE target regclass;
BEGIN
  SELECT inhrelid::regclass INTO target FROM pg_inherits
    WHERE inhparent = 'public.pgextwin_bgw_parent'::regclass
    ORDER BY inhrelid::regclass::text DESC LIMIT 1;
  IF target IS NULL THEN RAISE EXCEPTION 'No removable child'; END IF;
  EXECUTE format('DROP TABLE %s', target);
END $$;
'@ | Set-Content -Path $sql -Encoding utf8
    & (Join-Path $bin 'psql.exe') -h 127.0.0.1 -p $PgPort -U postgres -v ON_ERROR_STOP=1 -f $sql
    if($LASTEXITCODE -ne 0){throw 'Could not remove future child for BGW test'}
    # Initial child partitions were created by the setup superuser. Grant
    # read access ONLY to this test parent's children, not all public tables.
    @'
DO $$
DECLARE child record;
BEGIN
  FOR child IN SELECT inhrelid::regclass AS table_name FROM pg_inherits
               WHERE inhparent='public.pgextwin_bgw_parent'::regclass
  LOOP
    EXECUTE format('GRANT SELECT ON %s TO partman_maintainer', child.table_name);
  END LOOP;
END $$;
'@ | Set-Content -Path $sql -Encoding utf8
    & (Join-Path $bin 'psql.exe') -h 127.0.0.1 -p $PgPort -U postgres -v ON_ERROR_STOP=1 -f $sql
    if($LASTEXITCODE -ne 0){throw 'Scoped child grants failed'}
    $remaining=[int]((& (Join-Path $bin 'psql.exe') -h 127.0.0.1 -p $PgPort -U postgres -At -c $countCmd | Select-Object -Last 1).Trim())
    if($remaining -ne $expected-1){throw 'Controlled child removal failed'}
    & (Join-Path $bin 'pg_ctl.exe') -D $data -m fast stop
    if($LASTEXITCODE -ne 0){throw 'initial stop failed'}
    $opts="-p $PgPort -c shared_preload_libraries=pg_partman_bgw -c pg_partman_bgw.dbname=postgres -c pg_partman_bgw.role=partman_maintainer -c pg_partman_bgw.interval=2 -c pg_partman_bgw.jobmon=off -c log_min_messages=debug1"
    & (Join-Path $bin 'pg_ctl.exe') -D $data -l $log -o $opts start
    if($LASTEXITCODE -ne 0){throw 'BGW shared preload startup failed'}
    $success=$false
    $recovered=0
    for($i=0;$i -lt 45;$i++){
       Start-Sleep -Seconds 2
       $text=Get-Content $log -Raw
       if($text -match 'FATAL:|permission denied|could not load library'){
          throw 'BGW failed to start, connect or maintain partitions with non-superuser role'
       }
       $called=($text -match 'run_maintenance_proc' -and $text -match 'called by role partman_maintainer')
       $out=@(& (Join-Path $bin 'psql.exe') -h 127.0.0.1 -p $PgPort -U postgres -At -v ON_ERROR_STOP=1 -c $countCmd)
       if($LASTEXITCODE -ne 0){throw 'Failed to query partition catalog during BGW test'}
       $recovered=[int]($out | Select-Object -Last 1).Trim()
       if($called -and $recovered -ge $expected){$success=$true;break}
    }
    if(-not $success){throw "BGW did not replenish partitions as non-superuser within 90 seconds: expected=$expected actual=$recovered"}

    Write-Host 'PASS: preload, non-superuser dynamic BGW and scheduled maintenance invocation'
} catch{
    if(Test-Path $log){Get-Content $log -Tail 220}
    throw
} finally{
    if(Test-Path (Join-Path $data 'postmaster.pid')){& (Join-Path $bin 'pg_ctl.exe') -D $data -m immediate stop}
}
