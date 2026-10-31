import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_deco_status_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Regression cover for #543 (selected-point lookups).
///
/// The chart's selected index refers to the ACTIVE source's series, but the
/// deco card's "at time" subtitle resolved it against `dive.profile`, the
/// merged union of every source's samples. On a consolidated dive the union
/// holds both computers' samples at each second, so the same index landed on
/// an earlier time than the point under the cursor.
void main() {
  final now = DateTime(2026, 7, 13);

  // The active (primary) computer samples once a minute.
  const pointsA = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 60, depth: 10.0),
    DiveProfilePoint(timestamp: 120, depth: 20.0),
    DiveProfilePoint(timestamp: 180, depth: 20.0),
    DiveProfilePoint(timestamp: 240, depth: 10.0),
    DiveProfilePoint(timestamp: 300, depth: 0.0),
  ];
  // The consolidated secondary sampled the same seconds; getDiveById returns
  // both interleaved, so merged[4] is at 120 s while pointsA[4] is at 240 s.
  const mergedProfile = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 60, depth: 10.0),
    DiveProfilePoint(timestamp: 60, depth: 11.0),
    DiveProfilePoint(timestamp: 120, depth: 20.0),
    DiveProfilePoint(timestamp: 120, depth: 21.0),
    DiveProfilePoint(timestamp: 180, depth: 20.0),
    DiveProfilePoint(timestamp: 180, depth: 21.0),
    DiveProfilePoint(timestamp: 240, depth: 10.0),
    DiveProfilePoint(timestamp: 240, depth: 11.0),
    DiveProfilePoint(timestamp: 300, depth: 0.0),
    DiveProfilePoint(timestamp: 300, depth: 0.0),
  ];

  DiveDataSource source({
    required String id,
    required String computerId,
    required bool isPrimary,
  }) {
    return DiveDataSource(
      id: id,
      diveId: 'test-dive-1',
      computerId: computerId,
      isPrimary: isPrimary,
      computerName: computerId,
      importedAt: now,
      createdAt: now,
    );
  }

  // One fully populated DecoStatus so the deco card renders (it hides on an
  // empty decoStatuses list).
  ProfileAnalysis analysisWithDeco() {
    final compartments = List.generate(
      zhl16CompartmentCount,
      (i) => TissueCompartment(
        compartmentNumber: i + 1,
        halfTimeN2: zhl16cN2HalfTimes[i],
        halfTimeHe: zhl16cHeHalfTimes[i],
        mValueAN2: zhl16cN2A[i],
        mValueBN2: zhl16cN2B[i],
        mValueAHe: zhl16cHeA[i],
        mValueBHe: zhl16cHeB[i],
        currentPN2: inspiredSurfaceN2Bar,
        currentPHe: 0.0,
      ),
    );
    final status = DecoStatus(
      compartments: compartments,
      ndlSeconds: 999 * 60,
      ceilingMeters: 0,
      ttsSeconds: 0,
      gfLow: 0.3,
      gfHigh: 0.7,
      decoStops: const [],
      currentDepthMeters: 0,
      ambientPressureBar: 1.0,
    );
    return ProfileAnalysis.empty().copyWith(
      decoStatuses: List.filled(pointsA.length, status),
      ppO2Curve: List.filled(pointsA.length, 0.21),
    );
  }

  final dive = createTestDiveWithBottomTime().copyWith(profile: mergedProfile);

  /// The page on a consolidated dive. The primary source has an analysis to
  /// show and src-b, a source with no profile analysis, has none.
  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
    final sources = [
      source(id: 'src-a', computerId: 'dc-a', isPrimary: true),
      source(id: 'src-b', computerId: 'dc-b', isPrimary: false),
    ];
    final profiles = {
      'src-a': const SourceProfile(
        sourceId: 'src-a',
        computerId: 'dc-a',
        isEdited: false,
        points: pointsA,
      ),
      'src-b': const SourceProfile(
        sourceId: 'src-b',
        computerId: 'dc-b',
        isEdited: false,
        points: mergedProfile,
      ),
    };
    final base = await getBaseOverrides();
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
          diveDataSourcesProvider(dive.id).overrideWith((ref) async => sources),
          sourceProfilesProvider(dive.id).overrideWith((ref) async => profiles),
          gasSwitchesProvider(
            dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(
            dive.id,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => analysisWithDeco()),
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: 'src-b',
          )).overrideWith((ref) async => null),
          weeklyOtuProvider(dive.id).overrideWith((ref) async => 0.0),
          // The chart reported index 4 of the series it draws (pointsA).
          profileTrackingIndexProvider(dive.id).overrideWith((ref) => 4),
          computersForDiveProvider(dive.id).overrideWith(
            (ref) async => [
              DiveComputer(
                id: 'dc-a',
                name: 'dc-a',
                createdAt: now,
                updatedAt: now,
              ),
              DiveComputer(
                id: 'dc-b',
                name: 'dc-b',
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveDetailPage(diveId: dive.id, embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    );
  }

  testWidgets(
    'the deco card "at time" follows the active source, not the merged profile',
    (tester) async {
      await pumpPage(tester);

      final card = tester.widget<CompactDecoStatusCard>(
        find.byType(CompactDecoStatusCard),
      );
      // pointsA[4] is 240 s. mergedProfile[4] would have read 120 s.
      expect(card.subtitle, '4:00');
    },
  );

  testWidgets('a source with no analysis shows none, not the last source\'s', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    expect(find.byType(CompactDecoStatusCard), findsOneWidget);

    container.read(activeDiveSourceProvider(dive.id).notifier).state = 'src-b';
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The kept analysis is for riding out a blip in one source's read. On
    // another source it would pass one computer's deco off as this one's.
    expect(find.byType(CompactDecoStatusCard), findsNothing);
  });
}
