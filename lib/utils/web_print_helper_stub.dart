import 'dart:typed_data';

class WebPrintHelper {
  // Web版でのPDFダウンロード処理
  static void downloadPdfInWeb(Uint8List pdfBytes, String filename) {
    print('PDFダウンロード機能はWeb環境でのみ利用可能です');
  }

  // モバイル・デスクトップ用かどうかを判定
  static bool isMobileWeb() {
    return false;
  }

  // ブラウザ情報の取得
  static String getBrowserInfo() {
    return 'N/A (Not Web)';
  }
} 