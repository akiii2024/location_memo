import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'diagnostic_log_store.dart';
import 'firebase_availability.dart';

class CrashReportingService {
  CrashReportingService._();

  static final CrashReportingService instance = CrashReportingService._();
  static const _preferenceKey = 'crash_reporting_enabled';

  bool _enabled = true;
  bool _initialized = false;

  bool get enabled => _enabled;

  static void installGlobalHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      appLog('Flutter framework error', details.stack);
      DiagnosticLogStore.instance.record(
        'flutter_framework_error',
        error: details.exception,
      );
      instance.record(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: true,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      appLog('Unhandled asynchronous error', stack);
      DiagnosticLogStore.instance.record('unhandled_async_error', error: error);
      instance.record(error, stack, fatal: true);
      return true;
    };
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_preferenceKey) ?? true;
    if (!kIsWeb && FirebaseAvailability.isReady) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        _enabled,
      );
      _initialized = true;
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferenceKey, value);
    if (!kIsWeb && FirebaseAvailability.isReady) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(value);
      _initialized = true;
    }
  }

  Future<void> record(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    if (kIsWeb || !_enabled || !_initialized) return;
    try {
      // Do not attach user ids, location, memo text, map titles or file paths.
      await FirebaseCrashlytics.instance.recordError(
        error.runtimeType.toString(),
        stack,
        fatal: fatal,
        reason: '匿名化されたアプリエラー',
      );
    } catch (reportingError, reportingStack) {
      appLog(
        'Crash reporting failed: ${reportingError.runtimeType}',
        reportingStack,
      );
    }
  }
}
