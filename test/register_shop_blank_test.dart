import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van1/register_shop_blank.dart';
import 'package:van1/register_shop_next.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows onboarding artwork', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegisterShopBlankScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byTooltip('ย้อนกลับ'), findsOneWidget);
    expect(find.byKey(const Key('merchant_onboarding_cta')), findsOneWidget);
  });

  testWidgets('CTA navigates to register shop next screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: <String, WidgetBuilder>{
          '/register-shop-next': (_) => const RegisterShopNextScreen(),
        },
        home: const RegisterShopBlankScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('merchant_onboarding_cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('service_tap_market')), findsOneWidget);
  });

  testWidgets('back button pops when possible', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterShopBlankScreen(),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byTooltip('ย้อนกลับ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('open'), findsOneWidget);
  });
}
