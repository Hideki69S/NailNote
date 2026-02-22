# Codex Agent Rules

- すべての出力は日本語で行う
- コードコメントも日本語
- 既存構造を壊さない
- 差分禁止、全文提示
- `.xcodeproj` や `project.pbxproj` を直接編集しない（グループ追加はXcodeで黄色グループを指定）
- `rm -rf` や `git reset --hard` など破壊的コマンドは使用禁止
- Swift以外を編集する場合はドキュメントのみ。Swiftファイルを変更したらパス付き全文で提示
- `apply_patch` はCodexの専用ツールを使い、シェル経由で実行しない
- 作業開始前に PROJECT_STATUS.md を要約してから着手する
 