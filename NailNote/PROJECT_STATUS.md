# PROJECT_STATUS.md

## 概要（プロジェクト名、技術スタック、目的）
- プロジェクト名：NailNote（ネイル施術と用品管理の個人ログアプリ）
- 技術スタック：Swift 5.10 / SwiftUI / CoreData / PhotosUI / UIKitブリッジ（画像選択） / Xcode 16系想定
- 目的：記録（Entry）と用品（NailProduct）の CRUD、写真・カテゴリ・自己評価を一元管理し、将来的にはシミュレーションやバーコード連携まで拡張する

## 現在の構造（ツリー）
```
NailNote/
├─ App/                  # エントリポイントとRootView
├─ Assets.xcassets/      # 色・画像アセット
├─ Core/                 # CoreDataモデル、PhotoStore、カテゴリ定義
│  ├─ Model/             # （空き枠、今後の拡張）
│  ├─ NailNote.xcdatamodeld
│  ├─ *+CoreDataClass.swift / *+CoreDataProperties.swift
├─ Design/               # ガラス系コンポーネントとStarRating
├─ Features/
│  ├─ Entries/           # EntryList/Add/Edit/用品選択
│  ├─ Products/          # ProductList/Add/Edit/カテゴリenum
│  ├─ Settings/          # 設定タブ
│  └─ Sim/               # シミュレーション系画面
└─ (その他) Persistence.swift など
```

## CoreData（Entity/プロパティ/Codegen/注意点）
- **NailEntry**（Manual/None, クラス/プロパティ自前管理）
  - 主キー `id: UUID?`
  - `title:String?`, `note:String?`, `date:Date?`, `createdAt`, `updatedAt`
  - `photoId:UUID?`（EntryPhotoStoreで実ファイルを管理）
  - `designCategory:String?`, `colorCategory:String?`（NailDesignCategory/NailColorToneと相互変換）
  - `rating:Double`（0〜5, 0.5刻み）
  - 関連 `usedItems:NSOrderedSet?` → NailEntryUsedItem
  - 注意：削除時は `EntryPhotoStore.delete` を必ず呼ぶ
- **NailProduct**（Manual/None）
  - 主キー `id:UUID?`
  - `name`, `category`, `purchasePlace`, `priceYenTaxIn:Int32`
  - `purchasedAt:Date?`, `createdAt`, `updatedAt`
  - `photoId`, `samplePhotoId`（ProductPhotoStore管理）
  - リレーション `usedInEntries:NSSet?`
  - 注意：価格は税込み円。フォームでは `ShopSelectionField` で既存＋新規入力
- **NailEntryUsedItem**（Manual/None）
  - `id:UUID?`, `orderIndex:Int16`, `entry`, `product`
  - EntryとProductの中間テーブルとして表示順を保持
- **UsageQuota**（Manual/None）
  - `monthKey:String?`, `freeSimRemaining:Int16`, `updatedAt`
  - シミュレーション課金制御用。UIは未接続
- すべて Codegen: Manual/None。`xcdatamodeld` を編集したら `Editor > Create NSManagedObject Subclass` で再生成の必要あり

## 実装済み機能
- RootView で 4タブ（記録/用品/シミュ/設定）構成
- EntryListView
  - GlassBackground + GlassCard
  - デザイン/カラーのフィルタ（Menu）と AppStorage 永続
  - サムネイル読み込み、デザイン/カラー badge、StarRatingView 表示
  - Entry 削除時は PhotoStore もクリーン
- Add/Edit Entry
  - 用品選択（ProductMultiSelectView）、自己評価、デザイン/カラー設定
- ProductListView
  - GlassBackground + GlassCard、カテゴリタブ、SHOP/価格/キーワードフィルタ
  - SHOP は登録済＋新規追加を選択でき、Sample写真や購入金額見出し表示
  - 浮遊＋ボタンで AddOrEditProductView を起動
- AddOrEditProductView
  - PhotosPicker で商品/サンプル画像を選択
  - 日本の和暦カレンダー＋ yyyy/MM/dd 表記の DatePicker
- PhotoStore
  - `EntryPhotoStore` / `ProductPhotoStore` でサムネイル生成・削除
- Designコンポーネント
  - GlassTheme / GlassBackgroundView / GlassCard / StarRatingView
  - 背景グラデやカード枠、影、評価スターの色調が統一

## 現在のUI状態
- Glassmorphism：RootView配下の EntryListView / ProductListView で背景＋カードが適用済み。Sim/Settings/フォーム画面は未対応（従来の Form/NavigationStackのまま）。
- カード化：EntryListView と ProductListView のセルのみ。Entry/Products の詳細フォームやシミュ画面はリスト表示（カードなし）。
- タブ：RootView は `記録 / 用品 / シミュ / 設定` の4タブ維持。タイトルバーは非表示にしてタブ名がラベルになる。

## 直近で起きた問題と学び（＋再発防止ルール）
1. **NailNote.xcodeproj の破損**
   - 誤操作で pbxproj が壊れ Xcode でツリー非表示・Run不可状態になった。
   - *再発防止*：pbxproj を直接編集しない。Xcode 上でグループ操作する際もコミット前に diff を確認し、危険なら `git restore NailNote.xcodeproj/project.pbxproj` で巻き戻す。
2. **`Could not attach to process`（実機デバッグ時）**
   - Xcode の派生データやデバイス再起動で解決。
   - *再発防止*：Run失敗時は「Product > Clean Build Folder」「デバイス再接続」「Xcode再起動」を順に実施。ログを PROJECT_STATUS.md に追記して可視化。
3. **ガラスUIが白飛びして文字が読めない問題**
   - GlassTheme/GlassCard のグラデ・枠線を調整、`.foregroundStyle(.primary)` をカード内で強制。
   - *再発防止*：彩度調整は Design配下のみで完結させ、他画面の文字色を無理に上書きしない。テーマに変更を入れたら Entry/Product 双方で実機確認。

## 次にやること（優先順とDoD）
1. **記録一覧の追加フィルタ（カラー系統タブ化）**
   - DoD：EntryListView でデザイン/カラーを視覚的に切替でき、AppStorage に保持される。UIがカード幅内に収まり、レイアウト崩れがないこと。
2. **Entry/Products のフォーム刷新（将来のScrollViewレイアウト）**
   - DoD：Form 依存をなくし、写真・カテゴリタブ・用品選択を1画面でスクロール表示できる。既存バリデーション維持。
3. **バーコード検索基盤**
   - DoD：BarcodeLookupService（既存未使用ファイル）を完成させ、Barcode読み取り→候補商品表示→手動編集の流れが最低限動く。

※ 各タスク前に本ファイルを更新して最新状態を反映する。

## 作業手順テンプレ
1. `git checkout -b feature/<topic>` で枝分け
2. `git status && git pull --rebase` で同期
3. 変更箇所を明確に決め、必要なら `PROJECT_STATUS.md` を更新
4. コード編集 → `xcodebuild -scheme NailNote -destination 'platform=iOS Simulator,name=iPhone 15' clean build` or Xcode Run
5. 実機確認が必要なら同じビルドを実機で Run（Could not attach 対策の手順順守）
6. `git status` → `git add` → `git commit -m "feat: ..."` → `git push`

## Codex への作業ルール（Do / Don't）
- **Do**
  - 出力は常に日本語、ファイル提示は全文
  - 既存構造（フォルダ階層、ファイル名）を尊重
  - apply_patch で最小単位の編集を行い、Design以外のテーマ変更は慎重に
  - PhotoStore経由でファイルを扱い、CoreData削除時は写真削除も行う
- **Don't**
  - `rm -rf`、`git reset --hard`、`xcodeproj` 直編集
  - Swift以外の不要ファイル追加（今回のドキュメント系を除く）
  - エラー再現せずに設定を変更すること
  - 差分出力（必ずファイル全文を記載する）

## 重要コマンド集
- 状態確認：`git status`, `git diff --stat`, `rg 'pattern' -n`
- クリーン：`xcodebuild clean -scheme NailNote`
- ビルド：`xcodebuild -scheme NailNote -destination 'platform=iOS Simulator,name=iPhone 15' build`
- 派生データ削除：`rm -rf ~/Library/Developer/Xcode/DerivedData`（※手動実行のみ。自動化しない）
- CoreData再生成：Xcode > Editor > Create NSManagedObject Subclass
- 画像確認：`open ~/Library/Developer/CoreSimulator/.../Documents/EntryPhotos`（必要な時のみ）

