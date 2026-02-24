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
### 2026-02-24 (前回)
変更ファイル: Features/Entries/AddEntryView.swift, Features/Entries/EditEntryView.swift, Features/Products/AddOrEditProductView.swift, Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実機確認: 未実施（UI変更のみ、Simulator/実機とも未確認）
実装内容: 記録・用品の登録/編集フォームを`GlassBackgroundView`で包み、`Form`の背景を透過させることで一覧タブと同じガラス調グラデーションを画面全体に適用。これにより「他画面も同じ背景にしたい」という要望に合わせて、主要フォーム画面もビジュアルを統一した。SimHomeViewではエントリ一覧をローカルスナップショットでそのまま描画する構造にまとめ直し、`entries` や状態プロパティ参照時のコンパイルエラーを解消。
影響範囲: AddEntryView / EditEntryView / AddOrEditProductView のナビゲーションスタックと背景描画。`Form`の背景が透明になるため、項目の視認性が変わる可能性あり。SimHomeViewのAIスコア一覧描画ロジックも影響。

### 2026-02-24 (今回)
変更ファイル: App/RootView.swift, Features/Entries/EntryListView.swift, Features/Entries/EditEntryView.swift, Features/Products/ProductListView.swift, Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: `EntryRowView`のカード高さを`minHeight 150→130`に調整し、サムネイルフレームを`56→72→84`ptへ段階的に拡大して写真をさらに見やすくした。さらにカード内部に乳白グラデ＋ローズゴールド枠のグローレイヤー、きらめき付きタイトル、カプセル型の`[実施日付]/[自己評価]`タグ、AIスコア表示を追加して「可愛くてリッチ」な見た目へ刷新。実施日付が見切れないようフォントサイズ・間隔・タグの固定サイズを調整し、見出しも折り返さず表示できるようにした。デザイン名のテキストは最小スケールを下げて可変縮小させ、途中で`...`にならず最後まで表示できるようにした。AIスコア済みの写真には左上にスコアバッジを重ね、アイコンもペン（`pencil.and.outline`）に統一し、カード下段でのテキスト表示は廃止してバッジのみで示す構成に整理した。フィルターの各メニュー・キーワード入力のみ白背景＋ごく薄い枠線に変更し、カード全体や周囲のGlassトーンは維持して視認性を高めた。Simタブでは`onChange`が参照していた`evaluationSnapshots`計算プロパティを廃止し、`entries.map { $0.aiScoreBridge?.evaluatedAt }`を直接渡すことで`entries`解決エラーを改善。`alertBinding`/`confirmationDialogBinding`の計算プロパティを除去し、インラインBindingへ変更しつつ、`EntryThumbnailView`呼び出しも新しい`aiScore`引数に追随。写真の無い記録カードはAI一覧に表示しないようフィルタリングを追加し、未評価の説明文を簡潔化した上で、画面上部に「AI評価には写真が必要」という赤字注意書きを常設。`AI出力サンプル`カードは`AISampleCardView`へ切り出し、`@Binding var showingSample`経由でモーダル表示を制御。`content`計算プロパティの閉じ括弧位置も補正し、後続ヘルパーのスコープ崩れを防止。さらに用品一覧のSHOPメニューとキーワード入力も白背景＋淡いアウトラインに合わせ、デザイン一覧と視覚トーンを統一。タブバーのAIアイコンも同じペンに揃えてアプリ全体で表現を統一し、`EditEntryView`から余計な`NavigationStack`を取り除いて保存後に確実に一覧へ戻れるようにした。
影響範囲: デザイン一覧のカード表示（高さ・サムネイルサイズ変更＋リッチ装飾）とフィルターUI、Simタブ内のAIネイルスコアロジック、用品一覧のフィルター操作感。UI密度・画像サイズ・ボタン背景が変化するため、文字折り返しやレイアウト崩れを実機確認する必要あり。
実機確認: 未実施。`xcodebuild`によるビルドを試行したが、`xcode-select`がCommand Line Toolsを指しているためビルドできず。Xcode本体のDeveloperディレクトリ設定後に再実行予定。
次にやること: 1) `xcode-select --switch`でXcode.app付属のDeveloperディレクトリに切り替え、`xcodebuild`でビルド確認 2) Simulator/実機でSimタブの表示と評価ボタン挙動を再確認 3) 継続タスク（AIネイルスコアUI磨き、用品カード改善など）を進行

### 2026-02-24 (追記)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザイン一覧のフィルター行にある「カラー」メニューの先頭アイコンを、`drop.fill` から絵文字 `🎨` に変更した。カラー絞り込み機能や選択ロジックには手を入れず、表示ラベルのみを差し替えて視認性と意図の分かりやすさを改善した。
影響範囲: EntryListView の `colorFilterMenu` ラベル表示のみ。フィルタ機能の内部挙動・保存値（`EntryColorFilter`）には影響なし。
実機確認: 未実施（ユーザーによるビルド確認待ち）。
次にやること: 1) Simulator/実機でフィルター行の表示崩れ有無を確認 2) 他フィルターアイコンとの統一感を必要に応じて調整

### 2026-02-24 (追記2)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザイン一覧のフィルター行にある「デザイン」メニューの先頭アイコンを、`line.3.horizontal.decrease.circle` から絵文字 `💅` に変更した。既存のフィルター選択ロジック・保存値（`EntryDesignFilter`）には変更を加えていない。
影響範囲: EntryListView の `designFilterMenu` ラベル表示のみ。検索・絞り込みの挙動には影響なし。
実機確認: 未実施（ユーザーによるビルド確認待ち）。
次にやること: 1) Simulator/実機でデザイン/カラー両メニューの絵文字位置と余白を確認 2) 必要ならフォントサイズを微調整

### 2026-02-24 (追記3)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザイン一覧カードを「軽めの大人っぽさ」に寄せるため、`EntryRowView` と関連コンポーネントの装飾を小幅調整した。具体的にはタイトルをグラデ文字＋両端きらめきから単色文字＋左側のみ控えめアイコンへ変更し、カードのグローレイヤーはくすみベージュ/グレー系に再配色して影と枠線の強さを下げた。あわせてサムネイル枠色・影、情報タグ（実施日/自己評価）、AIスコアバッジも彩度と発光感を抑え、可読性を維持したまま落ち着いたトーンへ寄せた。
影響範囲: EntryListView のカード見た目（タイトル行、カード背景、タグ、バッジ、サムネイル枠）に限定。データ構造・フィルタロジック・保存処理への影響はない。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで明るい環境・暗い環境それぞれの可読性を確認 2) 物足りない場合はタイトル色とカード影だけを段階的に戻して中間案を作成

### 2026-02-24 (追記4)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: ユーザー指定の「セージグレー x ローズゴールド」案を試すため、前回の軽め調整をベースに配色を再チューニングした。カード背景グラデーションをセージ寄りグレーへ寄せ、外枠とサムネイル枠をローズゴールド寄りの中低彩度トーンへ変更。タイトル色とアイコン色、情報タグの文字/枠線、AIスコアバッジのグラデーションも同系色に揃え、味気なさを抑えつつ大人っぽい華やかさを追加した。
影響範囲: EntryListView の見た目のみ（タイトル行、カード背景、枠線、タグ、AIバッジ、サムネイル枠）。機能・保存データ・フィルタ挙動への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで色味の沈み具合を確認 2) 必要ならローズゴールド成分（枠線とバッジ）だけ強度を±10%で微調整

### 2026-02-24 (追記5)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせて配色案を「1. スモーキーローズ x シャンパン」に差し替えた。セージ系だったカード背景をシャンパン系の淡いグラデーションへ戻し、外枠・サムネイル枠・タイトル色・情報タグ・AIスコアバッジを低彩度ローズ寄りへ再調整。落ち着きは維持しつつ、味気なさを避けるためにローズ成分をやや増やした。
影響範囲: EntryListView の見た目のみ（カード背景、枠線、タイトル、タグ、AIバッジ、サムネイル枠）。機能・保存・フィルタロジックへの影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで白背景とのコントラストを確認 2) くすみが強すぎる場合はタイトル色のみ10%濃くする

### 2026-02-24 (追記6)
変更ファイル: Design/GlassCard.swift, Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザイン一覧カードの「内側と外側の距離感」を少し詰めるため、`GlassCard` に `contentPadding` パラメータ（既定値16）を追加し、互換性を保ったまま画面ごとに内側余白を調整できるようにした。`EntryListView` の `EntryRowView` では `contentPadding: 14` を指定し、カードの内側余白だけをわずかに縮小して、体感的に内側領域が広く見えるようにした。
影響範囲: EntryListView のカード内余白と、GlassCard を使う他画面での将来的な余白調整拡張性。既定値を維持しているため既存画面の見た目は変化しない。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorでカード内コンテンツの詰まり具合を確認 2) さらに詰めたい場合は `contentPadding` を 13 へ再調整

### 2026-02-24 (追記7)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせて、デザイン一覧カードの `contentPadding` を `14 -> 12` へ変更した。カードの外寸を維持したまま内側余白をさらに詰め、コンテンツ領域がより広く見えるように調整。
影響範囲: EntryListView のカード内余白のみ。機能・データ・他画面レイアウトへの影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで窮屈さがないか確認 2) 必要なら `12.5` 相当（実装は 13 へ戻す）で中間調整

### 2026-02-24 (追記8)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせて、デザイン一覧カードの `contentPadding` を `12 -> 10` に変更。カードの外寸を維持しつつ内側余白をさらに圧縮し、内側の表示面積を拡大した。
影響範囲: EntryListView のカード内余白のみ。機能・データ・他画面への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで文字詰まりと可読性を確認 2) 詰まりが強ければ `11` に戻して中間調整

### 2026-02-24 (追記9)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AI評価チャート（`AIScoreRadarChart`）の見た目をリッチ化。背景に淡いラジアルグラデを追加し、レーダー軸線・外周線を強調。データポリゴンはピンク〜ラベンダー系グラデ塗り＋グラデ線に変更し、各頂点にグローポイントを追加。中央スコアはメダル風サークルに変更して `TOTAL` 表示を追加。ラベルはカプセル背景で可読性を上げ、チャート高さも `200 -> 220` に拡張した。
影響範囲: SimHomeView 内の `EntryAIScoreSummaryView` / `AIScoreRadarChart` の表示のみ。評価ロジック・保存処理・API連携には影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorでラベル重なりと可読性を確認 2) 必要ならラベル位置係数（`1.18`）とメダルサイズを微調整

### 2026-02-24 (追記10)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: チャートの白系ベースフレームと項目ラベルが背景に同化する問題に対応し、`AIScoreRadarChart` の配色を再調整。グリッド線・外周破線・軸線をローズグレー系へ変更し、ラベルカプセル背景をシャンパン寄りの半透明色＋ローズグレーストロークに変更。中央メダルの塗りと `TOTAL` 文字色も同系色へ寄せ、全体のリッチ感を維持しながら視認性を改善した。
影響範囲: SimHomeView のチャート表示色のみ。レイアウト構造・評価ロジック・データ保存には影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで明るい背景上のコントラストを確認 2) 必要ならグリッド線の不透明度をさらに+0.05調整

### 2026-02-24 (追記11)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AI評価コメントを「スコアを形成する5項目別」に変更。`EntryAIScoreSummaryView` の表示を `Good/Improve` から `5項目コメント` セクションへ置き換え、`仕上がり / 甘皮ライン / 厚み / デザイン / 持ち予測` の順で表示するようにした。`NEXT` と `前提条件` は既存のまま維持。あわせて `makePrompt` を更新し、`highlights` に5項目コメントを固定順で返すようAIへの指示を強化。モックレスポンスも同形式に合わせた。既存データ互換のため、形式不一致時はスコア値からフォールバックコメントを生成する実装を追加した。
影響範囲: SimHomeView のAI結果表示（コメントセクション）と、AIレスポンス生成プロンプト／モックレスポンス。評価保存の基本フロー・NEXT・前提条件表示には影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 新規評価で5項目コメントが想定順に表示されるか確認 2) 既存評価データでフォールバック文言が不自然でないか確認

### 2026-02-24 (追記12)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせて、AI評価チャートの配色をピンク基調から青基調へ変更。背景ハロー、グリッド線、外周破線、軸線、データ面グラデ、輪郭線、頂点マーカー、中央メダル、ラベルカプセルまでをブルー〜シアン系で統一し、既存のリッチ感を維持しながらクールトーンに寄せた。
影響範囲: `AIScoreRadarChart` の表示色のみ。レイアウト・評価ロジック・保存データには影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで青色のコントラストと可読性を確認 2) 必要なら輪郭線とラベル枠の彩度を軽微調整

### 2026-02-24 (追記13)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせて、AI評価チャートの配色を青基調からグリーン基調へ変更。背景ハロー、グリッド線、軸線、データ面グラデ、輪郭線、頂点マーカー、中央メダル、ラベルカプセルをミント〜リーフグリーン系で再統一し、リッチ感を保ちながら爽やかなトーンへ調整した。
影響範囲: `AIScoreRadarChart` の表示色のみ。チャート構造・評価ロジック・保存データへの影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで背景とのコントラストを確認 2) 必要なら外周線の濃度を+0.05調整

### 2026-02-24 (追記14)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザイン一覧カードでサムネ左側の詰まり感を緩和するため、`EntryThumbnailView` に `offset(x: 3)` を付与して視覚的にわずかに右へ移動。レイアウト計算に影響しない `offset` を採用し、右カラム（タイトル/情報/バッジ）の幅や折り返しへの干渉を避けた。
影響範囲: EntryListView のサムネ表示位置のみ。カード内の他要素レイアウト・機能・データ処理には影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで余白バランスを確認 2) 必要なら `x: 2` または `x: 4` で微調整

### 2026-02-24 (追記15)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: 追加要望に合わせてサムネ位置をさらに右へ 2pt 移動し、`offset(x: 3) -> offset(x: 5)` に変更。`offset` はレイアウト計算を変えないため、右カラム幅への影響を抑えたまま視覚位置のみを調整した。
影響範囲: EntryListView のサムネ描画位置のみ。右カラムのレイアウト・機能・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで左余白の見え方を確認 2) 必要なら `x: 4` へ1pt戻して中間調整

### 2026-02-24 (追記16)
変更ファイル: Design/GlassTheme.swift, PROJECT_STATUS.md
実装内容: 全ページ背景の共通グラデーションを「スモーキーセージ × シャンパン」へ変更。`GlassTheme.backgroundGradient` の3色を淡いセージ〜シャンパン系へ再定義し、あわせて `orbColors` も同系の低彩度トーンへ調整した。可愛さを残しつつ大人っぽい落ち着きを出す方向で全画面に反映される構成。
影響範囲: `GlassBackgroundView` を使う画面全体（記録/用品/AI/設定および各フォーム画面）の背景トーン。機能・ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで全タブの背景統一感を確認 2) 必要なら中間色の明度を微調整
