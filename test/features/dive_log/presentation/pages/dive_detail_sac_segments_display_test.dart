import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_table.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_time_columns.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The "Gas consumption by segment" card as the page wires it: phase rows from
/// their provider beside the time chart, the profile cursor reaching the
/// highlight, and the collapse toggle. The card's own behaviour is covered by
/// `sac_segments_view_test.dart`.
void main() {
  const backGas = DiveTank(
    id: 'back-gas',
    volume: 12.0,
    startPressure: 200.0,
    endPressure: 50.0,
    gasMix: GasMix(),
    role: TankRole.backGas,
  );

  /// Six points a minute apart, descending then ascending, so a tracking
  /// index resolves to a real timestamp inside the segments below.
  Dive diveWithProfile() {
    return createTestDiveWithBottomTime().copyWith(
      profile: List.generate(
        6,
        (i) => DiveProfilePoint(
          timestamp: i * 60,
          depth: (i < 3 ? i * 8.0 : (5 - i) * 8.0),
        ),
      ),
      tanks: const [backGas],
    );
  }

  SacSegment segment({
    required int startTimestamp,
    required int endTimestamp,
    required double avgDepth,
    required double sacRate,
    DivePhase? phase,
    SacSegmentationType? segmentationType,
  }) {
    return SacSegment(
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      avgDepth: avgDepth,
      minDepth: 0.0,
      maxDepth: 24.0,
      sacRate: sacRate,
      gasConsumed: 4.0,
      phase: phase,
      segmentationType: segmentationType,
    );
  }

  /// Descent / bottom / ascent, one per minute band, in the shape
  /// `phaseSegmentsProvider` produces.
  List<SacSegment> phaseSegments() => [
    segment(
      startTimestamp: 0,
      endTimestamp: 120,
      avgDepth: 8.0,
      sacRate: 0.9,
      phase: DivePhase.descent,
      segmentationType: SacSegmentationType.depthPhase,
    ),
    segment(
      startTimestamp: 120,
      endTimestamp: 240,
      avgDepth: 24.0,
      sacRate: 0.8,
      phase: DivePhase.bottom,
      segmentationType: SacSegmentationType.depthPhase,
    ),
    segment(
      startTimestamp: 240,
      endTimestamp: 300,
      avgDepth: 8.0,
      sacRate: 0.6,
      phase: DivePhase.ascent,
      segmentationType: SacSegmentationType.depthPhase,
    ),
  ];

  /// The card's own render gate reads the analysis, so it must carry
  /// segments even when the phase provider supplies the displayed ones.
  ProfileAnalysis analysisWithSegments() {
    return ProfileAnalysis.empty().copyWith(
      sacSegments: [
        segment(
          startTimestamp: 0,
          endTimestamp: 300,
          avgDepth: 18.0,
          sacRate: 0.8,
          segmentationType: SacSegmentationType.timeInterval,
        ),
      ],
    );
  }

  Future<void> pumpWith(
    WidgetTester tester, {
    required Dive dive,
    bool hasPhases = true,
    int? trackingIndex,
  }) async {
    final base = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.sac),
      ),
    );
    // The narrow test surface overflows this card's row; that is not what
    // these tests are about.
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          profileAnalysisProvider(
            dive.id,
          ).overrideWith((ref) async => analysisWithSegments()),
          phaseSegmentsProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => hasPhases ? phaseSegments() : null),
          if (trackingIndex != null)
            profileTrackingIndexProvider(
              dive.id,
            ).overrideWith((ref) => trackingIndex),
          gasSwitchesProvider(
            dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(
            dive.id,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          sourceProfilesProvider(
            dive.id,
          ).overrideWith((ref) async => <String, SourceProfile>{}),
          weeklyOtuProvider(dive.id).overrideWith((ref) async => 0.0),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveDetailPage(diveId: dive.id, embedded: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Finder sacCard(WidgetTester tester) {
    final l10n = AppLocalizations.of(
      tester.element(find.byType(DiveDetailPage)),
    );
    final card = find.widgetWithText(
      CollapsibleCardSection,
      l10n.diveLog_detail_section_sacRateBySegment,
    );
    expect(card, findsOneWidget);
    return card;
  }

  /// Whether [phase]'s row is drawn selected.
  bool rowIsHighlighted(WidgetTester tester, Finder card, DivePhase phase) {
    final label = tester.widget<Text>(
      find.descendant(of: card, matching: find.text(phase.displayName)),
    );
    return label.style?.fontWeight == FontWeight.bold;
  }

  group('phase breakdown', () {
    testWidgets('labels each row with its phase beside the time chart', (
      tester,
    ) async {
      await pumpWith(tester, dive: diveWithProfile());

      final card = sacCard(tester);
      expect(
        find.descendant(of: card, matching: find.byType(SacTimeColumns)),
        findsOneWidget,
      );
      for (final (phase, icon) in [
        (DivePhase.descent, Icons.south),
        (DivePhase.bottom, Icons.horizontal_rule),
        (DivePhase.ascent, Icons.north),
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(phase.displayName)),
          findsOneWidget,
          reason: '${phase.name} row should be labelled',
        );
        expect(
          find.descendant(of: card, matching: find.byIcon(icon)),
          findsOneWidget,
          reason: '${phase.name} row should carry its icon',
        );
      }
    });

    testWidgets('names the unit once, for the lane in view', (tester) async {
      await pumpWith(tester, dive: diveWithProfile());

      expect(
        find.descendant(of: sacCard(tester), matching: find.text('bar/min')),
        findsOneWidget,
      );
    });

    testWidgets('leaves the phase table out until its segments load', (
      tester,
    ) async {
      await pumpWith(tester, dive: diveWithProfile(), hasPhases: false);

      final card = sacCard(tester);
      expect(
        find.descendant(of: card, matching: find.byType(SacTimeColumns)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(SacSegmentTable)),
        findsNothing,
      );
    });
  });

  group('selected-point highlight', () {
    testWidgets('highlights the phase row holding the selected point', (
      tester,
    ) async {
      // Point 3 sits at t=180s, inside the bottom segment (120-240).
      await pumpWith(tester, dive: diveWithProfile(), trackingIndex: 3);

      final card = sacCard(tester);
      expect(rowIsHighlighted(tester, card, DivePhase.bottom), isTrue);
      expect(rowIsHighlighted(tester, card, DivePhase.descent), isFalse);
      expect(rowIsHighlighted(tester, card, DivePhase.ascent), isFalse);
    });

    testWidgets('no selected point leaves every row unhighlighted', (
      tester,
    ) async {
      await pumpWith(tester, dive: diveWithProfile());

      final card = sacCard(tester);
      for (final phase in [
        DivePhase.descent,
        DivePhase.bottom,
        DivePhase.ascent,
      ]) {
        expect(
          rowIsHighlighted(tester, card, phase),
          isFalse,
          reason: '${phase.name} row should not be highlighted',
        );
      }
    });
  });

  group('collapse toggle', () {
    testWidgets('collapsing the card writes the choice back to the provider', (
      tester,
    ) async {
      final dive = diveWithProfile();
      await pumpWith(tester, dive: dive);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      );
      expect(container.read(sacSegmentsSectionExpandedProvider), isTrue);

      // The card sits below the fold on the 800x600 test surface, so the
      // header has to be scrolled to before it can take a tap.
      final header = find
          .descendant(of: sacCard(tester), matching: find.byType(InkWell))
          .first;
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      await tester.tap(header);
      await tester.pumpAndSettle();

      expect(container.read(sacSegmentsSectionExpandedProvider), isFalse);
      expect(
        find.descendant(
          of: sacCard(tester),
          matching: find.textContaining(RegExp(r'^Average \d')),
        ),
        findsOneWidget,
        reason: 'the collapsed card still gives the dive average',
      );
    });
  });
}
