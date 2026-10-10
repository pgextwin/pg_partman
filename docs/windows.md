# pg_partman 5.5.0 — Windows x64 installation

## Releases and compatibility

The existing [v5.5.0-windows.1](https://github.com/pgextwin/pg_partman/releases/tag/v5.5.0-windows.1) is SQL-only and remains immutable. Newer builds may optionally include a separately compiled BGW binary; check the actual ZIP for `lib/pg_partman_bgw.dll`. The BGW is never enabled automatically. PG14–18 require major-specific ZIPs; PostgreSQL 14 receives support only until its EOL, 2026-11-12.

## SQL-only installation (no preload required)

Verify `SHA256SUMS.txt`, ZIP provenance and SBOM before installation. Copy the ZIP's `share/extension` files into the matching PostgreSQL installation's `share/extension`. Restart only if needed for other reasons, then run `CREATE SCHEMA partman; CREATE EXTENSION pg_partman SCHEMA partman;` and the SQL routing smoke test. To maintain partitions, invoke `CALL partman.run_maintenance_proc();` with a correctly privileged role or external scheduler. An optional DLL present on disk does not affect SQL-only usage.

## Opt-in BGW (only if ZIP contains the tested native DLL)

Copy `lib/pg_partman_bgw.dll` into the matching PostgreSQL major installation's `lib` folder while the server is stopped. Configure the PostgreSQL instance, for example:

```conf
shared_preload_libraries = 'pg_partman_bgw'  # preserve any other existing preload libraries
pg_partman_bgw.dbname = 'postgres'
pg_partman_bgw.role = 'partman_maintainer'
pg_partman_bgw.interval = 3600
pg_partman_bgw.jobmon = off
```

Use dedicated non-superuser `partman_maintainer` with CONNECT to the selected DB; USAGE, EXECUTE and required DML permissions in the partman schema; ownership and DDL rights for its partitioned parent; SELECT on existing children; and permission to create future children in the target schema. Apply grants only to intended tables and databases. Start PostgreSQL and inspect server logs for worker registration, scheduling, maintenance and shutdown. Avoid overlapping external maintenance schedules.

## Actual CI acceptance and limitations

The same Windows CI runs two independent tests on PG14–18: (1) SQL-only partition creation, routing and cleanup without preload; (2) native MSVC DLL import/export check, preload startup as a non-superuser, real scheduled maintenance that restores a removed child partition, server-log assertion and cleanup. All five jobs, ZIP/SBOM/Grype validation, source SHA and GitHub attestations must pass on the exact candidate commit and new Release branch before declaring BGW supported.

Windows failover, high concurrency, actual production schedules, custom security policies, upgrades/downgrades and rollback are not covered by the pilot; validate these separately. Never silently replace a released ZIP or install a DLL from the wrong PostgreSQL major.
