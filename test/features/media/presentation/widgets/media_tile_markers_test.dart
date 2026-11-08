import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/media_tile_markers.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';

import '../../../../helpers/l10n_test_helpers.dart';

final _item = MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: 'asset-1',
  takenAt: DateTime(2026, 3, 12),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

const _people = Key('media-tile-marker-people');
const _species = Key('media-tile-marker-species');
const _time = Key('media-tile-marker-time');

/// The tag markers on a library tile (issue #4218).
void main() {
  Future<List<int>> pump(
    WidgetTester tester, {
    bool people = false,
    bool species = false,
    bool time = false,
    bool enabled = true,
  }) async {
    final tileTaps = [0];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaTagBadgesProvider.overrideWith(
            (ref) => MediaTagBadgesNotifier.unstored(enabled),
          ),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tileTaps[0]++,
              child: Center(
                child: MediaTileMarkers(
                  entry: MediaLibraryEntry(
                    item: _item,
                    hasPeople: people,
                    hasSpecies: species,
                    hasTimeInDive: time,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tileTaps;
  }

  testWidgets('draws nothing for an item with no markers', (tester) async {
    await pump(tester);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('draws one glyph per marker, in a fixed order', (tester) async {
    await pump(tester, people: true, species: true, time: true);
    double x(Key key) => tester.getCenter(find.byKey(key)).dx;
    expect(x(_people), lessThan(x(_species)));
    expect(x(_species), lessThan(x(_time)));
  });

  testWidgets('draws only the markers the item has', (tester) async {
    await pump(tester, species: true);
    expect(find.byKey(_species), findsOneWidget);
    expect(find.byKey(_people), findsNothing);
    expect(find.byKey(_time), findsNothing);
  });

  testWidgets('each marker explains itself in a tooltip', (tester) async {
    await pump(tester, people: true, species: true, time: true);
    final messages = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((t) => t.message)
        .toList();
    expect(messages, [
      'People tagged',
      'Species tagged',
      'Placed on the dive profile',
    ]);
  });

  testWidgets('the setting switched off hides every marker', (tester) async {
    await pump(tester, people: true, species: true, time: true, enabled: false);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('a tap on a marker goes through to the tile', (tester) async {
    final taps = await pump(tester, people: true);
    await tester.tap(find.byKey(_people));
    expect(taps.single, 1);
  });
}
