import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String _tutorialCompleteKey = 'tutorial_completed';

  /// 初回起動かどうかを判定
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_tutorialCompleteKey) ?? false);
  }

  /// チュートリアル完了フラグを設定
  static Future<void> setTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialCompleteKey, true);
  }

  /// チュートリアル完了フラグをリセット（テスト用）
  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tutorialCompleteKey);
  }
}
