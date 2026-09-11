// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Flutter 3.35の正式対象であるJavaScriptビルド専用の条件付き実装。

import 'app_logger.dart';
import 'dart:html' as html;
import 'dart:typed_data';

class WebPrintHelper {
  // Web版でのPDFダウンロード処理
  static void downloadPdfInWeb(Uint8List pdfBytes, String filename) {
    try {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      appLog('PDF downloaded: $filename');
    } catch (e) {
      appLog('Web PDFダウンロードエラー: $e');
    }
  }

  // モバイル・デスクトップ用かどうかを判定
  static bool isMobileWeb() {
    try {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      return userAgent.contains('mobile') ||
          userAgent.contains('android') ||
          userAgent.contains('iphone') ||
          userAgent.contains('ipad');
    } catch (e) {
      return false;
    }
  }

  // ブラウザ情報の取得
  static String getBrowserInfo() {
    try {
      return html.window.navigator.userAgent;
    } catch (e) {
      return 'Unknown';
    }
  }
}
