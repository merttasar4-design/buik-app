import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:buik_app/main.dart' as app;

const _email = String.fromEnvironment('TEST_USER_EMAIL');
const _password = String.fromEnvironment('TEST_USER_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('member logs in and can navigate all tabs', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('GİRİŞ YAP'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      _email,
    );
    await tester.enterText(find.byType(TextField).last, _password);
    await tester.pump();

    await tester.tap(find.text('GİRİŞ YAP'));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Should now be on the Calendar tab (default) inside MainShell.
    expect(find.text('TAKVİM'), findsOneWidget);

    await tester.tap(find.text('Yoklama'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('YOKLAMA'), findsOneWidget);
    debugPrint(
      'ATTENDANCE_PANEL: ${find.text('Toplantı Kodu').evaluate().isNotEmpty ? 'member-checkin' : 'other'}',
    );

    await tester.tap(find.text('Duyurular'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('DUYURULAR'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('PROFİL'), findsOneWidget);
    expect(find.text(_email), findsOneWidget);

    final roleFinder = find.text('Üye');
    debugPrint('ROLE_LABEL_FOUND: ${roleFinder.evaluate().isNotEmpty}');
  });
}
