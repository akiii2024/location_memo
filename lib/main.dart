import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:location_memo/screens/splash_screen.dart';
import 'package:location_memo/utils/app_bootstrap.dart';
import 'package:location_memo/utils/theme_provider.dart';
import 'package:location_memo/utils/offline_mode_provider.dart';
import 'package:location_memo/utils/crash_reporting_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = AppBootstrapController();
  CrashReportingService.installGlobalHandlers();
  ErrorWidget.builder = (_) => _AppErrorView(onRetry: bootstrap.initialize);
  runApp(MyApp(bootstrap: bootstrap));
  unawaited(bootstrap.initialize());
}

class _AppErrorView extends StatelessWidget {
  const _AppErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  '画面を表示できませんでした',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '入力内容は端末内に残っています。再試行しても戻らない場合は、アプリまたはブラウザを再起動してください。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('再試行'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({required this.bootstrap, super.key});

  final AppBootstrapController bootstrap;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: bootstrap),
        ChangeNotifierProvider(create: (_) => OfflineModeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: '位置メモ',
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ja')],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
