# pg_partman native Windows BGW technical evidence

PG14–18 MSVC compilation, actual PostgreSQL preload, least-privilege maintenance side-effects and scheduled partition replenishment passed in [CI 38067766523](https://github.com/pgextwin/pg_partman/actions/runs/38067766523). The same BGW is now available in signed [v5.5.0-windows.2](https://github.com/pgextwin/pg_partman/releases/tag/v5.5.0-windows.2), which passed fresh PG14–18 build, operation and attestation checks in [Release CI](https://github.com/pgextwin/pg_partman/actions/runs/38090908572). Existing `v5.5.0-windows.1` remains immutable SQL-only.

BGW is off until explicitly configured; SQL-only usage must continue passing separately. Packaging was independently verified before publishing. SQL-only use requires no preload; BGW remains opt-in. Production upgrades, high concurrency, custom authorization and failover need separate acceptance. See docs/windows.md and issue #3.
