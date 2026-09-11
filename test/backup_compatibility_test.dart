import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_memo/utils/backup_service.dart';

void main() {
  test('v1フルバックアップを恒久互換形式として受理する', () {
    final backup = jsonEncode({
      'version': '1.0.0',
      'type': 'full_backup',
      'data': {
        'maps': [
          {'id': 10, 'title': '旧地図'},
        ],
        'memos': [
          {'id': 20, 'mapId': 10, 'title': '旧メモ', 'content': '本文'},
        ],
      },
    });

    expect(BackupService.isSupportedBackupJson(backup), isTrue);
  });

  test('v2は画像・音声・MIME・ID対応表を含めて受理する', () {
    final media = base64Encode([1, 2, 3, 4]);
    final backup = jsonEncode({
      'version': '2.0.0',
      'schemaVersion': 2,
      'type': 'full_backup',
      'data': {
        'idMap': {'10': 10},
        'maps': [
          {
            'id': 10,
            'title': '地図',
            'imageData': media,
            'imageMimeType': 'image/png',
          },
        ],
        'memos': [
          {
            'id': 20,
            'mapId': 10,
            'title': 'メモ',
            'content': '本文',
            'imageDataList': [media],
            'imageMimeTypes': ['image/jpeg'],
            'audioData': media,
            'audioMimeType': 'audio/webm',
          },
        ],
      },
    });

    expect(BackupService.isSupportedBackupJson(backup), isTrue);
  });

  test('壊れたBase64と未知バージョンを拒否する', () {
    final invalidMedia = jsonEncode({
      'version': '2.0.0',
      'type': 'full_backup',
      'data': {
        'maps': [
          {'id': 1, 'title': '地図', 'imageData': '!invalid!'},
        ],
        'memos': [],
      },
    });
    final unsupported = jsonEncode({
      'version': '3.0.0',
      'type': 'full_backup',
      'data': {'maps': [], 'memos': []},
    });

    expect(BackupService.isSupportedBackupJson(invalidMedia), isFalse);
    expect(BackupService.isSupportedBackupJson(unsupported), isFalse);
  });

  test('メディア種別の偽装とMIME件数不一致を拒否する', () {
    final media = base64Encode([1]);
    final wrongAudioMime = jsonEncode({
      'version': '2.0.0',
      'type': 'full_backup',
      'data': {
        'maps': [],
        'memos': [
          {
            'title': 'メモ',
            'content': '本文',
            'audioData': media,
            'audioMimeType': 'text/html',
          },
        ],
      },
    });
    final mismatchedImages = jsonEncode({
      'version': '2.0.0',
      'type': 'full_backup',
      'data': {
        'maps': [],
        'memos': [
          {
            'title': 'メモ',
            'content': '本文',
            'imageDataList': [media, media],
            'imageMimeTypes': ['image/png'],
          },
        ],
      },
    });

    expect(BackupService.isSupportedBackupJson(wrongAudioMime), isFalse);
    expect(BackupService.isSupportedBackupJson(mismatchedImages), isFalse);
  });
}
