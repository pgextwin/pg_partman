# Windows pilot — pg_partman

Status: **engineering only / release blocked until green full matrix**.

Upstream: https://github.com/pgpartman/pg_partman/tree/f7e83b9c441c7e97066d815bbe14e02a9dc5ff94

This is SQL/PLpgSQL-only; the optional pg_partman_bgw is **not built, packaged, or supported**. Scheduled maintenance must be invoked by an external scheduler or manually. Use least-privilege maintenance roles; do not use BGW as a superuser.

1. Validate full native Windows x64 CI for PG14 (if still maintained) through PG18.
2. Verify exact license bytes and immutable upstream SHA.
3. Validate `CREATE EXTENSION pg_partman` and scenarios in `config/test-contract.json`.
4. For deployment, stop the server before replacing libraries; install the ZIP contents into the matching PostgreSQL root and restart for preload modules.
5. Run the documented SQL tests and repeat on an isolated production-equivalent Windows environment.

Do not install a pilot ZIP into production and do not treat unexecuted tests as passes. Upgrades, rollback, interaction with other extensions and backup/restore require separate testing.

All published binary artifacts must carry source provenance, exact PostgreSQL major, checksums, SBOM and vulnerability report.
