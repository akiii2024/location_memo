import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:location_memo/screens/main_screen.dart';
import 'package:location_memo/screens/splash_screen.dart';
import 'package:location_memo/utils/theme_provider.dart';
import 'package:location_memo/utils/app_info.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized;
  // Hive 初期化（永続データ用）
  await Hive.initFlutter();
  await AppInfo.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Location Memo',
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
