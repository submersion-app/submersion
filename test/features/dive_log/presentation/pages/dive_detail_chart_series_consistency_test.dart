import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Regression cover for #1167.
///
/// On a multi-source dive the chart draws the ACTIVE source's points, but the
/// markers and the playback/range extent were computed from `dive.profile` --
/// the merged series across every source. The two disagree whenever the
/// sources differ in depth or duration, so the "Max Depth" flag could report a
/// depth the drawn curve never reaches and the range slider could run past the
/// end of the visible series.
void main() {
  final now = DateTime(2026, 5, 7);

  // Two computers on one dive, sampling the same seconds. dc-a (primary, and
  // therefore the active source by default) reads 20 m; dc-b reads 30 m and
  // keeps logging for two minutes after dc-a stops.
  const pointsA = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 60, depth: 10.0),
    DiveProfilePoint(timestamp: 120, depth: 20.0),
    DiveProfilePoint(timestamp: 180, depth: 0.0),
  ];
  const pointsB = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 60, depth: 15.0),
    DiveProfilePoint(timestamp: 120, depth: 30.0),
    DiveProfilePoint(timestamp: 180, depth: 0.0),
    DiveProfilePoint(timestamp: 240, depth: 0.0),
    DiveProfilePoint(timestamp: 300, depth: 0.0),
  ];

  // What getDiveById returns: every source's samples, ordered by timestamp.
  // dc-b's sample sorts first at each shared second, which is what made the
  // marker's exact-timestamp lookup return the wrong computer's depth.
  const mergedProfile = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 60, depth: 15.0),
    DiveProfilePoint(timestamp: 60, depth: 10.0),
    DiveProfilePoint(timestamp: 120, depth: 30.0),
    DiveProfilePoint(timestamp: 120, depth: 20.0),
    DiveProfilePoint(timestamp: 180, depth: 0.0),
    DiveProfilePoint(timestamp: 180, depth: 0.0),
    DiveProfilePoint(timestamp: 240, depth: 0.0),
    DiveProfilePoint(timestamp: 300, depth: 0.0),
  ];

  ProfileAnalysis analysisOf(List<DiveProfilePoint> points) =>
      ProfileAnalysisService().analyze(
        diveId: 'test-dive-1',
        depths: [for (final p in points) p.depth],
        timestamps: [for (final p in points) p.timestamp],
      );

  late Dive dive;
  late List<DiveDataSource> sources;
  late Map<String, SourceProfile> profiles;

  setUp(() {
    dive = createTestDiveWithBottomTime().copyWith(profile: mergedProfile);
    sources = [
      DiveDataSource(
        id: 'src-a',
        diveId: dive.id,
        computerId: 'dc-a',
        isPrimary: true,
        computerName: 'Shallow Teric',
        maxDepth: 20.0,
        duration: 180,
        importedAt: now,
        createdAt: now,
      ),
      DiveDataSource(
        id: 'src-b',
        diveId: dive.id,
        computerId: 'dc-b',
        isPrimary: false,
        computerName: 'Deep Teric',
        maxDepth: 30.0,
        duration: 300,
        importedAt: now,
        createdAt: now,
      ),
    ];
    profiles = {
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
        points: pointsB,
      ),
    };
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final base = await getBaseOverrides();
    final originalOnError = FlutterError.onError;
    // The explicit restore below runs on the happy path so assertions see the
    // real handler. This tearDown is the safety net: if pumpWidget throws, the
    // suppressing handler would otherwise leak into every later test here.
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
          // The page asks for the ACTIVE source's analysis, so this is
          // computed from dc-a's points: maxDepth 20 m at t=120.
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => analysisOf(pointsA)),
          computersForDiveProvider(dive.id).overrideWith(
            (ref) async => [
              DiveComputer(
                id: 'dc-a',
                name: 'Shallow Teric',
                createdAt: now,
                updatedAt: now,
              ),
              DiveComputer(
                id: 'dc-b',
                name: 'Deep Teric',
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
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = originalOnError;
  }

  DiveProfileChart chartOf(WidgetTester tester) =>
      tester.widget<DiveProfileChart>(find.byType(DiveProfileChart));

  testWidgets('the chart draws the active source, not the merged series', (
    tester,
  ) async {
    await pumpPage(tester);

    // Guards the premise of the tests below.
    expect(chartOf(tester).profile, pointsA);
  });

  testWidgets('the max depth marker sits on the drawn series', (tester) async {
    await pumpPage(tester);

    final markers = chartOf(tester).markers ?? const <ProfileMarker>[];
    final maxDepth = markers
        .where((m) => m.type == ProfileMarkerType.maxDepth)
        .toList();

    expect(
      maxDepth,
      isNotEmpty,
      reason: 'showMaxDepthMarker defaults to true, so a marker is expected',
    );
    // dc-b reached 30 m at the same second; the active source only reached 20.
    expect(
      maxDepth.single.depth,
      20.0,
      reason: 'marker must come from the drawn source, not the merged profile',
    );
  });

  testWidgets('every marker lands on a point of the drawn series', (
    tester,
  ) async {
    await pumpPage(tester);

    final chart = chartOf(tester);
    final drawn = {for (final p in chart.profile) (p.timestamp, p.depth)};

    for (final marker in chart.markers ?? const <ProfileMarker>[]) {
      expect(
        drawn.contains((marker.timestamp, marker.depth)),
        isTrue,
        reason:
            'marker ${marker.type} at t=${marker.timestamp} d=${marker.depth} '
            'is not a point on the drawn series',
      );
    }
  });

  testWidgets('the range extent stops at the end of the drawn series', (
    tester,
  ) async {
    await pumpPage(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveProfileChart)),
    );
    final rangeMax = container
        .read(rangeSelectionProvider(dive.id))
        .maxTimestamp;

    // The merged series runs to 300s because dc-b kept logging; the drawn
    // source ends at 180s.
    expect(rangeMax, 180);
  });
}
