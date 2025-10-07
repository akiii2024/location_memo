# GitHub Actions 設定ガイド

このディレクトリには、APKの自動ビルドとリリースのためのGitHub Actionsワークフローが含まれています。

## ワークフローファイル

### 1. `build-android.yml`
- **目的**: 基本的なAPKビルド
- **トリガー**: main/developブランチへのプッシュ、プルリクエスト、手動実行
- **機能**: 
  - Flutterアプリのビルド
  - テストの実行
  - APKファイルのアーティファクトとして保存
  - タグがプッシュされた場合の自動リリース

### 2. `build-android-with-firebase.yml`
- **目的**: Firebase設定を含むAPKビルド
- **トリガー**: main/developブランチへのプッシュ、プルリクエスト、手動実行
- **機能**:
  - Firebase設定ファイルの自動生成
  - APKとAAB（Android App Bundle）の両方をビルド
  - アーティファクトとして保存
  - タグがプッシュされた場合の自動リリース

### 3. `release.yml`
- **目的**: 手動リリース作成
- **トリガー**: タグのプッシュ、手動実行
- **機能**:
  - バージョン情報の自動取得
  - リリースノートの自動生成
  - APKファイルの添付

## 必要な設定

### 1. GitHub Secrets の設定

リポジトリの Settings > Secrets and variables > Actions で以下のシークレットを設定してください：

#### Firebase設定（Firebaseを使用する場合）
- `FIREBASE_CONFIG`: `android/app/google-services.json` の内容をBase64エンコードしたもの

```bash
# google-services.jsonをBase64エンコード
base64 -i android/app/google-services.json
```

### 2. リリースの作成方法

#### 方法1: タグを使用した自動リリース
```bash
# バージョンタグを作成
git tag v1.0.0
git push origin v1.0.0
```

#### 方法2: 手動リリース
1. GitHubリポジトリの Actions タブに移動
2. "Create Release" ワークフローを選択
3. "Run workflow" をクリック
4. バージョン番号を入力して実行

### 3. バージョン管理

`pubspec.yaml` のバージョンを更新してください：

```yaml
version: 1.0.0+1  # 1.0.0はバージョン名、+1はビルド番号
```

## トラブルシューティング

### よくある問題

1. **Firebase設定エラー**
   - `FIREBASE_CONFIG` シークレットが正しく設定されているか確認
   - Base64エンコードが正しく行われているか確認

2. **ビルドエラー**
   - Flutterのバージョンが正しいか確認
   - 依存関係が正しくインストールされているか確認

3. **リリースが作成されない**
   - `GITHUB_TOKEN` の権限を確認
   - タグの形式が正しいか確認（v1.0.0形式）

### ログの確認

GitHub Actionsのログは、リポジトリの Actions タブで確認できます。エラーが発生した場合は、ログを確認して問題を特定してください。

## カスタマイズ

ワークフローファイルは、プロジェクトの要件に応じてカスタマイズできます：

- ビルド設定の変更
- 追加のテストステップ
- 異なるプラットフォームへの対応
- 通知の設定

詳細については、[GitHub Actions の公式ドキュメント](https://docs.github.com/ja/actions)を参照してください。

## 追加: バージョン変更で自動リリース

- ファイル: `.github/workflows/auto-release-on-version-change.yml`
- 挙動: `main` ブランチに push されたコミットで、`pubspec.yaml` の `version:` が前回コミットから変更されている場合にのみ発火します。
- 処理内容:
  - 変更検知 → Flutter セットアップ → APK/AAB ビルド → `v{pubspecのversion}` のタグ作成 → GitHub Release 作成（APK/AAB添付）
- 前提:
  - 必要に応じて `FIREBASE_CONFIG` シークレットを設定すると、`google-services.json` が生成されます（任意）。
  - `GITHUB_TOKEN` は既定で有効です。
- 注意:
  - タグは `v{version}` 形式で自動作成・push されます（例: `version: 1.2.3+4` → `v1.2.3+4`）。
  - `main` に直接 push された差分が対象です。PRマージ時も `main` にコミットが載れば発火します。
