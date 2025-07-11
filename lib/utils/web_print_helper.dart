import 'dart:html' as html;
import 'dart:typed_data';

class WebPrintHelper {
  // Web版でのPDFダウンロード処理
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