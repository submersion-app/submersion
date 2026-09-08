import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Attribution on a dive whose sources are consecutive halves (#1451).
///
/// `usesPerSourceRendering` is false for those, so every profile surface
/// draws the merged `dive.profile` rather than one source's bucket. The
/// chart gates each per-computer layer on `activeComputerId`: a computer
/// draws when it matches, when it is overlaid, or when nothing is active at
/// all. Naming one half's computer there therefore hid the OTHER half's tank
/// pressures and events, while its depth samples stayed on the chart, because
/// a Combine renders no source bar to overlay the other half from.
void main() {
  final now = DateTime(2026, 5, 7);

  // Two computers that never overlap: the first logs 0-180s, the second
  // picks up at 240s. This is the shape sourceProfilesAreSequential detects.
  const firstHalf = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 60, depth: 18.0),
    DiveProfilePoint(timestamp: 120, depth: 20.0),
    DiveProfilePoint(timestamp: 180, depth: 5.0),
  ];
  const secondHalf = [
    DiveProfilePoint(timestamp: 240, depth: 6.0),
    DiveProfilePoint(timestamp: 300, depth: 22.0),
    DiveProfilePoint(timestamp: 360, depth: 0.0),
  ];
  const merged = [...firstHalf, ...secondHalf];

  DiveDataSource sourceOf(
    String id,
    String computerId, {
    required bool primary,
  }) => DiveDataSource(
    id: id,
    diveId: 'test-dive-1',
    computerId: computerId,
    isPrimary: primary,
    computerName: computerId,
    importedAt: now,
    createdAt: now,
  );

  Future<DiveProfileChart> pumpHost(
    WidgetTester tester, {
    required List<DiveDataSource> sources,
    required Map<String, SourceProfile> profiles,
    required List<DiveProfilePoint> diveProfile,
  }) async {
    final dive = createTestDiveWithBottomTime().copyWith(profile: diveProfile);
    final base = await getBaseOverrides();

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
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: DiveProfileChartHost(dive: dive),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    return tester.widget<DiveProfileChart>(find.byType(DiveProfileChart));
  }

  testWidgets('a Combine credits the merged series to no single computer', (
    tester,
  ) async {
    final chart = await pumpHost(
      tester,
      sources: [
        sourceOf('src-a', 'dc-a', primary: true),
        sourceOf('src-b', 'dc-b', primary: false),
      ],
      profiles: {
        'src-a': const SourceProfile(
          sourceId: 'src-a',
          computerId: 'dc-a',
          isEdited: false,
          points: firstHalf,
        ),
        'src-b': const SourceProfile(
          sourceId: 'src-b',
          computerId: 'dc-b',
          isEdited: false,
          points: secondHalf,
        ),
      },
      diveProfile: merged,
    );

    // Guards the premise: both halves are on screen.
    expect(chart.profile, merged);
    // So neither half's computer may gate the per-computer layers.
    expect(chart.activeComputerId, isNull);
  });

  // The counterweight: a single source's union IS that source, so it still
  // owns the series and keeps its attribution. Without this, "return null
  // whenever no per-source bucket is drawn" would look equally correct.
  testWidgets('a single-source dive still credits its own computer', (
    tester,
  ) async {
    final chart = await pumpHost(
      tester,
      sources: [sourceOf('src-a', 'dc-a', primary: true)],
      profiles: {
        'src-a': const SourceProfile(
          sourceId: 'src-a',
          computerId: 'dc-a',
          isEdited: false,
          points: firstHalf,
        ),
      },
      diveProfile: firstHalf,
    );

    expect(chart.activeComputerId, 'dc-a');
  });
}
