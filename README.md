# Location Memo - フィールドワーク記録アプリ

位置情報付きメモアプリケーション。フィールドワークや野外調査での記録を効率的に管理できます。

## 機能

### 📍 位置情報付きメモ
- 緯度・経度情報と共にメモを記録
- 発見時刻、発見者、標本番号などの詳細情報を保存
- カテゴリ分けによる整理

### 🗺️ カスタム地図
- 独自の地図画像をアップロード
- 地図上にピンを配置してメモを関連付け
- 複数の地図を管理
- ピン一覧表示機能

### 🔍 検索機能
- メモのタイトル、内容、カテゴリでの検索
- 位置情報による絞り込み

### 📊 データ管理
- SQLiteデータベースによる永続化
- PDF出力機能
- データのエクスポート・インポート

### 🤖 AI機能
- **画像分析**: 写真を撮影して自動でメモ内容を生成
- **音声録音**: 音声メモの録音・再生機能
- **AIアシスタント**: メモ内容の改善提案や質問応答

### 🎨 UI/UX機能
- **ダークモード対応**: ライト/ダークテーマの切り替え
- **チュートリアル機能**: 初回利用時のガイド
- **スプラッシュスクリーン**: アプリ起動時の表示
- **レスポンシブデザイン**: 様々な画面サイズに対応

## 技術スタック

- **フレームワーク**: Flutter 3.5.3+
- **データベース**: SQLite (sqflite)
- **状態管理**: Provider
- **PDF生成**: pdf, printing
- **画像処理**: image, image_picker
- **ファイル管理**: file_picker, path_provider
- **AI機能**: Google Generative AI (Gemini)
- **音声録音**: flutter_sound
- **ローカルストレージ**: Hive, shared_preferences
- **フォント**: Noto Sans JP
- **権限管理**: permission_handler

## セットアップ

### 前提条件
- Flutter SDK 3.5.3以上
- Dart SDK

### インストール手順

1. リポジトリをクローン
```bash
git clone [repository-url]
cd location_memo
```

2. 依存関係をインストール
```bash
flutter pub get
```

3. AI機能の設定（オプション）
```bash
# 環境変数でAPIキーを設定
flutter run --dart-define=GEMINI_API_KEY=your_api_key_here

# または、lib/utils/api_config.dartファイルを直接編集
```

4. アプリを実行
```bash
flutter run
```

## プロジェクト構造

```
lib/
├── main.dart                 # アプリケーションのエントリーポイント
├── models/
│   ├── memo.dart            # メモデータモデル
│   └── map_info.dart        # 地図情報モデル
├── screens/
│   ├── splash_screen.dart   # スプラッシュスクリーン
│   ├── main_screen.dart     # メイン画面（ナビゲーション）
│   ├── home_screen.dart     # ホーム画面（地図一覧）
│   ├── map_list_screen.dart # 地図一覧画面
│   ├── map_screen.dart      # 地図表示画面
│   ├── add_map_screen.dart  # 地図追加画面
│   ├── add_memo_screen.dart # メモ追加画面
│   ├── memo_list_screen.dart # メモ一覧画面
│   ├── memo_detail_screen.dart # メモ詳細画面
│   ├── pin_list_screen.dart # ピン一覧画面
│   ├── search_screen.dart   # 検索画面
│   ├── settings_screen.dart # 設定画面
│   └── tutorial_screen.dart # チュートリアル画面
├── utils/
│   ├── app_info.dart        # アプリ情報管理
│   ├── database_helper.dart # データベース操作
│   ├── print_helper.dart    # PDF出力支援
│   ├── ai_service.dart      # AI機能管理
│   ├── audio_service.dart   # 音声録音機能
│   ├── theme_provider.dart  # テーマ管理
│   ├── tutorial_service.dart # チュートリアル管理
│   └── api_config.dart      # API設定（.gitignore）
└── widgets/
    └── custom_map_widget.dart # カスタム地図ウィジェット
```

## 使用方法

1. **初回起動**: チュートリアルが表示され、アプリの使い方を学習
2. **地図の追加**: ホーム画面で「+」ボタンを押して地図画像をアップロード
3. **メモの作成**: 地図上でタップしてピンを配置し、メモを記録
4. **AI機能の活用**:
   - 📸 **画像分析**: メモ追加画面で「写真を撮影してAI分析」ボタンを使用
   - 🎙️ **音声録音**: 音声録音ボタンで音声メモを作成
   - 🤖 **AIアシスタント**: AppBarのロボットアイコンで内容改善や質問
5. **ピン管理**: ピン一覧画面で地図上のピンを一覧表示・管理
6. **検索**: 検索タブでメモを検索・フィルタリング
7. **データ管理**: 設定画面でデータのエクスポート・インポート
8. **テーマ切り替え**: 設定画面でライト/ダークモードを切り替え

## AI機能の設定

### Gemini APIキーの取得
1. [Google AI Studio](https://aistudio.google.com) にアクセス
2. Googleアカウントでログイン
3. "Get API key"をクリックして新しいAPIキーを作成

### APIキーの設定方法
**方法1: 環境変数（推奨）**
```bash
flutter run --dart-define=GEMINI_API_KEY=your_actual_api_key_here
```

**方法2: 直接編集**
`lib/utils/api_config.dart`ファイルを編集してAPIキーを設定

**注意**: APIキーは`.gitignore`に含まれているため、Gitにコミットされません。

## アプリ情報

- **バージョン**: 0.1.1-alpha+1
- **対応プラットフォーム**: Android, iOS, Web, Windows, macOS, Linux
- **最小SDK**: Android API 21以上

## ライセンス

このプロジェクトはプライベートプロジェクトです。

## 開発者

フィールドワーク記録の効率化を目的として開発されたアプリケーションです。

## 注意事項

### セキュリティ
- APIキーは`.gitignore`に含まれているため、Gitにコミットされません
- 本番環境では環境変数を使用してAPIキーを管理してください
- APIキーを公開リポジトリにアップロードしないでください

### 権限
- カメラ権限: 画像分析機能に必要
- マイク権限: 音声録音機能に必要
- ストレージ権限: ファイル保存に必要

### 開発メモ
- 位置情報機能（geolocator）は一時的に無効化されています
- Hiveを使用したローカルストレージ機能が追加されています
- チュートリアル機能により初回利用時のユーザビリティが向上しています
