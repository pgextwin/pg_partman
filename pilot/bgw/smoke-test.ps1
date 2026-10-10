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

    # A rejected maintenance role must never be promoted to superuser in order
    # to make the BGW work. Assert explicit missing schema ACLs and observe
    # a real restricted-role BGW attempt on a running isolated PostgreSQL.
    @'
CREATE ROLE pgextwin_bgw_denied LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
DO $$
BEGIN
  IF (SELECT rolsuper FROM pg_roles WHERE rolname='partman_maintainer')
     OR (SELECT rolsuper FROM pg_roles WHERE rolname='pgextwin_bgw_denied')
     OR has_schema_privilege('pgextwin_bgw_denied','partman','USAGE')
  THEN
     RAISE EXCEPTION 'BGW least privilege / denied-role guard is invalid';
  END IF;
END $$;
'@ | Set-Content -Path $sql -Encoding utf8
    & (Join-Path $bin 'psql.exe') -h 127.0.0.1 -p $PgPort -U postgres -v ON_ERROR_STOP=1 -f $sql
    if($LASTEXITCODE -ne 0){throw 'BGW forbidden-role ACL setup failed'}
    & (Join-Path $bin 'pg_ctl.exe') -D $data -m fast stop
    if($LASTEXITCODE -ne 0){throw 'BGW graceful stop failed'}
    $deniedOpts=$opts.Replace('pg_partman_bgw.role=partman_maintainer','pg_partman_bgw.role=pgextwin_bgw_denied')
    $logOffset=(Get-Content $log -Raw).Length
    & (Join-Path $bin 'pg_ctl.exe') -D $data -l $log -o $deniedOpts start
    if($LASTEXITCODE -ne 0){throw 'BGW denied-role server start failed'}
    $negativeObserved=$false
    for($i=0;$i -lt 35;$i++){
        Start-Sleep -Seconds 2
        $delta=(Get-Content $log -Raw).Substring($logOffset)
        if($delta -match 'permission denied' -and $delta -match 'pgextwin_bgw_denied'){
            $negativeObserved=$true
            break
        }
    }
    if(-not $negativeObserved){throw 'BGW denied role did not produce the expected authorization failure'}
    & (Join-Path $bin 'pg_isready.exe') -h 127.0.0.1 -p $PgPort -q
    if($LASTEXITCODE -ne 0){throw 'A denied BGW role stopped the healthy PostgreSQL server'}
    Write-Host 'PASS: explicitly denied, non-superuser BGW cannot perform maintenance and PostgreSQL stays available.'

    # A fully successful restart must run fresh maintenance under the scoped
    # maintenance role, not merely preserve stale log lines from the first run.
    & (Join-Path $bin 'pg_ctl.exe') -D $data -m fast stop
    if($LASTEXITCODE -ne 0){throw 'BGW denied-role cleanup stop failed'}
    $logOffset=(Get-Content $log -Raw).Length
    & (Join-Path $bin 'pg_ctl.exe') -D $data -l $log -o $opts start
    if($LASTEXITCODE -ne 0){throw 'BGW normal restart failed'}
    $restartOK=$false
    for($i=0;$i -lt 40;$i++){
        Start-Sleep -Seconds 2
        $delta=(Get-Content $log -Raw).Substring($logOffset)
        if($delta -match 'run_maintenance_proc' -and $delta -match 'called by role partman_maintainer'){
            $restartOK=$true
            break
        }
        if($delta -match 'FATAL:|permission denied|could not load library'){
            throw 'BGW normal restart failed an operational or authorization check'
        }
    }
    if(-not $restartOK){throw 'No scheduled BGW maintenance after a clean PostgreSQL restart'}
    Write-Host 'PASS: clean stop/restart re-registers and executes the BGW.'

    # Fault injection is confined to this disposable CI data directory.
    # Immediate shutdown simulates abrupt postmaster termination; assert
    # server crash-recovery and a newly invoked worker after restart.
    & (Join-Path $bin 'pg_ctl.exe') -D $data -m immediate stop
    if($LASTEXITCODE -ne 0){throw 'Controlled immediate PostgreSQL shutdown failed'}
    $logOffset=(Get-Content $log -Raw).Length
    & (Join-Path $bin 'pg_ctl.exe') -D $data -l $log -o $opts start
    if($LASTEXITCODE -ne 0){throw 'BGW post-crash server recovery/start failed'}
    $crashOK=$false
    for($i=0;$i -lt 40;$i++){
        Start-Sleep -Seconds 2
        $delta=(Get-Content $log -Raw).Substring($logOffset)
        $replayed=$delta -match 'database system was interrupted|automatic recovery in progress|redo starts at'
        $worker=$delta -match 'run_maintenance_proc' -and $delta -match 'called by role partman_maintainer'
        if($replayed -and $worker){$crashOK=$true;break}
        if($delta -match 'FATAL:|permission denied|could not load library'){
            throw 'BGW post-crash startup reported an unrecoverable error'
        }
    }
    if(-not $crashOK){throw 'BGW failed to resume scheduled work after PostgreSQL crash recovery'}
    & (Join-Path $bin 'pg_isready.exe') -h 127.0.0.1 -p $PgPort -q
    if($LASTEXITCODE -ne 0){throw 'Post-crash PostgreSQL is unavailable'}
    Write-Host 'PASS: controlled immediate stop, crash recovery and fresh unprivileged BGW maintenance.'

} catch{
    if(Test-Path $log){Get-Content $log -Tail 220}
    throw
} finally{
    if(Test-Path (Join-Path $data 'postmaster.pid')){& (Join-Path $bin 'pg_ctl.exe') -D $data -m immediate stop}
}
