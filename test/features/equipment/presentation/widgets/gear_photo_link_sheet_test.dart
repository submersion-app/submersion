import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_photo_link_sheet.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_library_grouping.dart';
import 'package:submersion/features/media/domain/entities/media_library_sort.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';

import '../../../media/presentation/support/media_widget_harness.dart';

/// Serves one page of the Library: [items].
class _OnePage extends MediaLibraryRepository {
  _OnePage(this.items);

  final List<MediaItem> items;

  @override
  Future<MediaLibraryPageResult> getPage({
    required String? diverId,
    MediaLibraryFilter filter = MediaLibraryFilter.none,
    SortState<MediaSortField> sort = kDefaultMediaSort,
    MediaLibraryGrouping grouping = MediaLibraryGrouping.none,
    MediaLibraryCursor? after,
    int limit = MediaLibraryRepository.pageSize,
  }) async => MediaLibraryPageResult(
    entries: [for (final i in items) MediaLibraryEntry(item: i)],
    nextCursor: null,
  );
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
    List<String> diveIds = const ['d1', 'd2'],
    List<MediaItem> onDives = const [],
    List<MediaItem> library = const [],
    List<MediaItem> linked = const [],
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
          equipmentDiveIdsProvider('e1').overrideWith((ref) async => diveIds),
          linkableMediaOnEquipmentDivesProvider(
            'e1',
          ).overrideWith((ref) async => onDives),
          mediaLibraryRepositoryProvider.overrideWithValue(_OnePage(library)),
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
}
