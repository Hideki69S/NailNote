---
name: nailnote-dev
description: Use this skill when working on the NailNote app's SwiftUI screens, AI nail score flow, or project-specific development workflow. It covers the required pre-checks, protected structure, implementation guardrails, and mandatory PROJECT_STATUS.md update process for this repository.
---

# NailNote Development

このスキルは、NailNote リポジトリで実装や調査を行うときに使う。
常時ルールは `AGENTS.md` を優先し、このスキルでは NailNote 固有の進め方だけを補強する。

## 使う場面

- SwiftUI 画面を修正するとき
- AIネイルスコア周りを触るとき
- 実機確認を前提に作業するとき
- セッション再開時に現状把握から入りたいとき

## 開始手順

1. `PROJECT_STATUS.md` を読み、現状を日本語で短く要約してから着手する。
2. `git status --short` で未コミット変更を確認する。
3. 既存変更、特に `NailNote.xcodeproj/project.pbxproj` は勝手に戻さない。

## 構造ガード

- `.xcodeproj` と `project.pbxproj` は直接編集しない。
- `RootView` のタブ構成は `記録 / 用品 / AI / 設定` の 4 つを維持する。
- `SimHomeView` は AIネイルスコア専用ハブとして扱い、先頭には `AdPlaceholderBanner` を維持する。
- Swift 以外を編集する場合は、原則としてドキュメントのみ触る。

## 実装ガード

- CoreData の AI スコア保存は `EntryAIScoreBridge` 経由の方針を崩さない。
- AI 評価実行ボタンは、必ず確認ダイアログを経由させる。
- `OPENAI_API_KEY` 未設定時はモックレスポンス仕様を維持する。
- 写真や一覧レイアウト変更では、既存の可読性と折り返し崩れに注意する。

## 実機確認

- 実機確認は、まず現在使える端末で行う。
- `iPhone 17e` は `developer disk image` 問題の再発余地があるため、接続できない場合は無理に固執しない。
- 実機で止まる場合は、接続状態、Developer Mode、Apple ID / Signing を順に切り分ける。

## 作業完了時

- Swift ファイルを変更した場合は、`PROJECT_STATUS.md` を必ず更新する。
- 追記内容には次を含める。
  - 変更したファイル一覧
  - 実装内容の概要
  - 影響範囲
  - 実機確認状況
  - 次にやること
- 完了報告では、変更要点だけを短く伝え、ファイル全文は出さない。
