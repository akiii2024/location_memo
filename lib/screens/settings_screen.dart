import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_list_screen.dart';
import 'tutorial_screen.dart';
import '../utils/theme_provider.dart';
import '../utils/app_info.dart';
import '../utils/ai_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _isTestingConnection = false;

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
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'APIキーの取得方法:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. aistudio.google.com にアクセス\n'
                    '2. Googleアカウントでログイン\n'
                    '3. "Get API key"をクリック\n'
                    '4. 新しいAPIキーを作成\n'
                    '5. コピーしたキーをコードに設定',
                    style: TextStyle(fontSize: 12),
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
                    const Text(
                      '接続テスト:',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
      final isConnected = await AIService.testApiConnection();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isConnected ? '✅ 接続成功' : '❌ 接続失敗'),
            content: Text(isConnected
                ? 'AIサービスに正常に接続できました。画像分析機能が利用可能です。'
                : 'AIサービスへの接続に失敗しました。\n\n'
                    '考えられる原因:\n'
                    '• APIキーが無効または期限切れ\n'
                    '• ネットワーク接続の問題\n'
                    '• サーバーが一時的に利用不可\n\n'
                    'しばらく時間をおいてから再試行してください。'),
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ 接続エラー'),
            content: Text('API接続テスト中にエラーが発生しました:\n\n$e\n\n'
                'APIキーの設定とネットワーク接続を確認してください。'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications, color: Colors.grey),
              title:
                  const Text('通知（未実装）', style: TextStyle(color: Colors.grey)),
              subtitle: const Text('アプリの通知を有効/無効にします',
                  style: TextStyle(color: Colors.grey)),
              trailing: Switch(
                value: _notifications,
                onChanged: null, // nullにすることでスイッチを無効化
              ),
            ),
          ),
          const SizedBox(height: 8),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.dark_mode),
                  title: const Text('ダークモード（Beta）'),
                  subtitle:
                      const Text('ダークテーマを有効/無効にします（実験中のため色合いがおかしくなることがあります。）'),
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
            child: ListTile(
              leading: const Icon(Icons.smart_toy, color: Colors.blue),
              title: const Text('AI機能設定'),
              subtitle: Text(AIService.isConfigured
                  ? 'AIサービス利用可能'
                  : 'Gemini APIキーを設定してください'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showAISettings,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('チュートリアルを見る'),
              subtitle: const Text('アプリの使い方を確認します'),
              trailing: const Icon(Icons.arrow_forward_ios),
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
            child: ListTile(
              leading: const Icon(Icons.info),
              title: const Text('バージョン情報'),
              subtitle: const Text('アプリのバージョン情報を表示'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('バージョン情報'),
                    content: Text(
                        '${AppInfo.appName}\n${AppInfo.version}\nDeveloped by Akihisa Iwata'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.map),
              title: const Text('カスタム地図管理'),
              subtitle: const Text('保存された地図の管理と削除'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MapListScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('データ管理'),
              subtitle: const Text('アプリのデータを管理します'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('データ管理'),
                    content: const Text('この機能は今後実装予定です。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
