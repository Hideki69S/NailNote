# PROJECT_STATUS.md

## 概要（プロジェクト名、技術スタック、目的）
- プロジェクト名：NailNote
- 技術スタック：Swift 5.10 / SwiftUI / CoreData / PhotosUI / UIKit（写真系ブリッジ） / Xcode 16系、iOS 17実機を前提
- 目的：ネイル施術記録（NailEntry）と用品（NailProduct）を一つのアプリで管理し、写真・カテゴリ・カラー・自己評価・購入情報・将来のシミュレーション/バーコード連携まで拡張できる基盤を作る

## 現在の構造（主要ディレクトリ）
```
NailNote/
├─ App/                  # RootView, Appエントリ
├─ Assets.xcassets/      # アセット
├─ Core/                 # CoreDataモデル、PhotoStore、カテゴリ
│  ├─ NailNote.xcdatamodeld
│  ├─ *+CoreDataClass/Properties.swift（Entry/Product/UsedItem/UsageQuota）
│  ├─ NailDesignCategory.swift / NailColorTone.swift
│  ├─ EntryPhotoStore.swift / ProductPhotoStore.swift
│  └─ Persistence.swift
├─ Design/               # GlassTheme, GlassBackgroundView, GlassCard, StarRatingView
├─ Features/
│  ├─ Entries/           # EntryListView, AddEntryView, EditEntryView, ProductMultiSelectView
│  ├─ Products/          # ProductListView, AddOrEditProductView, NailProductCategory
│  ├─ Settings/          # SettingsView
│  └─ Sim/               # SimHomeView（AIネイルスコアハブ）, AdPlaceholderBanner
├─ PROJECT_STATUS.md     # 本ファイル
└─ （New Group/ 配下に旧構成の複製が残存。触らず要注意）
```

## CoreData（Entity名・主要プロパティ・Codegen・注意点）
- **NailEntry**（codeGenerationType: class → Manual/None）
  - `id(UUID)`, `title(String?)`, `note(String?)`, `date(Date)`, `createdAt/updatedAt(Date)`
  - `photoId(UUID?)`（EntryPhotoStoreで管理）
  - `designCategory(String?)`, `colorCategory(String?)`, `rating(Double)`
  - `usedItems(NSOrderedSet<NailEntryUsedItem>)`
  - 注意：削除時は EntryPhotoStore.delete を忘れず実行
- **NailEntryUsedItem**（Manual/None）
  - `id(UUID)`, `orderIndex(Int16)`、`entry`←→`product` 片側Nullify
  - 注意：Entry保存時は順序を再構築し直しのうえ結び直す
- **EntryAIScore**（Manual/None）
  - `id(UUID)`, `totalScore(Int16)`, 各サブスコア（finishQuality 等 5項目）
  - `highlights/improvements/nextSteps/assumptions` は JSON文字列で保存、`caution`、`confidence(Double)`, `evaluatedAt`, `photoHash`
  - `entry` と 1:1 関係で、同一写真ハッシュは再評価しない
  - Xcodeプロジェクト上ではコード生成対象外のため、アプリ側では `EntryAIScoreBridge`（KVCラッパー）を通じて `NSManagedObject` を安全に読み書きする。
- **NailProduct**（Manual/None）
  - `id(UUID)`, `name(String)`, `category(String)`, `purchasePlace(String?)`
  - `purchasedAt(Date?)`, `priceYenTaxIn(Int32)`, `createdAt/updatedAt(Date)`
  - 写真：`photoId(UUID?)`, `samplePhotoId(UUID?)`（ProductPhotoStore shared）
  - `productUrl(String?)`（登録画面でLink/Share）
  - 注意：価格は数値保持のみ。表示整形はビュー側で `¥`＋カンマにする
- **UsageQuota**（Manual/None）
  - `monthKey(String)`, `freeSimRemaining(Int16)`, `aiScoreUsed(Int16)`, `updatedAt(Date)`
- 全Entityが Manual/None のため、`xcdatamodeld` 更新時は「Create NSManagedObject Subclass」で再生成する必要がある

## 実装済み機能
- RootView：TabView（記録/用品/シミュ/設定）。Settingsタブは常設。
- RootView：現在は `記録 / 用品 / AI / 設定` の4タブ。旧シミュタブをAIネイルスコアへ置換し、ラベルも「AI」に統一。Settingsタブは常設。
- EntryListView：
  - GlassBackground＋GlassCard。デザイン/カラーのフィルタを AppStorage で保持し、左寄せ配置。
  - StarRatingView で0.5刻みの自己評価を表示。カラー/デザインバッジと広告プレースホルダ行、FloatingAddButton あり。
  - 削除時に EntryPhotoStore.delete を実行。
  - AIスコア表示は `EntryAIScoreBridge` で CoreData を直接読み出し、コード生成の有無に依存しない。
- AddEntryView / EditEntryView：
  - Formベース。写真選択（PhotosPicker）、カテゴリ/カラー/評価入力、NailProduct のカテゴリタブ＋トグルリスト選択。
  - Edit画面で保存後に一覧へ戻ると値が反映されるよう CoreData保存＋リストFetchが連動。
- ProductListView：
  - Glass背景＋カード化。広告行、SHOP/キーワードフィルタ、カテゴリタブ（10カテゴリ）。
  - SHOPフィルタは登録済み購入場所からプルダウン。リンク/共有ボタンは一覧では非表示。
  - 用品写真は現在未表示（干渉問題のため一時撤去）。
- EditEntryView：
  - フォーム中心のUI（写真・カテゴリ・カラー・評価・用品選択）。
  - ※AIネイルスコア機能はSimタブへ移設済み。Edit画面ではAI関連UIを保持していない。
- AddOrEditProductView：
  - Form。SHOP選択は既存＋「新規追加」を1画面で完結。商品URL入力で Link/Share ボタンを表示。
  - 購入日 DatePicker は和暦ではなく西暦グレゴリオ暦＋日本語ロケール。購入金額は `¥1,234` 表示、右寄せ。
- Design コンポーネント：GlassTheme/GlassBackgroundView/GlassCard/StarRatingView を共通利用し可読性を確保。

## 現在のUI状態（ガラス/カード適用状況）
- ガラス背景＋カード：EntryListView・ProductListViewで適用済み。Sim/Settings/フォーム（Add/Edit系）は従来のForm背景。
- カード化：Entry/Productの各Rowのみ。フォーム内 Section には未導入。
- FloatingAddButton：Entry/Products で右下丸ボタンに統一。タイトルバーは隠し、広告行＋フィルタ＋リストの縦配置。
- 用品リストはフィルタ/タブ領域が固定表示、スクロールはリストのみ。
- 写真：Entryリストにはサムネイルあり。Productリストは調整中のため無し。

## 直近で起きた問題と学び（＋再発防止ルール）
1. **NailNote.xcodeproj の破損**
   - フォルダ参照や直編集でツリー非表示＆Runボタン無効化。
   - *再発防止*：`.xcodeproj`/`project.pbxproj` は直接編集禁止。参照追加はXcode GUIで黄色グループを選び、差分が入ったらレビューして不要なら `git restore`。
2. **Glass UI の白飛び・文字可読性低下**
   - 初期テーマが白すぎてボタン/文字が見えなくなった。
   - *再発防止*：GlassThemeで彩度/コントラストを集中管理し、各ビューで `foregroundStyle(.primary)` を徹底。
3. **写真レイアウト崩れ（ProductRow）**
   - 写真とShare/Linkボタンが干渉し折り返し発生。結果として写真表示を中断。
   - *再発防止*：写真を戻す際はオートレイアウトをテキスト優先で設計し、余白・折り返しのテストを実機で行う。
4. **CoreData反映遅延（記録編集後に一覧へ戻っても更新されない）**
   - FetchRequestの結果が更新されず、アプリ再起動でしか反映されなかった。
   - *再発防止*：編集時に `viewContext.save()` を確実に行い、FetchRequestで `animation: .default` を指定している現在の構成を維持。必要に応じて `NSManagedObjectContext.refresh` を検討。
5. **apply_patch 実行方法の警告**
   - `exec_command` 経由で `apply_patch` を呼び警告が発生。
   - *再発防止*：コード編集時はCodexの `apply_patch` ツールを直接利用し、シェルからは呼ばない。
6. **AIスコア関連型が認識されないコンパイルエラー**
   - 自動生成された CoreData クラスに `EntryAIScore` / `aiScore` が含まれず、`NailEntry.aiScore` 参照時にビルド不能となった。
   - *再発防止*：`EntryAIScoreBridge` で `NSManagedObject` を直接扱い、`NailEntry` / `UsageQuota` には KVCベースの拡張を用意。型定義が欠落してもビルドできるようにした。

## 次にやること（優先順＋DoD）
1. **AIネイルスコアのUI磨き込み**
   - DoD：結果カードの視認性向上、広告枠差し替え案の確定、評価履歴の導線追加、確認ダイアログ文言の最終決定。
2. **用品カードへの写真復活 + Share/Link配置確定**
   - DoD：商品・サンプル写真2枚をカード右側に配置しても商品名が折り返さず、Share/Linkボタンの位置が固定される。
3. **フォーム刷新（ScrollView + GlassCard）**
   - DoD：Add/Edit画面のForm依存を解消し、背景・カードと一貫したデザインへ移行。購入日カレンダー、購入金額、ショップ選択のUXを改善。
4. **BarcodeLookupServiceの実装**
   - DoD：バーコードスキャン→Web検索→候補反映→手動修正の一連の流れが動作し、通信エラー時にユーザ通知する。
5. **プロジェクトドキュメントの継続更新**
   - DoD：大きな仕様変更前後に PROJECT_STATUS.md を更新し、Git履歴で差分が追える状態を保つ。
6. **AIネイルスコア出力サンプルUIの追加**
   - DoD：AIスコアが未評価でもサンプルJSON/カードを閲覧でき、実行前に期待値を共有できる。

## 作業手順テンプレ
1. `git checkout -b feature/<topic>`（必要なら main を pull した後）
2. `git status && git pull --rebase` で最新化
3. 着手前に `PROJECT_STATUS.md` と `AGENTS.md` を確認し、必要ならルール追記
4. 変更 → `xcodebuild -scheme NailNote -destination 'platform=iOS Simulator,name=iPhone 15' build` または Xcode Run
5. 実機検証が必要な場合：Run失敗時は Clean Build Folder → デバイス再接続 → Xcode再起動 → DerivedData削除 の順で対処
6. `git status`→`git add`→`git commit -m "feat: ..."`→`git push`
7. 作業完了後に PROJECT_STATUS.md を更新し、次回のためのメモを残す

## Codexへの作業ルール（Do / Don't）
- **Do**
  - すべての出力を日本語で行い、コードコメントも日本語
  - 変更したファイルはパス付きで全文提示（差分禁止）
  - 既存フォルダ構造を壊さず、ファイル追加は Design またはドキュメント配下に限定（要件がない限り）
  - CoreDataエンティティ削除時は PhotoStore のファイル削除も合わせて実施
  - `apply_patch` ツールを使い、小さな変更単位でコミット
- **Don't**
  - `rm -rf`、`git reset --hard`、`.xcodeproj` や `project.pbxproj` への直接編集
  - 差分表示での回答（必ず全文）
  - Swift以外の不要ファイル追加（必要なドキュメント以外）
  - RootViewのタブ数変更（設定タブ削除など）

## 重要コマンド集
- 状態確認：`git status`, `git diff --stat`, `rg "pattern" -n`
- 探索：`find . -maxdepth 2 -type f`, `rg --files`
- ビルド：`xcodebuild -scheme NailNote -destination 'platform=iOS Simulator,name=iPhone 15' build`
- クリーン：`xcodebuild clean -scheme NailNote`
- 実機トラブル：手動で `rm -rf ~/Library/Developer/Xcode/DerivedData`（要確認）
- 画像保存先確認：`open ~/Library/Developer/CoreSimulator/.../Documents/EntryPhotos`
- CoreData再生成：Xcode → Editor → Create NSManagedObject Subclass

## 最新セッション（自動更新）
日付: 2026-02-23
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実機確認: 未実施（Xcode Indexing継続中のためビルド走らず）
実装内容: SimHomeViewでNavigationStack部分を切り出し、警告ダイアログ用Bindingを共通化して型推論エラーを解消。ターゲット未登録だったAdPlaceholderBannerを暫定的に同ファイルへ内包し、常に広告プレースホルダを描画できるようにした。さらにAIスコアカードでは写真のハッシュを再計算して、写真が変わった場合のみ「再評価」ボタンを表示する制御を追加し、誤って同一写真で再評価できないようにした。最新のSwift 6ルールに合わせ、写真読み込み処理をMainActor経由に切り替え、ハッシュ計算ユーティリティをnonisolatedなData拡張にして警告を解消。AIタブの「AIへの依頼メモ」入力フィールドを撤去し、代わりに出力サンプル確認ボタンのみを残したシンプルなカードに変更。AIスコア詳細ビューにはカラオケ採点風の五角形レーダーチャートを追加し、5項目スコアを視覚的に把握できるようにした。
影響範囲: AIタブ（SimHomeView）の画面構成／警告・確認ダイアログ、AIスコアカードのアクションボタン表示制御。EntryAIScore評価処理そのものには変更なし。
次にやること: 1) Indexing完了後にビルド＆AI評価フローを実機確認 2) AdPlaceholderBannerを専用ファイルで使い回す場合はXcode側でターゲット登録 or 再構成 3) AIスコア履歴/サンプルUI拡充タスクを継続
