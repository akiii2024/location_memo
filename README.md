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

### 🔍 検索機能
- メモのタイトル、内容、カテゴリでの検索
- 位置情報による絞り込み

### 📊 データ管理
- SQLiteデータベースによる永続化
- PDF出力機能
- データのエクスポート・インポート

## 技術スタック

- **フレームワーク**: Flutter
- **データベース**: SQLite (sqflite)
- **状態管理**: Provider
- **PDF生成**: pdf, printing
- **画像処理**: image, image_picker
- **ファイル管理**: file_picker, path_provider
- **フォント**: Noto Sans JP

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

3. アプリを実行
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
│   ├── main_screen.dart     # メイン画面（ナビゲーション）
│   ├── home_screen.dart     # ホーム画面（地図一覧）
│   ├── map_screen.dart      # 地図表示画面
│   ├── add_map_screen.dart  # 地図追加画面
│   ├── add_memo_screen.dart # メモ追加画面
│   ├── memo_list_screen.dart # メモ一覧画面
│   ├── memo_detail_screen.dart # メモ詳細画面
│   ├── search_screen.dart   # 検索画面
│   └── settings_screen.dart # 設定画面
├── utils/
│   ├── database_helper.dart # データベース操作
│   └── print_helper.dart    # PDF出力支援
└── widgets/
    └── custom_map_widget.dart # カスタム地図ウィジェット
```

## 使用方法

1. **地図の追加**: ホーム画面で「+」ボタンを押して地図画像をアップロード
2. **メモの作成**: 地図上でタップしてピンを配置し、メモを記録
3. **検索**: 検索タブでメモを検索・フィルタリング
4. **データ管理**: 設定画面でデータのエクスポート・インポート

## ライセンス

このプロジェクトはプライベートプロジェクトです。

## 開発者

フィールドワーク記録の効率化を目的として開発されたアプリケーションです。

## 注意事項

このプロジェクトのREADMEは、AI（Claude 3.5 Sonnet）によって自動生成されています。プロジェクトの実際の内容を分析し、適切な説明文を作成しました。
