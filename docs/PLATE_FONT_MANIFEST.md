# プレート書体リソース台帳（Phase 3.5-B）

2026-11-04。承認済みの公式固定コミットのファイルを、既存Asset Catalogのデータセットとして収録する。TTF・ライセンス・登録台帳をハッシュ照合し、CoreTextの公開データ読込APIから書体を生成する。Info.plistのUIAppFontsやプロジェクト手編集は不要。アプリ内の「設定 → フォントライセンス」で著作権表示と全文を閲覧できる。

取得元コミット：`2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc`（google/fonts）。

|ファイル|内部バージョン|バイト数|SHA256|
|---|---|---:|---|
|ZenMaruGothic-Regular.ttf|Version 1.002|3832756|a0c0b53543e0993ae2225e629c833f3d51495ad31720694ff112ce4ce11111ef|
|ZenMaruGothic-Medium.ttf|Version 1.001|3810988|3cfdb98a13571ede17fcc769f5093a97c38b80a7b9b2ab754a26b4d822092b3b|
|ZenMaruGothic-Bold.ttf|Version 1.001|3779008|fe24426b9c8b5523a0146a8235c8674eccf0493af354a53ec895c3596d9eb745|
|KosugiMaru-Regular.ttf|Version 4.002|3565716|4b8d0022c8dadd090ef67cd1f71f130714767af7806cba2eb4ebe4b0271c1d68|
|HachiMaruPop-Regular.ttf|Version 1.300|4385624|78408910c8f1a2f174a279cbc1484b48b71780039eba3fe1be2bfcc5d4df3f98|
|Yomogi-Regular.ttf|Version 3.206|4045904|ec280f473a03187292905618f24fdb08a6dcbf8620b52637e3b589fe745259b9|
|ZenKurenaido-Regular.ttf|Version 1.001|4303112|58b8d930d9fc10c8a5810c085bae378dacb98d0779073ee6d53d919f19ee6a4f|
|YuseiMagic-Regular.ttf|Version 1.200|3134968|82098615f39ed9da6a8ccc674b9006e49c70dd5b775a7a1697f6bedd22ce25a2|
|KaiseiDecol-Regular.ttf|Version 5.003|4503152|fb9202b97944fa00b5f145ad4701def5c306bcd0d26407917baef9e01b042056|
|KaiseiDecol-Medium.ttf|Version 5.003|4297772|6db5273d6807f4f575222a70ebf3bb548173dcdda2f22d9bf272d6d0e7161aa1|
|KaiseiDecol-Bold.ttf|Version 5.003|4286896|0e3a6da5145fdbba32cfb1c806812d95457506e1698f5d61e8f834fb847f0d6f|
|MochiyPopOne-Regular.ttf|Version 2.000|5163948|9e009430e1316c271a5f34759c6b65fc343c4e806f193042528887e7235a92c6|

合計49109844 bytes（TTFのみ、非圧縮）。ZEN丸Light・Black、M PLUSは収録しない。ZEN丸と解星はRegular／Medium／Bold、それ以外はRegular。

- Zen Maru Gothic：OFL-1.1。本文：https://raw.githubusercontent.com/google/fonts/2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/zenmarugothic/OFL.txt。本文SHA256：`2a20cf7ce1909d8ee1e949095d340f7d7656705f7c810a2d6faf56800ad0cb3d`。
- Kosugi Maru：Apache-2.0。本文：https://raw.githubusercontent.com/google/fonts/2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/apache/kosugimaru/LICENSE.txt。本文SHA256：`cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`。
- Hachi Maru Pop：OFL-1.1。本文：https://raw.githubusercontent.com/google/fonts/2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/hachimarupop/OFL.txt。本文SHA256：`8d3c434650e84f42ddb33e9b5929089ea51c39b231b798dacb33087d5f05d9f1`。
- Yomogi：OFL-1.1。本文：https://raw.githubusercontent.com/google/fonts/2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/yomogi/OFL.txt。本文SHA256：`bc0330d5973ab1f200553f51b4cb4ef11b81187fdcd0249f7f83992726c02a48`。
- Zen Kurenaido：OFL-1.1。本文：https://raw.githubusercontent.com/google/fonts/2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/zenkurenaido/OFL.txt。本文SHA256：`fdfcb596ac910b447e482f42d4d1e5df3cfcb71c681a9f10e7f2d0126b274111`。
- Yusei Magic：OFL-1.1。本文：https://raw.githubusercontent.com/google/fonts/2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/yuseimagic/OFL.txt。本文SHA256：`c74e8c47951ddd9c902f07097761cfa0457993e28d8e1e946e273c0250be77c9`。
- Kaisei Decol：OFL-1.1。本文：https://raw.githubusercontent.com/google/fonts/2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/kaiseidecol/OFL.txt。本文SHA256：`6c5445d4febbf6d84025b874a85c51e7e4bfa7495279eccdb4c317a6de857b46`。
- Mochiy Pop One：OFL-1.1。本文：https://raw.githubusercontent.com/google/fonts/2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/mochiypopone/OFL.txt。本文SHA256：`76be26178f13ef82866cf6a5c54272191bb583c203ad7035021c7681c9043558`。

将来の差し替え時はユーザーの承認を得て、版・許諾・ファイルハッシュ・書体IDとの対応を確認する。同じ書体IDへ黙って異なるフォントを割り当てない。フォント本体・台帳双方の変更をレビューし、12ファイルの読込／描画／保存サムネイルの回帰検証を行う。
