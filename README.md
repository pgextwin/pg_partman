# pg_partman — signed Windows x64 binaries

[日本語](README_ja.md) | English

Windows x64 builds of upstream [pg_partman](https://github.com/pgpartman/pg_partman) 5.5.0 for community PostgreSQL 14–18. The build uses immutable upstream commit `f7e83b9c441c7e97066d815bbe14e02a9dc5ff94` and exact PostgreSQL license. PostgreSQL 14 is built only while maintained (EOL 2026-11-12).

- **Existing immutable [v5.5.0-windows.1](https://github.com/pgextwin/pg_partman/releases/tag/v5.5.0-windows.1): SQL-only.** No BGW DLL; external scheduler/manual maintenance required.
- **Candidate v5.5.0-windows.2:** SQL-only functionality by default **plus optional** `lib/pg_partman_bgw.dll`. This version must pass a fresh full PG14–18 Windows x64 signed Release build before publication. It is not available until GitHub actually publishes it.
- BGW is **not enabled by merely installing the ZIP**. To opt in, configure `shared_preload_libraries = 'pg_partman_bgw'`, `pg_partman_bgw.dbname`, `pg_partman_bgw.role` and `pg_partman_bgw.interval` and restart PostgreSQL. A non-superuser role needs appropriate privileges on its own parent, children and the pg_partman schema; do not assign superuser purely to make the worker pass.

See [installation and operating guidance](docs/windows.md), including tests and limitations. Install the ZIP matching your exact PostgreSQL **major**, Windows x64 and the upstream version. Verify SHA256SUMS, SPDX SBOM, Grype and GitHub attestations. Upgrades, failover, overlapping schedulers and interaction with other preloaded extensions require separate deployment validation.
