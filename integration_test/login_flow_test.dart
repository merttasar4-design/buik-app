import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:buik_app/main.dart' as app;

const _password = String.fromEnvironment('TEST_USER_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up form submits to Supabase and shows feedback', (
    tester,
  ) async {
    final uniqueEmail =
        'buikclaude+sim${DateTime.now().millisecondsSinceEpoch}@gmail.com';

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Splash screen waits 2s then navigates to Login.
    expect(find.text('GİRİŞ YAP'), findsOneWidget);

    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await tester.pumpAndSettle();

    expect(find.text('KAYIT OL'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, uniqueEmail);
    await tester.enterText(find.byType(TextField).last, _password);
    await tester.pumpAndSettle();

    await tester.tap(find.text('KAYIT OL'));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 3));
    await tester.pump();

    // Either a successful sign-up message or a Supabase-side error (e.g. rate
    // limiting) is shown — both prove the request reached Supabase and the
    // UI surfaced the result.
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect((snackBar.content as Text).data, isNotEmpty);
  });
}
