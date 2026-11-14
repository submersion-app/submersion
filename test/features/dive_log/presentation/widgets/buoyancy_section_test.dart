import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_balance_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_lead_block.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_safety_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/twin_summary_rows.dart';

import '../../../../helpers/mock_providers.dart';
import 'buoyancy_outcome_fixture.dart';

Future<void> _pump(WidgetTester tester, BuoyancyTwinOutcome? outcome) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        buoyancyTwinProvider('d1').overrideWith((ref) async => outcome),
      ],
      child: const MaterialApp(
        // Pinned so the asserted strings and decimal separators do not depend
        // on the host locale (repo convention).
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BuoyancySection(
              diveId: 'd1',
              units: UnitFormatter(AppSettings()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the verdict and expands the breakdown', (tester) async {
    await _pump(tester, buoyancyOutcome());
    // Verdict amount is rendered (1.8 kg buoyant).
    expect(find.textContaining('1.8'), findsWidgets);

    // Expand the breakdown and find the lead row.
    final expansion = find.byType(ExpansionTile);
    expect(expansion, findsOneWidget);
    await tester.ensureVisible(expansion);
    await tester.tap(expansion);
    await tester.pumpAndSettle();
    expect(find.textContaining('-6.0'), findsWidgets);
  });

  testWidgets('a measured body fat term says so, without the BMI source '
      '(issue #4525)', (tester) async {
    await _pump(
      tester,
      buoyancyOutcome(
        extraVerdictTerms: const [
          TwinStaticTerm(
            label: 'bodyFat',
            kg: 0.6,
            source: TermSource.bodyComposition,
          ),
        ],
      ),
    );
    final expansion = find.byType(ExpansionTile);
    await tester.ensureVisible(expansion);
    await tester.tap(expansion);
    await tester.pumpAndSettle();

    expect(find.text('Body fat (measured)'), findsOneWidget);
    expect(find.textContaining('estimated from BMI'), findsNothing);
  });

  testWidgets('an estimated body term keeps its BMI source', (tester) async {
    await _pump(
      tester,
      buoyancyOutcome(
        extraVerdictTerms: const [
          TwinStaticTerm(
            label: 'bmi',
            kg: 0.6,
            source: TermSource.bodyComposition,
          ),
        ],
      ),
    );
    final expansion = find.byType(ExpansionTile);
    await tester.ensureVisible(expansion);
    await tester.tap(expansion);
    await tester.pumpAndSettle();

    expect(find.text('Body composition'), findsOneWidget);
    expect(find.text('(estimated from BMI)'), findsOneWidget);
  });

  testWidgets('warns when droppable lead is below the minimum ditchable', (
    tester,
  ) async {
    await _pump(
      tester,
      buoyancyOutcome(minDitchableKg: 6.0, droppableLeadKg: 2.0),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
  });

  testWidgets('hints that no lead was recorded when lead is zero', (
    tester,
  ) async {
    // Lead lives either in the dive's Weights section or as a dry weight on
    // weights-type gear; zero means neither, and the net reads far too
    // buoyant (issue #1103).
    await _pump(tester, buoyancyOutcome(leadKg: 0.0, droppableLeadKg: 0.0));
    expect(find.textContaining('No lead recorded'), findsOneWidget);
  });

  testWidgets('with no lead recorded the ditchable row does not warn', (
    tester,
  ) async {
    await _pump(
      tester,
      buoyancyOutcome(leadKg: 0.0, droppableLeadKg: 0.0, minDitchableKg: 5.0),
    );
    expect(find.textContaining('No lead recorded'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.textContaining('you can ditch'), findsNothing);
  });

  testWidgets('no lead hint is absent once lead is known', (tester) async {
    await _pump(tester, buoyancyOutcome());
    expect(find.textContaining('No lead recorded'), findsNothing);
  });

  testWidgets('hints when a tank material had to be assumed', (tester) async {
    // #3686: an imported tank with no material and specs that match no
    // preset is modelled as aluminium; the card must say so.
    await _pump(
      tester,
      buoyancyOutcome(
        tanks: const [
          TwinTankInput(
            id: 't1',
            label: 'tank',
            volumeL: 12.0,
            workingPressureBar: 232.0,
          ),
        ],
      ),
    );
    expect(find.textContaining('Tank material not set'), findsOneWidget);
  });

  testWidgets('no tank material hint once every material is resolved', (
    tester,
  ) async {
    // 12 L / 200 bar resolves to Steel 12L even without a material.
    await _pump(
      tester,
      buoyancyOutcome(
        tanks: const [
          TwinTankInput(
            id: 't1',
            label: 'tank',
            volumeL: 12.0,
            workingPressureBar: 200.0,
          ),
        ],
      ),
    );
    expect(find.textContaining('Tank material not set'), findsNothing);
  });

  testWidgets('a narrow card fits its header row', (tester) async {
    // Half of a 700px paired row. The title, the Adjust button and the info
    // icon could not shrink, so the header overflowed; the title now gives
    // way instead.
    await tester.binding.setSurfaceSize(const Size(300, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, buoyancyOutcome());

    expect(tester.takeException(), isNull);
    expect(find.text('BUOYANCY'), findsOneWidget);
  });

  testWidgets('says how buoyant the diver was exactly once', (tester) async {
    await _pump(tester, buoyancyOutcome());
    expect(find.text('1.8 kg buoyant'), findsOneWidget);
    expect(find.textContaining('1.8 kg'), findsOneWidget);
    // The old sentence form of the verdict is gone.
    expect(find.textContaining('At your final stop'), findsNothing);
  });

  testWidgets('lays out readout, chart, balance, lead, then safety rows', (
    tester,
  ) async {
    await _pump(tester, buoyancyOutcome());
    double top(Finder f) => tester.getTopLeft(f).dy;
    final order = [
      top(find.text('1.8 kg buoyant')),
      top(find.byType(BuoyancyChart)),
      top(find.byType(BuoyancyBalanceBar)),
      top(find.byType(ExpansionTile)),
      top(find.byType(BuoyancyLeadBlock)),
      top(find.byType(BuoyancySafetyRows)),
    ];
    expect(order, [...order]..sort());
  });

  testWidgets('the start, end and swing tiles are gone', (tester) async {
    await _pump(tester, buoyancyOutcome());
    expect(find.text('Start of dive'), findsNothing);
    expect(find.text('End of dive'), findsNothing);
    expect(find.text('Buoyancy swing'), findsNothing);
    expect(find.byType(TwinSummaryRows), findsNothing);
  });

  testWidgets('the info sheet no longer explains buoyancy swing', (
    tester,
  ) async {
    await _pump(tester, buoyancyOutcome());
    await tester.ensureVisible(find.byType(InfoButton));
    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Peak lift needed'), findsWidgets);
    expect(find.textContaining('Buoyancy swing'), findsNothing);
  });

  testWidgets('a no-profile dive reads the convention in the diver units', (
    tester,
  ) async {
    await _pump(
      tester,
      buoyancyOutcome(
        samples: const [],
        anchor: const TwinAnchor(
          kind: TwinAnchorKind.convention,
          timestamp: -1,
          depthM: 5,
        ),
      ),
    );
    expect(
      find.text('estimated at the 5m safety-stop convention'),
      findsOneWidget,
    );
    expect(find.byType(BuoyancyChart), findsNothing);
  });

  for (final width in [300.0, 366.0]) {
    testWidgets('nothing overflows on a ${width.round()} px card', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        buoyancyOutcome(
          minDitchableKg: 6.0,
          droppableLeadKg: 2.0,
          wingLiftCapacityKg: 13.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders nothing when the outcome is null', (tester) async {
    await _pump(tester, null);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('header uses an info icon instead of the hover tooltip', (
    tester,
  ) async {
    await _pump(tester, buoyancyOutcome());

    expect(find.byType(InfoButton), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            w.message ==
                'Modeled net buoyancy through the dive from your profile, gas use, and gear.',
      ),
      findsNothing,
    );
    await tester.ensureVisible(find.byType(InfoButton));
    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Peak lift needed'), findsWidgets);
  });

  group('profile cursor sync (#4423)', () {
    // The chart profile: index i is at i * 30 seconds.
    final dive = createTestDiveWithBottomTime(id: 'd1').copyWith(
      profile: [
        for (var t = 0; t <= 600; t += 30)
          DiveProfilePoint(timestamp: t, depth: 10),
      ],
    );

    Future<ProviderContainer> pumpSynced(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            buoyancyTwinProvider(
              'd1',
            ).overrideWith((ref) async => buoyancyOutcome()),
            activeSourceProfileProvider('d1').overrideWith((ref) => null),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: BuoyancySection(
                  diveId: 'd1',
                  dive: dive,
                  units: const UnitFormatter(AppSettings()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(BuoyancySection)),
      );
    }

    testWidgets('the profile cursor moves the buoyancy marker', (tester) async {
      final c = await pumpSynced(tester);
      c.read(profileTrackingIndexProvider('d1').notifier).state = 4;
      await tester.pump();
      final chart = tester.widget<BuoyancyChart>(find.byType(BuoyancyChart));
      expect(chart.cursorSeconds, 120);
    });

    testWidgets('buoyancy hover writes the profile cursor index', (
      tester,
    ) async {
      final c = await pumpSynced(tester);
      tester.widget<BuoyancyChart>(find.byType(BuoyancyChart)).onCursorSeconds!(
        95,
      );
      expect(c.read(profileTrackingIndexProvider('d1')), 3);
      tester.widget<BuoyancyChart>(find.byType(BuoyancyChart)).onCursorSeconds!(
        null,
      );
      expect(c.read(profileTrackingIndexProvider('d1')), isNull);
    });

    testWidgets('without a dive the card keeps its own cursor', (tester) async {
      await _pump(tester, buoyancyOutcome());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BuoyancySection)),
      );
      tester.widget<BuoyancyChart>(find.byType(BuoyancyChart)).onCursorSeconds!(
        0,
      );
      await tester.pump();
      // The readout follows the touch, and the dive's cursor is untouched.
      expect(find.text('at 0m, 0:00'), findsOneWidget);
      expect(container.read(profileTrackingIndexProvider('d1')), isNull);
    });

    testWidgets('the profile cursor moves the readout and the balance', (
      tester,
    ) async {
      final c = await pumpSynced(tester);
      expect(find.text('at your final stop, about 5m'), findsOneWidget);
      // Index 0 is 0 s: the fixture's first sample, at the surface.
      c.read(profileTrackingIndexProvider('d1').notifier).state = 0;
      await tester.pump();
      expect(find.text('at 0m, 0:00'), findsOneWidget);
      expect(find.text('2.0 kg buoyant'), findsOneWidget);
    });
  });
}
