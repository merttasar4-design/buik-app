import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:buik_app/main.dart' as app;

/// Mağaza ekran görüntüleri: misafir modunda ana ekranları gezer.
/// Çalıştırma: python3 tool/store_screenshots.py <simülatör-udid>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 3]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // tool/store_screenshots.py bu satırı görünce simülatör ekranını çeker.
  Future<void> shot(WidgetTester tester, String name) async {
    // ignore: avoid_print
    print('STORE_SHOT $name');
    await settle(tester, 3);
  }

  testWidgets('store screenshots', (tester) async {
    app.main();
    await settle(tester, 2);
    await settle(tester, 4);
    await shot(tester, '01_giris');

    await tester.tap(find.text('Giriş yapmadan devam et'));
    await settle(tester, 5);
    // Etkinliği olan bir güne dokun ki takvim boş görünmesin.
    await tester.tap(find.text('25').last);
    await settle(tester, 2);
    await shot(tester, '02_takvim');

    await tester.tap(find.text('Duyurular').last);
    await settle(tester, 4);
    await shot(tester, '03_duyurular');

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).last);
    scaffold.openDrawer();
    await settle(tester, 2);
    await shot(tester, '04_menu');
  });
}
