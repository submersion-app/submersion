import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_summary_widget.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

EquipmentItem _priced(String id, double? price, String currency) {
  return EquipmentItem(
    id: id,
    name: 'Item $id',
    type: EquipmentType.regulator,
    purchasePrice: price,
    purchaseCurrency: currency,
  );
}

void main() {
  Future<void> pumpSummary(
    WidgetTester tester,
    List<EquipmentItem> equipment, {
    String defaultCurrency = 'USD',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settings = MockSettingsNotifier();
    final overrides = await getBaseOverrides(settingsNotifier: settings);
    await settings.setDefaultCurrency(defaultCurrency);

    final router = GoRouter(
      initialLocation: '/equipment',
      routes: [
        GoRoute(
          path: '/equipment',
          builder: (context, state) => const EquipmentSummaryWidget(),
        ),
      ],
    );

    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          allEquipmentProvider.overrideWith((ref) async => equipment),
          serviceDueEquipmentProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  String card(double total, String code) =>
      '${currencySymbol(code)}${total.toStringAsFixed(0)}';

  testWidgets('one currency yields a single total in that currency', (
    tester,
  ) async {
    await pumpSummary(tester, [
      _priced('a', 100.0, 'EUR'),
      _priced('b', 250.0, 'EUR'),
    ]);

    expect(find.text(card(350, 'EUR')), findsOneWidget);
  });

  testWidgets('mixed currencies are never added into one figure', (
    tester,
  ) async {
    // The regression this guards: 100 EUR + 900 USD once rendered as a single
    // "$1000" total under whichever symbol the diver's default happened to be.
    await pumpSummary(tester, [
      _priced('a', 100.0, 'EUR'),
      _priced('b', 900.0, 'USD'),
    ]);

    expect(find.text(card(900, 'USD')), findsOneWidget);
    expect(find.text(card(100, 'EUR')), findsOneWidget);
    expect(find.text(card(1000, 'USD')), findsNothing);
  });

  testWidgets('a blank stored currency falls back to the diver default', (
    tester,
  ) async {
    await pumpSummary(tester, [
      _priced('a', 40.0, ''),
      _priced('b', 60.0, 'GBP'),
    ], defaultCurrency: 'GBP');

    expect(find.text(card(100, 'GBP')), findsOneWidget);
  });

  testWidgets('items without a price contribute no total card', (tester) async {
    await pumpSummary(tester, [
      _priced('a', null, 'EUR'),
      _priced('b', null, 'USD'),
    ]);

    expect(find.byIcon(Icons.attach_money), findsNothing);
  });
}
