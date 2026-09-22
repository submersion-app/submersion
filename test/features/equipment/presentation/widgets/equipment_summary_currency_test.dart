import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
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

  String card(double total, String code) =>
      '${currencySymbol(code)}${total.toStringAsFixed(0)}';

  DueClock clock(EquipmentItem item, ServiceClockSeverity severity) {
    final t0 = DateTime(2026, 1, 1);
    return (
      item: item,
      status: ServiceClockStatus(
        schedule: ServiceSchedule(
          id: 's-${item.id}',
          equipmentId: item.id,
          serviceKindId: 'annual',
          createdAt: t0,
          updatedAt: t0,
        ),
        kind: ServiceKind(
          id: 'annual',
          name: 'Annual service',
          createdAt: t0,
          updatedAt: t0,
        ),
        anchor: t0,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        severity: severity,
        now: DateTime.now(),
      ),
    );
  }

  /// Asserts the whole service-due section (heading icon, card, avatar
  /// badge) is painted from [swatch].
  void expectServiceDueSwatch(WidgetTester tester, StatusSwatch swatch) {
    final heading = find.text('Service Due');
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.ancestor(of: heading, matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.warning),
      ),
    );
    expect(icon.color, swatch.accent);

    // The item is listed twice: in the service-due card and again under
    // recent items. The service-due section renders first.
    final row = find.text('Item d1').first;
    final card = tester.widget<Card>(
      find.ancestor(of: row, matching: find.byType(Card)).first,
    );
    expect(card.color, swatch.container);

    final tile = find.ancestor(of: row, matching: find.byType(ListTile)).first;
    final avatar = tester.widget<CircleAvatar>(
      find.descendant(of: tile, matching: find.byType(CircleAvatar)),
    );
    expect(avatar.backgroundColor, swatch.accent);
    final glyph = tester.widget<Icon>(
      find.descendant(of: tile, matching: find.byIcon(Icons.build)),
    );
    expect(glyph.color, swatch.onAccent);
  }

  testWidgets('an overdue item paints the service-due section as alert', (
    tester,
  ) async {
    final due = _priced('d1', null, 'USD');
    await pumpSummary(
      tester,
      [due],
      serviceDue: [due],
      dueClocks: [clock(due, ServiceClockSeverity.overdue)],
    );

    expectServiceDueSwatch(tester, StatusColors.light.alert);
  });

  testWidgets('items only coming due paint the section as warn, not alert', (
    tester,
  ) async {
    final due = _priced('d1', null, 'USD');
    await pumpSummary(
      tester,
      [due],
      serviceDue: [due],
      dueClocks: [clock(due, ServiceClockSeverity.dueSoon)],
    );

    expectServiceDueSwatch(tester, StatusColors.light.warn);
  });

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

  testWidgets('each total card names the currency it is counted in', (
    tester,
  ) async {
    await pumpSummary(tester, [_priced('a', 250.0, 'EUR')]);

    expect(find.text('Total Value (EUR)'), findsOneWidget);
    expect(find.text('Total Value'), findsNothing);
  });

  testWidgets('currencies sharing a symbol stay distinguishable', (
    tester,
  ) async {
    // The reported bug (#1519): intl renders both USD and CAD as a bare "$",
    // so two "Total Value" cards read as "$900" and "$400" with nothing to
    // say which pile of gear was bought in which country's dollars.
    await pumpSummary(tester, [
      _priced('a', 900.0, 'USD'),
      _priced('b', 400.0, 'CAD'),
    ]);

    expect(currencySymbol('CAD'), currencySymbol('USD'));
    expect(find.text('Total Value (USD)'), findsOneWidget);
    expect(find.text('Total Value (CAD)'), findsOneWidget);
  });

  testWidgets('the currency reaches the stat card semantics', (tester) async {
    // A screen reader announces the label, never the "$" glyph's origin, so
    // the code has to be in the spoken string too. Matched with findsWidgets
    // because the card's Semantics node and its merge container both carry it.
    final handle = tester.ensureSemantics();
    await pumpSummary(tester, [_priced('a', 900.0, 'CAD')]);

    expect(find.bySemanticsLabel('Total Value (CAD): \$900'), findsWidgets);
    handle.dispose();
  });

  testWidgets('items without a price contribute no total card', (tester) async {
    await pumpSummary(tester, [
      _priced('a', null, 'EUR'),
      _priced('b', null, 'USD'),
    ]);

    expect(find.byIcon(Icons.attach_money), findsNothing);
  });
}
