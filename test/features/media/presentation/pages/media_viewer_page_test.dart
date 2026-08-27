import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

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

MediaItem item(String id, {String? diveId}) => MediaItem(
  id: id,
  diveId: diveId,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026, 7, 1, 10),
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  /// The viewer's provider scope + a locale-pinned MaterialApp around [home].
  Widget host(Widget home) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mediaSourceResolverRegistryProvider.overrideWithValue(
        MediaSourceResolverRegistry({
          MediaSourceType.platformGallery: _UnavailableResolver(
            MediaSourceType.platformGallery,
          ),
        }),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<MediaItem> mediaList,
    required String initialMediaId,
    bool showGoToDive = false,
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
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(
              mediaList: mediaList,
              initialMediaId: initialMediaId,
              showGoToDive: showGoToDive,
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

  /// Runs [action] and lets the page animation finish.
  ///
  /// Deliberately NOT inside runAsync, unlike the initial pump: pumping from
  /// the real-async zone does not drive the fake-async clock the page
  /// animation ticks on, so animateToPage never settles and the indicator
  /// stays on the old page.
  Future<void> settlePager(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    await action();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  testWidgets('opens on the initial item and swipes between items', (
    tester,
  ) async {
    await pump(tester, mediaList: [item('a'), item('b')], initialMediaId: 'b');
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.fling(
        find.byType(PageView).first,
        const Offset(600, 0),
        1200,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
    });
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('arrow buttons page forward and back', (tester) async {
    await pump(tester, mediaList: [item('a'), item('b')], initialMediaId: 'a');
    expect(find.text('1 / 2'), findsOneWidget);
    // Nothing to go back to on the first item.
    expect(find.byTooltip('Previous media'), findsNothing);

    await settlePager(tester, () => tester.tap(find.byTooltip('Next media')));
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byTooltip('Next media'), findsNothing);

    await settlePager(
      tester,
      () => tester.tap(find.byTooltip('Previous media')),
    );
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('a single item gets no arrows', (tester) async {
    await pump(tester, mediaList: [item('a')], initialMediaId: 'a');

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byTooltip('Previous media'), findsNothing);
    expect(find.byTooltip('Next media'), findsNothing);
  });

  testWidgets('left/right arrow keys page through the gallery', (tester) async {
    await pump(tester, mediaList: [item('a'), item('b')], initialMediaId: 'a');

    await settlePager(
      tester,
      () => tester.sendKeyEvent(LogicalKeyboardKey.arrowRight),
    );
    expect(find.text('2 / 2'), findsOneWidget);

    await settlePager(
      tester,
      () => tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft),
    );
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('a second press mid-animation advances a second item', (
    tester,
  ) async {
    await pump(
      tester,
      mediaList: [item('a'), item('b'), item('c')],
      initialMediaId: 'a',
    );

    // Two presses inside one 250ms page animation. Stepping from the last
    // SETTLED page would re-target item 2 and swallow the second press.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('arrow keys stop at the ends rather than wrapping', (
    tester,
  ) async {
    await pump(tester, mediaList: [item('a'), item('b')], initialMediaId: 'a');

    await settlePager(
      tester,
      () => tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft),
    );
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('a gallery that shrinks under the viewer still navigates', (
    tester,
  ) async {
    await pump(
      tester,
      mediaList: [item('a'), item('b'), item('c'), item('d'), item('e')],
      initialMediaId: 'e',
    );
    expect(find.text('5 / 5'), findsOneWidget);

    // The list is live: a delete elsewhere, a dive-deletion cascade or a sync
    // pull can shrink it under the open viewer. Re-pumping the same widget
    // position keeps the State, and with it a nav target past the new end.
    await pump(tester, mediaList: [item('a'), item('b')], initialMediaId: 'e');
    expect(find.text('2 / 2'), findsOneWidget);

    await settlePager(
      tester,
      () => tester.tap(find.byTooltip('Previous media')),
    );
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('arrows hide with the rest of the chrome', (tester) async {
    await pump(tester, mediaList: [item('a'), item('b')], initialMediaId: 'a');
    expect(find.byTooltip('Next media'), findsOneWidget);

    // Tapping the photo toggles the chrome off; the arrows are chrome. The
    // tap lands between the arrows, which must not swallow it. The extra
    // elapsed time lets PhotoView's double-tap recognizer time out and
    // release the gesture arena.
    await tester.tapAt(tester.getCenter(find.byType(Scaffold)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.byTooltip('Next media'), findsNothing);
    expect(find.text('1 / 2'), findsNothing);
  });

  testWidgets('Escape closes the viewer', (tester) async {
    // Pushed over a host page (not pumped as home) so there is a route to
    // pop back to. No runAsync here: pumpAndSettle drives the fake clock,
    // and mixing the two leaks async work past the end of the test.
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MediaViewerPage(
                  mediaList: [item('a'), item('b')],
                  initialMediaId: 'a',
                ),
              ),
            ),
            child: const Text('Open viewer'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open viewer'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(MediaViewerPage), findsNothing);
    expect(find.text('Open viewer'), findsOneWidget);
  });

  testWidgets('empty list shows the localized empty message', (tester) async {
    await pump(tester, mediaList: const [], initialMediaId: 'x');
    expect(find.text('No photos available'), findsOneWidget);
  });

  testWidgets('Go to dive appears only when enabled and the item is linked', (
    tester,
  ) async {
    await pump(
      tester,
      mediaList: [item('a', diveId: 'd1')],
      initialMediaId: 'a',
      showGoToDive: true,
    );
    expect(find.byTooltip('Go to dive'), findsOneWidget);
  });

  testWidgets('Go to dive hidden when disabled', (tester) async {
    await pump(
      tester,
      mediaList: [item('a', diveId: 'd1')],
      initialMediaId: 'a',
    );
    expect(find.byTooltip('Go to dive'), findsNothing);
  });

  testWidgets('Go to dive hidden for unlinked items', (tester) async {
    await pump(
      tester,
      mediaList: [item('a')],
      initialMediaId: 'a',
      showGoToDive: true,
    );
    expect(find.byTooltip('Go to dive'), findsNothing);
  });

  testWidgets('Go to dive leaves the media section beneath the dive detail', (
    tester,
  ) async {
    // Shell-shaped like production: app_router puts BOTH /media and
    // /dives/:diveId inside one ShellRoute with no parentNavigatorKey, so the
    // pushed page lands on the same shell navigator that already carries the
    // imperatively pushed viewer. A flat router would exercise a different
    // go_router path and hide that interaction. :diveId is a CHILD of /dives,
    // which is what makes a stack-replacing `go` synthesize the dive list.
    final router = GoRouter(
      initialLocation: '/media',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/media',
              builder: (context, state) => Builder(
                builder: (inner) => TextButton(
                  onPressed: () => Navigator.of(inner).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => MediaViewerPage(
                        mediaList: [item('a', diveId: 'd1')],
                        initialMediaId: 'a',
                        showGoToDive: true,
                      ),
                    ),
                  ),
                  child: const Text('Media Section'),
                ),
              ),
            ),
            GoRoute(
              path: '/dives',
              builder: (context, state) => const Text('Dive List'),
              routes: [
                GoRoute(
                  path: ':diveId',
                  builder: (context, state) => Scaffold(
                    appBar: AppBar(),
                    body: const Text('Dive Detail'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

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
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Media Section'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Go to dive'));
    await tester.pumpAndSettle();
    expect(find.text('Dive Detail'), findsOneWidget);
    // Pin the router itself, not just what is painted: a plain Navigator.push
    // of the same page would satisfy the widget assertions while leaving the
    // router desynchronized from the screen.
    expect(router.state.uri.toString(), '/dives/d1');
    // skipOffstage: false -- the guarantee is that the dive list is never
    // MATERIALIZED underneath, not merely that it is currently invisible.
    expect(find.text('Dive List', skipOffstage: false), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Back returns to the photo the user launched from, with the media
    // section still beneath it.
    expect(find.byTooltip('Go to dive'), findsOneWidget);
    expect(find.text('Media Section', skipOffstage: false), findsOneWidget);
  });
}
