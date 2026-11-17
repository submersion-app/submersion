import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_deco_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_gas_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sac_segments_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_weight_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_card_editor.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import '../widgets/buoyancy_outcome_fixture.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The worked out cards beside and around Cylinders and Weight during a
/// sitting: they draw the dive as stored until Save, while the half of a
/// pair that can be edited draws the sitting (issue #4527, plan 5).
void main() {
  final l = AppLocalizationsEn();
  const back = DiveTank(
    id: 'a',
    volume: 12,
    startPressure: 200,
    endPressure: 60,
  );
  const belt = DiveWeight(
    id: 'w',
    diveId: 'dive-1',
    weightType: WeightType.belt,
    amountKg: 6,
  );
  // A short profile, so the deco, tissue and SAC segments cards have
  // something to work out.
  final logged = dive.copyWith(
    tanks: const [back],
    weights: const [belt],
    runtime: const Duration(minutes: 5),
    profile: List.generate(
      6,
      (i) => DiveProfilePoint(
        timestamp: i * 60,
        depth: i < 3 ? i * 8.0 : (5 - i) * 8.0,
      ),
    ),
  );
  // One SAC segment, so Gas consumption by segment has a row and pairs.
  final analysis = ProfileAnalysis.empty().copyWith(
    sacSegments: const [
      SacSegment(
        startTimestamp: 0,
        endTimestamp: 300,
        avgDepth: 18.0,
        minDepth: 0.0,
        maxDepth: 24.0,
        sacRate: 0.8,
        gasConsumed: 4.0,
        segmentationType: SacSegmentationType.timeInterval,
      ),
    ],
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  /// The page at desktop width with [visible] shown, every worked out
  /// card answered without a database read.
  Future<FakeSave> open(
    WidgetTester tester,
    Set<DiveDetailSectionId> visible,
  ) async {
    final page = await pumpPage(
      tester,
      stored: logged,
      visible: visible,
      // As the list pane shows it: a full page this wide gives way to it.
      embedded: true,
      size: const Size(1200, 3000),
      extra: <Override>[
        profileAnalysisProvider(dive.id).overrideWith((ref) async => analysis),
        gasSwitchesProvider(
          dive.id,
        ).overrideWith((ref) async => <GasSwitchWithTank>[]),
        sourceProfilesProvider(
          dive.id,
        ).overrideWith((ref) async => <String, SourceProfile>{}),
        tankPressuresProvider(
          dive.id,
        ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
        buoyancyTwinProvider(
          dive.id,
        ).overrideWith((ref) async => buoyancyOutcome()),
      ],
    );
    await settle(tester);
    return page.save;
  }

  RecordEditController<Dive> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Dive>(
        tester.element(find.byType(RecordCardFrame<Dive>).first),
      )!;

  Finder frameOf(String id) => find.byWidgetPredicate(
    (w) => w is RecordCardFrame<Dive> && w.card.id == id,
  );

  /// The dive each card of [type] was handed.
  List<Dive> divesOf<T extends Widget>(
    WidgetTester tester,
    Dive Function(T) dive,
  ) => [for (final w in tester.widgetList<T>(find.byType(T))) dive(w)];

  testWidgets('a gauge mode picked in the sitting leaves deco, tissue and '
      'SAC segments until Save', (tester) async {
    final save = await open(tester, const {
      DiveDetailSectionId.tanks,
      DiveDetailSectionId.decoStatus,
      DiveDetailSectionId.tissueLoading,
      DiveDetailSectionId.sacSegments,
    });
    List<DiveMode> modesShown() => [
      ...divesOf<DiveDecoStatusSection>(tester, (w) => w.dive),
      ...divesOf<DiveTissueLoadingSection>(tester, (w) => w.dive),
      ...divesOf<DiveSacSegmentsSection>(tester, (w) => w.dive),
    ].map((d) => d.diveMode).toList();
    expect(find.byType(DiveDecoStatusSection), findsWidgets);
    expect(find.byType(DiveTissueLoadingSection), findsWidgets);
    expect(find.byType(DiveSacSegmentsSection), findsWidgets);

    await unlock(tester);
    await tester.tap(find.byTooltip('Edit Cylinders'));
    await settle(tester);
    await tester.tap(find.text('GAUGE'));
    await settle(tester);
    expect(controllerOf(tester).session!.working.isGauge, isTrue);

    // Still there, still worked out from the dive as stored.
    expect(find.byType(DiveDecoStatusSection), findsWidgets);
    expect(find.byType(DiveTissueLoadingSection), findsWidgets);
    expect(find.byType(DiveSacSegmentsSection), findsWidgets);
    expect(modesShown(), allOf(isNotEmpty, everyElement(DiveMode.oc)));

    // Done keeps them too: only Save takes them away.
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.byType(DiveDecoStatusSection), findsWidgets);
    expect(find.byType(DiveSacSegmentsSection), findsWidgets);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(save.calls.single.merged.diveMode, DiveMode.gauge);
    expect(find.byType(DiveDecoStatusSection), findsNothing);
    expect(find.byType(DiveTissueLoadingSection), findsNothing);
    expect(find.byType(DiveSacSegmentsSection), findsNothing);
  });

  testWidgets('the Tanks half of its pair opens in place beside SAC '
      'segments, which keeps the stored dive', (tester) async {
    await open(tester, const {
      DiveDetailSectionId.tanks,
      DiveDetailSectionId.sacSegments,
    });
    final pair = find.byKey(const ValueKey('diveSectionPair_tanks'));
    final sac = find.byType(DiveSacSegmentsSection);
    expect(pair, findsOneWidget);
    await unlock(tester);
    final before = tester.getRect(frameOf('tanks'));
    expect(tester.getRect(sac).left, greaterThan(before.right - 1));

    await tester.tap(find.byTooltip('Edit Cylinders'));
    await settle(tester);

    expect(
      find.descendant(of: pair, matching: find.byType(DiveTanksCardEditor)),
      findsOneWidget,
    );
    final after = tester.getRect(frameOf('tanks'));
    expect(after.topLeft, before.topLeft);
    expect(after.width, before.width);
    expect(tester.getRect(sac).left, greaterThan(after.right - 1));

    // A second cylinder, then Done: the Cylinders half draws it, the
    // SAC segments half the dive as stored.
    final s = controllerOf(tester).session!;
    setTanks(s, [
      ...s.working.tanks,
      const DiveTank(id: 'b', volume: 7, order: 1),
    ], replaced: true);
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(pair, findsOneWidget);
    expect(
      divesOf<DiveDetailCylindersSection>(
        tester,
        (w) => w.dive,
      ).map((d) => d.tanks.length),
      allOf(isNotEmpty, everyElement(2)),
    );
    expect(
      divesOf<DiveSacSegmentsSection>(
        tester,
        (w) => w.dive,
      ).map((d) => d.tanks.length),
      allOf(isNotEmpty, everyElement(1)),
    );
  });

  testWidgets('a weight added shows on the Weights half after Done; '
      'Buoyancy keeps the stored dive', (tester) async {
    await open(tester, const {
      DiveDetailSectionId.weights,
      DiveDetailSectionId.buoyancy,
    });
    final pair = find.byKey(const ValueKey('diveSectionPair_weights'));
    expect(pair, findsOneWidget);
    await unlock(tester);
    final before = tester.getRect(frameOf('weights'));

    await tester.tap(find.byTooltip('Edit Weight'));
    await settle(tester);
    expect(
      find.descendant(of: pair, matching: find.byType(DiveWeightsCardEditor)),
      findsOneWidget,
    );
    expect(tester.getRect(frameOf('weights')).topLeft, before.topLeft);
    await tester.tap(find.text(l.diveLog_edit_addWeightEntry));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(pair, findsOneWidget);
    expect(
      divesOf<DiveWeightSection>(
        tester,
        (w) => w.dive,
      ).map((d) => d.weights.length),
      allOf(isNotEmpty, everyElement(2)),
    );
    expect(
      divesOf<DiveDetailBuoyancySection>(
        tester,
        (w) => w.dive,
      ).map((d) => d.weights.length),
      allOf(isNotEmpty, everyElement(1)),
    );
  });
}
