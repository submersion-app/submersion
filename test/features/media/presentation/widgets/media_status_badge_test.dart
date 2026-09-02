import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_panel.dart';
import 'package:submersion/features/media/presentation/widgets/media_status_badge.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

MediaItem _item({
  MediaSourceType sourceType = MediaSourceType.platformGallery,
  bool missing = false,
  bool uploaded = false,
}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: sourceType,
  platformAssetId: 'asset-1',
  originalFilename: 'reef.jpg',
  isOrphaned: missing,
  lastVerifiedAt: DateTime.utc(2026),
  remoteUploadedAt: uploaded ? DateTime.utc(2026, 7) : null,
  takenAt: DateTime(2026, 3, 12),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

/// Pins the toggle without SharedPreferences, so these tests drive the
/// setting directly rather than through the provider fallback.
class _StubBadgeToggle extends MediaProvenanceBadgesNotifier {
  _StubBadgeToggle(super.enabled) : super.unstored();
}

void main() {
  late String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  /// Tap counter as a mutable list: a returned int would snapshot the value
  /// at pump time and could never observe a later tap, which is exactly how
  /// the propagation assertion below was silently vacuous.
  Future<List<int>> pump(
    WidgetTester tester,
    MediaItem item, {
    bool attached = true,
    QueueFacts? queue,
    bool provenanceBadges = true,
    MediaServingRecorder? recorder,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tileTaps = [0];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaStoreAttachedProvider.overrideWith((ref) async => attached),
          mediaQueueFactsProvider.overrideWith(
            (ref, id) => Stream.value(queue),
          ),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            recorder ?? MediaServingRecorder(),
          ),
          mediaProvenanceBadgesProvider.overrideWith(
            (ref) => _StubBadgeToggle(provenanceBadges),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            // opaque so the stand-in tile is tappable across its whole
            // area, the way a real grid tile is: with the default
            // deferToChild it would only hit-test where the small badge is,
            // which made the non-propagation counter unobservable.
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tileTaps[0]++,
              child: Center(child: MediaStatusBadge(item: item)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tileTaps;
  }

  testWidgets('a healthy item reports where it is served from', (tester) async {
    // The reversal of the original quiet-on-success design. Rendering nothing
    // here made a working badge layer indistinguishable from a broken one on
    // a library where every item is healthy.
    await pump(tester, _item(uploaded: true));

    expect(find.byKey(const Key('media-status-badge')), findsNothing);
    expect(find.byKey(const Key('media-provenance-badge')), findsOneWidget);
    // No observation recorded, so it falls back to what the row type implies.
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });

  testWidgets('health outranks provenance', (tester) async {
    await pump(tester, _item(missing: true));

    expect(find.byKey(const Key('media-status-badge')), findsOneWidget);
    expect(find.byKey(const Key('media-provenance-badge')), findsNothing);
  });

  testWidgets('the provenance badge can be switched off', (tester) async {
    await pump(tester, _item(uploaded: true), provenanceBadges: false);

    expect(find.byKey(const Key('media-provenance-badge')), findsNothing);
  });

  testWidgets('switching provenance off still shows a problem', (tester) async {
    // The setting silences decoration, never a state the diver may need to
    // act on. A broken photo must not be able to look healthy.
    await pump(tester, _item(missing: true), provenanceBadges: false);

    expect(find.byKey(const Key('media-status-badge')), findsOneWidget);
  });

  testWidgets('an observed source outranks the row type', (tester) async {
    // A gallery row served from the cloud store is exactly the case the
    // observation exists to reveal.
    final recorder = MediaServingRecorder();
    recorder.record(
      'm1',
      thumbnail: true,
      servedFrom: ServedFrom.storeNetwork,
      servedTier: ServedTier.thumbnail,
    );

    await pump(tester, _item(uploaded: true), recorder: recorder);

    expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
  });

  testWidgets('a grid tile reads the thumbnail observation, not the original', (
    tester,
  ) async {
    // The viewer records the same row under thumbnail: false. Reading that
    // one would leave every grid badge stuck on its fallback.
    final recorder = MediaServingRecorder();
    recorder.record(
      'm1',
      thumbnail: false,
      servedFrom: ServedFrom.storeNetwork,
      servedTier: ServedTier.original,
    );

    await pump(tester, _item(uploaded: true), recorder: recorder);

    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });

  testWidgets('an observation arriving later updates the badge', (
    tester,
  ) async {
    // The subscription is hand-rolled rather than a ListenableBuilder, so the
    // live-update path needs its own guard: a badge that never notices its
    // observation would sit on the fallback forever and quietly lie.
    final recorder = MediaServingRecorder();
    await pump(tester, _item(uploaded: true), recorder: recorder);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);

    recorder.record(
      'm1',
      thumbnail: true,
      servedFrom: ServedFrom.storeCache,
      servedTier: ServedTier.thumbnail,
    );
    await tester.pump();

    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
  });

  testWidgets('another item resolving does not change this badge', (
    tester,
  ) async {
    // The recorder notifies globally, so every visible badge hears every
    // resolution. Only its own answer may move it.
    final recorder = MediaServingRecorder();
    await pump(tester, _item(uploaded: true), recorder: recorder);

    recorder.record(
      'some-other-item',
      thumbnail: true,
      servedFrom: ServedFrom.storeNetwork,
      servedTier: ServedTier.thumbnail,
    );
    await tester.pump();

    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cloud_outlined), findsNothing);
  });

  testWidgets('a missing item renders the broken glyph', (tester) async {
    await pump(tester, _item(missing: true));

    expect(find.byKey(const Key('media-status-badge')), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('an unbacked item renders the cloud-off glyph', (tester) async {
    await pump(tester, _item());

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('a missing but backed-up item renders the cloud glyph', (
    tester,
  ) async {
    await pump(tester, _item(missing: true, uploaded: true));

    expect(find.byIcon(Icons.cloud), findsOneWidget);
  });

  testWidgets('an in-flight transfer renders the upload glyph', (tester) async {
    await pump(tester, _item(), queue: const QueueFacts(state: 'transferring'));

    expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  });

  testWidgets('an ineligible source stays silent', (tester) async {
    await pump(tester, _item(sourceType: MediaSourceType.networkUrl));

    expect(find.byKey(const Key('media-status-badge')), findsNothing);
  });

  testWidgets('the tooltip names the state', (tester) async {
    await pump(tester, _item(missing: true));

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'Missing and not backed up');
  });

  // The badge sits inside a tile whose own tap opens the viewer. Aiming at
  // the badge has to explain the badge, not navigate away from it.
  testWidgets('tapping the badge opens the info panel and not the tile', (
    tester,
  ) async {
    final tileTaps = await pump(tester, _item(missing: true));

    await tester.tap(find.byKey(const Key('media-status-badge')));
    await tester.pumpAndSettle();

    expect(find.byType(MediaInfoPanel), findsOneWidget);
    // The half this test is actually named for. Without it a regression that
    // let the tap propagate would still pass, because the panel would open
    // either way.
    expect(tileTaps[0], 0, reason: 'the tile tap must not also fire');
  });

  // Proves the counter above is actually wired. Without this, tileTaps could
  // be zero because nothing ever increments it, and the non-propagation
  // assertion would be vacuous no matter what the badge did.
  testWidgets('the surrounding tile tap counter does increment', (
    tester,
  ) async {
    final tileTaps = await pump(tester, _item(missing: true));

    // Away from the centred badge, so this lands on the tile itself.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(tileTaps[0], 1);
  });
}
