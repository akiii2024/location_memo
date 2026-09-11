import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:location_memo/screens/main_screen.dart';
import 'package:location_memo/screens/tutorial_screen.dart';
import 'package:location_memo/utils/app_info.dart';
import 'package:location_memo/utils/app_bootstrap.dart';
import 'package:location_memo/utils/tutorial_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isRouting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  Future<void> _routeIntoApp() async {
    if (_isRouting) return;
    _isRouting = true;
    final isFirstLaunch = await TutorialService.isFirstLaunch();
    if (!mounted) return;
    final nextScreen = isFirstLaunch
        ? const TutorialScreen()
        : const MainScreen();
    await Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = context.watch<AppBootstrapController>();
    if (bootstrap.canEnterApp) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _routeIntoApp());
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                '位置メモ',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontFamily: 'NotoSansJP',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppInfo.version,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Powered by Flutter',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  fontFamily: 'NotoSansJP',
                ),
              ),
              const SizedBox(height: 50),
              if (bootstrap.state == AppBootstrapState.failed) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    bootstrap.failure?.userMessage ?? 'アプリを起動できませんでした。',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: bootstrap.initialize,
                  icon: const Icon(Icons.refresh),
                  label: const Text('再試行'),
                ),
              ] else
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
