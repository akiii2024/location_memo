import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

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

      print('ファイル「$fileName」のダウンロードを開始しました');
    } catch (e) {
      print('ダウンロードエラー: $e');
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

      print('データURIを使用してファイル「$fileName」のダウンロードを開始しました');
    } catch (e) {
      print('フォールバックダウンロードもエラー: $e');
      // 最終フォールバック: コンソール出力
      print('=== バックアップファイル「$fileName」の内容 ===');
      print('以下のJSONデータをコピーして手動で保存してください：');
      print(content);
      print('=== バックアップファイル終了 ===');
    }
  }
}
