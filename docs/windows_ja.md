# pg_partman Windows パイロット

**状態：技術検証中。全 PostgreSQL major の機能テスト・成果物検査が成功するまで公開禁止。**

上流：https://github.com/pgpartman/pg_partman/tree/f7e83b9c441c7e97066d815bbe14e02a9dc5ff94

SQL/PLpgSQL のみを構成します。バックグラウンドワーカー（BGW）は生成・配布・サポートしません。メンテナンスは外部スケジューラ等で実行し、専用の最小権限ユーザーを使用してください。
PG14 は 2026-11-12 を超えて維持しません。ZIP の対応 major、SQL ファイル、ライセンス、SBOM・Grype・出自を確認してください。現時点では本番環境への導入を推奨しません。
