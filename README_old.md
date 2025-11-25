# Location Memo - フィールドワーク記録アプリ

位置情報付きメモアプリケーション。フィールドワークや野外調査での記録を効率的に管理できます。

## 備考
アプリの方向性が定まり次第AIで生成されたreadmeを人力で書き直す予定です。

## 機能

### 📍 位置情報付きメモ
- 緯度・経度情報と共にメモを記録（現在は手動位置指定）
- 発見時刻、発見者、標本番号などの詳細情報を保存
- カテゴリ分けによる整理
- 複数画像の添付機能（1つのメモに複数の写真を添付可能）
- 音声メモの録音・再生機能

### 🗺️ カスタム地図
- 独自の地図画像（PDF、画像）をアップロード
- 地図上にピンを配置してメモを関連付け
- 複数の地図を管理
- ピン一覧表示機能
- 位置選択画面での詳細位置指定

### 🔍 検索機能
- メモのタイトル、内容、カテゴリでの検索
- 位置情報による絞り込み
- 発見者・標本番号による検索

### 📊 データ管理
- SQLiteデータベースによる永続化（ネイティブ）
- Hiveによるデータ管理（Web）
- PDF出力機能（地図画像、ピン付き地図、メモリスト、PDFレポート）
- 包括的なデータバックアップ・復元機能（画像を含む）
- JSONベースのデータエクスポート・インポート
- 地図データの個別バックアップ

### 🤖 AI機能
- **画像分析**: 写真を撮影して自動でメモ内容を生成
- **音声録音**: 音声メモの録音・再生機能（Web/ネイティブ対応）
- **AIアシスタント**: メモ内容の改善提案や質問応答
- **デバッグ機能**: APIキー設定状況の詳細確認

### 🎨 UI/UX機能
- **ダークモード対応**: ライト/ダークテーマの切り替え
- **チュートリアル機能**: 初回利用時のガイド
- **スプラッシュスクリーン**: アプリ起動時の表示
- **レスポンシブデザイン**: 様々な画面サイズに対応
- **日本語フォント**: Noto Sans JP対応
- **SVGアイコン対応**: 高品質なベクターアイコン表示

### 🌐 PWA対応
- **プログレッシブウェブアプリ**: ブラウザからホーム画面にインストール可能
- **オフライン対応**: 基本的な機能はオフラインでも利用可能
- **ネイティブアプリ体験**: フルスクリーン表示、スプラッシュスクリーン
- **Web特化機能**: WebAudioService、WebPrintHelper

## 技術スタック

- **フレームワーク**: Flutter 3.5.0+
- **データベース**: SQLite (sqflite) / Hive (Web)
- **状態管理**: Provider
- **PDF生成**: pdf, printing
- **画像処理**: image, image_picker
- **ファイル管理**: file_picker, path_provider
- **AI機能**: Google Generative AI (Gemini)
- **音声録音**: flutter_sound
- **権限管理**: permission_handler
- **ローカルストレージ**: Hive, shared_preferences
- **フォント**: Noto Sans JP
- **データ共有**: share_plus
- **URL起動**: url_launcher
- **HTTP通信**: http
- **PWA**: Web App Manifest, Service Worker
- **SVG対応**: flutter_svg

## セットアップ

### 前提条件
- Flutter SDK 3.5.0以上
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

3. Hiveアダプターを生成
```bash
flutter packages pub run build_runner build
```

4. AI機能の設定（オプション）
```bash
# 環境変数でAPIキーを設定
flutter run --dart-define=GEMINI_API_KEY=your_api_key_here

# または、lib/utils/api_config.dartファイルを直接編集
```

5. アプリを実行
```bash
flutter run
```

## GitHub Pagesでのデプロイ

### 自動デプロイ（推奨）

1. **GitHubリポジトリの設定**
   - GitHubリポジトリのSettings → Pages
   - Source: "Deploy from a branch"を選択
   - Branch: `gh-pages`を選択
   - Saveをクリック

2. **GitHub Actionsの有効化**
   - `.github/workflows/deploy.yml`が既に設定済み
   - mainブランチにプッシュすると自動的にデプロイされます

3. **デプロイの確認**
   - プッシュ後、Actionsタブでデプロイ状況を確認
   - 成功すると `https://[username].github.io/location_memo/` でアクセス可能

### 手動デプロイ

1. **Webビルド**
```bash
flutter build web --release --base-href "/location_memo/"
```

2. **GitHub Pagesブランチの作成**
```bash
git checkout -b gh-pages
git add build/web -f
git commit -m "Deploy to GitHub Pages"
git push origin gh-pages
```

3. **GitHub Pagesの設定**
   - リポジトリのSettings → Pages
   - Source: "Deploy from a branch"を選択
   - Branch: `gh-pages`を選択

### PWA機能の確認

デプロイ後、以下の方法でPWA機能を確認できます：

1. **Chrome DevTools**
   - F12 → Application → Manifest
   - Service WorkersタブでSWの状態を確認

2. **Lighthouse**
   - F12 → Lighthouse → Generate report
   - PWAスコアを確認

3. **インストール**
   - Chrome: アドレスバーのインストールアイコン
   - Safari: 共有ボタン → "ホーム画面に追加"

## プロジェクト構造

```
lib/
├── main.dart                 # アプリケーションのエントリーポイント
├── models/
│   ├── memo.dart            # メモデータモデル (Hive対応)
│   ├── memo.g.dart          # メモモデルのHiveアダプター
│   ├── map_info.dart        # 地図情報モデル (Hive対応)
│   └── map_info.g.dart      # 地図情報モデルのHiveアダプター
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
│   ├── location_picker_screen.dart # 位置選択画面
│   ├── settings_screen.dart # 設定画面
│   └── tutorial_screen.dart # チュートリアル画面
├── utils/
│   ├── app_info.dart        # アプリ情報管理
│   ├── database_helper.dart # データベース操作（SQLite/Hive）
│   ├── print_helper.dart    # PDF出力支援
│   ├── web_print_helper.dart # Web版PDF出力支援
│   ├── web_print_helper_stub.dart # Web版PDF出力スタブ
│   ├── ai_service.dart      # AI機能管理
│   ├── audio_service.dart   # 音声録音機能
│   ├── web_audio_service.dart # Web版音声録音機能
│   ├── web_audio_service_stub.dart # Web版音声録音スタブ
│   ├── backup_service.dart  # バックアップ・復元機能
│   ├── theme_provider.dart  # テーマ管理
│   ├── tutorial_service.dart # チュートリアル管理
│   ├── image_helper.dart    # 画像処理支援
│   ├── default_values.dart  # デフォルト値定義
│   └── api_config.dart      # API設定（.gitignore）
└── widgets/
    └── custom_map_widget.dart # カスタム地図ウィジェット
```

## 使用方法

1. **初回起動**: チュートリアルが表示され、アプリの使い方を学習
2. **地図の追加**: ホーム画面で「+」ボタンを押して地図画像をアップロード
3. **メモの作成**: 地図上でタップしてピンを配置し、メモを記録
4. **複数画像の添付**: メモ追加画面で「+」ボタンを押して複数の写真を添付
5. **音声録音**: 音声録音ボタンで音声メモを録音・再生
6. **位置選択**: 位置選択画面で正確な位置を指定
7. **AI機能の活用**:
   - 📸 **画像分析**: メモ追加画面で「写真を撮影してAI分析」ボタンを使用
   - 🎙️ **音声録音**: 音声録音ボタンで音声メモを作成
   - 🤖 **AIアシスタント**: AppBarのロボットアイコンで内容改善や質問
8. **ピン管理**: ピン一覧画面で地図上のピンを一覧表示・管理
9. **検索**: 検索タブでメモを検索・フィルタリング
10. **データ管理**: 設定画面でデータのバックアップ・復元・エクスポート
11. **テーマ切り替え**: 設定画面でライト/ダークモードを切り替え

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

## データバックアップ機能

### 全データバックアップ
- メモデータ、地図データ、画像ファイルを含む完全なバックアップ
- JSON形式でのエクスポート（Base64エンコードされた画像を含む）
- 設定画面から「データをエクスポート」で実行

### 地図個別バックアップ
- 特定の地図とそのメモデータのみをバックアップ
- 地図一覧画面のコンテキストメニューから実行

### データ復元
- バックアップファイルからの完全復元
- 重複データの自動処理
- 設定画面から「データをインポート」で実行

## 音声録音機能

### ネイティブ環境
- flutter_soundを使用した高品質録音
- 音声ファイルの永続化
- 再生・停止機能

### Web環境
- WebAudioServiceによるブラウザ録音
- Base64エンコードでのデータ保存
- プラットフォーム間の互換性

## アプリ情報

- **バージョン**: 0.1.9-alpha+3
- **対応プラットフォーム**: Android, iOS, Web, Windows, macOS, Linux
- **最小SDK**: Android API 21以上

## 開発状況

### ✅ 完全実装済み
- カスタム地図（PDF/画像）の読み込み・表示
- 地図上のピン配置機能
- 詳細メモ情報（発見時間、発見者、標本番号、カテゴリ、備考）
- 複数画像添付機能
- 音声録音・再生機能
- 包括的なバックアップ・復元機能
- 印刷機能（地図画像、ピン付き地図、メモリスト、PDFレポート）
- SQLite/Hiveによるデータ管理
- AI機能（画像分析、音声録音、チャット）
- チュートリアル機能
- ダークモード対応
- SVGアイコン対応

### ⚠️ 部分実装・制限あり
- **位置情報機能**: 現在は手動位置指定のみ（GPS機能は一時的に無効化）
- 通知機能（UI作成済みだが機能未実装）

### 📋 今後の実装予定
- GPS位置情報機能の再有効化
- グリッド座標機能
- 手動座標指定機能の拡張
- オンライン共有機能
- 位置情報機能の完全復旧

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

### 制限事項
- **位置情報機能**: geolocatorパッケージが一時的に無効化されており、現在は手動位置指定のみ対応
- Web環境では一部機能に制限があります
- 音声録音機能はブラウザの制限により品質が異なる場合があります

### 開発メモ
- Hiveを使用したWeb対応ローカルストレージ
- SQLiteとHiveの統合データベース管理
- プラットフォーム固有のサービス実装（音声、印刷）
- 包括的なバックアップ・復元システム
- AI機能の詳細なデバッグ・診断機能
- SVGアイコン対応による高品質なUI表示
