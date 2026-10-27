import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitcas_driver/controller.dart';
import 'package:bitcas_driver/main.dart';
import 'package:bitcas_driver/missions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App opens on the map as a guest', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => const <String, dynamic>{
        'appName': 'BITCAS Driver',
        'packageName': 'ph.lgu.bitcas.bitcas_driver',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
    await tester.pumpWidget(const DriverApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Use the app for 15 minutes'), findsNothing);
    expect(find.text('Map'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsWidgets);

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    await tester.tap(find.byTooltip('Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Using the app without an account'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Daily and random missions track events and can be claimed', () async {
    SharedPreferences.setMockInitialValues({});
    final app = AppController();
    await app.init();

    expect(app.isGuest, isTrue);
    expect(app.randomMissions.length, 3);

    app.record(MissionEvent.logsOpen);
    expect(app.canClaim('daily_logs'), isFalse);
    expect(app.claim('daily_logs'), isFalse);

    await app.setThemeMode(ThemeMode.dark);
    expect(app.themeMode, ThemeMode.dark);

    await app.signUp(name: 'Ana Cruz', email: 'ana@example.com');
    expect(app.account?.initials, 'AC');
    expect(app.canClaim('daily_logs'), isTrue);
    expect(app.claim('daily_logs'), isTrue);
    expect(app.claim('daily_logs'), isFalse);
    expect(app.board.points, 30);
    await app.signOut();
    expect(app.isGuest, isTrue);

    app.dispose();
  });
}
