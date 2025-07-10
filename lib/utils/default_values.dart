import 'package:shared_preferences/shared_preferences.dart';

class DefaultValues {
  static const String _discovererKey = 'default_discoverer';
  static const String _specimenNumberPrefixKey =
      'default_specimen_number_prefix';
  static const String _categoryKey = 'default_category';
  static const String _notesKey = 'default_notes';

  // 発見者のデフォルト値を取得
  static Future<String?> getDefaultDiscoverer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_discovererKey);
  }

  // 発見者のデフォルト値を設定
  static Future<void> setDefaultDiscoverer(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value != null && value.isNotEmpty) {
      await prefs.setString(_discovererKey, value);
    } else {
      await prefs.remove(_discovererKey);
    }
  }

  // 標本番号プレフィックスのデフォルト値を取得
  static Future<String?> getDefaultSpecimenNumberPrefix() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_specimenNumberPrefixKey);
  }

  // 標本番号プレフィックスのデフォルト値を設定
  static Future<void> setDefaultSpecimenNumberPrefix(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value != null && value.isNotEmpty) {
      await prefs.setString(_specimenNumberPrefixKey, value);
    } else {
      await prefs.remove(_specimenNumberPrefixKey);
    }
  }

  // カテゴリのデフォルト値を取得
  static Future<String?> getDefaultCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_categoryKey);
  }

  // カテゴリのデフォルト値を設定
  static Future<void> setDefaultCategory(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value != null && value.isNotEmpty) {
      await prefs.setString(_categoryKey, value);
    } else {
      await prefs.remove(_categoryKey);
    }
  }

  // 備考のデフォルト値を取得
  static Future<String?> getDefaultNotes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_notesKey);
  }

  // 備考のデフォルト値を設定
  static Future<void> setDefaultNotes(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value != null && value.isNotEmpty) {
      await prefs.setString(_notesKey, value);
    } else {
      await prefs.remove(_notesKey);
    }
  }

  // 全てのデフォルト値を取得
  static Future<Map<String, String?>> getAllDefaultValues() async {
    return {
      'discoverer': await getDefaultDiscoverer(),
      'specimenNumberPrefix': await getDefaultSpecimenNumberPrefix(),
      'category': await getDefaultCategory(),
      'notes': await getDefaultNotes(),
    };
  }

  // 全てのデフォルト値をクリア
  static Future<void> clearAllDefaultValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_discovererKey);
    await prefs.remove(_specimenNumberPrefixKey);
    await prefs.remove(_categoryKey);
    await prefs.remove(_notesKey);
  }
}
