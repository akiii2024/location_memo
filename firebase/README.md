# Firebaseセキュリティルール

`firebase/firestore.rules` と `firebase/storage.rules` は、認証、地図共有、
添付ファイル、およびアカウント削除に必要なアクセス制御です。

- プロフィールと共有先メールの一覧取得を禁止
- 地図・メモを所有者または明示された共有ユーザーのみに制限
- Storageの画像/音声を20MB、プロフィール画像を5MBに制限
- 所有者以外によるベース地図の上書きを禁止

公開前にFirebase CLIの対象プロジェクトを確認します。

```bash
firebase login
firebase use --add
```

エミュレーターで共有、共有解除、未認証アクセス、アカウント削除を検証した後、
FirestoreとStorageのルールを同時にデプロイします。

```bash
firebase deploy --only firestore:rules,storage
```

別のFirebaseプロジェクトを使う場合は、`firebase.json` と生成済みの
`lib/firebase_options.dart` を同じプロジェクトへ揃えてください。
