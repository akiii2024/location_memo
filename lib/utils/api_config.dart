// API設定ファイル
// このファイルは.gitignoreに含まれているため、実際のAPIキーを安全に管理できます

class ApiConfig {
  // Gemini APIキー
  // 環境変数から読み込むか、デフォルト値を設定
  //
  // 使用方法:
  // 1. 環境変数で設定（推奨）:
  //    flutter run --dart-define=GEMINI_API_KEY=your_actual_api_key_here
  //
  // 2. 直接編集:
  //    このファイルのdefaultValueを実際のAPIキーに変更
  //
  // 注意: 実際のAPIキーをGitにコミットしないでください
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '', // 環境変数で設定してください
  );

  // その他のAPIキーをここに追加
  // static const String otherApiKey = String.fromEnvironment('OTHER_API_KEY');
}
