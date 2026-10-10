# pg_partman — experimental Windows x64 technical pilot

[日本語](README_ja.md) | English

This is an **unofficial, unverified technical pilot** for [pg_partman](https://github.com/pgpartman/pg_partman) on standard Windows PostgreSQL 14–18 x64. **No binary release or successful functional compatibility is claimed until each CI matrix job actually passes.**

- Official upstream tag: `v5.5.0`
- Pinned upstream commit: `f7e83b9c441c7e97066d815bbe14e02a9dc5ff94`
- Release version: `5.5.0`
- PostgreSQL 14 is eligible **only until 2026-11-12**, subject to actual upstream and Windows runtime compatibility. Central `resolve-matrix.ps1` removes it after end of support.
- PostgreSQL 15, 16, 17, 18 require independent passing build, server startup, functional test, ZIP, SPDX SBOM, Grype and checksum checks.
- License files in this repository are exact upstream copies verified during CI against the pinned source.
- See [pilot scope and installation](docs/windows.md).

There is **no automatic release**, no catalog promotion, and no unattended publishing in this pilot.
