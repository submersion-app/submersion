import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _equipment = EquipmentItem(
  id: 'equip-svc',
  name: 'Primary Reg',
  type: EquipmentType.regulator,
);

ServiceRecord _record({
  required String id,
  double? cost,
  String currency = 'USD',
}) {
  return ServiceRecord(
    id: id,
    equipmentId: _equipment.id,
    serviceCategory: ServiceCategory.annual,
    serviceDate: DateTime(2026, 1, 1),
    cost: cost,
    currency: currency,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

class _SeededServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _SeededServiceRecordNotifier(List<ServiceRecord> records)
    : super(AsyncValue.data(records));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    required List<ServiceRecord> records,
    Map<String, double> totals = const {},
    String defaultCurrency = 'USD',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settings = MockSettingsNotifier();
    final overrides = await getBaseOverrides(settingsNotifier: settings);
    await settings.setDefaultCurrency(defaultCurrency);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider(
            _equipment.id,
          ).overrideWith((ref) async => _equipment),
          equipmentDiveCountProvider(
            _equipment.id,
          ).overrideWith((ref) async => 0),
          equipmentTripCountProvider(
            _equipment.id,
          ).overrideWith((ref) async => 0),
          serviceRecordNotifierProvider(
            _equipment.id,
          ).overrideWith((ref) => _SeededServiceRecordNotifier(records)),
          serviceRecordTotalCostProvider(
            _equipment.id,
          ).overrideWith((ref) async => totals),
          serviceClockStatusesProvider(
            _equipment.id,
          ).overrideWith((ref) async => const []),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentDetailPage(equipmentId: _equipment.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // `.first` because a per-currency total and its record row can render the
  // same formatted string, which would make the target ambiguous.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder.first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('service record cost display', () {
    testWidgets('a record shows its own currency, not a hardcoded dollar', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        records: [_record(id: 'r1', cost: 120, currency: 'EUR')],
      );

      final expected = formatMoney(120, 'EUR');
      await scrollTo(tester, find.text(expected));
      expect(find.text(expected), findsOneWidget);
      expect(expected, contains('€'));
    });

    testWidgets('total cost is split per currency, never added together', (
      tester,
    ) async {
      // The regression: 100 EUR + 900 USD once rendered as a single "$1000".
      await pumpDetail(
        tester,
        records: [
          _record(id: 'r1', cost: 100, currency: 'EUR'),
          _record(id: 'r2', cost: 900, currency: 'USD'),
        ],
        totals: const {'EUR': 100, 'USD': 900},
      );

      await scrollTo(tester, find.text(formatMoney(900, 'USD')));

      // One total row per currency, so both are labelled -- a single combined
      // row would give exactly one label.
      expect(find.text('Total Service Cost'), findsNWidgets(2));
      // Each currency's own figure appears, and the naive sum never does.
      expect(find.text(formatMoney(900, 'USD')), findsWidgets);
      expect(find.text(formatMoney(100, 'EUR')), findsWidgets);
      expect(find.text(formatMoney(1000, 'USD')), findsNothing);
      expect(find.text(formatMoney(1000, 'EUR')), findsNothing);
    });

    testWidgets('a blank stored currency falls back to the diver default', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        records: [_record(id: 'r1', cost: 40, currency: '')],
        totals: const {'': 40},
        defaultCurrency: 'GBP',
      );

      await scrollTo(tester, find.text(formatMoney(40, 'GBP')));
      expect(find.text(formatMoney(40, 'GBP')), findsOneWidget);
    });

    testWidgets('records without a cost produce no total row', (tester) async {
      await pumpDetail(tester, records: [_record(id: 'r1')]);

      expect(find.text('Total Service Cost'), findsNothing);
    });
  });

  group('ServiceRecordDialog currency', () {
    Future<DropdownMenu<String>> pumpDialog(
      WidgetTester tester, {
      ServiceRecord? existing,
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            serviceKindsProvider.overrideWith((ref) async => const []),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServiceRecordDialog(
                equipmentId: _equipment.id,
                existingRecord: existing,
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menu = find.byType(DropdownMenu<String>);
      await tester.scrollUntilVisible(
        menu,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      return tester.widget<DropdownMenu<String>>(menu);
    }

    testWidgets('a new record opens in the diver default currency', (
      tester,
    ) async {
      final menu = await pumpDialog(tester, defaultCurrency: 'SEK');

      expect(menu.controller?.text, 'SEK');
      // The cost field's prefix tracks the selected currency.
      expect(find.textContaining(currencySymbol('SEK')), findsWidgets);
    });

    testWidgets('editing keeps the currency the record was priced in', (
      tester,
    ) async {
      final menu = await pumpDialog(
        tester,
        existing: _record(id: 'r1', cost: 75, currency: 'EUR'),
        defaultCurrency: 'USD',
      );

      // The stored currency wins over the diver's default when editing --
      // otherwise saving would silently reprice the record.
      expect(menu.controller?.text, 'EUR');
    });

    testWidgets('a stored code outside the presets is still offered', (
      tester,
    ) async {
      final menu = await pumpDialog(
        tester,
        existing: _record(id: 'r1', cost: 75, currency: 'ISK'),
      );

      expect(menu.controller?.text, 'ISK');
      expect(menu.dropdownMenuEntries.map((e) => e.value).first, 'ISK');
    });
  });
}
