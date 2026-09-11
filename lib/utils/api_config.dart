// API設定ファイル
// 実際のAPIキーをソースコードへ直接記載しないでください。

class ApiConfig {
  // Gemini APIキー
  // 環境変数から読み込むか、デフォルト値を設定
  //
  // 使用方法:
  // 1. 環境変数で設定（推奨）:
  //    flutter run --dart-define=GEMINI_API_KEY=your_actual_api_key_here
  //
  // 注意: APIキーはアプリ/Webバンドルから抽出可能です。
  // 公開版ではキーをクライアントへ埋め込まず、認証・レート制限・App Checkを
  // 備えたバックエンド経由にしてください。Web版のAI機能は安全のため無効です。
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '', // 環境変数で設定してください
  );

  // その他のAPIキーをここに追加
  // static const String otherApiKey = String.fromEnvironment('OTHER_API_KEY');
}
