import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_tooltip.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/media/presentation/widgets/media_hover_region.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A 46-minute dive sampled every 10 s (index i is at i * 10 seconds), long
/// enough that the page scrolls the profile card away.
final _profile = [
  for (var t = 0; t <= 46 * 60; t += 10)
    DiveProfilePoint(
      timestamp: t,
      depth: t < 150 ? t / 150 * 30 : (t > 2640 ? 0 : 27),
    ),
];

final _dive = createTestDiveWithBottomTime(
  id: 'dive-a',
).copyWith(profile: _profile);

/// A photo taken 20 minutes into the dive.
MediaItem _photo() {
  final now = DateTime.utc(2026, 1, 1);
  return MediaItem(
    id: 'm1',
    diveId: _dive.id,
    originalFilename: 'm1.jpg',
    mediaType: MediaType.photo,
    takenAt: now,
    createdAt: now,
    updatedAt: now,
    enrichment: MediaEnrichment(
      id: 'e1',
      mediaId: 'm1',
      diveId: _dive.id,
      elapsedSeconds: 1200,
      depthMeters: 27,
      matchConfidence: MatchConfidence.exact,
      createdAt: now,
    ),
  );
}

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides();
    final original = FlutterError.onError;
    addTearDown(() => FlutterError.onError = original);
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      original?.call(d);
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(_dive.id).overrideWith((ref) async => _dive),
          diveDataSourcesProvider(
            _dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          sourceProfilesProvider(
            _dive.id,
          ).overrideWith((ref) async => <String, SourceProfile>{}),
          gasSwitchesProvider(
            _dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(
            _dive.id,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          sourceProfileAnalysisProvider((
            diveId: _dive.id,
            sourceId: null,
          )).overrideWith(
            (ref) async => ProfileAnalysisService().analyze(
              diveId: _dive.id,
              depths: [for (final p in _profile) p.depth],
              timestamps: [for (final p in _profile) p.timestamp],
            ),
          ),
          mediaForDiveProvider(_dive.id).overrideWith((ref) => [_photo()]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveDetailPage(diveId: _dive.id, embedded: true),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  // Issue #4524, end to end: the media section sits below the profile card,
  // so by the time a thumbnail is under the pointer only the pinned strip is
  // left to show where in the dive it was taken.
  testWidgets('hovering a media thumbnail puts the pinned strip\'s cursor and '
      'tooltip on its moment, and leaving clears them', (tester) async {
    await pumpPage(tester);
    final thumbnail = find.descendant(
      of: find.byType(DiveMediaSection),
      matching: find.byType(MediaHoverRegion),
    );
    await tester.scrollUntilVisible(
      thumbnail,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(PinnedProfileStrip), findsOneWidget);
    expect(find.byType(PinnedStripTooltip), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveMediaSection)),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(890, 890));
    addTearDown(mouse.removePointer);

    await mouse.moveTo(tester.getCenter(thumbnail));
    await tester.pump();
    await tester.pump();

    // 1200 s on a 10 s series.
    expect(container.read(profileTrackingIndexProvider(_dive.id)), 120);
    expect(find.byType(PinnedStripTooltip), findsOneWidget);

    await mouse.moveTo(const Offset(890, 890));
    await tester.pump();
    await tester.pump();

    expect(container.read(profileTrackingIndexProvider(_dive.id)), isNull);
    expect(find.byType(PinnedStripTooltip), findsNothing);
  });
}
