import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/share_helper.dart';
import '../models/map_info.dart';

class MapShareScreen extends StatelessWidget {
  final MapInfo mapInfo;
  final String ownerUid;

  const MapShareScreen({
    Key? key,
    required this.mapInfo,
    required this.ownerUid,
  }) : super(key: key);

  String get _shareLink {
    return ShareHelper.generateMapShareLink(
      mapId: mapInfo.id!,
      ownerUid: ownerUid,
      title: mapInfo.title,
    );
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _shareLink));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('リンクをクリップボードにコピーしました'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareMapLink(BuildContext context) async {
    try {
      final result = Share.share(
        '地図「${mapInfo.title}」を共有します\n\n$_shareLink',
        subject: '地図の共有: ${mapInfo.title}',
      );
      await result;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('共有に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('地図を共有'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 地図情報カード
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.map, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mapInfo.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // QRコードセクション
            const Text(
              'QRコード',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _shareLink,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'QRコードをスキャンして地図にアクセス',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // リンクセクション
            const Text(
              '共有リンク',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: SelectableText(
                        _shareLink,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy),
                            label: const Text('コピー'),
                            onPressed: () => _copyToClipboard(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                                                  Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.share),
                              label: const Text('共有'),
                              onPressed: () => _shareMapLink(context),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 説明テキスト
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '共有方法',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• QRコードを他のユーザーにスキャンしてもらう\n'
                    '• 共有リンクをコピーして送信する\n'
                    '• 「共有」ボタンでアプリから直接共有する',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
