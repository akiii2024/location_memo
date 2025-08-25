import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'map_list_screen.dart';
import 'tutorial_screen.dart';
import 'about_app_screen.dart';
import '../utils/theme_provider.dart';
import '../utils/app_info.dart';
import '../utils/ai_service.dart';
import '../utils/backup_service.dart';
import '../utils/database_helper.dart';
import '../utils/default_values.dart';
import '../models/map_info.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isTestingConnection = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isMapBackingUp = false;
  bool _isMapRestoring = false;
  BackupInfo? _backupInfo;
  List<MapInfo> _maps = [];

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
    _loadMaps();
  }

  Future<void> _loadBackupInfo() async {
    final info = await BackupService.getBackupInfo();
    if (mounted) {
      setState(() {
        _backupInfo = info;
      });
    }
  }

  Future<void> _loadMaps() async {
    final maps = await DatabaseHelper.instance.readAllMaps();
    if (mounted) {
      setState(() {
        _maps = maps;
      });
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isBackingUp = true;
    });

    try {
      final success = await BackupService.shareBackupFile();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('バックアップファイルを作成しました'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('バックアップの作成に失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _createMapBackup(int mapId) async {
    setState(() {
      _isMapBackingUp = true;
    });

    try {
      final success = await BackupService.shareMapBackupFile(mapId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('地図のバックアップファイルを作成しました'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('地図のバックアップ作成に失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMapBackingUp = false;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    setState(() {
      _isRestoring = true;
    });

    try {
      final result = await BackupService.importData(context);

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          // データが更新されたのでバックアップ情報を再読み込み
          await _loadBackupInfo();
          await _loadMaps();
        } else {
          if (result.message != 'インポートがキャンセルされました') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _restoreMapBackup() async {
    setState(() {
      _isMapRestoring = true;
    });

    try {
      final result = await BackupService.importMapData(context);

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
          // データが更新されたので情報を再読み込み
          await _loadBackupInfo();
          await _loadMaps();
        } else {
          if (result.message != 'インポートがキャンセルされました') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMapRestoring = false;
        });
      }
    }
  }

  void _showMapBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📍 地図ごとのバックアップ'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '特定の地図とそのメモのみをバックアップします。',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (_maps.isEmpty)
                const Text(
                  '地図が登録されていません。',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _maps.length,
                    itemBuilder: (context, index) {
                      final map = _maps[index];
                      return FutureBuilder<MapBackupInfo?>(
                        future: BackupService.getMapBackupInfo(map.id!),
                        builder: (context, snapshot) {
                          final info = snapshot.data;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Icon(
                                  Icons.map,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                map.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: info != null
                                  ? Text(
                                      'メモ: ${info.totalMemos}件${info.hasImage ? ' • 画像あり' : ''}')
                                  : const Text('読み込み中...'),
                              trailing: IconButton(
                                icon: const Icon(Icons.backup),
                                onPressed: _isMapBackingUp
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _createMapBackup(map.id!);
                                      },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💾 データのバックアップ・復元'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_backupInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue.shade900.withOpacity(0.3)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.shade700
                          : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '現在のデータ:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '地図: ${_backupInfo!.totalMaps}件',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      Text(
                        'メモ: ${_backupInfo!.totalMemos}件',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 全体バックアップセクション
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.green.shade900.withOpacity(0.3)
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.green.shade700
                        : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.backup, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '全体バックアップ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '全てのメモと地図データ（画像を含む）をJSONファイルとして保存します。',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isBackingUp ? null : _createBackup,
                        icon: _isBackingUp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.backup),
                        label: Text(_isBackingUp ? 'バックアップ中...' : 'バックアップを作成'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 地図ごとのバックアップセクション
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.shade900.withOpacity(0.3)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue.shade700
                        : Colors.blue.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.map, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '地図ごとのバックアップ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '特定の地図とそのメモのみをバックアップします。',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _maps.isEmpty || _isMapBackingUp
                            ? null
                            : _showMapBackupDialog,
                        icon: const Icon(Icons.map),
                        label: const Text('地図を選択してバックアップ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 復元セクション
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange.shade900.withOpacity(0.3)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange.shade700
                        : Colors.orange.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restore, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '復元',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'バックアップファイルからデータを復元します。',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRestoring ? null : _restoreBackup,
                        icon: _isRestoring
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.restore),
                        label: Text(_isRestoring ? '復元中...' : '全体バックアップから復元'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isMapRestoring ? null : _restoreMapBackup,
                        icon: _isMapRestoring
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.map),
                        label:
                            Text(_isMapRestoring ? '復元中...' : '地図バックアップから復元'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showAISettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤖 AI機能設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gemini AI機能を使用するには、Google AI StudioでAPIキーを取得し、'
              'lib/utils/ai_service.dartファイルの_apiKeyを設定してください。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade600
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APIキーの取得方法:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. aistudio.google.com にアクセス\n'
                    '2. Googleアカウントでログイン\n'
                    '3. "Get API key"をクリック\n'
                    '4. 新しいAPIキーを作成\n'
                    '5. コピーしたキーをコードに設定',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        AIService.isConfigured
                            ? Icons.check_circle
                            : Icons.error,
                        color:
                            AIService.isConfigured ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AIService.isConfigured ? 'APIキー設定済み' : 'APIキー未設定',
                        style: TextStyle(
                          color: AIService.isConfigured
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (AIService.isConfigured) ...[
                    Text(
                      '接続テスト:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isTestingConnection ? null : _testApiConnection,
                        icon: _isTestingConnection
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: Text(
                            _isTestingConnection ? 'テスト中...' : 'API接続をテスト'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _isTestingConnection = true;
    });

    try {
      print('Settings Debug: API接続テスト開始');
      final isConnected = await AIService.testApiConnection();
      print('Settings Debug: API接続テスト結果: $isConnected');

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isConnected ? '✅ 接続成功' : '❌ 接続失敗'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isConnected
                    ? 'AIサービスに正常に接続できました。画像分析機能が利用可能です。'
                    : 'AIサービスへの接続に失敗しました。\n\n'
                        '考えられる原因:\n'
                        '• APIキーが無効または期限切れ\n'
                        '• ネットワーク接続の問題\n'
                        '• サーバーが一時的に利用不可\n\n'
                        'しばらく時間をおいてから再試行してください。'),
                if (!isConnected) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.orange.shade900.withOpacity(0.3)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange.shade700
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'デバッグ情報:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• プラットフォーム: ${Theme.of(context).platform}',
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          '• Web環境: ${kIsWeb}',
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          '• APIキー設定: ${AIService.isConfigured}',
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        if (kIsWeb) ...[
                          Text(
                            '• 現在のURL: ${Uri.base}',
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                          Text(
                            '• HTTPS接続: ${Uri.base.scheme == 'https'}',
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Settings Debug: API接続テストエラー: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ 接続エラー'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API接続テスト中にエラーが発生しました:\n\n$e\n\n'
                    'APIキーの設定とネットワーク接続を確認してください。'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red.shade900.withOpacity(0.3)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.red.shade700
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'エラー詳細:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• エラータイプ: ${e.runtimeType}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      Text(
                        '• プラットフォーム: ${Theme.of(context).platform}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      Text(
                        '• Web環境: ${kIsWeb}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      Text(
                        '• APIキー設定: ${AIService.isConfigured}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      if (kIsWeb) ...[
                        Text(
                          '• 現在のURL: ${Uri.base}',
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          '• HTTPS接続: ${Uri.base.scheme == 'https'}',
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📝 お問い合わせ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'アプリに関するご意見・ご質問・バグ報告などがございましたら、'
              'お気軽にお問い合わせください。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue.shade900.withOpacity(0.3)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.shade700
                      : Colors.blue.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'お問い合わせ内容例:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• アプリの使い方について\n'
                    '• 新機能のご要望\n'
                    '• バグの報告\n'
                    '• その他のご質問',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green.shade900.withOpacity(0.3)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.green.shade700
                      : Colors.green.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'お問い合わせ方法:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Google Formが開きます。'
                    'お問い合わせ内容を記入して送信してください。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: _openContactForm,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('フォームを開く'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openContactForm() async {
    final Uri formUri = Uri.parse(
      'https://docs.google.com/forms/d/e/1FAIpQLSdXoVEFSNiFam-GKOVesRgyW4OM0O0cjLGeJzySjX09bp-juw/viewform?usp=header',
    );

    try {
      if (await canLaunchUrl(formUri)) {
        await launchUrl(formUri, mode: LaunchMode.externalApplication);
        Navigator.pop(context); // ダイアログを閉じる
      } else {
        await launchUrl(formUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('お問い合わせフォームを開けませんでした: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDefaultValuesDialog() {
    showDialog(
      context: context,
      builder: (context) => DefaultValuesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // アプリ設定セクション
          _buildSectionHeader('⚙️ アプリ設定', Icons.settings),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: Icon(Icons.dark_mode, color: Colors.indigo.shade600),
                  title: const Text('ダークモード'),
                  subtitle: const Text('ダークテーマを有効/無効にします'),
                  trailing: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.setDarkMode(value);
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.smart_toy, color: Colors.blue.shade600),
              title: const Text('AI機能設定'),
              subtitle: Text(AIService.isConfigured
                  ? 'AIサービス利用可能'
                  : 'Gemini APIキーを設定してください'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showAISettings,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.settings, color: Colors.deepPurple.shade600),
              title: const Text('デフォルト値設定'),
              subtitle: const Text('発見者・標本番号・カテゴリ・備考の初期値を設定'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showDefaultValuesDialog,
            ),
          ),

          const SizedBox(height: 24),

          // データ管理セクション
          _buildSectionHeader('💾 データ管理', Icons.storage),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.backup, color: Colors.green.shade600),
              title: const Text('バックアップ・復元'),
              subtitle: Text(_backupInfo != null
                  ? 'データ: 地図${_backupInfo!.totalMaps}件・メモ${_backupInfo!.totalMemos}件'
                  : 'データをバックアップ・復元します'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showBackupDialog,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.map, color: Colors.orange.shade600),
              title: const Text('カスタム地図管理'),
              subtitle: const Text('保存された地図の管理と削除'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MapListScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ヘルプ・サポートセクション
          _buildSectionHeader('❓ ヘルプ・サポート', Icons.help_outline),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.school, color: Colors.purple.shade600),
              title: const Text('チュートリアル'),
              subtitle: const Text('アプリの使い方を確認します'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TutorialScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.feedback, color: Colors.teal.shade600),
              title: const Text('お問い合わせ'),
              subtitle: const Text('ご意見・ご質問・バグ報告（Google Form）'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showContactDialog,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.info, color: Colors.grey.shade600),
              title: const Text('このアプリについて'),
              subtitle: Text('${AppInfo.version}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutAppScreen(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class DefaultValuesDialog extends StatefulWidget {
  @override
  _DefaultValuesDialogState createState() => _DefaultValuesDialogState();
}

class _DefaultValuesDialogState extends State<DefaultValuesDialog> {
  final TextEditingController _discovererController = TextEditingController();
  final TextEditingController _specimenNumberPrefixController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _categories = [
    'カテゴリを選択してください',
    '植物',
    '動物',
    '昆虫',
    '鉱物',
    '化石',
    '地形',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaultValues();
  }

  Future<void> _loadDefaultValues() async {
    try {
      final values = await DefaultValues.getAllDefaultValues();
      setState(() {
        _discovererController.text = values['discoverer'] ?? '';
        _specimenNumberPrefixController.text =
            values['specimenNumberPrefix'] ?? '';
        _notesController.text = values['notes'] ?? '';
        _selectedCategory = values['category'] ?? _categories[0];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDefaultValues() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await DefaultValues.setDefaultDiscoverer(
        _discovererController.text.trim().isEmpty
            ? null
            : _discovererController.text.trim(),
      );
      await DefaultValues.setDefaultSpecimenNumberPrefix(
        _specimenNumberPrefixController.text.trim().isEmpty
            ? null
            : _specimenNumberPrefixController.text.trim(),
      );
      await DefaultValues.setDefaultCategory(
        _selectedCategory == _categories[0] ? null : _selectedCategory,
      );
      await DefaultValues.setDefaultNotes(
        _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('デフォルト値を保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _clearDefaultValues() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('デフォルト値をクリア'),
        content: const Text('全てのデフォルト値を削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('クリア'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      setState(() {
        _isSaving = true;
      });

      try {
        await DefaultValues.clearAllDefaultValues();
        setState(() {
          _discovererController.clear();
          _specimenNumberPrefixController.clear();
          _notesController.clear();
          _selectedCategory = _categories[0];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('デフォルト値をクリアしました'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('クリアに失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('📝 デフォルト値設定'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '新しいメモを作成する際に自動的に入力されるデフォルト値を設定できます。',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  // 発見者
                  TextField(
                    controller: _discovererController,
                    decoration: const InputDecoration(
                      labelText: '発見者',
                      hintText: '例: 田中太郎',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 標本番号プレフィックス
                  TextField(
                    controller: _specimenNumberPrefixController,
                    decoration: const InputDecoration(
                      labelText: '標本番号プレフィックス',
                      hintText: '例: LM-2024-',
                      border: OutlineInputBorder(),
                      helperText: '標本番号の先頭に自動的に付加されます',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // カテゴリ
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリ',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // 備考
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '備考',
                      hintText: '例: 調査地の環境条件など',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.shade900.withOpacity(0.3)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue.shade700
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '設定内容:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 発見者: 新しいメモの「発見者」フィールドに自動入力\n'
                          '• 標本番号プレフィックス: 標本番号の先頭に自動付加\n'
                          '• カテゴリ: 新しいメモのカテゴリを自動選択\n'
                          '• 備考: 新しいメモの「備考」フィールドに自動入力',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _clearDefaultValues,
          child: const Text('クリア'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveDefaultValues,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
