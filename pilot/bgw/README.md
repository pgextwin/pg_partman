# pg_partman native Windows BGW technical evidence

PG14–18 MSVC compilation, actual PostgreSQL preload, least-privilege maintenance side-effects and scheduled partition replenishment passed in [CI 38067766523](https://github.com/pgextwin/pg_partman/actions/runs/38067766523). This code is shared with the next optional BGW-capable packaged Release. Existing `v5.5.0-windows.1` remains immutable SQL-only.

BGW is off until explicitly configured; SQL-only usage must continue passing separately. Packaging is authorized only after the *fresh* shared attested-release matrix, provenance, ZIP and supply-chain checks succeed. Production upgrades, high concurrency, custom authorization and failover need separate acceptance. See docs/windows.md and issue #3.
