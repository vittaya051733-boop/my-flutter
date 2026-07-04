import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van1/register_screen.dart';
import 'package:van1/register_shop_next.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows service selection artwork', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegisterShopNextScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byTooltip('ย้อนกลับ'), findsOneWidget);
    expect(find.byKey(const Key('service_tap_market')), findsOneWidget);
    expect(find.byKey(const Key('service_tap_shop')), findsOneWidget);
    expect(find.byKey(const Key('service_tap_restaurant')), findsOneWidget);
    expect(find.byKey(const Key('service_tap_pharmacy')), findsOneWidget);
  });

  testWidgets('market tap opens register screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegisterShopNextScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('service_tap_market')));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  for (final entry in <MapEntry<Key, String>>[
    MapEntry(const Key('service_tap_shop'), 'ร้านค้า'),
    MapEntry(const Key('service_tap_restaurant'), 'ร้านอาหาร'),
    MapEntry(const Key('service_tap_pharmacy'), 'ร้านขายยา'),
  ]) {
    testWidgets('${entry.value} tap opens register screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: RegisterShopNextScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(entry.key));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  }
}
