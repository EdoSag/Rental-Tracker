import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_tracker/main.dart';
import 'package:rental_tracker/state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Drives the real UI on a phone-sized screen with a temporary database.
void main() {
  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rental');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
    final dbDir = await databaseFactory.getDatabasesPath();
    final f = File('$dbDir/rental.db');
    if (f.existsSync()) f.deleteSync();
  });

  testWidgets('enter a month and see results, summary and settings', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final state = (await tester.runAsync(AppState.load))!;
    state.updateSettings((s) {
      s.rents = [3000, 3200, 2800, 3500];
      s.mgmtPct = 10;
    });
    await tester.pumpWidget(RentalApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('יעקב'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Type a current electricity reading for Yaakov: first month -> base reading.
    final cur = find.widgetWithText(TextField, 'קריאה נוכחית').first;
    await tester.enterText(cur, '1000');
    await tester.pump();
    expect(find.text('קריאה ראשונה – בסיס'), findsWidgets);

    // Go to the next month and enter 1200 -> 200 kWh * 0.65 = 130.
    await tester.tap(find.byTooltip('החודש הבא'));
    await tester.pumpAndSettle();
    final prevField = tester.widget<TextField>(find.widgetWithText(TextField, 'קריאה אחרונה').first);
    expect(prevField.controller!.text, '1000');
    await tester.enterText(find.widgetWithText(TextField, 'קריאה נוכחית').first, '1200');
    await tester.pump();
    expect(find.text('צריכה: 200 קוט"ש'), findsOneWidget);

    // Lower reading -> warning, not blocked.
    await tester.enterText(find.widgetWithText(TextField, 'קריאה נוכחית').first, '900');
    await tester.pump();
    expect(find.textContaining('ייתכן שהוחלף שעון'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'קריאה נוכחית').first, '1200');
    await tester.pump();

    // Scroll to the results card.
    await tester.scrollUntilVisible(find.text('תוצאות החודש'), 400, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('3,130 ₪'), findsWidgets); // Yaakov: 3000 rent + 130 electricity
    expect(tester.takeException(), isNull);

    // Summary tab
    await tester.tap(find.text('סיכום').last);
    await tester.pumpAndSettle();
    expect(find.text('ייצוא לאקסל'), findsOneWidget);
    expect(find.text('סיכום שנתי'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Settings tab: partner percentages warning.
    await tester.tap(find.text('הגדרות').last);
    await tester.pumpAndSettle();
    expect(find.text('סה"כ 100%'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'ענר'), '30');
    await tester.pump();
    expect(find.textContaining('105%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.runAsync(state.flush);
  });
}
