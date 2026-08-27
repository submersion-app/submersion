import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
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
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// The Media section's library query hydrates rows lean: it left-joins no
/// enrichment, because the grid never renders photo-time depth. The viewer,
/// however, gates the mini profile chart, the dive computer face and the
/// bottom depth/elapsed chips on exactly that enrichment. Opened from the
/// library, an item that shows all three under dive detail therefore showed
/// none of them.
///
/// These tests pin the viewer's own hydration: given a lean item with a dive
/// link, it resolves the full record and renders the same dive context that
/// dive detail does.
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

MediaItem _item(String id, {String? diveId, MediaEnrichment? enrichment}) =>
    MediaItem(
      id: id,
      diveId: diveId,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime.utc(2026, 7, 1, 10),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
      enrichment: enrichment,
    );

MediaEnrichment _enrichment(String mediaId) => MediaEnrichment(
  id: 'e-$mediaId',
  mediaId: mediaId,
  diveId: 'd1',
  elapsedSeconds: 180,
  depthMeters: 15.0,
  matchConfidence: MatchConfidence.exact,
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
    SharedPreferences.setMockInitialValues({'perdix_overlay_enabled': true});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester, {
    required List<MediaItem> mediaList,
    required String initialMediaId,
    // Riverpod 3 does not export its Override type, so the list cannot be
    // named; the spread below casts it back from context.
    List<dynamic> overrides = const [],
  }) async {
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
            ...overrides.cast(),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(
              mediaList: mediaList,
              initialMediaId: initialMediaId,
              showGoToDive: true,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  }

  testWidgets('a lean library item shows the mini dive profile chart', (
    tester,
  ) async {
    await pump(
      tester,
      mediaList: [_item('m1', diveId: 'd1')],
      initialMediaId: 'm1',
      overrides: [
        mediaByIdProvider('m1').overrideWith(
          (ref) async =>
              _item('m1', diveId: 'd1', enrichment: _enrichment('m1')),
        ),
      ],
    );

    expect(find.byType(MiniDiveProfileOverlay), findsOneWidget);
  });

  testWidgets('a lean library item shows the dive computer face', (
    tester,
  ) async {
    await pump(
      tester,
      mediaList: [_item('m1', diveId: 'd1')],
      initialMediaId: 'm1',
      overrides: [
        mediaByIdProvider('m1').overrideWith(
          (ref) async =>
              _item('m1', diveId: 'd1', enrichment: _enrichment('m1')),
        ),
      ],
    );

    expect(find.byType(PerdixFace), findsOneWidget);
  });

  testWidgets('a lean library item shows photo depth and elapsed time', (
    tester,
  ) async {
    await pump(
      tester,
      mediaList: [_item('m1', diveId: 'd1')],
      initialMediaId: 'm1',
      overrides: [
        mediaByIdProvider('m1').overrideWith(
          (ref) async =>
              _item('m1', diveId: 'd1', enrichment: _enrichment('m1')),
        ),
      ],
    );

    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
  });

  testWidgets('an item unlinked in both the snapshot and the database shows '
      'no dive context', (tester) async {
    await pump(
      tester,
      mediaList: [_item('m1')],
      initialMediaId: 'm1',
      overrides: [
        mediaByIdProvider('m1').overrideWith((ref) async => _item('m1')),
      ],
    );

    expect(find.byType(MiniDiveProfileOverlay), findsNothing);
    expect(find.byType(PerdixFace), findsNothing);
    expect(find.byIcon(Icons.scuba_diving), findsNothing);
  });

  // The list handed to the viewer is an immutable snapshot taken when the grid
  // pushed the route. Re-linking updates the media row, but a snapshot
  // captured before that still says diveId == null, and reading the dive link
  // off the snapshot meant a freshly re-linked photo opened with no
  // Go-to-dive action, no depth chips, no mini profile and no dive computer:
  // indistinguishable from an item that really is unlinked.
  testWidgets('a re-linked item whose snapshot still says unlinked takes its '
      'dive from the database', (tester) async {
    await pump(
      tester,
      mediaList: [_item('m1')],
      initialMediaId: 'm1',
      overrides: [
        mediaByIdProvider('m1').overrideWith(
          (ref) async =>
              _item('m1', diveId: 'd1', enrichment: _enrichment('m1')),
        ),
      ],
    );

    expect(find.byIcon(Icons.scuba_diving), findsOneWidget);
    expect(find.byType(MiniDiveProfileOverlay), findsOneWidget);
    expect(find.byType(PerdixFace), findsOneWidget);
  });

  // The snapshot already carrying an enrichment is not a reason to trust it.
  // It is still a route-time capture, so a re-link (or a backfill) since then
  // leaves it describing the wrong dive, and skipping the read would render
  // that stale context for as long as the viewer stayed open.
  testWidgets('an item that arrived already enriched still follows the '
      'database', (tester) async {
    await pump(
      tester,
      mediaList: [_item('m1', diveId: 'd-old', enrichment: _enrichment('m1'))],
      initialMediaId: 'm1',
      overrides: [
        mediaByIdProvider('m1').overrideWith(
          (ref) async =>
              _item('m1', diveId: 'd1', enrichment: _enrichment('m1')),
        ),
      ],
    );

    // d1 is the dive the database reports; only it has a profile here, so
    // the overlays render exactly when the stale d-old was NOT used.
    expect(find.byType(MiniDiveProfileOverlay), findsOneWidget);
    expect(find.byType(PerdixFace), findsOneWidget);
  });

  testWidgets('a re-linked item with no enrichment yet backfills the dive the '
      'database reports', (tester) async {
    final enrichedDives = <String>[];
    final enricher = DiveMediaEnricher(
      loadDive: (diveId) async {
        enrichedDives.add(diveId);
        return _dive;
      },
      loadMediaForDive: (diveId) async => const [],
      saveEnrichments: (enrichments) async {},
    );

    await pump(
      tester,
      mediaList: [_item('m1')],
      initialMediaId: 'm1',
      overrides: [
        mediaByIdProvider(
          'm1',
        ).overrideWith((ref) async => _item('m1', diveId: 'd1')),
        diveMediaEnricherProvider.overrideWithValue(enricher),
      ],
    );

    expect(enrichedDives, ['d1']);
  });

  testWidgets('an item whose enrichment row is missing backfills the dive '
      'once', (tester) async {
    final enrichedDives = <String>[];
    final enricher = DiveMediaEnricher(
      loadDive: (diveId) async {
        enrichedDives.add(diveId);
        return _dive;
      },
      loadMediaForDive: (diveId) async => const [],
      saveEnrichments: (enrichments) async {},
    );

    await pump(
      tester,
      mediaList: [
        _item('m1', diveId: 'd1'),
        _item('m2', diveId: 'd1'),
      ],
      initialMediaId: 'm1',
      overrides: [
        // The row exists but carries no enrichment: the backfill is the only
        // thing that can produce one.
        mediaByIdProvider(
          'm1',
        ).overrideWith((ref) async => _item('m1', diveId: 'd1')),
        mediaByIdProvider(
          'm2',
        ).overrideWith((ref) async => _item('m2', diveId: 'd1')),
        diveMediaEnricherProvider.overrideWithValue(enricher),
      ],
    );

    expect(enrichedDives, ['d1']);
  });
}
