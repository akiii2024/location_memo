import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_memo/screens/auth_screen.dart';
import 'package:location_memo/utils/ai_service.dart';

void main() {
  testWidgets('認証画面から新規登録へ切り替えられる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));

    expect(find.text('アカウントにログイン'), findsOneWidget);
    expect(find.text('パスワードを忘れた方'), findsOneWidget);

    await tester.ensureVisible(find.text('アカウントをお持ちでない方はこちら'));
    await tester.tap(find.text('アカウントをお持ちでない方はこちら'));
    await tester.pump();

    expect(find.text('新しくアカウントを作成'), findsOneWidget);
    expect(find.text('表示名 (任意)'), findsOneWidget);
    expect(find.text('パスワード (確認用)'), findsOneWidget);
  });

  testWidgets('新規登録では8文字未満のパスワードを拒否する', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.ensureVisible(find.text('アカウントをお持ちでない方はこちら'));
    await tester.tap(find.text('アカウントをお持ちでない方はこちら'));
    await tester.pump();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '1234567');
    await tester.enterText(find.byType(TextFormField).at(3), '1234567');
    await tester.ensureVisible(find.text('アカウントを作成'));
    await tester.tap(find.text('アカウントを作成'));
    await tester.pump();

    expect(find.text('パスワードは8文字以上で設定してください'), findsOneWidget);
  });

  test('APIキー未指定時はAI機能を無効化する', () {
    expect(AIService.isConfigured, isFalse);
  });

  testWidgets('360px幅・200%文字でもログイン画面が操作可能', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const AuthScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('アカウントにログイン'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'ログイン'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
