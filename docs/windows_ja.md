# pg_partman 5.5.0 — Windows x64 導入手順

## リリースの区分

既存の [v5.5.0-windows.1](https://github.com/pgextwin/pg_partman/releases/tag/v5.5.0-windows.1) はSQL専用で変更しません。新しいZIPに `lib/pg_partman_bgw.dll` が含まれる場合に限り、任意のBGWを有効にできます。PG14〜18それぞれの専用ZIPを使用し、PG14は2026-11-12のEOLまで対象です。

## SQL専用の導入

SHA256SUMS、出自証明、SBOMを検証し、ZIP内の `share/extension` を対象PGの同名フォルダーにコピーします。`CREATE SCHEMA partman; CREATE EXTENSION pg_partman SCHEMA partman;` を実行し、子テーブルへの振り分けを確認します。定期保守は `CALL partman.run_maintenance_proc();` を適切な権限の外部スケジューラーから実行できます。BGWの事前ロードは不要です。

## BGWを任意で有効化

対象のPostgreSQLメジャーバージョン向け `lib/pg_partman_bgw.dll` を、停止中のPostgreSQLの `lib` に配置し、以下を設定して再起動してください。既存の `shared_preload_libraries` にほかの拡張機能が指定されている場合は、その設定を残して追加します。

```conf
shared_preload_libraries = 'pg_partman_bgw'
pg_partman_bgw.dbname = 'postgres'
pg_partman_bgw.role = 'partman_maintainer'
pg_partman_bgw.interval = 3600
pg_partman_bgw.jobmon = off
```

対象データベースへのCONNECT、partmanスキーマのUSAGE・EXECUTE・必要なDML権限、対象親テーブルの所有権とDDL権限、既存子テーブルのSELECT権限、新規子の作成権限を、メンテナンス専用の非スーパーユーザーに限定して付与します。サーバーログでBGW起動・実行・終了を確認し、外部保守ジョブとの重複に注意してください。

## テストと制約

PG14〜18の各Windows CIで、ロードなしのSQL動作テストと、MSVC生成DLLのエクスポート確認・ロード・非管理者実行・欠落した子パーティションの自動補充を分けて実施します。さらにZIP・SPDX・Grype・SHA256・GitHub証明の成功を正式公開条件とします。フェイルオーバー、高負荷、独自の権限ポリシー、アップグレード・ロールバックは別途検証してください。既存ReleaseのZIPは改変せず、別タグで配布します。
