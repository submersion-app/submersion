import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/mini_dive_profile_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/set_media_time_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1090: the viewer's bottom overlay used to print the raw elapsed
/// offset (`+1879:28`, `+-5554653:32`) for a capture time far outside the
/// dive, with the mini profile dot pinned to the exit. These tests pin the
/// three states the overlay now distinguishes: positioned automatically,
/// positioned by the diver, and not positioned at all.
class _UnavailableResolver implements MediaSourceResolver {
  _UnavailableResolver(this.sourceType);
  @override
  final MediaSourceType sourceType;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

MediaItem _item({MediaEnrichment? enrichment}) => MediaItem(
  id: 'm1',
  diveId: 'd1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2016, 1, 6, 0, 3),
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
  enrichment: enrichment,
);

MediaEnrichment _enrichment(
  int elapsedSeconds, {
  MatchConfidence confidence = MatchConfidence.exact,
}) => MediaEnrichment(
  id: 'e-m1',
  mediaId: 'm1',
  diveId: 'd1',
  elapsedSeconds: elapsedSeconds,
  depthMeters: 15.0,
  matchConfidence: confidence,
  createdAt: DateTime.utc(2026, 7, 1),
);

final _dive = domain.Dive(
  id: 'd1',
  dateTime: DateTime.utc(2026, 7, 1, 9, 30),
  profile: const [
    domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
    domain.DiveProfilePoint(timestamp: 60, depth: 10.0),
    domain.DiveProfilePoint(timestamp: 120, depth: 20.0),
    domain.DiveProfilePoint(timestamp: 180, depth: 15.0),
    domain.DiveProfilePoint(timestamp: 240, depth: 5.0),
  ],
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, MediaItem item) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery: _UnavailableResolver(
                  MediaSourceType.platformGallery,
                ),
              }),
            ),
            diveProvider('d1').overrideWith((ref) async => _dive),
            mediaByIdProvider('m1').overrideWith((ref) async => item),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(mediaList: [item], initialMediaId: 'm1'),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  }

  testWidgets('an automatic position inside the dive shows the elapsed chip, '
      'depth and mini profile', (tester) async {
    await pump(tester, _item(enrichment: _enrichment(180)));

    expect(find.text('+3:00'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byType(MiniDiveProfileOverlay), findsOneWidget);
  });

  testWidgets('a surface shot just before the dive reads as a negative offset, '
      'not +-', (tester) async {
    await pump(
      tester,
      _item(
        enrichment: _enrichment(-90, confidence: MatchConfidence.estimated),
      ),
    );

    expect(find.text('-1:30'), findsOneWidget);
    expect(find.textContaining('+-'), findsNothing);
  });

  testWidgets('a position days outside the dive shows unknown instead of a '
      'raw offset', (tester) async {
    await pump(
      tester,
      _item(
        enrichment: _enrichment(
          1879 * 60,
          confidence: MatchConfidence.estimated,
        ),
      ),
    );

    expect(find.text('Time in dive unknown'), findsOneWidget);
    expect(find.textContaining('+1879'), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(find.byType(MiniDiveProfileOverlay), findsNothing);
    expect(find.text('Estimated'), findsNothing);
  });

  testWidgets('a manual position shows the pin and no confidence warning', (
    tester,
  ) async {
    await pump(
      tester,
      _item(enrichment: _enrichment(180, confidence: MatchConfidence.manual)),
    );

    expect(find.text('+3:00'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.text('Manual'), findsNothing);
    expect(find.byType(MiniDiveProfileOverlay), findsOneWidget);
  });

  testWidgets('tapping the elapsed chip opens the Set time dialog', (
    tester,
  ) async {
    await pump(tester, _item(enrichment: _enrichment(180)));

    await tester.tap(find.text('+3:00'));
    await tester.pumpAndSettle();

    expect(find.byType(SetMediaTimeDialog), findsOneWidget);
  });

  testWidgets('tapping the unknown chip opens the Set time dialog', (
    tester,
  ) async {
    await pump(
      tester,
      _item(
        enrichment: _enrichment(
          1879 * 60,
          confidence: MatchConfidence.estimated,
        ),
      ),
    );

    await tester.tap(find.text('Time in dive unknown'));
    await tester.pumpAndSettle();

    expect(find.byType(SetMediaTimeDialog), findsOneWidget);
  });
}
