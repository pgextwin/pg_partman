# Optional pg_partman Windows background worker (experimental)

Not part of the existing SQL-only `v5.5.0-windows.1` Release. No BGW distribution is authorized or promised.

This isolated PostgreSQL 17 pilot attempts an MSVC build of the **unmodified SHA-pinned** upstream 5.5.0 `src/pg_partman_bgw.c`, audits DLL entrypoints/imports, and tests real `shared_preload_libraries=pg_partman_bgw` startup with `pg_partman_bgw.role=partman_maintainer` and a non-superuser maintenance invocation. Failures remain visible; this does not alter the existing default package or its verified SQL-only behavior.

Acceptance for a future optional BGW Release additionally requires PostgreSQL 14–18, real child partition creation from BGW alone, shutdown/restart and signal behavior, negative privilege tests, signed binary provenance, checksums and supply-chain reports. See Issue #3.
