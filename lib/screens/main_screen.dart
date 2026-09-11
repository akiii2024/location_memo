import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location_memo/screens/home_screen.dart';
import 'package:location_memo/screens/search_screen.dart';
import 'package:location_memo/screens/pin_list_screen.dart';
import 'package:location_memo/screens/settings_screen.dart';
import 'package:location_memo/utils/app_bootstrap.dart';
import 'package:location_memo/utils/theme_provider.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
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
    // タッチイベント競合を防ぐため、十分な遅延後にダイアログを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _checkAndShowAlphaWarningDialog();
        }
      });
    });
  }

  Future<void> _checkAndShowAlphaWarningDialog() async {
    if (kReleaseMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final shouldShowDialog = prefs.getBool('show_alpha_warning') ?? true;

    if (shouldShowDialog && mounted) {
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
              title: const Row(
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
                  const Text(
                    'このアプリは現在開発中のテスト版です。',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '以下の点にご注意ください：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text('• 保存したデータが消える可能性があります'),
                  const Text('• アプリが予期せず停止する可能性があります'),
                  const Text('• 機能が変更・削除される可能性があります'),
                  const SizedBox(height: 8),
                  const Text(
                    '重要なデータは必ずバックアップを取ってからご利用ください。',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      const Expanded(
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
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: const Text(
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
    final isWide =
        MediaQuery.sizeOf(context).width >= AppSpacing.navigationRailBreakpoint;
    final bootstrap = context.watch<AppBootstrapController>();
    final body = Column(
      children: [
        if (bootstrap.state == AppBootstrapState.localOnly)
          _CloudUnavailableBanner(
            message:
                bootstrap.failure?.userMessage ?? 'クラウドへ接続できません。端末内の記録は利用できます。',
            isRetrying: bootstrap.state == AppBootstrapState.loading,
            onRetry: bootstrap.retryFirebase,
          ),
        Expanded(
          child: IndexedStack(index: _currentIndex, children: _screens),
        ),
      ],
    );

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                SafeArea(
                  right: false,
                  child: NavigationRail(
                    selectedIndex: _currentIndex,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: _selectDestination,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('ホーム'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search_outlined),
                        selectedIcon: Icon(Icons.search),
                        label: Text('検索'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.push_pin_outlined),
                        selectedIcon: Icon(Icons.push_pin),
                        label: Text('ピン一覧'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('設定'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectDestination,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'ホーム',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: '検索',
                ),
                NavigationDestination(
                  icon: Icon(Icons.push_pin_outlined),
                  selectedIcon: Icon(Icons.push_pin),
                  label: 'ピン一覧',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '設定',
                ),
              ],
            ),
    );
  }

  void _selectDestination(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }
}

class _CloudUnavailableBanner extends StatelessWidget {
  const _CloudUnavailableBanner({
    required this.message,
    required this.isRetrying,
    required this.onRetry,
  });

  final String message;
  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.tertiaryContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: colors.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: colors.onTertiaryContainer),
                  ),
                ),
                TextButton.icon(
                  onPressed: isRetrying ? null : onRetry,
                  icon: isRetrying
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
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
