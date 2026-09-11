// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Flutter 3.35の正式対象であるJavaScriptビルド専用の条件付き実装。

import 'app_logger.dart';
import 'dart:html' as html;
import 'dart:convert';

/// Web環境でのバックアップサービス
class WebBackupService {
  /// Web環境でのファイルダウンロード
  static void downloadFile(String content, String fileName) {
    try {
      // JSONコンテンツをUint8Listに変換
      final bytes = utf8.encode(content);

      // BlobオブジェクトとしてJSONファイルを作成
      final blob = html.Blob([bytes], 'application/json');

      // ダウンロード用のURLを生成
      final url = html.Url.createObjectUrlFromBlob(blob);

      // ダウンロードリンクを作成
      final anchor = html.AnchorElement(href: url)
        ..target = '_blank'
        ..download = fileName;

      // DOMに一時的に追加してクリック実行
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();

      // メモリリークを防ぐためURLオブジェクトを解放
      html.Url.revokeObjectUrl(url);

      appLog('ファイル「$fileName」のダウンロードを開始しました');
    } catch (e) {
      appLog('ダウンロードエラー: $e');
      // フォールバック: データURIを使用
      _fallbackDataUriDownload(content, fileName);
    }
  }

  /// フォールバック：データURIを使用したダウンロード
  static void _fallbackDataUriDownload(String content, String fileName) {
    try {
      // データURIとしてJSONを作成
      final dataUri =
          'data:application/json;charset=utf-8,${Uri.encodeComponent(content)}';

      // ダウンロードリンクを作成
      final anchor = html.AnchorElement(href: dataUri)
        ..target = '_blank'
        ..download = fileName;

      // DOMに一時的に追加してクリック実行
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();

      appLog('データURIを使用してファイル「$fileName」のダウンロードを開始しました');
    } catch (e) {
      appLog('フォールバックダウンロードもエラー: $e');
      // 最終フォールバック: コンソール出力
      appLog('=== バックアップファイル「$fileName」の内容 ===');
      appLog('以下のJSONデータをコピーして手動で保存してください：');
      appLog(content);
      appLog('=== バックアップファイル終了 ===');
    }
  }
}
