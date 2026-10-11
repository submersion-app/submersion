import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_factors_table.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

NumericFactor numeric(
  FocusFactorId id,
  double? g,
  double? b, {
  bool standsOut = false,
}) => NumericFactor(
  id: id,
  groupCovered: g == null ? 0 : 10,
  groupSize: 10,
  groupMean: g,
  baselineMean: b,
  standsOut: standsOut,
  strength: standsOut ? 1 : 0,
);

CategoricalFactor category(
  FocusFactorId id,
  List<(String, double, double)> top, {
  bool standsOut = false,
}) => CategoricalFactor(
  id: id,
  groupCovered: top.isEmpty ? 0 : 10,
  groupSize: 10,
  top: [
    for (final (k, g, b) in top)
      CategoryShare(
        key: k,
        groupShare: g,
        baselineShare: b,
        groupCount: (g * 10).round(),
        standsOut: standsOut,
        strength: g - b,
      ),
  ],
);

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(
    WidgetTester tester,
    FocusFactorReport report, {
    AppSettings settings = const AppSettings(),
    double width = 800,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FocusFactorsTable(report: report, metric: FocusMetric.rmv),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final report = FocusFactorReport(
    tooFewDives: false,
    factors: [
      numeric(FocusFactorId.maxDepth, 24.2, 21.6),
      numeric(FocusFactorId.avgDepth, 11.3, 13.4, standsOut: true),
      numeric(FocusFactorId.duration, 50, 50),
      numeric(FocusFactorId.waterTemp, null, null),
      category(FocusFactorId.entryMethod, [
        ('boat', 1.0, 0.64),
      ], standsOut: true),
      category(FocusFactorId.current, [('light', 0.42, 0.40)]),
    ],
  );

  testWidgets('headers name the metric and the columns', (tester) async {
    await pump(tester, report);
    expect(find.text('Full comparison'), findsOneWidget);
    expect(
      find.text(
        'All dives means every dive in the current filter that has RMV',
      ),
      findsOneWidget,
    );
    expect(find.text('These dives'), findsOneWidget);
    expect(find.text('All dives'), findsOneWidget);
    expect(find.text('Difference'), findsOneWidget);
  });

  testWidgets('standouts sort first in their group with a marker', (
    tester,
  ) async {
    await pump(tester, report);
    final avg = tester.getTopLeft(find.text('Average depth'));
    final max = tester.getTopLeft(find.text('Max depth'));
    expect(avg.dy, lessThan(max.dy));
    expect(
      find.byKey(const ValueKey('focus-standout-marker-avgDepth')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('focus-standout-marker-maxDepth')),
      findsNothing,
    );
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('quiet rows fold behind Show more and expand on tap', (
    tester,
  ) async {
    await pump(tester, report);
    expect(find.text('Duration'), findsNothing);
    expect(find.text('Water temp'), findsNothing);
    expect(find.text('Current'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('focus-factors-show-more')));
    await tester.pump();
    expect(find.text('Show 3 more factors'), findsNothing);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Not recorded'), findsOneWidget);
  });

  testWidgets('a new report folds again', (tester) async {
    await pump(tester, report);
    await tester.tap(find.byKey(const ValueKey('focus-factors-show-more')));
    await tester.pump();
    await pump(
      tester,
      FocusFactorReport(
        tooFewDives: false,
        factors: report.factors.reversed.toList(),
      ),
    );
    expect(find.text('Duration'), findsNothing);
  });

  testWidgets('all quiet shows no headings, only the button', (tester) async {
    await pump(
      tester,
      FocusFactorReport(
        tooFewDives: false,
        factors: [
          numeric(FocusFactorId.duration, 50, 50),
          category(FocusFactorId.current, [('light', 0.42, 0.40)]),
        ],
      ),
    );
    expect(find.text('Dive shape'), findsNothing);
    expect(find.text('Conditions'), findsNothing);
    expect(find.text('Show 2 more factors'), findsOneWidget);
  });

  testWidgets('nothing quiet shows no button', (tester) async {
    await pump(
      tester,
      FocusFactorReport(
        tooFewDives: false,
        factors: [numeric(FocusFactorId.maxDepth, 24.2, 21.6)],
      ),
    );
    expect(find.byKey(const ValueKey('focus-factors-show-more')), findsNothing);
  });

  final tiny = FocusFactorReport(
    tooFewDives: false,
    factors: [numeric(FocusFactorId.maxDepth, 20.03, 20.0)],
  );

  testWidgets('a 3 cm gap folds in metres', (tester) async {
    await pump(tester, tiny);
    expect(find.text('Max depth'), findsNothing);
  });

  testWidgets('the same 3 cm gap shows in feet, where it rounds to 0.1', (
    tester,
  ) async {
    await pump(
      tester,
      tiny,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );
    expect(find.text('Max depth'), findsOneWidget);
    expect(find.text('+0.1ft'), findsOneWidget);
  });

  testWidgets('a phone width moves the difference under the group value', (
    tester,
  ) async {
    await pump(tester, report, width: 400);
    expect(find.text('Difference'), findsNothing);
    expect(find.textContaining('-2.1'), findsOneWidget);
  });

  testWidgets('too few dives renders nothing', (tester) async {
    await pump(tester, const FocusFactorReport(factors: [], tooFewDives: true));
    expect(find.text('Full comparison'), findsNothing);
  });
}
