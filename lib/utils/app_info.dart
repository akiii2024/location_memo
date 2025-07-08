import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  static PackageInfo? _packageInfo;

  /// パッケージ情報を初期化
  static Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// アプリのバージョン文字列を取得
  static String get version {
    if (_packageInfo == null) {
      return 'Unknown';
    }
    return 'Version ${_packageInfo!.version}';
  }

  /// アプリの詳細なバージョン情報を取得
  static String get detailedVersion {
    if (_packageInfo == null) {
      return 'Unknown';
    }
    return 'Version ${_packageInfo!.version}';
  }

  /// アプリ名を取得
  static String get appName {
    if (_packageInfo == null) {
      return 'Location Memo';
    }
    return _packageInfo!.appName;
  }

  /// パッケージ名を取得
  static String get packageName {
    if (_packageInfo == null) {
      return 'Unknown';
    }
    return _packageInfo!.packageName;
  }

  /// ビルド番号を取得
  static String get buildNumber {
    if (_packageInfo == null) {
      return 'Unknown';
    }
    return _packageInfo!.buildNumber;
  }
}
