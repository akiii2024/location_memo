# 位置メモ Web・Android 公開チェックリスト

## 必須（公開前）

- [x] `flutter analyze`が0件、`flutter test`が全件合格する
- [x] JDK 17で署名付き`flutter build appbundle --release --dart-define=ENABLE_AI=false`が成功する
- [x] `flutter build web --release --base-href /location_memo/ --no-wasm-dry-run --dart-define=ENABLE_AI=false`が成功する
- [ ] `firebase deploy --only firestore:rules,storage` で本リポジトリのルールを反映する
- [ ] 既存ユーザーへ一度ログインしてもらい、共有先検索用の `shareDirectory` を作成する（新ルールではメールアドレス一覧の検索を許可しない）
- [x] Firebase Emulatorで所有者・共有者・第三者・未認証ユーザーの読み書き、共有解除、MIME・20MB制限を確認する
- [x] PWAを360px・768px・1440px幅で目視し、840px境界の下部ナビゲーション／NavigationRail切替を確認する
- [ ] Firebase App CheckをAndroid（Play Integrity）とWeb（reCAPTCHA Enterprise）へ登録し、メトリクス確認後にFirestore・Storage・Authenticationへ段階適用する
- [ ] Firebase Authenticationのパスワードポリシー、メール列挙保護、認証メールの送信元・本文、承認済みドメインを確認する
- [ ] Firebase/Google CloudのAPIキーへ対象アプリ・対象APIの制限が設定されていることを確認する
- [ ] 旧版が発行済みの場合、既存Storageのダウンロードトークン付きURLを再アップロード等で失効・移行する
- [x] Android applicationId `com.aki.location_memo`、target SDK 36を維持する
- [ ] Android署名鍵を安全にバックアップし、Play App Signingを設定する
- [ ] プライバシーポリシーとアカウント削除ページが公開URLで表示できることを確認する
- [ ] Google Playの「データ セーフティ」とアカウント削除URL、App Storeの「Appのプライバシー」を実装内容どおりに申告する
- [ ] Google Formが削除依頼を受け付けられ、担当者が本人確認・削除を完了できる運用を用意する
- [ ] Firebase ConsoleでCrashlyticsにテスト障害が届くこと、設定OFF時に届かないことを確認する
- [ ] CI secrets（Firebase設定、reCAPTCHA Enterpriseサイトキー、Android署名情報）を登録する

## AI機能

- [x] `ENABLE_AI=false`をWeb/AAB/CIで固定し、Gemini APIキーを公開成果物へ埋め込まない
- [x] Webの`main.dart.js`とAABの`libapp.so`にGemini通信URL・AIデバッグ・OCR導線が含まれないことを確認する
- [ ] AI機能を公開する場合はFirebase AI Logicへ移行し、App Check、レート制限、利用量上限を有効化する
- [ ] AIへ送信される画像・音声・メモ本文について、利用前の説明とプライバシーポリシーの記載を再確認する

## ストア素材・品質

- [ ] 実機でカメラ、写真、マイク、バックアップ、復元、共有、削除を確認する
- [ ] 大きな文字、スクリーンリーダー、キーボード、ライト/ダークテーマで主要操作を確認する
- [ ] 低速・オフライン・権限拒否・容量上限・認証期限切れ時の表示を確認する
- [ ] アイコン、スクリーンショット、説明文、カテゴリ、年齢区分、サポートURLをGoogle Playへ登録する
- [ ] リリース番号とビルド番号を公開のたびに増やす
- [ ] Google Play内部テスト→クローズドテスト→10%→50%→100%の順で公開する
- [ ] データ欠損、起動不能、Crashlyticsの新規致命障害があれば段階公開を停止する

## 現在の既知事項

- 公開版のAI機能はAPIキー保護のため無効
- ローカルWebビルドはコンパイル確認用App Check値を使用。公開成果物はCIの`RECAPTCHA_ENTERPRISE_SITE_KEY`で必ず再生成する
- Flutter WebはJavaScriptビルドを正式対象とし、Wasm・iOSは次段階で対応
- Android SDKライセンス状態は各CI/公開端末で確認が必要
- Firebaseルールはローカル変更だけでは反映されないため、検証後のデプロイが必須
