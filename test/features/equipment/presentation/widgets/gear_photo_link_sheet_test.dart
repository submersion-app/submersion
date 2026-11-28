import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_photo_link_sheet.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_library_grouping.dart';
import 'package:submersion/features/media/domain/entities/media_library_sort.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';

import '../../../media/presentation/support/media_widget_harness.dart';

/// Serves the Library as [pages], one per call.
class _Pages extends MediaLibraryRepository {
  _Pages(this.pages);

  final List<List<MediaItem>> pages;

  @override
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    SortState<MediaSortField> sort = kDefaultMediaSort,
    MediaLibraryGrouping grouping = MediaLibraryGrouping.none,
    MediaLibraryCursor? after,
    int limit = MediaLibraryRepository.pageSize,
  }) async {
    final index = after == null ? 0 : int.parse(after.id);
    return MediaLibraryPageResult(
      entries: [for (final i in pages[index]) MediaLibraryEntry(item: i)],
      nextCursor: index + 1 < pages.length
          ? MediaLibraryCursor(
              sortKey: 0,
              id: '${index + 1}',
              groupKeys: const [],
            )
          : null,
    );
  }
}

/// Serves the photos of each dive from [byDive], recording the dives asked.
class _DivePhotos extends MediaGearRepository {
  _DivePhotos(this.byDive);

  final Map<String, List<MediaItem>> byDive;
  final asked = <List<String>>[];

  @override
  Future<List<MediaLibraryEntry>> linkableEntriesOnDives(
    List<String> diveIds,
  ) async {
    asked.add(diveIds);
    return [
      for (final d in diveIds)
        for (final m in byDive[d] ?? const <MediaItem>[])
          MediaLibraryEntry(item: m, diveNumber: int.parse(d.substring(1))),
    ];
  }
}

/// Link photos on the gear page (issue #5046): a sheet of the item's dives'
/// photos or all photos, linked ones checked.
void main() {
  const drysuit = EquipmentItem(
    id: 'e1',
    name: 'Drysuit',
    type: EquipmentType.drysuit,
  );

  Future<List<MediaItem>?> open(
    WidgetTester tester, {
    List<String> diveIds = const ['d2', 'd1'],
    List<MediaItem> onDives = const [],
    _DivePhotos? divePhotos,
    List<List<MediaItem>>? libraryPages,
    List<MediaItem> library = const [],
    List<MediaItem> linked = const [],
    Object? diveIdsError,
    Future<void> Function()? act,
  }) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    List<MediaItem>? result;
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentDiveIdsProvider('e1').overrideWith(
            (ref) async => diveIdsError == null ? diveIds : throw diveIdsError,
          ),
          mediaGearRepositoryProvider.overrideWithValue(
            divePhotos ??
                _DivePhotos({
                  for (final m in onDives)
                    m.diveId!: [
                      for (final o in onDives)
                        if (o.diveId == m.diveId) o,
                    ],
                }),
          ),
          mediaLibraryRepositoryProvider.overrideWithValue(
            _Pages(libraryPages ?? [library]),
          ),
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showGearPhotoLinkSheet(
                context,
                item: drysuit,
                linked: linked,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act?.call();
    return result;
  }

  testWidgets('the sheet opens on Dives with this gear grouped by dive', (
    tester,
  ) async {
    await open(
      tester,
      onDives: [
        testMediaItem(id: 'a', diveId: 'd2', takenAt: DateTime(2026, 5, 2)),
        testMediaItem(id: 'b', diveId: 'd1', takenAt: DateTime(2026, 5, 1)),
      ],
    );
    expect(find.text('Link photos to Drysuit'), findsOneWidget);
    final segments = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(segments.selected, {false}, reason: 'false is Dives with this gear');
    expect(
      find.byKey(const ValueKey('gear_photo_link_group_d2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('gear_photo_link_group_d1')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('gear_photo_link_group_d2')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('gear_photo_link_group_d1')))
            .dy,
      ),
    );
  });

  testWidgets('the sheet opens on All photos for an item with no dives', (
    tester,
  ) async {
    await open(
      tester,
      diveIds: const [],
      library: [testMediaItem(id: 'x')],
    );
    final segments = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(segments.selected, {true});
    expect(
      find.byKey(const ValueKey('gear_photo_link_tile_x')),
      findsOneWidget,
    );
  });

  testWidgets('a failed read of the item\'s dives falls back to All photos', (
    tester,
  ) async {
    await open(
      tester,
      diveIdsError: StateError('database closed'),
      library: [testMediaItem(id: 'x')],
    );
    final segments = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(segments.selected, {true});
    expect(
      find.byKey(const ValueKey('gear_photo_link_tile_x')),
      findsOneWidget,
    );
  });

  testWidgets('photos on no dive are grouped by day', (tester) async {
    await open(
      tester,
      diveIds: const [],
      library: [
        testMediaItem(id: 'x', takenAt: DateTime.utc(2026, 4, 9, 12)),
        testMediaItem(id: 'y', takenAt: DateTime.utc(2026, 3, 3, 12)),
      ],
    );
    final headers = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'gear_photo_link_group_',
          ),
    );
    expect(headers, findsNWidgets(2));
  });

  testWidgets('unchecking a linked photo removes it', (tester) async {
    final a = testMediaItem(id: 'a', diveId: 'd1');
    final b = testMediaItem(id: 'b', diveId: 'd1');
    final result = await open(
      tester,
      onDives: [a, b],
      linked: [a],
      act: () async {
        await tester.tap(find.byKey(const ValueKey('gear_photo_link_tile_a')));
        await tester.tap(find.byKey(const ValueKey('gear_photo_link_tile_b')));
        await tester.pumpAndSettle();
        expect(find.text('Apply 2 changes'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('gear_photo_link_apply')));
        await tester.pumpAndSettle();
      },
    );
    expect([for (final m in result!) m.id], ['b']);
  });

  testWidgets('All photos loads on when a page leaves the sheet unfilled', (
    tester,
  ) async {
    await open(
      tester,
      diveIds: const [],
      libraryPages: [
        [testMediaItem(id: 'doc', mediaType: MediaType.document)],
        [testMediaItem(id: 'x')],
      ],
    );
    expect(
      find.byKey(const ValueKey('gear_photo_link_tile_x')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Dives with this gear reads dives a page at a time', (
    tester,
  ) async {
    final ids = [for (var i = 0; i < 120; i++) 'd$i'];
    final divePhotos = _DivePhotos({
      'd0': [testMediaItem(id: 'p0', diveId: 'd0')],
      'd119': [testMediaItem(id: 'p119', diveId: 'd119')],
    });
    await open(tester, diveIds: ids, divePhotos: divePhotos);

    expect(divePhotos.asked.first, hasLength(50));
    // Few photos leave the sheet unfilled, so it reads on to the last dive.
    expect([for (final a in divePhotos.asked) a.length], [50, 50, 20]);
    expect(
      find.byKey(const ValueKey('gear_photo_link_tile_p119')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
