import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    // PWA環境での動的パディング計算
    double bottomPadding = 0;
    if (kIsWeb) {
      // Web環境での追加パディング
      final mediaQuery = MediaQuery.of(context);
      final screenHeight = mediaQuery.size.height;
      final viewInsets = mediaQuery.viewInsets;
      final padding = mediaQuery.padding;

      // PWA環境でのホームバー対応
      if (screenHeight < 800) {
        // 小さな画面（モバイル）でのパディング調整
        bottomPadding = 20;
      } else {
        // デスクトップでのパディング調整
        bottomPadding = 10;
      }

      // ビューポートの安全領域を考慮
      bottomPadding += padding.bottom;
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        // Web環境での追加パディング
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SafeArea(
          // SafeAreaの設定を調整
          minimum: EdgeInsets.only(
            bottom: kIsWeb ? 8.0 : 0.0, // Web環境では最小パディングを追加
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              // PWA環境での表示を最適化
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey,
              // Web環境での高さ調整
              selectedFontSize: kIsWeb ? 10 : 12,
              unselectedFontSize: kIsWeb ? 10 : 12,
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
          ),
        ),
      ),
    );
  }
}
