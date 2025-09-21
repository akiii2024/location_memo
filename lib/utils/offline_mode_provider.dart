import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user prefers to operate without Firebase authentication.
class OfflineModeProvider extends ChangeNotifier {
  static const String _preferenceKey = 'offline_mode_enabled';

  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  final Completer<void> _initializationCompleter = Completer<void>();

  OfflineModeProvider() {
    _loadPreference();
  }

  Future<void> ensureInitialized() => _initializationCompleter.future;

  Future<void> enableOfflineMode() => _updateOfflineMode(true);

  Future<void> disableOfflineMode() => _updateOfflineMode(false);

  Future<void> toggleOfflineMode() => _updateOfflineMode(!_isOfflineMode);

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOfflineMode = prefs.getBool(_preferenceKey) ?? false;
    } finally {
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
      notifyListeners();
    }
  }

  Future<void> _updateOfflineMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferenceKey, value);

    if (_isOfflineMode != value) {
      _isOfflineMode = value;
      notifyListeners();
    } else if (!_initializationCompleter.isCompleted) {
      _initializationCompleter.complete();
    }
  }
}
