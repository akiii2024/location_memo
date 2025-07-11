// モバイル環境用のスタブファイル
// Web環境でない場合にWebAudioServiceの代わりに使用される

class WebAudioService {
  // Web Audio APIのサポート確認
  static bool isSupported() {
    return false;
  }

  // マイク権限の確認
  static Future<bool> checkMicrophonePermission() async {
    return false;
  }

  // 録音開始
  static Future<bool> startRecording() async {
    return false;
  }

  // 録音停止
  static Future<String?> stopRecording() async {
    return null;
  }

  // 音声再生
  static Future<bool> playAudio(String audioData) async {
    return false;
  }

  // 再生停止
  static Future<void> stopPlaying() async {
    // 何もしない
  }

  // 録音中かどうか
  static bool get isRecording => false;

  // 再生中かどうか
  static bool get isPlaying => false;

  // リソースの解放
  static void dispose() {
    // 何もしない
  }

  // 音声形式の取得
  static String getAudioFormat() {
    return 'unknown';
  }

  // ブラウザ情報の取得
  static String getBrowserInfo() {
    return 'N/A (Not Web)';
  }
} 