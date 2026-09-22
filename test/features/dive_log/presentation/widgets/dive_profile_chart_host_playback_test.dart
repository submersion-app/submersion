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
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The inline chart host must not subscribe to playback state (#2231).
///
/// Playback only ever runs from [ProfileTransportControls], which exists
/// solely inside `FullscreenProfilePage`. That page is pushed onto the root
/// navigator, so the inline host is covered whenever the ticker is running:
/// a covered route is skipped for layout and paint, but its elements stay in
/// the tree and still rebuild on a provider change. Watching the 25ms ticker
/// therefore re-ran the host's whole build (a dozen provider reads plus the
/// gas-segment, photo-marker and chart-marker derivations) about 31 times a
/// second, to feed a cursor behind an opaque page.
void main() {
  final now = DateTime(2026, 5, 7);

  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 600, depth: 18.0),
    DiveProfilePoint(timestamp: 1200, depth: 20.0),
    DiveProfilePoint(timestamp: 1800, depth: 0.0),
  ];

  final source = DiveDataSource(
    id: 'src-a',
    diveId: 'test-dive-1',
    computerId: 'dc-a',
    isPrimary: true,
    computerName: 'dc-a',
    importedAt: now,
    createdAt: now,
  );

  /// Pumps the host until every async chart input has settled, so a later
  /// rebuild can only have come from the playback ticker.
  Future<(Dive, ProviderContainer)> pumpHost(WidgetTester tester) async {
    final dive = createTestDiveWithBottomTime().copyWith(profile: profile);
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => [source]),
          sourceProfilesProvider(dive.id).overrideWith(
            (ref) async => {
              'src-a': const SourceProfile(
                sourceId: 'src-a',
                computerId: 'dc-a',
                isEdited: false,
                points: profile,
              ),
            },
          ),
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
    await tester.pump(const Duration(seconds: 1));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveProfileChartHost)),
    );
    return (dive, container);
  }

  testWidgets('a playback tick does not rebuild the inline chart host', (
    tester,
  ) async {
    final (dive, container) = await pumpHost(tester);
    final notifier = container.read(playbackProvider(dive.id).notifier);

    // Guards the premise: the host has already pushed the drawn series'
    // extent into playback, so nothing below re-initializes and resets it.
    expect(
      container.read(playbackProvider(dive.id)).maxTimestamp,
      profile.last.timestamp,
    );

    // A rebuilt ConsumerWidget constructs a new child, so widget identity is
    // the rebuild probe.
    final before = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );

    // What the fullscreen transport does on entry, then press play.
    notifier.togglePlaybackMode();
    notifier.play();
    await tester.pump(const Duration(seconds: 1));

    // Guards the premise the other way: the ticker really did advance, so a
    // passing identity check means "did not rebuild", not "never ticked".
    expect(
      container.read(playbackProvider(dive.id)).currentTimestamp,
      greaterThan(0),
    );

    final after = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    expect(
      identical(before, after),
      isTrue,
      reason: 'the host rebuilt behind the fullscreen page on a playback tick',
    );

    // Cancel the 25ms periodic timer, or the binding reports it pending.
    notifier.pause();
  });

  testWidgets('the inline host draws no playback cursor while playback runs', (
    tester,
  ) async {
    final (dive, container) = await pumpHost(tester);
    final notifier = container.read(playbackProvider(dive.id).notifier);

    notifier.togglePlaybackMode();
    notifier.seekTo(600);
    await tester.pump();

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    // The cursor was never reachable here: the only surface that activates
    // playback covers this one. `DiveProfileChart.playbackTimestamp` stays a
    // supported input (see dive_profile_chart_test.dart) for whenever inline
    // playback returns; the host simply no longer feeds it.
    expect(chart.playbackTimestamp, isNull);
  });
}
