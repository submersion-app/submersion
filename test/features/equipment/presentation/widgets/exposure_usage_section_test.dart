import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_usage_history.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/equipment_usage_builder.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/exposure_card.dart';
import 'package:submersion/features/insights/presentation/widgets/category_bar_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The exposure card's recency tiles and usage chart (issue #5074).
final _today = DateTime.utc(2026, 11, 27);

EquipmentExposureSample _s(DateTime date, {int minutes = 60}) =>
    EquipmentExposureSample(date: date, durationSeconds: minutes * 60);

EquipmentUsageHistory _usage(List<EquipmentExposureSample> samples) =>
    buildUsageHistory(
      samples: samples,
      classifier: const ExposureClassifier(),
      today: _today,
    );

EquipmentExposureTotals _totals(
  List<EquipmentExposureSample> samples, {
  Map<ExposureUnit, double> extra = const {},
}) => EquipmentExposureTotals(
  byUnit: {
    ExposureUnit.dives: samples.length.toDouble(),
    ExposureUnit.hours: samples.fold(0.0, (a, s) => a + s.durationHours),
    ...extra,
  },
  diveCount: samples.length,
  firstDive: samples.map((s) => s.date).reduce((a, b) => a.isBefore(b) ? a : b),
  lastDive: samples.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b),
);

Future<void> _pump(
  WidgetTester tester,
  EquipmentExposureTotals totals,
  EquipmentUsageHistory usage, {
  double width = 800,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        equipmentExposureTotalsProvider(
          'reg',
        ).overrideWith((ref) async => totals),
        equipmentUsageHistoryProvider('reg').overrideWith((ref) async => usage),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: ExposureCard(equipmentId: 'reg')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<({String label, int count})> _bars(WidgetTester tester) =>
    tester.widget<CategoryBarChart>(find.byType(CategoryBarChart)).data;

void main() {
  late String? savedLocale;
  setUp(() {
    savedLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedLocale);

  // Five months idle: the last dives were in June 2026.
  final idleSince = [
    for (var d = 1; d <= 18; d++) _s(DateTime.utc(2026, 1 + d % 6, d)),
    _s(DateTime.utc(2019, 4, 2)),
  ];

  testWidgets('headline tiles show last dived, dives and hours', (
    tester,
  ) async {
    await _pump(
      tester,
      _totals(idleSince, extra: {ExposureUnit.coldDives: 12}),
      _usage(idleSince),
    );

    expect(find.text('Last dived'), findsOneWidget);
    expect(find.text('5 months ago'), findsOneWidget);
    expect(find.text('Dives'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('Hours'), findsOneWidget);
    expect(find.text('19.0'), findsOneWidget);
    expect(find.text('19 dives'), findsNothing);
    expect(find.text('12 cold dives'), findsOneWidget);
  });

  testWidgets('the last dived tile names the date for a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _totals(idleSince), _usage(idleSince));

    expect(
      find.bySemanticsLabel(RegExp(r'Last dived 5 months ago, on Jun 17')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('12-month view draws twelve bars and the caption', (
    tester,
  ) async {
    await _pump(tester, _totals(idleSince), _usage(idleSince));

    final bars = _bars(tester);
    expect(bars, hasLength(12));
    expect(bars.last.label, 'Nov');
    expect(bars.fold(0, (a, b) => a + b.count), 18);
    expect(find.text('18 dives in the last 12 months'), findsOneWidget);
  });

  testWidgets('switching to all years draws one bar per year', (tester) async {
    await _pump(tester, _totals(idleSince), _usage(idleSince));

    await tester.tap(find.text('All years'));
    await tester.pumpAndSettle();

    final bars = _bars(tester);
    expect(bars, hasLength(8));
    expect(bars.first.label, '2019');
    expect(bars.last, (label: '2026', count: 18));
    expect(find.textContaining('in the last 12 months'), findsNothing);
  });

  testWidgets('a bar tooltip gives its period, dives and hours', (
    tester,
  ) async {
    await _pump(tester, _totals(idleSince), _usage(idleSince));

    final chart = tester.widget<CategoryBarChart>(
      find.byType(CategoryBarChart),
    );
    // June 2026 is the seventh of the twelve months (Dec 2025 first).
    expect(chart.tooltipText!(6), 'Jun 2026\n3 dives, 3.0 hours');
  });

  testWidgets('idle item shows twelve empty months and the idle caption', (
    tester,
  ) async {
    final old = [_s(DateTime.utc(2023, 5, 1)), _s(DateTime.utc(2024, 6, 1))];
    await _pump(tester, _totals(old), _usage(old));

    final bars = _bars(tester);
    expect(bars, hasLength(12));
    expect(bars.every((b) => b.count == 0), isTrue);
    expect(find.text('No dives in the last 12 months'), findsOneWidget);
    expect(find.text('2 years ago'), findsOneWidget);
  });

  testWidgets('large totals fit the tiles', (tester) async {
    final usage = _usage([_s(DateTime.utc(2026, 11, 20))]);
    await _pump(
      tester,
      EquipmentExposureTotals(
        byUnit: const {ExposureUnit.dives: 15000, ExposureUnit.hours: 12345.6},
        diveCount: 15000,
        firstDive: DateTime.utc(2001, 1, 1),
        lastDive: DateTime.utc(2026, 11, 20),
      ),
      usage,
      width: 360,
    );

    expect(find.text('15,000'), findsOneWidget);
    expect(find.text('12345.6'), findsOneWidget);
    expect(find.text('7 days ago'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dive today reads as Today', (tester) async {
    final today = [_s(DateTime.utc(2026, 11, 27, 8))];
    await _pump(tester, _totals(today), _usage(today));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('1 dive in the last 12 months'), findsOneWidget);
  });
}
