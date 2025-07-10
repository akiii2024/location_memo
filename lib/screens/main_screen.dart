import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location_memo/screens/home_screen.dart';
import 'package:location_memo/screens/search_screen.dart';
import 'package:location_memo/screens/pin_list_screen.dart';
import 'package:location_memo/screens/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const PinListScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 画面が構築された後にalpha版警告ダイアログを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowAlphaWarningDialog();
    });
  }

  Future<void> _checkAndShowAlphaWarningDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShowDialog = prefs.getBool('show_alpha_warning') ?? true;

    if (shouldShowDialog) {
      _showAlphaWarningDialog();
    }
  }

  void _showAlphaWarningDialog() {
    bool dontShowAgain = false;

    showDialog(
      context: context,
      barrierDismissible: false, // ダイアログ外タップで閉じない
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('開発版について'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'このアプリは現在開発中のテスト版です。',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '以下の点にご注意ください：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• 保存したデータが消える可能性があります'),
                  Text('• アプリが予期せず停止する可能性があります'),
                  Text('• 機能が変更・削除される可能性があります'),
                  SizedBox(height: 8),
                  Text(
                    '重要なデータは必ずバックアップを取ってからご利用ください。',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: dontShowAgain,
                        onChanged: (value) {
                          setState(() {
                            dontShowAgain = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          '次回から表示しない',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // 設定を保存
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('show_alpha_warning', !dontShowAgain);

                    Navigator.of(context).pop();
                  },
                  child: Text(
                    '理解しました',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '検索',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.push_pin),
            label: 'ピン一覧',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
