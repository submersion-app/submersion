import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_summary_widget.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

EquipmentItem _item(
  String id,
  double? price, {
  EquipmentStatus status = EquipmentStatus.active,
  String currency = 'USD',
}) => EquipmentItem(
  id: id,
  name: 'Item $id',
  type: EquipmentType.regulator,
  status: status,
  isActive: status != EquipmentStatus.wanted,
  purchasePrice: price,
  purchaseCurrency: currency,
);

/// Wishlist gear in the Equipment summary (#2025): kept out of the owned
/// totals and shown on cards of its own.
void main() {
  Future<void> pumpSummary(
    WidgetTester tester,
    List<EquipmentItem> equipment, {
    String defaultCurrency = 'USD',
    List<EquipmentItem> serviceDue = const [],
    List<DueClock> dueClocks = const [],
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
          serviceDueEquipmentProvider.overrideWith(
            (ref, _) async => serviceDue,
          ),
          dueClocksProvider.overrideWith((ref) async => dueClocks),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('wanted gear stays out of the owned totals', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSummary(tester, [
      _item('a', 300),
      _item('w', 900, status: EquipmentStatus.wanted),
    ]);

    expect(find.bySemanticsLabel('Total Items: 1'), findsWidgets);
    expect(find.bySemanticsLabel('Active: 1'), findsWidgets);
    expect(find.bySemanticsLabel('Total Value (USD): \$300'), findsWidgets);
    // Nor is it listed among the recent (owned) equipment.
    expect(find.text('Item w'), findsNothing);
    handle.dispose();
  });

  testWidgets('wanted gear gets its own count and value cards', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSummary(tester, [
      _item('a', 300),
      _item('w1', 900, status: EquipmentStatus.wanted),
      _item('w2', 100, status: EquipmentStatus.wanted, currency: 'EUR'),
    ]);

    expect(find.bySemanticsLabel('Wanted: 2'), findsWidgets);
    expect(find.bySemanticsLabel('Wanted Value (USD): \$900'), findsWidgets);
    expect(find.text('Wanted Value (EUR)'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('no wishlist, no wanted cards', (tester) async {
    await pumpSummary(tester, [_item('a', 300)]);

    expect(find.text('Wanted'), findsNothing);
    expect(find.textContaining('Wanted Value'), findsNothing);
  });
}
