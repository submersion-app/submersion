import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

class _SeededLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededLibraryNotifier(super.state);

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ViewModeSettingsRepo extends AppSettingsRepository {
  _ViewModeSettingsRepo(this.mode);

  final MediaLibraryViewMode mode;

  @override
  Future<String?> getRawSetting(String key) async =>
      key == 'media_library_view_mode' ? mode.name : null;

  @override
  Future<void> setRawSetting(String key, String value) async {}
}

MediaLibraryEntry _entry(String id, {String? diveId, DateTime? takenAt}) {
  final at = takenAt ?? DateTime.utc(2026, 3, 12, 10);
  return MediaLibraryEntry(
    item: MediaItem(
      id: id,
      diveId: diveId,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      platformAssetId: 'asset-$id',
      takenAt: at,
      createdAt: at,
      updatedAt: at,
    ),
    siteName: diveId == null ? null : 'Site $diveId',
  );
}

class _OpenCall {
  _OpenCall(this.ids, this.initialId);

  final List<String> ids;
  final String initialId;
}

/// Pumps the library in [mode] on [entries] (in the page's sorted order) and
/// returns the list the viewer opener receives.
Future<List<_OpenCall>> _pumpView(
  WidgetTester tester,
  MediaLibraryViewMode mode,
  List<MediaLibraryEntry> entries,
) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final calls = <_OpenCall>[];
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        mediaLibraryNotifierProvider.overrideWith(
          (ref) => _SeededLibraryNotifier(MediaLibraryState(entries: entries)),
        ),
        appSettingsRepositoryProvider.overrideWithValue(
          _ViewModeSettingsRepo(mode),
        ),
        sitesProvider.overrideWith((ref) async => const []),
        allTripsProvider.overrideWith((ref) async => const []),
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
        mediaStoreIdentityProvider.overrideWith((ref) async => null),
        currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
        mediaServingRecorderProvider.overrideWithValue(MediaServingRecorder()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaLibraryView(
            openViewer: (context, items, initialMediaId) => calls.add(
              _OpenCall([for (final i in items) i.id], initialMediaId),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return calls;
}

/// Taps the tile for [id] through its own callback, so the test does not
/// depend on where thumbnail decoding leaves the hit area.
void _tapTile(WidgetTester tester, String id) {
  final tile = tester.widget<MediaLibraryTile>(
    find.byWidgetPredicate(
      (w) => w is MediaLibraryTile && w.entry.item.id == id,
    ),
  );
  tile.onTap();
}

/// The tiles' ids in the order the gallery lays them out.
List<String> _shownOrder(WidgetTester tester) => [
  for (final tile in tester.widgetList<MediaLibraryTile>(
    find.byType(MediaLibraryTile),
  ))
    tile.entry.item.id,
];

void main() {
  // Issue #4146: the grouped modes regroup the sorted page, and the viewer's
  // Next must step through what the gallery shows, not the page order.
  testWidgets('by dive, the viewer pages in the grouped order shown', (
    tester,
  ) async {
    // Sorted by time, two dives' photos interleave with an unlinked one.
    final calls = await _pumpView(tester, MediaLibraryViewMode.byDive, [
      _entry('a', diveId: 'd1'),
      _entry('u'),
      _entry('b', diveId: 'd2'),
      _entry('c', diveId: 'd1'),
    ]);

    expect(_shownOrder(tester), ['a', 'c', 'b', 'u']);

    _tapTile(tester, 'a');

    expect(calls, hasLength(1));
    expect(calls.single.ids, ['a', 'c', 'b', 'u']);
    expect(calls.single.initialId, 'a');
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('timeline, the viewer pages in the day order shown', (
    tester,
  ) async {
    // A sort that is not by date leaves days interleaved in the page.
    final day1 = DateTime.utc(2026, 3, 12, 10);
    final day2 = DateTime.utc(2026, 3, 13, 10);
    final calls = await _pumpView(tester, MediaLibraryViewMode.timeline, [
      _entry('a', takenAt: day1),
      _entry('b', takenAt: day2),
      _entry('c', takenAt: day1),
    ]);

    expect(_shownOrder(tester), ['a', 'c', 'b']);

    _tapTile(tester, 'c');

    expect(calls.single.ids, ['a', 'c', 'b']);
    expect(calls.single.initialId, 'c');
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('the flat grid keeps the page order', (tester) async {
    final calls = await _pumpView(tester, MediaLibraryViewMode.grid, [
      _entry('a', diveId: 'd1'),
      _entry('u'),
      _entry('b', diveId: 'd2'),
      _entry('c', diveId: 'd1'),
    ]);

    _tapTile(tester, 'b');

    expect(calls.single.ids, ['a', 'u', 'b', 'c']);
    expect(calls.single.initialId, 'b');
    await tester.pump(const Duration(milliseconds: 400));
  });
}
