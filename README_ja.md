# pg_partman — Windows x64 バイナリ

[English](README.md) | 日本語

[pg_partman](https://github.com/pgpartman/pg_partman)の**非公式Windows x64バイナリ**を配布しています。日時やIDに基づくパーティションを保守する拡張機能です。

## ダウンロードと対応環境

[最新の公開Release](https://github.com/pgextwin/pg_partman/releases/latest)から、利用中のPostgreSQLメジャーバージョンと一致するZIPを選んでください。[過去のReleases](https://github.com/pgextwin/pg_partman/releases)も確認できます。PostgreSQL **14〜18**向けの配布状況は[pgextwinカタログ](https://pgextwin.github.io/website/ja/)を参照してください。PostgreSQL 14のコミュニティサポートは2026年11月12日に終了します。

## インストール

1. バックアップを取得し、[上流の導入手順](https://github.com/pgpartman/pg_partman)を確認します。
2. 既存ファイルを置き換える前にPostgreSQLを停止します。対応するZIP内のlib/とshare/extension/以下を、PostgreSQLの同名ディレクトリに配置します。
3. `v5.5.0-windows.1`はSQL機能のみを含みます。`v5.5.0-windows.2`には任意で使用できる`pg_partman_bgw.dll`も付属します。SQL機能だけを使う場合、事前ロードは不要です。バックグラウンドワーカーを使う場合は、上流の説明に従い`shared_preload_libraries`、`pg_partman_bgw.dbname`、`pg_partman_bgw.role`、`pg_partman_bgw.interval`を設定し、PostgreSQLを再起動します。
4. 必要な設定を反映してPostgreSQLを起動し、利用するデータベースで`CREATE EXTENSION pg_partman;`を実行します。

ダウンロードしたZIPを、Releaseに掲載された`SHA256SUMS.txt`と照合してください。SPDX形式のSBOM、脆弱性レポート、署名付き証明の有無はReleaseで確認できます。本番環境に導入する前に、検証環境で動作を確認してください。

## ライセンス

利用方法や制限事項は[上流のpg_partman](https://github.com/pgpartman/pg_partman)を参照してください。本配布は上流公式のWindows版ではありません。ライセンスは同梱の表記に従います。
