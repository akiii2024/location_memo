# 環境変数設定ガイド

## 概要
Location MemoアプリでAI機能（音声文字起こし、画像分析）を使用するには、Gemini APIキーの設定が必要です。

## セットアップ手順

### 1. APIキーの取得
1. [Google AI Studio](https://aistudio.google.com/) にアクセス
2. アカウントでログイン
3. APIキーを生成
4. 生成されたキーをコピー

### 2. 環境変数ファイルの作成

プロジェクトルートに `.env` ファイルを作成：

```
GEMINI_API_KEY=your_actual_api_key_here
```

**重要**: `your_actual_api_key_here` を実際のAPIキーに置き換えてください。

### 3. アプリの実行

#### 推奨方法（PowerShellスクリプト使用）
```powershell
# デバッグモードで実行
.\run.ps1

# リリースモードで実行
.\run.ps1 -Mode release

# 特定のデバイスで実行
.\run.ps1 -Device windows
```

#### セッション専用の環境変数設定
```powershell
# 環境変数を設定（セッション内でのみ有効）
.\set-env.ps1

# APIキーを直接指定して設定
.\set-env.ps1 -ApiKey "your_actual_api_key_here"

# 環境変数をクリア
.\clear-env.ps1
```

#### 従来の方法
```powershell
# 環境変数を設定して実行
$env:GEMINI_API_KEY="your_actual_api_key_here"
flutter run
```

## 実行モード

- **debug**: デバッグモード（デフォルト）
- **release**: リリースモード
- **profile**: プロファイルモード

## スクリプトの使い分け

### `run.ps1` - 統合実行スクリプト
- 環境変数の設定とFlutterアプリの実行を一度に行う
- プロジェクト専用の設定
- 推奨方法

### `set-env.ps1` - セッション専用環境変数設定
- 現在のPowerShellセッションでのみ環境変数を設定
- 複数のFlutterコマンドを実行する場合に便利
- セッション終了で自動的にクリアされる

### `clear-env.ps1` - 環境変数クリア
- セッション内の環境変数を手動でクリア
- セキュリティを重視する場合に使用

## セキュリティ

- `.env` ファイルは `.gitignore` に含まれているため、Gitにコミットされません
- APIキーは絶対に公開リポジトリにアップロードしないでください
- 本番環境では、より安全なシークレット管理サービスを使用してください

## トラブルシューティング

### APIキーが設定されていない場合
- AI機能（音声文字起こし、画像分析）は使用できません
- 基本的なメモ機能は正常に動作します

### API使用量制限エラー
- Google AI Studioで使用量を確認
- 課金設定を有効にする
- しばらく時間をおいてから再試行

### その他のエラー
- APIキーが正しく設定されているか確認
- インターネット接続を確認
- Flutterの依存関係を更新: `flutter pub get` 