# pg_partman — 署名付き Windows x64 バイナリ

[English](README.md) | 日本語

PostgreSQL 14〜18（Windows x64）向けの上流 pg_partman 5.5.0 のコミュニティ製バイナリです。上流のコミットは `f7e83b9c441c7e97066d815bbe14e02a9dc5ff94` に固定し、PostgreSQL ライセンスを原本と照合します。PG14 はサポート終了日（2026-11-12）までを対象とします。

- **既存の [v5.5.0-windows.1](https://github.com/pgextwin/pg_partman/releases/tag/v5.5.0-windows.1) は SQL 専用版**です。BGW は同梱されず、手動・外部スケジューラーで保守します。
- **v5.5.0-windows.2 は公開検証対象**です。SQL 機能はそのまま使え、`lib/pg_partman_bgw.dll` を任意機能として追加する予定です。PG14〜18の署名付きRelease CI全件成功までは正式配布を宣言しません。
- DLL をコピーするだけでは BGW は動作しません。任意に `shared_preload_libraries = 'pg_partman_bgw'`、`pg_partman_bgw.dbname`、`pg_partman_bgw.role`、`pg_partman_bgw.interval` を設定し、PostgreSQL を再起動します。メンテナンス用の非スーパーユーザーには、対象親子テーブルと partman スキーマに必要な権限のみを付与してください。

[インストール方法と検証範囲](docs/windows_ja.md)を参照してください。対応するPGメジャー専用ZIPを選び、SHA256・SPDX SBOM・Grype・GitHub証明を検証してください。アップグレード、フェイルオーバー、他の事前ロード拡張との組合せは別途検証が必要です。
