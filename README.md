# pg_partman — Windows x64

[日本語](README_ja.md) | English

pgextwin distributes **unofficial Windows x64 binaries** of [pg_partman](https://github.com/pgpartman/pg_partman). pg_partman maintains time- and ID-based partitions.

## Downloads and compatibility

Get the [latest published Release](https://github.com/pgextwin/pg_partman/releases/latest), or [browse all Releases](https://github.com/pgextwin/pg_partman/releases). Published PostgreSQL **14–18** packages appear in the [pgextwin catalog](https://pgextwin.github.io/website/en/). Select the ZIP matching your PostgreSQL major. PostgreSQL 14 community support ends November 12, 2026.

## Installation

1. Back up the relevant installation and review the [upstream setup instructions](https://github.com/pgpartman/pg_partman).
2. Stop PostgreSQL before replacing files. Extract the matching ZIP and place the files from lib/ and share/extension/ into the corresponding PostgreSQL directories.
3. Release v5.5.0-windows.1 contains SQL functionality only. The newer v5.5.0-windows.2 also includes the optional pg_partman_bgw.dll background worker. The SQL functionality does not require preload. To use the background worker, follow upstream instructions for shared_preload_libraries, pg_partman_bgw.dbname, pg_partman_bgw.role, pg_partman_bgw.interval and restart PostgreSQL.
4. Start PostgreSQL after configuring the package and run CREATE EXTENSION pg_partman; in each database that needs it.

Use the Release's SHA256SUMS.txt to verify downloads. SPDX SBOMs, vulnerability reports and signed attestations may be supplied with the Release. Test in a non-production environment first.

## License

For SQL/API usage and limitations, consult [upstream pg_partman](https://github.com/pgpartman/pg_partman). pgextwin is independent from the upstream authors. The included license notices apply.
