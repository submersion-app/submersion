import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_standouts_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

NumericFactor numeric(
  FocusFactorId id,
  double g,
  double b, {
  double strength = 1,
}) => NumericFactor(
  id: id,
  groupCovered: 10,
  groupSize: 10,
  groupMean: g,
  baselineMean: b,
  standsOut: true,
  strength: strength,
);

CategoricalFactor category(
  FocusFactorId id,
  String key,
  double g,
  double b,
  int count, {
  double strength = 1,
  int groupSize = 10,
  int baselineCovered = 20,
  int baselineSize = 20,
}) => CategoricalFactor(
  id: id,
  groupCovered: groupSize,
  groupSize: groupSize,
  baselineCovered: baselineCovered,
  baselineSize: baselineSize,
  top: [
    CategoryShare(
      key: key,
      groupShare: g,
      baselineShare: b,
      groupCount: count,
      standsOut: true,
      strength: strength,
    ),
  ],
);

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(WidgetTester tester, FocusFactorReport report) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await getBaseOverrides(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FocusStandoutsCard(report: report)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('findings read as sentences, strongest first', (tester) async {
    await pump(
      tester,
      FocusFactorReport(
        tooFewDives: false,
        factors: [
          numeric(FocusFactorId.avgDepth, 11.3, 13.4, strength: 0.4),
          category(
            FocusFactorId.entryMethod,
            'boat',
            1.0,
            0.64,
            10,
            strength: 0.36,
          ),
          category(FocusFactorId.gas, 'nitrox', 0.8, 0.5, 8, strength: 0.3),
        ],
      ),
    );
    expect(find.text('What stands out'), findsOneWidget);
    expect(
      find.text('Average depth 2.1m shallower (11.3m vs 13.4m)'),
      findsOneWidget,
    );
    expect(
      find.text('All 10 were Boat (64% of all your dives)'),
      findsOneWidget,
    );
    expect(
      find.text('8 of 10 were Nitrox, against 50% of all your dives'),
      findsOneWidget,
    );
    final depth = tester.getTopLeft(find.textContaining('Average depth'));
    final boat = tester.getTopLeft(find.textContaining('All 10'));
    expect(depth.dy, lessThan(boat.dy));
  });

  testWidgets('a partly recorded baseline names its denominator', (
    tester,
  ) async {
    await pump(
      tester,
      FocusFactorReport(
        tooFewDives: false,
        factors: [
          category(
            FocusFactorId.entryMethod,
            'boat',
            1.0,
            0.6,
            3,
            groupSize: 3,
            baselineCovered: 5,
            baselineSize: 10,
          ),
          category(
            FocusFactorId.gas,
            'nitrox',
            0.8,
            0.5,
            8,
            strength: 0.3,
            baselineCovered: 8,
            baselineSize: 12,
          ),
        ],
      ),
    );
    expect(
      find.text(
        'All 3 were Boat (60% of the 5 of 10 dives with this recorded)',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '8 of 10 were Nitrox, against 50% of the 8 of 12 dives with this '
        'recorded',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('of all your dives'), findsNothing);
  });

  test('every locale keeps each number in the recorded sentences', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      const coverage = 'COVERAGE';
      final all = l10n.insights_focus_standouts_categoryAllRecorded(
        31,
        'BOAT',
        '60%',
        coverage,
      );
      final some = l10n.insights_focus_standouts_categorySomeRecorded(
        29,
        31,
        'BOAT',
        '60%',
        coverage,
      );
      for (final part in ['31', 'BOAT', '60%', coverage]) {
        expect(all, contains(part), reason: '$locale all: $part');
        expect(some, contains(part), reason: '$locale some: $part');
      }
      expect(some, contains('29'), reason: '$locale some: count');
    }
  });

  testWidgets('direction words follow the factor', (tester) async {
    await pump(
      tester,
      FocusFactorReport(
        tooFewDives: false,
        factors: [
          numeric(FocusFactorId.maxDepth, 30, 20),
          numeric(FocusFactorId.duration, 40, 50),
          numeric(FocusFactorId.waterTemp, 25, 20),
          numeric(FocusFactorId.tankVolume, 15, 12),
          numeric(FocusFactorId.weight, 5, 7),
        ],
      ),
    );
    expect(find.textContaining('deeper'), findsOneWidget);
    expect(find.textContaining('shorter'), findsOneWidget);
    expect(find.textContaining('warmer'), findsOneWidget);
    expect(find.textContaining('larger'), findsOneWidget);
    expect(find.textContaining('less lead'), findsOneWidget);
  });

  testWidgets('more than five findings adds a count line', (tester) async {
    await pump(
      tester,
      FocusFactorReport(
        tooFewDives: false,
        factors: [
          for (final id in [
            FocusFactorId.maxDepth,
            FocusFactorId.avgDepth,
            FocusFactorId.duration,
            FocusFactorId.waterTemp,
            FocusFactorId.tankVolume,
            FocusFactorId.weight,
          ])
            numeric(id, 2, 1),
          category(FocusFactorId.gas, 'air', 1, 0.5, 10),
        ],
      ),
    );
    expect(find.text('and 2 more in the full comparison'), findsOneWidget);
    expect(find.textContaining('('), findsNWidgets(5));
  });

  testWidgets('no standouts says so', (tester) async {
    await pump(
      tester,
      const FocusFactorReport(
        tooFewDives: false,
        factors: [
          NumericFactor(
            id: FocusFactorId.maxDepth,
            groupCovered: 3,
            groupSize: 3,
            groupMean: 1,
            baselineMean: 1,
            standsOut: false,
            strength: 0,
          ),
        ],
      ),
    );
    expect(find.text('Nothing stands out about these dives.'), findsOneWidget);
  });

  testWidgets('too few dives asks for more', (tester) async {
    await pump(tester, const FocusFactorReport(factors: [], tooFewDives: true));
    expect(
      find.text('Pick at least 3 dives to see what they share'),
      findsOneWidget,
    );
  });
}
