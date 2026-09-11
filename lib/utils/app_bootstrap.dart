import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'app_failure.dart';
import 'app_info.dart';
import 'app_logger.dart';
import 'crash_reporting_service.dart';
import 'collaboration_sync_coordinator.dart';
import 'database_helper.dart';
import 'diagnostic_log_store.dart';
import 'feature_flags.dart';
import 'firebase_availability.dart';

enum AppBootstrapState { idle, loading, ready, localOnly, failed }

class AppBootstrapController extends ChangeNotifier {
  AppBootstrapState _state = AppBootstrapState.idle;
  AppFailure? _failure;

  AppBootstrapState get state => _state;
  AppFailure? get failure => _failure;
  bool get isFirebaseAvailable => FirebaseAvailability.isReady;
  bool get canEnterApp =>
      _state == AppBootstrapState.ready ||
      _state == AppBootstrapState.localOnly;

  Future<void> initialize() async {
    if (_state == AppBootstrapState.loading) return;
    _state = AppBootstrapState.loading;
    _failure = null;
    notifyListeners();

    // Firebase接続はローカルDBを待たずに開始する。クラウド側が失敗しても
    // ローカル初期化の成否とは分離して扱う。
    final firebaseInitialization = _prepareFirebase();

    try {
      await Future.wait([
        AppInfo.init(),
        DiagnosticLogStore.instance.initialize(),
        _initializeLocalData(),
      ]);
    } catch (error, stackTrace) {
      DiagnosticLogStore.instance.record('local_startup_failed', error: error);
      appLog('Local startup failed: ${error.runtimeType}', stackTrace);
      _failure = AppFailure.from(
        error,
        stackTrace: stackTrace,
        kind: AppFailureKind.startup,
        message: '端末内データを読み込めませんでした。再試行してください。',
      );
      _state = AppBootstrapState.failed;
      notifyListeners();
      return;
    }

    await _completeFirebaseInitialization(firebaseInitialization);
    notifyListeners();
  }

  Future<void> _initializeLocalData() async {
    await DatabaseHelper.instance.init();
    // On Android, opening the database here runs additive migrations before
    // the first screen starts reading records.
    await DatabaseHelper.instance.readAllMaps();
  }

  Future<void> retryFirebase() async {
    if (_state == AppBootstrapState.loading) return;
    _state = AppBootstrapState.loading;
    notifyListeners();
    await _completeFirebaseInitialization(_prepareFirebase());
    notifyListeners();
  }

  Future<AppFailure?> _prepareFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await _activateAppCheck();
      return null;
    } catch (error, stackTrace) {
      DiagnosticLogStore.instance.record(
        'firebase_startup_failed',
        error: error,
      );
      appLog('Firebase startup unavailable: ${error.runtimeType}', stackTrace);
      return AppFailure.from(
        error,
        stackTrace: stackTrace,
        kind: AppFailureKind.network,
        message: 'クラウドへ接続できません。端末内の記録は引き続き利用できます。',
      );
    }
  }

  Future<void> _completeFirebaseInitialization(
    Future<AppFailure?> initialization,
  ) async {
    AppFailure? failure;
    try {
      failure = await initialization.timeout(const Duration(seconds: 12));
    } catch (error, stackTrace) {
      DiagnosticLogStore.instance.record(
        'firebase_startup_timeout',
        error: error,
      );
      appLog('Firebase startup timed out: ${error.runtimeType}', stackTrace);
      failure = AppFailure.from(
        error,
        stackTrace: stackTrace,
        kind: AppFailureKind.network,
        message: 'クラウドへの接続がタイムアウトしました。端末内の記録は利用できます。',
      );
    }

    if (failure != null) {
      FirebaseAvailability.markUnavailable();
      _failure = failure;
      _state = AppBootstrapState.localOnly;
      return;
    }

    FirebaseAvailability.markReady();
    try {
      await CrashReportingService.instance.initialize();
    } catch (error, stackTrace) {
      // 障害送信の初期化失敗だけでクラウド保存を無効化しない。
      appLog('Crash reporting initialization failed', stackTrace);
    }
    try {
      await CollaborationSyncCoordinator.instance.flushPending().timeout(
        const Duration(seconds: 10),
      );
    } catch (error, stackTrace) {
      // キューは永続化済みなので、次の起動・再接続時に再試行できる。
      appLog('Initial sync flush deferred: ${error.runtimeType}', stackTrace);
    }
    _failure = null;
    _state = AppBootstrapState.ready;
  }

  Future<void> _activateAppCheck() async {
    if (kIsWeb) {
      const siteKey = FeatureFlags.recaptchaEnterpriseSiteKey;
      if (siteKey.isEmpty) {
        appLog('App Check web provider is not configured.');
        if (kReleaseMode) {
          throw StateError('App Check site key is required for web release');
        }
        return;
      }
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider(siteKey),
      );
      return;
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  }
}
