import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  bool _isDarkMode = false;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isDarkMode = _prefs?.getBool(_themeKey) ?? false;
    } catch (e) {
      print('SharedPreferences初期化エラー: $e');
      // エラーが発生した場合はデフォルト値を使用
      _isDarkMode = false;
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized || _prefs == null) {
      try {
        _prefs = await SharedPreferences.getInstance();
      } catch (e) {
        print('SharedPreferences初期化エラー: $e');
        // エラーが発生した場合はnullのままにする
        _prefs = null;
      }
      _isInitialized = true;
    }
  }

  Future<void> toggleTheme() async {
    await _ensureInitialized();
    _isDarkMode = !_isDarkMode;
    try {
      await _prefs?.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('テーマ設定の保存エラー: $e');
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    await _ensureInitialized();
    _isDarkMode = value;
    try {
      await _prefs?.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('テーマ設定の保存エラー: $e');
    }
    notifyListeners();
  }

  // ライトテーマの定義
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      brightness: Brightness.light,
      fontFamily: 'NotoSansJP',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      // ライトモード時のタブバー設定を追加
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // ダークテーマの定義
  static ThemeData get darkTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      brightness: Brightness.dark,
      fontFamily: 'NotoSansJP',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.grey,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      // ダークモード時のタブバー設定を追加
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
