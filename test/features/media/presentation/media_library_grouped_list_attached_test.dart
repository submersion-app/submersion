import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

// The by-dive view's groups for media attached to a site or a piece of
// equipment but to no dive (issue #4149). They used to land under Unlinked,
// which read as "this photo belongs to nothing" for a site map that plainly
// belongs to its site.

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

/// Same quiet-badge stubs as media_library_grouped_list_test.dart: every tile
/// renders a status badge that reads these.
List<dynamic> _badgeOverrides() => [
  mediaStoreAttachedProvider.overrideWith((ref) async => false),
  mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
  settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
];

void main() {
  final groups = [
    MediaLibraryGroup(
      header: DiveGroupHeader(diveId: 'd1', diveNumber: 9),
      entries: [_entry('z')],
    ),
    MediaLibraryGroup(
      header: SiteGroupHeader(siteId: 's1', siteName: 'Rubis'),
      entries: [_entry('a')],
    ),
    MediaLibraryGroup(
      header: EquipmentGroupHeader(equipmentId: 'e1', name: 'Primary light'),
      entries: [_entry('b')],
    ),
    MediaLibraryGroup(header: DiveGroupHeader(), entries: [_entry('c')]),
  ];

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    bool isSelectionMode = false,
  }) async {
    final router = GoRouter(
      initialLocation: '/media',
      routes: [
        GoRoute(
          path: '/media',
          builder: (context, state) => Scaffold(
            body: MediaLibraryGroupedList(
              groups: groups,
              hasMore: false,
              onLoadMore: () {},
              onTileTap: (_) {},
              columns: 4,
              isSelectionMode: isSelectionMode,
            ),
          ),
        ),
        GoRoute(
          path: '/sites/:siteId',
          builder: (context, state) =>
              Text('Site ${state.pathParameters['siteId']}'),
        ),
        GoRoute(
          path: '/equipment/:equipmentId',
          builder: (context, state) =>
              Text('Equipment ${state.pathParameters['equipmentId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    // Tall enough for every group: the grid is lazy, so a header below the
    // fold is never built and cannot be found.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _badgeOverrides().cast(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('site and equipment groups are named for what they belong to', (
    tester,
  ) async {
    await pumpRouter(tester);

    expect(find.text('Site: Rubis'), findsOneWidget);
    expect(find.text('Equipment: Primary light'), findsOneWidget);
    // Only the row attached to nothing is still called Unlinked.
    expect(find.text('Unlinked'), findsOneWidget);
  });

  testWidgets('a nameless site or item falls back to a bare label', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _badgeOverrides().cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaLibraryGroupedList(
              groups: [
                MediaLibraryGroup(
                  header: SiteGroupHeader(siteId: 's1', siteName: '  '),
                  entries: [_entry('a')],
                ),
                MediaLibraryGroup(
                  header: EquipmentGroupHeader(equipmentId: 'e1'),
                  entries: [_entry('b')],
                ),
              ],
              hasMore: false,
              onLoadMore: () {},
              onTileTap: (_) {},
              columns: 4,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Site'), findsOneWidget);
    expect(find.text('Untitled equipment'), findsOneWidget);
  });

  testWidgets('a site header opens the site', (tester) async {
    final router = await pumpRouter(tester);

    await tester.tap(find.text('Site: Rubis'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/sites/s1');
    expect(find.text('Site s1'), findsOneWidget);
  });

  testWidgets('an equipment header opens the equipment item', (tester) async {
    final router = await pumpRouter(tester);

    await tester.tap(find.text('Equipment: Primary light'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/equipment/e1');
    expect(find.text('Equipment e1'), findsOneWidget);
  });

  testWidgets('each header announces where it goes, once', (tester) async {
    await pumpRouter(tester);

    // The label used to come out doubled ("#9\n#9"): the header named it in
    // its Semantics and again through its Text.
    expect(
      tester.getSemantics(find.text('#9')),
      matchesSemantics(
        label: '#9',
        hint: 'Open this dive',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );

    expect(
      tester.getSemantics(find.text('Site: Rubis')),
      matchesSemantics(
        label: 'Site: Rubis',
        hint: 'Open this site',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Equipment: Primary light')),
      matchesSemantics(
        label: 'Equipment: Primary light',
        hint: 'Open this equipment',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
  });

  testWidgets('the headers are inert while a selection is in progress', (
    tester,
  ) async {
    final router = await pumpRouter(tester, isSelectionMode: true);

    await tester.tap(find.text('Site: Rubis'));
    await tester.tap(find.text('Equipment: Primary light'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/media');
  });
}
