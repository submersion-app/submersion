import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/cost_of_ownership.dart';
import 'package:submersion/features/insights/presentation/providers/equipment_report_insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/equipment/cost_of_ownership_section.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

CostRow _row(String name, double cost, {int dives = 0, double hours = 0}) =>
    CostRow(
      item: EquipmentItem(id: name, name: name, type: EquipmentType.regulator),
      cost: cost,
      diveCount: dives,
      hours: hours,
    );

CurrencyCost _usd({
  List<CostRow>? rows,
  int undated = 0,
  List<({int year, double amount})>? byYear,
}) => CurrencyCost(
  currency: 'USD',
  total: 11960,
  perDive: 7.4,
  byYear:
      byYear ?? const [(year: 2024, amount: 900), (year: 2025, amount: 300)],
  undatedPurchases: undated,
  rows: rows ?? [_row('Apex Reg Set', 1565, dives: 340, hours: 412)],
);

const _eur = CurrencyCost(
  currency: 'EUR',
  total: 1180,
  perDive: 1.2,
  byYear: [(year: 2023, amount: 1180)],
  undatedPurchases: 0,
  rows: [],
);

Future<void> _pump(
  WidgetTester tester,
  Future<CostOfOwnership> Function() load,
) async {
  await tester.pumpWidget(
    // A fresh scope per pump: a scope keeps its first overrides.
    ProviderScope(
      key: UniqueKey(),
      overrides: [costOfOwnershipProvider.overrideWith((ref) => load())],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: CostOfOwnershipSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows headlines, bars and rows for one currency', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => CostOfOwnership(byCurrency: [_usd()], leftOutCount: 0),
    );

    expect(find.text('Cost of ownership'), findsOneWidget);
    expect(find.text(formatMoney(11960, 'USD')), findsOneWidget);
    expect(find.text('Spent in total'), findsOneWidget);
    expect(find.byType(CategoryBarChart), findsOneWidget);
    expect(find.text('Apex Reg Set'), findsOneWidget);
    final money = formatMoney(1565 / 340, 'USD');
    expect(find.text('$money / dive'), findsOneWidget);
    expect(
      find.text('${formatMoney(1565, 'USD')} over 340 dives'),
      findsOneWidget,
    );
  });

  testWidgets('the currency picker appears only with two currencies', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => CostOfOwnership(byCurrency: [_usd()], leftOutCount: 0),
    );
    expect(find.byKey(const ValueKey('cost-currency')), findsNothing);

    await _pump(
      tester,
      () async => CostOfOwnership(byCurrency: [_usd(), _eur], leftOutCount: 0),
    );
    expect(find.byKey(const ValueKey('cost-currency')), findsOneWidget);
  });

  testWidgets('switching currency swaps totals, bars and rows', (tester) async {
    await _pump(
      tester,
      () async => CostOfOwnership(byCurrency: [_usd(), _eur], leftOutCount: 0),
    );

    await tester.tap(find.byKey(const ValueKey('cost-currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR').last);
    await tester.pumpAndSettle();

    expect(find.text(formatMoney(1180, 'EUR')), findsOneWidget);
    expect(find.text(formatMoney(11960, 'USD')), findsNothing);
    expect(find.text('Apex Reg Set'), findsNothing);
  });

  testWidgets('per hour row reads the hourly value and hours subtitle', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => CostOfOwnership(byCurrency: [_usd()], leftOutCount: 0),
    );

    await tester.tap(find.byKey(const ValueKey('cost-metric')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per hour').last);
    await tester.pumpAndSettle();

    expect(
      find.text('${formatMoney(1565 / 412, 'USD')} / hour'),
      findsOneWidget,
    );
    expect(
      find.text('${formatMoney(1565, 'USD')} over 412 hours'),
      findsOneWidget,
    );
  });

  testWidgets('a short usage never reads over 0 hours', (tester) async {
    await _pump(
      tester,
      () async => CostOfOwnership(
        byCurrency: [
          _usd(rows: [_row('Mask', 100, dives: 1, hours: 0.3)]),
        ],
        leftOutCount: 0,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('cost-metric')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per hour').last);
    await tester.pumpAndSettle();

    expect(find.text('${formatMoney(100, 'USD')} over 1 hour'), findsOneWidget);
  });

  testWidgets('a row with no dives reads no dives yet, with its cost', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => CostOfOwnership(
        byCurrency: [
          _usd(rows: [_row('Dry suit', 1770)]),
        ],
        leftOutCount: 0,
      ),
    );

    expect(find.text('no dives yet'), findsOneWidget);
    expect(find.text(formatMoney(1770, 'USD')), findsOneWidget);
  });

  testWidgets('show all expands past ten and show less collapses', (
    tester,
  ) async {
    final rows = [for (var i = 0; i < 12; i++) _row('item $i', 100 - i * 1.0)];
    await _pump(
      tester,
      () async =>
          CostOfOwnership(byCurrency: [_usd(rows: rows)], leftOutCount: 0),
    );

    expect(find.text('item 11'), findsNothing);
    await tester.ensureVisible(find.text('Show all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('item 11'), findsOneWidget);
    await tester.ensureVisible(find.text('Show less'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('item 11'), findsNothing);
  });

  testWidgets('no show all control at ten rows', (tester) async {
    final rows = [for (var i = 0; i < 10; i++) _row('item $i', 100)];
    await _pump(
      tester,
      () async =>
          CostOfOwnership(byCurrency: [_usd(rows: rows)], leftOutCount: 0),
    );
    expect(find.text('Show all'), findsNothing);
  });

  testWidgets('shows the undated and left out notes only when above zero', (
    tester,
  ) async {
    await _pump(
      tester,
      () async =>
          CostOfOwnership(byCurrency: [_usd(undated: 2)], leftOutCount: 3),
    );
    expect(find.text('2 purchases have no date'), findsOneWidget);
    expect(find.text('3 items have no cost recorded'), findsOneWidget);

    await _pump(
      tester,
      () async => CostOfOwnership(byCurrency: [_usd()], leftOutCount: 0),
    );
    expect(find.textContaining('no date'), findsNothing);
    expect(find.textContaining('no cost recorded'), findsNothing);
  });

  testWidgets('a crowded chart survives a year with one digit', (tester) async {
    await _pump(
      tester,
      () async => CostOfOwnership(
        byCurrency: [
          _usd(
            byYear: [
              for (var year = 5; year < 45; year++) (year: year, amount: 100.0),
            ],
          ),
        ],
        leftOutCount: 0,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(CategoryBarChart), findsOneWidget);
  });

  testWidgets('leaves out the bars when no spending has a date', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => CostOfOwnership(
        byCurrency: [_usd(byYear: const [])],
        leftOutCount: 0,
      ),
    );
    expect(find.byType(CategoryBarChart), findsNothing);
  });

  testWidgets('no costs at all shows the empty text', (tester) async {
    await _pump(
      tester,
      () async => const CostOfOwnership(byCurrency: [], leftOutCount: 4),
    );
    expect(
      find.text('No purchase prices or service costs recorded yet'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load shows the error, not the empty text', (
    tester,
  ) async {
    await _pump(tester, () async => throw StateError('no db'));
    expect(find.text('Could not load gear costs'), findsOneWidget);
    expect(
      find.text('No purchase prices or service costs recorded yet'),
      findsNothing,
    );
  });
}
