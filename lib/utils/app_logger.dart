import 'package:flutter/foundation.dart';

/// 開発ビルド専用のログ出力。
///
/// メモ本文、画像解析結果、ファイルパスなどの利用者データが
/// リリースビルドのコンソールへ流出しないように一元管理する。
void appLog(Object? message, [StackTrace? stackTrace]) {
  if (!kDebugMode) {
    return;
  }

  debugPrint(message?.toString() ?? 'null');
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace);
  }
}
