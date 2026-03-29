---
name: nailnote-dev
description: Use this skill when working on the NailNote app's SwiftUI screens, AI nail score flow, project-specific implementation workflow, or session handoff flow. Use it for requests such as continuing from PROJECT_STATUS.md, editing RootView or SimHomeView safely, preserving NailNote's fixed tab structure, handling EntryAIScoreBridge-based persistence, or updating PROJECT_STATUS.md after Swift changes.
---

# NailNote Development

このスキルは、NailNote リポジトリで実装や調査を行うときに使う。
常時ルールは `AGENTS.md` を優先し、このスキルでは NailNote 固有の進め方だけを補強する。

## 基本方針

- 常に `PROJECT_STATUS.md` を起点に状況を復元する。
- 既存の構造保護ルールを優先し、勢いで広く触らない。
- 画面修正とあわせて、影響範囲と実機確認観点まで整理する。
- 詳細な追記テンプレートは `references/project-status-entry-template.md` を参照する。

## 開始手順

1. `PROJECT_STATUS.md` を読み、現状を日本語で短く要約してから着手する。
2. `git status --short` で未コミット変更を確認する。
3. 既存変更、特に `NailNote.xcodeproj/project.pbxproj` は勝手に戻さない。
4. 今回触る対象が `Entry` 系、`Product` 系、`AI` 系のどれかを先に絞る。

## 構造ガード

- `.xcodeproj` と `project.pbxproj` は直接編集しない。
- `RootView` のタブ構成は `記録 / 用品 / AI / 設定` の 4 つを維持する。
- `SimHomeView` は AIネイルスコア専用ハブとして扱い、先頭には `AdPlaceholderBanner` を維持する。
- Swift 以外を編集する場合は、原則としてドキュメントのみ触る。
- 旧構成が残る `New Group/` は原則触らない。

## 実装ガード

- CoreData の AI スコア保存は `EntryAIScoreBridge` 経由の方針を崩さない。
- AI 評価実行ボタンは、必ず確認ダイアログを経由させる。
- `OPENAI_API_KEY` 未設定時はモックレスポンス仕様を維持する。
- 写真や一覧レイアウト変更では、既存の可読性と折り返し崩れに注意する。
- Entry 編集では `viewContext.save()` と一覧反映を崩さない。
- Entry 写真削除や Entry 削除では `EntryPhotoStore.delete` の呼び忘れに注意する。
- CoreData モデル更新時は、Manual/None 運用を前提に生成物の扱いを慎重に確認する。

## 変更対象ごとの着眼点

- `Entries`: フィルタ保持、自己評価表示、写真削除、用品選択の整合性を見る。
- `Products`: カテゴリタブ、購入場所、価格表示、リンク共有まわりの UI 崩れを見る。
- `AI`: `SimHomeView` 起点、確認ダイアログ、モック分岐、`EntryAIScoreBridge` 保存を確認する。
- `Settings`: 一時プレビューや比較 UI は、採用後に削除しやすい形で実装する。

## 実機確認

- 実機確認は、まず現在使える端末で行う。
- `iPhone 17e` は `developer disk image` 問題の再発余地があるため、接続できない場合は無理に固執しない。
- 実機で止まる場合は、接続状態、Developer Mode、Apple ID / Signing を順に切り分ける。
- 現時点では、実機検証は `iPhone XS` を優先候補として扱う。

## 作業完了時

- Swift ファイルを変更した場合は、`PROJECT_STATUS.md` を必ず更新する。
- 追記内容には次を含める。
  - 変更したファイル一覧
  - 実装内容の概要
  - 影響範囲
  - 実機確認状況
  - 次にやること
- `PROJECT_STATUS.md` の追記書式に迷ったら `references/project-status-entry-template.md` を使う。
- 完了報告では、変更要点だけを短く伝え、ファイル全文は出さない。
