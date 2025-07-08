import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_list_screen.dart';
import '../utils/theme_provider.dart';
import '../utils/app_info.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;

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
