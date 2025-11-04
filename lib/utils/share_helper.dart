import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ShareHelper {
  /// 地図への共有リンクを生成
  static String generateMapShareLink({
    required int mapId,
    required String ownerUid,
    String? title,
  }) {
    // アプリのベースURL（実際のアプリに合わせて変更してください）
    final baseUrl = kIsWeb 
        ? Uri.base.origin 
        : 'https://location-memo.app'; // Web版以外の場合のデフォルトURL
    
    final encodedTitle = title != null ? Uri.encodeComponent(title) : '';
    final shareUrl = '$baseUrl/map/$ownerUid/$mapId${encodedTitle.isNotEmpty ? '?title=$encodedTitle' : ''}';
    
    return shareUrl;
  }

  /// 共有リンクが有効かチェック
  static bool isValidShareLink(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // URL形式: /map/{ownerUid}/{mapId}
      return pathSegments.length >= 3 && pathSegments[0] == 'map';
    } catch (e) {
      return false;
    }
  }

  /// 共有リンクから地図情報を抽出
  static MapShareInfo? parseShareLink(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length >= 3 && pathSegments[0] == 'map') {
        final ownerUid = pathSegments[1];
        final mapIdStr = pathSegments[2];
        final mapId = int.tryParse(mapIdStr);
        
        if (mapId != null) {
          final title = uri.queryParameters['title'];
          return MapShareInfo(
            mapId: mapId,
            ownerUid: ownerUid,
            title: title,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to parse share link: $e');
    }
    return null;
  }
}

class MapShareInfo {
  final int mapId;
  final String ownerUid;
  final String? title;

  MapShareInfo({
    required this.mapId,
    required this.ownerUid,
    this.title,
  });
}
