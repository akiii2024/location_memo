# Flutter Web・モバイル両対応 音声機能実装メモ

## 📋 概要

Flutter アプリケーションでWeb版とモバイル版の両方で動作する音声機能を実装するための技術メモです。
条件付きインポートを使用してプラットフォーム固有の機能を分離し、統一されたAPIを提供する方法を説明します。

---

## 🔴 最初の問題点

### 1. 条件付きインポートの構文エラー

**❌ 問題のあったコード:**
```dart
import 'dart:html' as html if (dart.library.html)
    show MediaRecorder, Blob, ...;
```

**🔥 エラー内容:**
```
Expected a string literal., severity: error
```

**🎯 何がダメだったか:**
- Dartの条件付きインポートの構文が間違っていた
- `as html`の位置が不正だった

### 2. Web専用APIの直接使用

**❌ 問題のあったコード:**
```dart
static html.MediaRecorder? _webRecorder;
static html.AudioElement? _webPlayer;
// ...
final userAgent = html.window.navigator.userAgent.toLowerCase();
```

**🔥 エラー内容:**
```
lib/utils/audio_service.dart:11:8: Error: Dart library 'dart:html' is not available on this platform.
```

**🎯 何がダメだったか:**
- モバイル環境では`dart:html`が存在しない
- Web専用のAPIを直接使用していた
- 条件付きインポートが正しく機能していなかった

---

## 🔄 段階的な修正プロセス

### 修正ステップ1: 条件付きインポート構文の修正

**🔧 試行した修正:**
```dart
import 'dart:html' if (dart.library.html) 'dart:html' as html
```

**❌ 結果:**
- まだエラーが発生
- 構文は正しいが、Web専用コードが残っている

### 修正ステップ2: Web機能の簡略化

**🔧 試行した修正:**
```dart
// Web用の変数（dynamic型で扱う）
static dynamic _webRecorder;
static dynamic _webPlayer;

// 実際の実装では JavaScript interop を使用
return true; // 簡略化：実際の実装では動的チェックを行う
```

**❌ 結果:**
- ビルドは成功するが、Web版で完全な機能が使えない
- プレースホルダー実装のため、実際の録音・再生ができない

### 修正ステップ3: 完全分離アプローチ（最終解決策）

**✅ 成功した修正:**
Web専用の機能を完全に別ファイルに分離し、条件付きインポートで適切に切り替える

---

## 📁 最終的な解決策の詳細

### 1. WebAudioService.dart - Web環境専用の音声サービス

**🎯 目的:** Web環境で完全な音声機能を提供

**✅ 実装内容:**
```dart
import 'dart:html' as html;  // Web環境でのみ利用可能
import 'dart:js_interop' as js;

class WebAudioService {
  static html.MediaRecorder? _mediaRecorder;
  static html.AudioElement? _audioElement;
  static List<html.Blob> _recordingChunks = [];
  static html.MediaStream? _mediaStream;
  static String? _currentRecordingData;
  static bool _isRecording = false;
  static bool _isPlaying = false;
  
  // 完全なWeb API実装
  static Future<bool> startRecording() async {
    // MediaRecorder API による録音実装
  }
  
  static Future<bool> playAudio(String audioData) async {
    // AudioElement API による再生実装
  }
}
```

**🔑 重要な機能:**
- **MediaRecorder API** による録音
- **AudioElement API** による再生
- **getUserMedia API** による権限管理
- **FileReader API** によるBase64変換

### 2. WebAudioServiceStub.dart - モバイル環境用のスタブ

**🎯 目的:** モバイル環境でビルドエラーを防止

**✅ 実装内容:**
```dart
// dart:htmlを使用しない
class WebAudioService {
  static bool isSupported() => false;
  static Future<bool> checkMicrophonePermission() async => false;
  static Future<bool> startRecording() async => false;
  static Future<String?> stopRecording() async => null;
  static Future<bool> playAudio(String audioData) async => false;
  static Future<void> stopPlaying() async {}
  static bool get isRecording => false;
  static bool get isPlaying => false;
  static void dispose() {}
  static String getAudioFormat() => 'unknown';
  static String getBrowserInfo() => 'N/A (Not Web)';
}
```

**🔑 重要な特徴:**
- Web専用APIを一切使用しない
- すべてのメソッドが存在するが、機能しない
- モバイル環境での型安全性を保証

### 3. AudioService.dart - 統一されたAPIインターフェース

**🎯 目的:** プラットフォームに関係なく同じAPIを提供

**✅ 条件付きインポート:**
```dart
import 'web_audio_service_stub.dart' 
    if (dart.library.html) 'web_audio_service.dart';
```

**🔑 この構文の意味:**
- デフォルト: `web_audio_service_stub.dart`を使用
- Web環境（`dart.library.html`が存在）: `web_audio_service.dart`を使用

**✅ プラットフォーム分岐:**
```dart
static Future<bool> startRecording() async {
  try {
    if (_isRecording) {
      print('既に録音中です');
      return false;
    }

    await initialize();

    if (!await checkPermissions()) {
      print('マイクの権限が必要です');
      return false;
    }

    if (kIsWeb) {
      final success = await WebAudioService.startRecording();
      if (success) {
        _isRecording = true;
      }
      return success;
    } else {
      return await _startMobileRecording();
    }
  } catch (e) {
    print('録音開始エラー: $e');
    return false;
  }
}
```

### 4. WebPrintHelper.dart & WebPrintHelperStub.dart

**🎯 目的:** PDF機能も同様に環境分離

**✅ Web版:**
```dart
import 'dart:html' as html;

class WebPrintHelper {
  static void downloadPdfInWeb(Uint8List pdfBytes, String filename) {
    try {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      print('PDF downloaded: $filename');
    } catch (e) {
      print('Web PDFダウンロードエラー: $e');
    }
  }
}
```

**✅ モバイル版スタブ:**
```dart
class WebPrintHelper {
  static void downloadPdfInWeb(Uint8List pdfBytes, String filename) {
    print('PDFダウンロード機能はWeb環境でのみ利用可能です');
  }
}
```

---

## 🔄 条件付きインポートの仕組み

### 正しい構文
```dart
import 'stub_file.dart' if (condition) 'real_file.dart';
```

### 動作原理
1. **条件チェック:** `dart.library.html`が存在するか確認
2. **Web環境:** `web_audio_service.dart`をインポート
3. **モバイル環境:** `web_audio_service_stub.dart`をインポート
4. **型安全性:** どちらも同じクラス名とメソッドを持つ

### 条件の例
- `dart.library.html` - Web環境で利用可能
- `dart.library.io` - モバイル/デスクトップ環境で利用可能
- `dart.library.js` - JavaScript環境で利用可能

---

## 📊 変更前 vs 変更後の比較

### 変更前（問題あり）
```dart
❌ 直接的なdart:htmlの使用
❌ 条件付きインポートの構文エラー
❌ モバイル環境でビルド失敗
❌ Web環境で不完全な機能
❌ プラットフォーム固有のコードが混在
```

### 変更後（解決済み）
```dart
✅ 環境別の完全分離
✅ 正しい条件付きインポート
✅ モバイル環境でのビルド成功
✅ Web環境での完全な機能
✅ 統一されたAPI
✅ 型安全性の保証
```

---

## 🎯 この解決策の利点

### 1. 型安全性
- コンパイル時にエラーを検出
- 両環境で同じクラス・メソッドが利用可能
- IntelliSenseによる自動補完が機能

### 2. 保守性
- 環境固有のコードが分離されている
- 新しい機能の追加が容易
- 各環境の実装を独立して変更可能

### 3. テスト性
- 各環境で独立してテスト可能
- スタブを使用したモックテストが可能
- 単体テストの作成が容易

### 4. パフォーマンス
- 不要なコードが含まれない
- 各環境で最適化された実装
- バンドルサイズの最適化

---

## 🚀 利用可能なAPI

### 共通API
```dart
// 初期化
await AudioService.initialize();

// 録音開始
await AudioService.startRecording();

// 録音停止
String? audioPath = await AudioService.stopRecording();

// 音声再生
await AudioService.playAudio(audioPath);

// 再生停止
await AudioService.stopPlaying();

// 状態確認
bool isRecording = AudioService.isRecording;
bool isPlaying = AudioService.isPlaying;

// プラットフォーム情報
print(AudioService.getPlatformInfo()); // "Web" or "Android" or "iOS"
print(AudioService.getAudioFormat()); // "webm" or "aac"

// リソース解放
await AudioService.dispose();
```

### Web専用API
```dart
// Web Audio APIサポート確認
bool isSupported = AudioService.isWebAudioSupported();

// ブラウザ情報取得
String browserInfo = AudioService.getBrowserInfo();
```

---

## 📂 ファイル構成

```
lib/utils/
├── audio_service.dart              # 統一されたAPIインターフェース
├── web_audio_service.dart          # Web環境専用の音声サービス
├── web_audio_service_stub.dart     # モバイル環境用のスタブ
├── print_helper.dart               # 統一されたPrint機能
├── web_print_helper.dart           # Web環境専用のPrint機能
└── web_print_helper_stub.dart      # モバイル環境用のPrintスタブ
```

---

## 🔧 ビルド確認

### モバイル版
```bash
flutter build apk
# ✅ 成功: app-release.apk (62.7MB)
```

### Web版
```bash
flutter build web
# ✅ 成功: build/web
```

---

## 🐛 トラブルシューティング

### 1. 条件付きインポートが機能しない
- 構文を再確認: `import 'stub.dart' if (condition) 'real.dart';`
- ファイルパスが正しいか確認
- 両方のファイルが同じクラス名を持つか確認

### 2. Web環境で音声機能が動作しない
- ブラウザでHTTPS環境を使用しているか確認
- マイク権限が許可されているか確認
- MediaRecorder APIの対応状況を確認

### 3. モバイル環境でビルドエラー
- `flutter clean`を実行
- pubspec.yamlの依存関係を確認
- flutter_soundプラグインの設定を確認

---

## 📚 参考資料

- [Flutter Conditional Imports](https://dart.dev/guides/libraries/conditional-imports)
- [Web Audio API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [MediaRecorder API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder)
- [Flutter Sound Plugin](https://pub.dev/packages/flutter_sound)

---

## 📝 まとめ

この実装により、Web版では完全なMediaRecorder APIを使用した高品質な音声機能を、モバイル版ではflutter_soundを使用した最適化された音声機能を提供できるようになりました。

条件付きインポートを使用することで、プラットフォーム固有の実装を分離しながら、統一されたAPIを提供し、型安全性を保ちながら両環境で動作するアプリケーションを構築できます。

---

**作成日:** 2024年12月  
**更新日:** 2024年12月  
**バージョン:** 1.0 