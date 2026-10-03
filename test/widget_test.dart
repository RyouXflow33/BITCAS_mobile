import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitcas_driver/main.dart';

void main() {
  testWidgets('Driver app shows the map title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DriverApp());
    await tester.pump();
    expect(find.text('BITCAS Driver'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Advisories'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
