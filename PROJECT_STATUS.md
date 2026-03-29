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

### 2026-02-24 (追記17)
変更ファイル: Design/GlassTheme.swift, Features/Settings/SettingsView.swift, Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: 設定画面に「ページ背景 / デザインカード / アイテムカード」の3項目を独立して選べるテーマプリセット設定を追加し、`@AppStorage` で保存されるようにした。`GlassTheme` には背景・デザインカード・アイテムカードそれぞれのプリセット定義と色パレットを追加済みで、デザイン一覧カード（タイトル、サムネ枠、グローレイヤー、情報タグ、AIスコアバッジ）は `designCardPalette` を参照する構成へ統一。用品一覧カードには `itemCardPalette` を使ったトーンレイヤーを追加し、背景とは別軸でカード色だけを切り替えられるようにした。これにより3種類の色をユーザーが任意に組み合わせ可能になった。
影響範囲: SettingsView のテーマ設定UI、EntryListView のカード配色、ProductListView のカード配色、GlassTheme のテーマ管理。データモデルや保存ロジックには影響なし。
実機確認: 未実施。`xcodebuild` を試行したが、`/Library/Developer/CommandLineTools` が選択されており Xcode 本体未選択のためビルド不能。
次にやること: 1) `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` 後に `xcodebuild -scheme NailNote -destination 'platform=iOS Simulator,name=iPhone 15' build` を再実行 2) 設定で3項目を組み合わせ変更し、記録/用品一覧へ即時反映されることを実機/Simulatorで確認

### 2026-02-24 (追記18)
変更ファイル: Design/GlassTheme.swift, Design/GlassBackgroundView.swift, Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: テーマ設定を変更しても見た目が切り替わらない問題を修正。原因は、背景/カード描画側が `UserDefaults` 変更を購読しておらず、再描画トリガーが不足していたこと。`GlassBackgroundView` に `@AppStorage(ThemeBackgroundPreset)` を追加し、選択中背景プリセットを直接参照して背景グラデとオーブ色を描画する方式へ変更。あわせて `EntryRowView` 系（サムネ枠、グローレイヤー、情報タグ、AIバッジ）と `ProductRow` にもそれぞれ `@AppStorage` を追加し、`designCardPalette(for:)` / `itemCardPalette(for:)` を使って選択値変更時に即時更新されるようにした。`GlassTheme` は preset 指定版の関数を追加し、現在値参照版はそのラッパーとして整理。
影響範囲: テーマ変更時の再描画タイミング（背景/デザインカード/アイテムカード）。配色定義そのものやデータ保存ロジックへの影響はなし。
実機確認: 未実施。CLIビルドは `xcode-select` が CommandLineTools のため継続して未実施。
次にやること: 1) 設定画面で3項目を変更し、記録/用品/AI/設定タブの背景・カードが即時反映されるか確認 2) 必要ならタブ遷移なしで反映されるようアニメーション有無を調整

### 2026-02-24 (追記19)
変更ファイル: Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせて、用品一覧のアイテムカードもデザインカードと同じ内側余白へ統一。`ProductRow` の `GlassCard` 呼び出しを `contentPadding: 10` 指定に変更し、上下左右の内側余白を 10pt に揃えた。
影響範囲: ProductListView のカード内余白のみ。機能・データ処理・テーマ選択ロジックへの影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorでカード内テキストとリング/サムネの詰まり具合を確認 2) 必要なら 9〜11 の範囲で微調整

### 2026-02-24 (追記20)
変更ファイル: Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: アイテムカード内の `[購入情報]` ラベルを、デザインカードの `[実施日付]` / `[自己評価]` と同系統のピルデザインへ変更。`ProductInfoTag` コンポーネントを新規追加し、カプセル背景・細枠・小アイコン付きの見た目で統一した。タグ色は `ThemeDesignCardPreset` を参照するため、デザインカードプリセット変更時に同じトーンで連動する。
影響範囲: ProductListView の左カラム見出し表示のみ。購入日/店舗/価格の表示ロジックやデータ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorでタグの高さ・位置バランスを確認 2) 必要ならアイコンを `cart` から別シンボルへ調整

### 2026-02-24 (追記21)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザイン一覧画面のフィルタ配置を2段構成へ変更。1段目にデザイン/カラー、2段目にキーワードフィルタを配置した。キーワード入力欄には `magnifyingglass` アイコンを追加し、検索意図が一目で分かる見た目に調整。既存のキーワード絞り込みロジック（`keywordText` による判定）は変更なし。
影響範囲: EntryListView のフィルタUI配置と見た目のみ。データ処理・保存ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで2段構成時の高さバランスを確認 2) 必要なら2段目の上下余白を微調整

### 2026-02-24 (追記22)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザインフィルタの初期表示ラベルを `すべて` から `デザイン` へ変更。内部の選択状態は従来どおり `all`（全件）を維持しており、絞り込み条件の挙動には変更なし。
影響範囲: EntryListView のデザインフィルタ表示文言のみ。保存値（`EntryDesignFilter`）とフィルタロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 初期表示が「デザイン」になっていることを確認 2) 選択後にカテゴリ名へ切り替わることを確認

### 2026-02-24 (追記23)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: カラー系統フィルタの初期表示ラベルを `すべて` から `カラー` へ変更。内部の選択状態は従来どおり `allColor`（全件）を維持し、絞り込み挙動には変更なし。
影響範囲: EntryListView のカラー系統フィルタ表示文言のみ。保存値（`EntryColorFilter`）と検索ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 初期表示が「カラー」になっていることを確認 2) 色選択後に各カテゴリ名へ切り替わることを確認

### 2026-02-24 (追記24)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザイン一覧のキーワードフィルタ先頭アイコンを `magnifyingglass` から、用品一覧のキーワードフィルタと同じ `text.magnifyingglass` へ変更。サイズ・色スタイルは既存のまま維持し、画面間で記号表現を統一した。
影響範囲: EntryListView のキーワード欄アイコン表示のみ。検索ロジック・入力挙動への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 記録/用品の両画面でアイコンの見え方が揃っているか確認 2) 必要なら左右余白を微調整

### 2026-02-24 (追記25)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザイン一覧画面のキーワード欄右側にソートUIを追加。ソート項目は `AIスコア / 自己評価 / 実施日付` をメニューから選択可能にし、昇順・降順は右端のアイコンボタン（上矢印/下矢印）で切り替えられるようにした。デフォルトは `実施日付` かつ `降順`（`EntrySortField = date`, `EntrySortAscending = false`）で、状態は `@AppStorage` に保存。表示リストは `filteredEntries` にソートを適用した `sortedEntries` を使う構成へ変更し、削除操作も表示順と一致するように調整した。
影響範囲: EntryListView のフィルタ下段UI（キーワード＋ソート）と一覧表示順。検索・カテゴリ絞り込みの判定ロジック、データ保存処理には影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで各ソート項目×昇降順の並びを確認 2) 必要ならソートメニューのラベル幅を調整

### 2026-02-24 (追記26)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: デザインカード内の自己評価ブロックを少し左へ寄せるため、`[自己評価]` と星評価を含む `VStack` に `padding(.trailing, 8)` を追加。これにより右端への寄り過ぎを緩和し、実施日付ブロックとの距離感をわずかに詰めた。
影響範囲: EntryListView のカード内レイアウト（自己評価表示位置）のみ。評価値・データ処理・フィルタ/ソート機能への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで自己評価の位置バランスを確認 2) 必要なら `6` または `10` へ微調整

### 2026-02-24 (追記27)
変更ファイル: Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: アイテムカード内のテキスト位置を右寄せ方向へ微調整。`ProductRow` に `textInset = 8` を追加し、アイテム名は `.padding(.horizontal, textInset)` で左右同量の余白を付与、購入情報ブロックは `.padding(.leading, textInset)` で左余白のみ追加した。これにより左端の詰まり感を緩和しつつ、アイテム名は左右バランスを保った配置にした。
影響範囲: ProductListView のカード内テキスト余白（アイテム名/購入情報）表示のみ。使用回数リング・サムネイル・機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで左余白の見え方を確認 2) 必要なら `textInset` を 6 または 10 へ微調整

### 2026-02-24 (追記28)
変更ファイル: Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: アイテムカード内の「使用回数リング」と「写真＋お気に入り」ブロックを、ユーザー要望に合わせて少し左へ移動。`ProductRow` に `mediaShiftLeft = 6` を追加し、該当2ブロックへ `.offset(x: -mediaShiftLeft)` を適用して、右側の余白を増やした。
影響範囲: ProductListView の中段（リング/写真）の視覚位置のみ。データ処理、タップ挙動、他画面レイアウトへの影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで右余白の見え方を確認 2) 必要なら移動量を 4〜8 の範囲で微調整

### 2026-02-24 (追記29)
変更ファイル: Features/Entries/AddEntryView.swift, Features/Entries/EditEntryView.swift, PROJECT_STATUS.md
実装内容: デザイン登録/編集画面の写真操作で「写真を削除」を押したときに「写真を変更（PhotosPicker起動）」まで同時に発火する不具合を修正。両画面とも `PhotosPicker` 直配置をやめ、`Button -> confirmationDialog -> photosPicker(isPresented:)` の流れへ変更し、変更/削除を独立動作にした。あわせて変更・削除どちらも実行前に「AIスコアがリセットされる」確認ダイアログを追加。編集画面では保存時に写真変更または削除があった場合、既存の `entry.aiScore` を削除して確実にリセットする処理を追加した。
影響範囲: AddEntryView / EditEntryView の写真操作UI、確認ダイアログ、Edit保存時のAIスコア整合性。その他の入力項目・保存フローへの影響は限定的。
実機確認: 未実施（ユーザーによる動作確認待ち）。
次にやること: 1) 実機/Simulatorで「変更」「削除」が独立して動くことを確認 2) 編集画面で写真変更後に保存し、AIスコアが消えることを確認

### 2026-02-24 (追記30)
変更ファイル: Features/Products/AddOrEditProductView.swift, PROJECT_STATUS.md
実装内容: アイテム登録/編集画面の「商品写真」「サンプルカラー写真」について、写真変更と削除を独立動作へ修正。`PhotosPicker` のラベル直押し構成を廃止し、各写真ごとに `変更ボタン -> photosPicker(isPresented:)` で起動する方式に切り替えた。削除ボタンには `buttonStyle(.borderless)` を適用し、Form内タップ競合による同時発火を防止。商品写真とサンプル写真でそれぞれ独立した picker 表示状態（`showingMainPhotoPicker` / `showingSamplePhotoPicker`）を持つ実装に変更した。
影響範囲: AddOrEditProductView の写真操作UI（商品写真/サンプル写真）。保存処理・写真ファイル保存/削除ロジック自体への影響なし。
実機確認: 未実施（ユーザーによる動作確認待ち）。
次にやること: 1) 実機/Simulatorで変更タップ時のみライブラリが起動し、削除タップで起動しないことを確認 2) 商品写真/サンプル写真それぞれで独立して動作することを確認

### 2026-02-24 (追記31)
変更ファイル: Features/Products/AddOrEditProductView.swift, PROJECT_STATUS.md
実装内容: アイテム登録/編集画面で「商品名」「カテゴリ」を必須項目として明示するため、各ラベル横に `必須` バッジを追加。あわせて「購入日を記録する」トグルを廃止し、購入日は常にDatePickerで入力する仕様へ変更した。保存時は `p.purchasedAt = purchasedAt` で常時保持し、既存データ読み込み時は `p.purchasedAt ?? Date()` を初期値として扱う。
影響範囲: AddOrEditProductView の基本情報セクションUIと購入日保存仕様。購入場所・価格・URL・写真保存ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示/保存確認待ち）。
次にやること: 1) 実機/Simulatorで必須表示とDatePicker常時表示を確認 2) 既存データ編集時の購入日初期表示を確認

### 2026-02-24 (追記32)
変更ファイル: Features/Products/AddOrEditProductView.swift, PROJECT_STATUS.md
実装内容: 商品URL入力欄のプレースホルダ文言から「（任意）」表記を削除し、`商品ページURL` に統一。必須項目はバッジで明示される方針に合わせ、任意表記を画面から減らした。
影響範囲: AddOrEditProductView の表示文言のみ。入力・保存・URL整形ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで文言反映を確認

### 2026-02-24 (追記33)
変更ファイル: Features/Products/AddOrEditProductView.swift, PROJECT_STATUS.md
実装内容: アイテム登録/編集画面で色が揃っていなかった見出しを統一。購入場所（`ShopSelectionField`）の `Menu` に `.tint(.primary)` と `.buttonStyle(.plain)` を適用し、見出しがアクセントブルーにならないよう調整。商品URLは単体TextField行から、他項目と同様の `見出し + 入力欄` のHStack構成へ変更し、見出し色を `.primary` に統一した。
影響範囲: AddOrEditProductView の基本情報セクション見た目のみ。保存ロジック・URL処理・写真処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで購入場所/商品URL見出し色が他項目と一致することを確認

### 2026-02-24 (追記34)
変更ファイル: Design/GlassCard.swift, Design/GlassTheme.swift, Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: デザインカード・アイテムカードの外枠色を、内側カラーと同系の濃い色へ変更。`GlassCard` に `strokeColor` パラメータを追加し、カードごとに外枠色を指定できるよう拡張。`GlassTheme` の `DesignCardPalette` / `ItemCardPalette` に `outerStroke` を追加し、各プリセットごとに同系統の濃色を定義。`EntryRowView` と `ProductRow` の `GlassCard` へ `strokeColor: palette.outerStroke` を適用して、テーマ選択に応じて外枠色が連動するようにした。テーマ名（表示名称）は変更なし。
影響範囲: デザイン一覧カードとアイテム一覧カードの最外周枠色。機能ロジック・データ保存・テーマ選択UIの挙動への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 各テーマで外枠が内側同系の濃色になっているか確認 2) 必要なら外枠の不透明度を微調整

### 2026-02-24 (追記35)
変更ファイル: Design/GlassCard.swift, Design/GlassTheme.swift, PROJECT_STATUS.md
実装内容: 「外枠が白く見える」問題に対応するため、カード最外周の枠線を強調。`GlassCard` の外枠線幅を `1.0 -> 1.25` に変更し、`GlassTheme` のデザイン/アイテム各プリセットの `outerStroke` をより濃い同系色（opacity 0.95）へ再調整した。これにより背景や内側ハイライトに埋もれず、外枠が同系色として認識しやすくなる。
影響範囲: デザインカード/アイテムカードの最外周枠の見え方のみ。機能ロジック・保存処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで外枠色の見え方を確認 2) 必要なら線幅を 1.1〜1.4 の範囲で微調整

### 2026-02-24 (追記36)
変更ファイル: Design/GlassCard.swift, Design/GlassTheme.swift, Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: ユーザー意図に合わせて「外枠線」ではなく「外側カード面」の色を調整。`GlassCard` に `backgroundGradient` 指定を追加し、デザインカード/アイテムカードでは外側カード面にテーマ連動の同系濃色グラデを適用するよう変更した。`GlassTheme` の各パレットへ `outerFillTop/outerFillBottom` を追加し、内側トーンより一段濃い色を定義。`EntryRowView` と `ProductRow` は `GlassCard(... backgroundGradient: ...)` 経由で外側カード色が切り替わる構成へ更新。
影響範囲: デザイン一覧/用品一覧カードの外側カード面の色味。枠線・機能ロジック・データ保存への影響は限定的。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 各テーマで外側カード面が同系濃色に見えるか確認 2) 濃さが強すぎる場合は `outerFill` の明度を微調整

### 2026-02-24 (追記37)
変更ファイル: Design/GlassTheme.swift, PROJECT_STATUS.md
実装内容: テーマカラーのプリセット数を各3種類から各5種類へ拡張。背景プリセットに `グラファイトミント / アイボリーコーラル`、デザインカードに `スレートブルー / テラコッタクリーム`、アイテムカードに `オリーブクレイ / プラムスモーク` を追加し、表示名と配色定義（内側・外側カード面・枠・タグ等）を実装した。設定画面は `allCases` 参照のためUI改修なしで選択肢が5件へ増加。
影響範囲: テーマ選択の選択肢数とカード/背景の色バリエーション。機能ロジック・データ保存処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 設定画面で各セクションが5件になっていることを確認 2) 新規追加2色ずつの見え方を実機/Simulatorで確認

### 2026-02-24 (追記38)
変更ファイル: Design/GlassCard.swift, PROJECT_STATUS.md
実装内容: カード外枠線を単色からグラデーション描画へ変更。`GlassCard` の外枠 `stroke` を `LinearGradient` 化し、同じテーマ色の濃淡（0.95 -> 0.55）で topLeading から bottomTrailing に流れる見え方へ調整した。これによりデザインカード/アイテムカードの外枠が単色よりリッチに見えるようになった。
影響範囲: GlassCard を利用するカード外枠線の見た目のみ。テーマ選択ロジック・データ保存処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで外枠グラデの見え方を確認 2) 必要なら線幅または濃淡差を微調整

### 2026-02-24 (追記39)
変更ファイル: Design/GlassCard.swift, Design/GlassTheme.swift, Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: カード外枠グラデが見えにくい問題を修正。`GlassCard` に `strokeGradient` を追加し、左上→右下の方向で明示的にグラデーションを描画できるようにした。`GlassTheme` のデザイン/アイテム各パレットへ `outerStrokeStart` / `outerStrokeEnd` を追加し、同系色の濃淡2色をテーマごとに定義。`EntryRowView` と `ProductRow` から `strokeGradient` を渡す構成に変更し、外枠が単色に見えずリッチな同系グラデとして表示されるよう調整した。
影響範囲: デザインカード/アイテムカード外枠線の見た目のみ。テーマ名・選択UI・保存ロジックへの影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 各テーマで左上→右下グラデが視認できるか確認 2) 必要なら `outerStrokeStart/End` のコントラストを微調整

### 2026-02-24 (追記40)
変更ファイル: Design/GlassTheme.swift, PROJECT_STATUS.md
実装内容: カード角の丸みを若干控えめにするため、共通角丸半径 `GlassTheme.cardCornerRadius` を `22 -> 20` に調整。これに連動してデザインカード/アイテムカードの外形と内部レイヤーの角丸も同率で小さくなる。
影響範囲: GlassCard と関連レイヤーの角丸見た目のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで丸みの減り具合を確認 2) 必要なら 19〜21 で微調整

### 2026-02-24 (追記41)
変更ファイル: Design/GlassTheme.swift, PROJECT_STATUS.md
実装内容: ユーザー指定に合わせてカード共通角丸半径を `20 -> 15` へ変更。デザインカード/アイテムカードの外形と内部装飾レイヤーの角丸がよりシャープになるよう調整した。
影響範囲: カード見た目（角丸）のみ。機能・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで角丸15の印象を確認

### 2026-02-24 (追記42)
変更ファイル: Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: カード外側と内側の距離を 1pt 狭めるため、デザインカード/アイテムカードの `GlassCard` 内側余白を `contentPadding: 10 -> 9` に変更。
影響範囲: 記録一覧・用品一覧カードの内側余白のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで9pt時の詰まり具合を確認 2) 必要なら 8〜10 の範囲で再調整

### 2026-02-24 (追記43)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AIネイルスコア画面で「AI出力サンプル」カード直下に、`AI評価 実施済み / AI評価 未実施` のトグルを追加。選択状態に応じて、写真付き記録一覧を `aiScoreBridge != nil`（実施済み）または `aiScoreBridge == nil`（未実施）で絞り込むようにした。初期状態は未実施表示。該当データがない場合の空状態文言もフィルタ内容に合わせて出し分けるよう調整。
影響範囲: SimHomeView の一覧表示フィルタUIと表示件数。AI評価実行ロジック・保存処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorでトグル切替時に一覧が即時切替されることを確認 2) 空状態文言の表示を確認

### 2026-02-24 (追記44)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AIタブ内の文言「AI出力サンプル」を「AI評価サンプル」に変更。カード見出し、ボタンラベル、サンプル画面のナビゲーションタイトルを統一した。
影響範囲: SimHomeView の表示文言のみ。機能ロジック・評価処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで文言統一を確認

### 2026-02-24 (追記45)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AI評価未実施カードの実行ボタン文言を `AIスコアを生成` から `AIネイルスコアを生成` に変更。再評価時の文言（`再評価を実行`）は維持。
影響範囲: SimHomeView のボタン表示文言のみ。評価ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで文言反映を確認

### 2026-02-24 (追記46)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AIサンプル関連の文言を「AI評価サンプル」から「AIネイルスコア出力サンプル」へ変更。カード見出し、確認ボタン、サンプル画面ナビゲーションタイトルを統一した。
影響範囲: SimHomeView の表示文言のみ。機能ロジック・評価処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで文言反映を確認

### 2026-02-24 (追記47)
変更ファイル: Design/GlassTheme.swift, Features/Settings/SettingsView.swift, Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AI評価チャートのカラーをテーマ切替できるよう拡張。`GlassTheme` に `AIScoreChartPreset`（5種類）と `AIScoreChartPalette` を追加し、`ThemeAIChartPreset` キーで保存する構成を実装。設定画面のテーマセクションへ `AI評価チャート` Picker を追加。`AIScoreRadarChart` はハードコード色を廃止し、`@AppStorage(ThemeAIChartPreset)` と `GlassTheme.aiScoreChartPalette(for:)` を参照して、ハロー/グリッド/軸/ポリゴン/頂点/中央メダル/ラベルの配色が即時切替されるように変更した。
影響範囲: SimHomeView のAIレーダーチャート配色とSettingsViewのテーマ設定UI。評価ロジック・保存データ（スコア値等）への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面でAI評価チャートテーマが5件表示されることを確認 2) 各テーマ切替でチャート色が即時反映されることを確認

### 2026-02-24 (追記48)
変更ファイル: Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: 「AI評価 実施済み」フィルタ選択時に、カードの評価結果を閉じた状態で表示するよう挙動を変更。`evaluationFilter` の切替監視を追加し、`evaluated` 選択時に `expandedEntries` をクリアするようにした。あわせて `syncExpandedEntries()` から評価済みカードの自動展開ロジックを除去し、評価結果はユーザー操作で開く方式へ統一。
影響範囲: SimHomeView のカード展開初期状態のみ。評価実行ロジック・保存データ・フィルタ条件への影響なし。
実機確認: 未実施（ユーザーによる動作確認待ち）。
次にやること: 1) 「実施済み」切替直後に全カードが閉じて表示されることを確認 2) 任意カードを開閉できることを確認

### 2026-02-24 (追記49)
変更ファイル: Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: カード内側カラーをジェル風の光沢に見せるため、デザインカード/アイテムカードの内側トーンレイヤーに光沢オーバーレイを追加。上部の面ハイライト（縦グラデ）と斜めの反射ハイライト（カプセル形状）を重ね、`blendMode(.screen)` で「ぷるん」とした艶感を強化した。既存の色テーマ・枠線・レイアウトは維持。
影響範囲: EntryListView と ProductListView のカード内側質感（見た目）のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで光沢の強さを確認 2) 必要ならハイライトの不透明度を微調整

### 2026-02-24 (追記50)
変更ファイル: Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: 「光沢が見えない」指摘に対応し、ジェル光沢オーバーレイを強化。上部ハイライトの不透明度と範囲を拡大し、斜め反射のサイズ・明度を上げ、さらに上部リムの細い反射ストロークを追加。ブレンドは `screen` から `plusLighter`（`compositingGroup` 併用）へ変更し、カード内側で光沢が視認しやすいよう調整した。
影響範囲: デザインカード/アイテムカード内側の光沢表現（見た目）のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで光沢の視認性を確認 2) 強すぎる場合は不透明度を段階調整

### 2026-02-24 (追記51)
変更ファイル: Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: 光沢方向の指定（右上→中央下）に合わせて、ジェル反射オーバーレイを再調整。`EntryGelGlossOverlay` / `ItemGelGlossOverlay` を `topTrailing` 基準へ変更し、太い反射筋＋細い反射筋の2本を同方向（約26〜27度）で重ねて視認性を強化。上部ハイライトの明度と範囲も増やし、上リム反射ストロークをやや強化した。
影響範囲: デザインカード/アイテムカード内側の光沢見た目のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorで右上起点の光沢筋が見えるか確認 2) 必要なら反射筋の角度と不透明度を微調整

### 2026-02-24 (追記52)
変更ファイル: Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望により、カード内側の光沢加工を一旦撤去。デザインカード/アイテムカードに追加していた光沢オーバーレイ適用を削除し、関連する `EntryGelGlossOverlay` / `ItemGelGlossOverlay` 実装も除去した。カード配色・枠線・レイアウトは維持。
影響範囲: 記録一覧/用品一覧カードの質感（見た目）のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 光沢なし状態の見え方を確認

### 2026-02-24 (追記53)
変更ファイル: Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: デザインカード/アイテムカードにメタリック感を追加。内側トーンレイヤーへ金属反射を意識した補助グラデーション（`blendMode(.overlay)`）を重ね、さらにメタリック調の補助ストロークを追加して、面の質感を少し硬質に調整した。光沢オーバーレイは使わず、既存テーマカラーを維持したまま「金属っぽい深み」を出す方向で実装。
影響範囲: 記録一覧/用品一覧カードの見た目（質感）のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorでメタリック感の強さを確認 2) 強すぎる/弱すぎる場合はoverlay不透明度を調整

### 2026-02-24 (追記54)
変更ファイル: Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: 「メタリック感が弱い」指摘に対応し、金属反射表現を強化。内側レイヤーの補助グラデを `topTrailing -> bottomLeading`（右上→左下）方向に変更し、`hardLight` で面のコントラストを上げた。さらに同方向の強い反射帯（グラデーションストップで細帯化）を `screen` で追加し、メタリック縁ストロークも太さと濃淡を強化。これによりカード面の金属的な反射が視認しやすくなるよう調整。
影響範囲: 記録一覧/用品一覧カードの見た目（メタリック質感）のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) 実機/Simulatorでメタリック感を確認 2) 強すぎる場合は反射帯opacityを微調整

### 2026-02-24 (追記55)
変更ファイル: Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望により、カードのメタリック加工を一旦撤去。デザインカード/アイテムカードの内側レイヤーに追加していたメタリック反射オーバーレイ（補助グラデ・反射帯・補助ストローク）を削除し、ベースのトーンレイヤー構成へ戻した。
影響範囲: 記録一覧/用品一覧カードの質感（見た目）のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) メタリックなし状態の見え方を確認

### 2026-02-24 (追記56)
変更ファイル: Design/GlassTheme.swift, Features/Entries/EntryListView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: デザインカード/アイテムカードのテーマに `レインボー` を追加。レインボー選択時は7原色（赤→橙→黄→緑→シアン→青→紫）の順で、カードごとに1色ずつ循環適用する仕様を実装した。`GlassTheme` の `designCardPalette` / `itemCardPalette` に `variantIndex` を追加し、`EntryListView` と `ProductListView` で一覧インデックス（表示順）を行ごとに渡す構成へ変更。既存テーマの挙動はそのまま維持。
影響範囲: 記録一覧/用品一覧のカード配色（レインボー選択時のみ）。保存ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面でデザインカード/アイテムカードに「レインボー」が出ることを確認 2) 一覧カードが7色順で循環することを確認

### 2026-02-24 (追記57)
変更ファイル: Features/Entries/EntryListView.swift, PROJECT_STATUS.md
実装内容: 「カード内側にも7原色を適用」の要望に対応し、デザインカード内側レイヤー（`EntryCardGlowLayer`）をカード行インデックス連動に変更。`EntryRowView` で算出済みの `palette` を `EntryCardGlowLayer(palette:)` に直接渡す構成へ修正し、レインボーテーマ時に外側だけでなく内側もカードごとに虹順で切り替わるようにした。アイテムカード内側は既に `cardIndex` 連動済み。
影響範囲: EntryListView のデザインカード内側配色（レインボー時）。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる見た目確認待ち）。
次にやること: 1) レインボー設定時にデザインカード内側が7色循環することを確認

### 2026-02-24 (追記58)
変更ファイル: Features/Products/ProductListView.swift, Features/Settings/SettingsView.swift, PROJECT_STATUS.md
実装内容: アイテムカードの配色をデザインカードと同一テーマ・同一パレットへ統一。`ProductRow` の参照を `ItemCardPreset` から `DesignCardPreset` ベースへ変更し、外側カード面・外枠グラデ・内側トーン（3段グラデ＋ストローク）すべてをデザインカードと同じ配色系で描画するよう修正した。設定画面は誤解防止のためアイテムカード個別Pickerを廃止し、「デザインカードに連動」表示へ変更。
影響範囲: ProductListView のカード配色と SettingsView のテーマ表示。データ保存・機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) デザインカードテーマ変更時にアイテムカードも同時に同系へ切り替わることを確認

### 2026-02-24 (追記59)
変更ファイル: Design/GlassTheme.swift, PROJECT_STATUS.md
実装内容: ページ背景テーマに `レインボー` を追加。`BackgroundPreset` に `rainbow` を追加し、背景グラデーション（多色の淡い虹トーン）とオーブ色（赤系/緑系/青系）を定義した。設定画面の背景Pickerは `allCases` 利用のため追加UI実装なしで選択可能。
影響範囲: GlassBackgroundView を利用する全画面の背景配色（レインボー選択時）。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面で背景テーマにレインボーが表示されることを確認 2) 各タブで背景の見え方を確認

### 2026-02-24 (追記60)
変更ファイル: Features/Settings/SettingsView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせて、アイテムカードテーマをデザインカード連動から独立設定へ戻した。SettingsViewに `アイテムカード` Picker（`ThemeItemCardPreset`）を復活。ProductListView は `DesignCardPreset` 参照をやめ、`ItemCardPreset` を使ってカード配色（外側カード面/外枠/内側トーン）を描画する構成へ復帰。これによりデザインカードとアイテムカードを別テーマで個別設定可能。
影響範囲: 設定画面のテーマ操作UI、用品一覧カードの配色参照先。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定でデザインカード/アイテムカードを別テーマにし、個別反映されることを確認

### 2026-02-24 (追記61)
変更ファイル: Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: アイテムカード独立化の補足修正として、`[購入情報]` タグ色もデザインテーマ依存を解消。`ProductInfoTag` を `ThemeItemCardPreset` 参照へ変更し、文字色/枠色を `ItemCardPalette` ベースで描画するよう調整した。
影響範囲: ProductListView の購入情報タグ配色。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) デザイン/アイテムを別テーマにした際、購入情報タグもアイテム側テーマで変わることを確認

### 2026-02-24 (追記62)
変更ファイル: Design/GlassTheme.swift, Features/Settings/SettingsView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: アイテムカードテーマを「デザインカードと同じテーマ群」に統一（ただし独立設定は維持）。`ItemCardPreset` を `ローズシャンパン / モーブブロンズ / セージゴールド / スレートブルー / テラコッタクリーム / レインボー` へ変更し、`itemCardPalette` は同名の `DesignCardPreset` から配色を生成する構成へ更新。設定画面と用品一覧のデフォルト/フォールバックも `roseChampagne` に更新。
影響範囲: アイテムカードテーマの選択肢と配色体系。デザインカードとの連動はなし（個別選択のまま）。旧アイテムテーマ値（mintStone等）が保存されている場合は新体系の既定値へフォールバック。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面でデザイン/アイテム両方のテーマ名が同一ラインナップになっていることを確認 2) それぞれ別テーマを選んで独立反映されることを確認

### 2026-02-24 (追記63)
変更ファイル: Design/GlassTheme.swift, Features/Settings/SettingsView.swift, Features/Products/ProductListView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせて、アイテムカードテーマの選択肢をデザインカードと同一ラインナップへ統一（ローズシャンパン / モーブブロンズ / セージゴールド / スレートブルー / テラコッタクリーム / レインボー）。連動はせず独立設定を維持し、`itemCardPalette` は同名デザインテーマの配色を変換して生成する方式に変更。SettingsView・ProductListView の itemCard デフォルト/フォールバックも `roseChampagne` に更新した。
影響範囲: テーマ選択UIの項目名、用品カード配色の基準。デザインカードとの設定連動はなし（独立のまま）。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面でデザインカード/アイテムカードのテーマ名が同一であることを確認 2) 別テーマを選んで独立反映されることを確認

### 2026-02-24 (追記64)
変更ファイル: NailNote/Design/GlassTheme.swift, PROJECT_STATUS.md
実装内容: シック系3テーマが設定画面で判別しにくい問題に対応し、背景/デザインカード/アイテムカードの各テーマ表示名を `シック（黒+シルバー）` `シック（黒+ゴールド）` `シック（白+ゴールド）` に統一した。テーマの実体ケース（`noirSilver/noirGold/ivoryGold`）と配色ロジックは既存のまま維持し、UI上で「未追加」に見えにくい状態へ調整。
影響範囲: 設定画面のテーマPicker表示名のみ。テーマ保存キー・配色計算・一覧カード描画ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面でシック系3テーマ名が背景/デザインカード/アイテムカードに表示されることを確認 2) 各テーマ選択時に画面とカード色が切り替わることを確認

### 2026-02-24 (追記65)
変更ファイル: NailNote/Design/GlassTheme.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせ、シック系3テーマの表示名を `ノワールシルバー / ノワールゴールド / アイボリーゴールド` に戻した。背景・デザインカード・アイテムカードの各 `displayName` を同時に統一し、配色ロジックと保存キーは変更していない。
影響範囲: 設定画面テーマPickerの表示名のみ。機能ロジック・データ処理への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面で3テーマ名が希望名称で表示されることを確認

### 2026-02-24 (追記66)
変更ファイル: NailNote/Features/Settings/SettingsView.swift, PROJECT_STATUS.md
実装内容: 設定画面に「デザインアイコン候補（プレビュー）」セクションを追加。SF Symbols の候補名と実アイコンを2カラムで見比べできるようにし、`showDesignIconPreview` フラグで簡単に非表示化できる構成にした（不要時は `false` へ変更、またはセクション削除）。
影響範囲: SettingsView の表示UIのみ。既存のテーマ設定・保存ロジック・各画面機能への影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面で候補表示と可読性を確認 2) 採用アイコン決定後に該当シンボルへ差し替え 3) プレビューセクションを削除またはフラグOFF

### 2026-02-24 (追記67)
変更ファイル: NailNote/Features/Settings/SettingsView.swift, PROJECT_STATUS.md
実装内容: デザインアイコン候補プレビューに、要望分の候補を追加。`hand.draw` をSF Symbols候補に追加し、あわせて絵文字候補として `💅` の表示行を追加した。これにより、塗っているニュアンスの候補を設定画面上で比較できる。
影響範囲: SettingsView のプレビュー表示のみ。テーマ設定・保存・各機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面で追加候補が表示されることを確認 2) 採用アイコン確定後に実際のフィルタアイコンへ反映

### 2026-02-24 (追記68)
変更ファイル: NailNote/Features/Settings/SettingsView.swift, PROJECT_STATUS.md
実装内容: 設定画面に「アイテムアイコン候補（プレビュー）」セクションを追加し、ネイル用品向け候補を一覧化。SF Symbols（`shippingbox` `archivebox` `bag` `pouch` `drop` `eyedropper` など）に加え、絵文字候補（`💅` `🧴` `🧪`）も表示して比較できるようにした。不要時に消しやすいよう `showItemIconPreview` フラグで切替可能。
影響範囲: SettingsView のプレビュー表示のみ。既存機能・保存ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 設定画面で候補表示と可読性を確認 2) 採用アイコン決定後に本番のアイコンへ反映 3) プレビューセクションを削除またはフラグOFF

### 2026-02-25 (追記69)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: 下段タブバーの「デザイン」アイコンを SF Symbols（`hand.raised.fill`）からカスタムアセット `IconDesignCustom` に差し替えた。`tabItem` は `Image("IconDesignCustom") + Text("デザイン")` 構成へ変更。
影響範囲: RootView のデザインタブアイコン表示のみ。タブ遷移・機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorでタブアイコンの表示サイズと選択時色を確認 2) 必要ならアセットの余白調整または画像差し替え

### 2026-02-25 (追記70)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: カスタムタブアイコンが巨大表示になる問題を修正。`tabItem` の記述を `Image + Text` から `Label("デザイン", image: "IconDesignCustom")` に変更し、他タブと同等の標準アイコンスケールで描画されるよう調整した。
影響範囲: RootView のデザインタブアイコン表示サイズのみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorでサイズが他タブと揃っていることを確認 2) まだ大きい場合はアセットPDFの余白/アートボード調整を実施

### 2026-02-25 (追記71)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: ユーザー指定の巨大化対策ルールに合わせ、下段タブ「デザイン」のカスタムアイコン定義を `Image("IconDesignCustom").renderingMode(.template).frame(width: 20, height: 20)` へ変更。`tabItem` 内のため `resizable()` は使用せず、`Text("デザイン")` と組み合わせる構成に統一した。
影響範囲: RootView のデザインタブアイコン描画サイズのみ。遷移・機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで他タブと同等サイズか確認 2) 依然大きい場合はPDFアートボード余白を調整

### 2026-02-25 (追記72)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: 下段タブ「デザイン」巨大化対応を再調整。使用アセットを `IconDesignCustom` と確認した上で、`CustomIconSources/design_icon.pdf` を同名imageset内の `design_icon.pdf` に再差し替え。`Contents.json` の `preserves-vector-representation: true` と `template-rendering-intent: template` は維持。`tabItem` は `Label` の `icon` クロージャ形式に変更し、`Image("IconDesignCustom").renderingMode(.template).frame(width: 20, height: 20)` を適用（`resizable()` 未使用）。
影響範囲: RootView のデザインタブアイコン描画のみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで巨大化解消を確認 2) なお大きい場合はPDFのアートボードを20〜24pt相当に調整

### 2026-02-25 (追記73)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: 「小さすぎる」指摘に対応し、`CustomIconSources/design_icon.pdf` を `IconDesignCustom.imageset/design_icon.pdf` へ再差し替え。アセット設定（`preserves-vector-representation: true` / `template-rendering-intent: template`）を維持確認。あわせて `tabItem` の `Image("IconDesignCustom")` から `frame(width: 20, height: 20)` を削除し、タブ標準サイズで描画させる構成へ調整した。
影響範囲: RootView のデザインタブアイコン表示サイズのみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorでサイズバランスを確認 2) 必要なら `frame(width: 24, height: 24)` で再調整

### 2026-02-25 (追記74)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: TabBar「デザイン」アイコンの巨大化再発防止として、`tabItem` を `Image + Text` 形式でサイズ固定に統一。`Image("IconDesignCustom")` に `renderingMode(.template)`, `resizable()`, `scaledToFit()`, `frame(width: 22, height: 22)` を適用した。これによりPDFアートボード差異があっても表示サイズを一定化。
影響範囲: RootView のデザインタブアイコン描画のみ。遷移・機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorでサイズと視認性を確認 2) 必要なら 24〜26pt に再調整

### 2026-02-25 (追記75)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: 「デザイン」タブアイコンが小さい指摘に対応し、`Image("IconDesignCustom")` のサイズを `22x22` から `24x24` へ拡大調整した。その他の描画指定（template/resizable/scaledToFit）は維持。
影響範囲: RootView のデザインタブアイコン表示サイズのみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorでサイズ感を確認 2) 必要なら 25〜26pt で再調整

### 2026-02-25 (追記76)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: 追加要望に対応し、デザインタブのカスタムアイコンサイズを `24x24` から `28x28` に再拡大。PDFアートボード内の描画領域が小さい場合でも、TabBar上で視認しやすいサイズに寄せた。
影響範囲: RootView のデザインタブアイコン表示サイズのみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorでサイズバランスを確認 2) 必要なら 26〜30pt の範囲で最終調整

### 2026-02-25 (追記77)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: さらに「小さい」指摘に対応し、デザインタブのカスタムアイコンサイズを `28x28` から `36x36` に拡大した。アセット側の描画領域が小さめでも視認できるよう、表示フレームを大きく確保。
影響範囲: RootView のデザインタブアイコン表示サイズのみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで最終サイズ確認 2) まだ小さければPDF内の実描画サイズを拡大して再書き出し

### 2026-02-25 (追記78)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: `CustomIconSources/design_icon.pdf` のアートボード過大（1152x768）による見かけサイズ不整合に対応するため、正方形化して `84x84px（28pt相当@3x）` で再生成し、`IconDesignCustom.imageset/design_icon.pdf` へ再反映。あわせてタブ側の過剰拡大を避けるため `RootView` のアイコン表示フレームを `36x36` から `24x24` へ戻した（template/resizable/scaledToFit は維持）。
影響範囲: デザインタブのアイコン見え方のみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorでサイズ確認 2) 必要なら 24〜28pt の範囲で微調整

### 2026-02-26 (追記79)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: 透過PNG反映後にデザインタブアイコンが大きく見える問題へ対応し、`Image("IconDesignCustom")` の表示フレームを `24x24` から `20x20` に調整。`renderingMode(.template) + resizable() + scaledToFit()` は維持し、他タブアイコンサイズに寄せた。
影響範囲: RootView のデザインタブアイコン表示サイズのみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで他タブと同等サイズか確認 2) 必要なら 19〜21pt で最終微調整

### 2026-02-26 (追記80)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: 「サイズが変わらない」問題の原因切り分けとして、`tabItem` の `frame` 指定ではなくアセット実サイズ依存である前提に切替。`IconDesignCustom.imageset/design_icon.png` を `1024x1024` から `84x84`（28pt相当@3x）へ縮小して反映し、`RootView` は `Label(\"デザイン\", image: \"IconDesignCustom\")` の標準定義に戻した。
影響範囲: デザインタブアイコンの表示サイズのみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 実機/Simulatorで他タブとのサイズ一致を確認 2) 必要なら 78〜90px の範囲でアセット側を再調整

### 2026-02-26 (追記81)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: ユーザー要望に合わせ、下段タブ「デザイン」アイコンをカスタムアセットから Apple純正寄せのSF Symbolへ一時切替。`Label("デザイン", image: "IconDesignCustom")` を `Label("デザイン", systemImage: "paintbrush.pointed")` に変更した。
影響範囲: RootView のデザインタブアイコン表示のみ。タブ遷移・機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 見え方確認 2) 問題なければカスタムアセット運用を停止するか判断

### 2026-02-26 (追記82)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: ユーザー指示「2を試す」に合わせ、下段タブ「デザイン」アイコンをSF Symbolから自作アイコン運用へ戻した。`Label("デザイン", systemImage: "paintbrush.pointed")` を `Label("デザイン", image: "IconDesignCustom")` に再変更。
影響範囲: RootView のデザインタブアイコン表示のみ。機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 見え方確認 2) 線の太さが不足する場合は元画像データ側で線幅を増やして再投入

### 2026-02-26 (追記83)
変更ファイル: NailNote/Assets.xcassets/IconDesignCustom.imageset/design_icon.png, NailNote/Assets.xcassets/IconDesignCustom.imageset/Contents.json, NailNote/Assets.xcassets/IconDesignSaved.imageset/Contents.json, NailNote/Assets.xcassets/IconDesignSaved.imageset/design_icon_saved.png, CustomIconSources/design_icon.png, CustomIconSources/design_icon_saved.png, PROJECT_STATUS.md
実装内容: デザインタブ用のカスタムアイコンを透過PNG運用へ切替し、サイズ感をタブ向けに再調整（最終87x87px, 3x扱い）。線をやや太く見せる加工版を `IconDesignCustom` に反映し、あわせて現時点の「戻し用」固定版として `IconDesignSaved` アセットを新規追加して保管した。
影響範囲: デザインタブのアイコン見た目のみ。タブ遷移・機能ロジックへの影響なし。
実機確認: 未実施（ユーザーによる表示確認待ち）。
次にやること: 1) 線の濃さをさらに上げる場合は元PNG側で線色/線幅を再調整 2) 他候補を試した後に `IconDesignSaved` へ即時復帰可能

### 2026-03-06 (追記84)
変更ファイル: NailNote/App/RootView.swift, PROJECT_STATUS.md
実装内容: デザインタブのカスタムPNGアイコンは保存版を含めて同一画像で、線の細さをSwift側だけで補正できなかったため、視認性を優先して `paintpalette.fill` のSF Symbolへ切り替えた。ラベル文言と4タブ構成は維持している。
影響範囲: RootView の「デザイン」タブアイコン表示のみ。画面遷移・データ・他タブの挙動には影響なし。
実機確認: 未実施（ユーザーによるXcode上の表示確認待ち）。
次にやること: 1) Xcode再ログイン後にビルドして見え方を確認 2) まだ弱ければ `paintbrush.pointed.fill` など他の塗りつぶし系SF Symbolも比較 3) カスタムPNGを再利用する場合は元画像側で線幅を再設計

### 2026-03-06 (追記85)
変更ファイル: NailNote/Features/Settings/SettingsView.swift, PROJECT_STATUS.md
実装内容: 設定画面のアイコン候補プレビューを、ネイル用途に寄せた候補だけへ整理した。デザイン側は `paintpalette.fill`、`paintbrush.pointed.fill`、`sparkles`、`wand.and.stars`、`hand.draw` と `💅` を比較できる形にし、各候補が実際のタブ文言 `デザイン` と並んで見えるプレビューUIへ変更した。アイテム側も候補数を絞り、同じ見せ方へ統一した。
影響範囲: SettingsView のプレビュー表示のみ。タブの実際のアイコン変更は行っていない。
実機確認: 未実施（ユーザーによる設定画面での見比べ待ち）。
次にやること: 1) 設定画面で候補を見比べて採用アイコンを確定 2) 確定後に RootView のタブアイコンへ反映 3) 不要になったプレビュー候補やアセットを整理

### 2026-03-25 (引き継ぎメモ)
変更ファイル: PROJECT_STATUS.md
実装内容: セッション再開用に、実機接続トラブルの状況を整理した。`iPhone 17e` 実機へ切り替え後、`Devices and Simulators` 上では当初 `Developer Mode disabled` が出ていたが、iPhone 側でデベロッパモード有効化までは完了。その後は `The developer disk image could not be mounted on this device.` で停止している。確認済みの環境は `Xcode 26.3 (17C529)`、実機OSは `iOS 26.3 (23D8128)`。Apple ID / Provisioning まわりでは、`No Accounts` と `Provisioning profile "iOS Team Provisioning Profile: com.iyashi.NailNote" expired on Mar 13, 2026.` も確認済みで、Apple ID再ログインと署名再生成が必要な状態。
影響範囲: ドキュメントのみ。アプリコード・アセットには影響なし。
実機確認: 未完了。次回は Mac 再起動後に `Devices and Simulators` を再確認し、`Ready` になるか・同エラー継続かを確認するところから再開する。
次にやること: 1) Mac再起動後に iPhone 17e を再接続して `Devices and Simulators` を確認 2) まだ DDI マウントエラーが出る場合は Apple ID の再ログイン、`Signing & Capabilities` の Team 再設定、必要なら Bundle Identifier 再生成を実施 3) 署名が通ったら設定画面のアイコン候補を見比べてデザインタブアイコンを確定

### 2026-03-30 (追記86)
変更ファイル: NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AIネイルスコア詳細カードに「前回比較」セクションを追加した。各評価済み記録に対して、ひとつ前のAI評価済み記録を自動で比較対象として引き当て、総合スコア差分と5項目ごとの差分、改善傾向の要約を表示するようにした。これにより単発評価だけでなく、上達の流れを画面内で追いやすくした。
影響範囲: SimHomeView のAI評価結果表示UIのみ。CoreData保存仕様や評価API呼び出し、既存の記録・用品機能には影響しない。
実機確認: 未実施（ローカル編集のみ。`iPhone XS` または Simulator で表示確認が必要）。
次にやること: 1) 前回比較UIの見え方と文言を実機確認 2) 必要なら比較対象条件を「直前の評価済み記録」以外にも拡張検討 3) 次段としてスコア推移グラフの追加を検討

### 2026-03-30 (追記87)
変更ファイル: NailNote/Features/Entries/EntryListView.swift, NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AIネイルスコア生成時に `Multiple validation errors occurred` が出る問題への対策として、`EntryAIScore` 新規作成時に必須 `id` を必ず採番するよう修正した。あわせてAI評価失敗時は CoreData の詳細 validation error を展開して表示し、どの属性で失敗したかを追いやすくした。
影響範囲: AIネイルスコアの保存処理とエラーメッセージ表示のみ。既存の記録・用品・一覧UIには影響しない。
実機確認: 未実施（再度 AIネイルスコア生成を実行して保存成功、または詳細エラー表示を確認する必要あり）。
次にやること: 1) AIネイルスコア生成を再試行して保存成功可否を確認 2) まだ validation error が出る場合は表示された属性名をもとに追加修正 3) 保存が通ったら前回比較UIもあわせて実機確認

### 2026-03-30 (追記88)
変更ファイル: NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: 前回比較の総合スコア表示を調整し、差分だけでなく「今回の総合スコア」「前回スコア」「差分」を同じ行で確認できるようにした。これにより、比較結果の文脈が分かりやすくなった。
影響範囲: SimHomeView の前回比較UI表示のみ。保存処理やAI評価ロジックには影響しない。
実機確認: 未実施（実機または Simulator で前回比較カードの見え方確認が必要）。
次にやること: 1) 総合スコア行の視認性を確認 2) 必要なら項目差分行も同じ粒度で情報量調整 3) 問題なければスコア推移グラフの検討へ進む

### 2026-03-30 (追記89)
変更ファイル: NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: 前回比較の総合スコア行で数値群が右に寄りすぎていたため、レイアウトを調整してタイトルの近くにまとまるようにした。今回スコア・前回スコア・差分を左寄せ気味に見せ、残り幅だけを末尾の Spacer で吸収する構成へ変更した。
影響範囲: SimHomeView の前回比較UIレイアウトのみ。保存処理や比較ロジックには影響しない。
実機確認: 未実施（実機または Simulator で位置バランス確認が必要）。
次にやること: 1) 総合スコア行が意図どおり左寄せで見えるか確認 2) 必要なら数値間スペースをさらに微調整 3) 問題なければスコア推移グラフ検討へ進む

### 2026-03-30 (追記90)
変更ファイル: NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AI評価済み記録の上達可視化を進めるため、SimHomeView に「スコア推移」カードを追加した。直近6件のAI評価済み記録から総合スコアの推移を軽量な折れ線グラフで表示し、あわせて最新評価の5項目スコアを一覧で見られるようにした。既存の前回比較と並べることで、単発比較と中期推移の両方を追える構成にした。
影響範囲: SimHomeView のAI評価ハブUIのみ。CoreData保存処理や評価API、記録・用品機能には影響しない。
実機確認: 未実施（実機または Simulator で折れ線グラフの見え方、点ラベル位置、最新5項目表示の可読性確認が必要）。
次にやること: 1) 推移グラフの見え方とラベル重なりを確認 2) 必要なら対象件数や配色を微調整 3) 問題なければ有料価値の次段として改善テーマ集計や月次レポートを検討

### 2026-03-30 (追記91)
変更ファイル: NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: 開発中の実機・Simulator テストを進めやすくするため、AIネイルスコアの月間利用上限を `DEBUG` ビルド時のみ無効化した。本番ビルドでは従来どおり上限 3 回を維持し、開発時だけ連続で評価を試せるようにした。
影響範囲: SimHomeView 内の AI評価利用上限判定のみ。保存処理や評価内容、本番ビルド時の上限制御には影響しない。
実機確認: 未実施（開発ビルドで上限到達後も継続してAI評価できるか確認が必要）。
次にやること: 1) 開発ビルドで利用上限エラーが出ず再評価できるか確認 2) 本番向け設定へ影響しないことを後で再確認 3) AI評価UIの見え方確認へ戻る

### 2026-03-30 (追記92)
変更ファイル: NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: スコア推移カードの配置を見直し、AI評価ハブの一番下へ移動した。まず個別の評価カードと前回比較を見てから、最後に中期推移を振り返る流れになるよう情報の順序を整理した。
影響範囲: SimHomeView のレイアウト順序のみ。推移グラフの内容や保存処理には影響しない。
実機確認: 未実施（画面全体の情報量バランスを実機または Simulator で確認する必要あり）。
次にやること: 1) 一番下配置でスクロール体験が自然か確認 2) 必要ならカード見出し文言を調整 3) 次段として改善テーマ集計や月次レポートの方向を検討

### 2026-03-30 (追記93)
変更ファイル: NailNote/Features/Entries/EntryListView.swift, NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: 前回比較の対象選定を見直し、「直前の評価済み記録」ではなく「同じデザインカテゴリの前回評価済み記録」を優先して比較するよう変更した。比較対象ラベルにもデザインカテゴリ名を表示し、マグネットなど同系統の施術どうしで上達を追いやすくした。
影響範囲: SimHomeView の前回比較ロジックと表示文言のみ。AI保存処理、推移グラフ、記録・用品機能には影響しない。
実機確認: 未実施（同じデザインカテゴリの複数記録で、比較対象が期待どおり切り替わるか確認が必要）。
次にやること: 1) 同系統デザインで比較対象が正しく選ばれるか確認 2) 同カテゴリ履歴が無い場合の見え方を確認 3) 問題なければ改善テーマ集計や月次レポートを検討

### 2026-03-30 (追記94)
変更ファイル: NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: AI評価カードを閉じた状態でも何のデザイン記録か分かるよう、カードヘッダーにデザインカテゴリラベルを追加した。`NailDesignCategory` の表示名を優先し、未設定時は「デザイン未設定」を表示する。
影響範囲: SimHomeView のカードヘッダー表示のみ。比較ロジック、保存処理、推移グラフには影響しない。
実機確認: 未実施（閉じたカード状態でラベルの可読性と余白を確認する必要あり）。
次にやること: 1) 実機または Simulator でラベルの見え方を確認 2) 長いデザイン名の折り返しや圧縮を必要に応じて調整 3) 問題なければ改善テーマ集計や月次レポートを検討

### 2026-03-30 (追記95)
変更ファイル: NailNote/Features/Sim/SimHomeView.swift, PROJECT_STATUS.md
実装内容: デザインカテゴリのピルがカード背景と近すぎたため、色味をくすんだローズシャンパン系へ調整した。文字色、グラデ背景、細い外枠をまとめて見直し、カードと差異化しつつ落ち着いた質感で視認しやすくした。
影響範囲: SimHomeView のデザインカテゴリピル見た目のみ。比較ロジック、保存処理、推移グラフには影響しない。
実機確認: 未実施（実機または Simulator でコントラストと質感確認が必要）。
次にやること: 1) ピルの見え方を確認 2) 必要なら彩度または枠線の強さを微調整 3) 問題なければ改善テーマ集計や月次レポートを検討
