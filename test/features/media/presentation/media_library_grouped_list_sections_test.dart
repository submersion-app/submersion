import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grouped_list.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_groupers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

// The By dive view's section headings (issue #4224): the run of site groups
// after the dives, the equipment groups after them, and Unlinked last, each
// labelled once where the kind of group changes, so the boundary between a
// diver's own dive photos and the site pictures is visible.

MediaLibraryEntry _entry(String id) => MediaLibraryEntry(
  item: MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: p.join(Directory.systemTemp.path, '$id.jpg'),
    takenAt: DateTime.utc(2026, 6, 12),
    createdAt: DateTime.utc(2026, 6, 12),
    updatedAt: DateTime.utc(2026, 6, 12),
  ),
);

MediaLibraryGroup _dive(String id, int number) => MediaLibraryGroup(
  header: DiveGroupHeader(diveId: id, diveNumber: number),
  entries: [_entry('photo-$id')],
);

MediaLibraryGroup _site(String id, String name) => MediaLibraryGroup(
  header: SiteGroupHeader(siteId: id, siteName: name),
  entries: [_entry('map-$id')],
);

MediaLibraryGroup _equipment(String id, String name) => MediaLibraryGroup(
  header: EquipmentGroupHeader(equipmentId: id, name: name),
  entries: [_entry('gear-$id')],
);

final _unlinked = MediaLibraryGroup(
  header: DiveGroupHeader(),
  entries: [_entry('loose')],
);

/// Same quiet-badge stubs as media_library_grouped_list_test.dart: every tile
/// renders a status badge that reads these.
List<dynamic> _badgeOverrides() => [
  mediaStoreAttachedProvider.overrideWith((ref) async => false),
  mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
  settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
];

void main() {
  Widget list(List<MediaLibraryGroup> groups) => ProviderScope(
    overrides: _badgeOverrides().cast(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaLibraryGroupedList(
          groups: groups,
          hasMore: false,
          onLoadMore: () {},
          onTileTap: (_) {},
          columns: 4,
        ),
      ),
    ),
  );

  Future<void> pump(WidgetTester tester, List<MediaLibraryGroup> groups) async {
    // Tall enough for every group: the grid is lazy, so a header below the
    // fold is never built and cannot be found.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(list(groups));
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('each run after the dives gets one heading above it', (
    tester,
  ) async {
    await pump(tester, [
      _dive('d1', 9),
      _dive('d2', 8),
      _site('s1', 'Blue Hole'),
      _site('s2', 'Canyon'),
      _equipment('e1', 'Primary light'),
      _unlinked,
    ]);

    expect(find.text('Site pictures'), findsOneWidget);
    expect(find.text('Equipment pictures'), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.byIcon(Icons.build_outlined), findsOneWidget);
    // Unlinked's section heading replaces its plain group header.
    expect(find.text('Unlinked'), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsOneWidget);

    expect(top(tester, '#8'), lessThan(top(tester, 'Site pictures')));
    expect(
      top(tester, 'Site pictures'),
      lessThan(top(tester, 'Site: Blue Hole')),
    );
    expect(
      top(tester, 'Site: Canyon'),
      lessThan(top(tester, 'Equipment pictures')),
    );
    expect(
      top(tester, 'Equipment pictures'),
      lessThan(top(tester, 'Equipment: Primary light')),
    );
  });

  testWidgets('dives alone get no heading', (tester) async {
    await pump(tester, [_dive('d1', 9), _dive('d2', 8)]);

    expect(find.text('Site pictures'), findsNothing);
    expect(find.text('Equipment pictures'), findsNothing);
    expect(find.byIcon(Icons.link_off), findsNothing);
  });

  testWidgets('a list of site groups alone starts with its heading', (
    tester,
  ) async {
    await pump(tester, [_site('s1', 'Blue Hole'), _site('s2', 'Canyon')]);

    expect(find.text('Site pictures'), findsOneWidget);
    expect(
      top(tester, 'Site pictures'),
      lessThan(top(tester, 'Site: Blue Hole')),
    );
  });

  testWidgets('a section spanning a second page keeps one heading', (
    tester,
  ) async {
    await pump(tester, [_dive('d1', 9), _site('s1', 'Blue Hole')]);
    // The next page brings more of the same run.
    await tester.pumpWidget(
      list([_dive('d1', 9), _site('s1', 'Blue Hole'), _site('s2', 'Canyon')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Site pictures'), findsOneWidget);
    expect(find.text('Site: Canyon'), findsOneWidget);
  });
}
