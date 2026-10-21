// The Photos & videos page hosts the pending setup card and the guided setup,
// and both used to route media items back to /settings/photos-media: a tap
// there stacked another copy of the page the diver was already on, and the
// item never resolved. On this page they lead to the Using row instead, and
// the guided setup's storage step goes back to the page it was opened from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/presentation/pages/photos_videos_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_upload_progress_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/settings/presentation/pages/photos_media_setup_page.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_pane_navigator.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _attachItem = PendingSetupItem(
  kind: SetupItemKind.mediaStoreAttach,
  key: 'store_s1',
  label: 'Dropbox',
  route: '/settings/photos-media',
);

const _itemText = 'Connect media storage (Dropbox)';

class _Stub extends StatelessWidget {
  const _Stub(this.name);
  final String name;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(name)));
}

/// The Data pane's pages this test reaches, the rest standing in as stubs.
Widget? _panePage(Uri location) => switch (location.pathSegments) {
  ['settings', 'photos-media'] => const PhotosVideosPage(),
  ['settings', 'photos-media', 'setup'] => const PhotosMediaSetupPage(),
  ['settings', 'media-sources'] => const _Stub('Sources stub'),
  ['settings', 'cloud-sync'] => const _Stub('Sync stub'),
  _ => null,
};

/// Phone routes mirror app_router.dart: setup nests under photos-media.
GoRouter _phoneRouter() => GoRouter(
  initialLocation: '/settings/photos-media',
  routes: [
    GoRoute(
      path: '/settings',
      builder: (context, state) => const _Stub('Settings stub'),
      routes: [
        GoRoute(
          path: 'photos-media',
          builder: (context, state) => const PhotosVideosPage(),
          routes: [
            GoRoute(
              path: 'setup',
              builder: (context, state) => const PhotosMediaSetupPage(),
            ),
          ],
        ),
        GoRoute(
          path: 'media-sources',
          builder: (context, state) => const _Stub('Sources stub'),
        ),
      ],
    ),
  ],
);

/// The desktop Data pane with Photos & videos open in it.
GoRouter _paneRouter() => GoRouter(
  initialLocation: '/settings?selected=data&dataPage=photos-media',
  routes: [
    GoRoute(
      path: '/settings',
      builder: (context, state) => const Scaffold(
        body: SettingsPaneNavigator(
          sectionId: 'data',
          queryParam: 'dataPage',
          hub: Text('Data hub'),
          pageFor: _panePage,
        ),
      ),
    ),
  ],
);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

List<String> _paneStack(GoRouter router) =>
    Uri.parse(_location(router)).queryParametersAll['dataPage'] ?? const [];

Finder _photosPages() => find.byType(PhotosVideosPage, skipOffstage: false);

Finder _openButtonOf(String stepTitle) => find.descendant(
  of: find.ancestor(of: find.text(stepTitle), matching: find.byType(Card)),
  matching: find.widgetWithText(FilledButton, 'Open'),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(
    WidgetTester tester,
    GoRouter router, {
    List<PendingSetupItem> items = const [_attachItem],
    Size size = const Size(900, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          photosCopiesProvider.overrideWith(
            (ref) async =>
                (attached: false, store: null, group: null, label: null),
          ),
          photosStoreReachableProvider.overrideWithValue(true),
          mediaUploadProgressProvider.overrideWith(
            (ref) async => (copied: 0, total: 0),
          ),
          mediaTransferSummaryProvider.overrideWith(
            (ref) => Stream.value(const MediaTransferSummary()),
          ),
          mediaStoreRuntimeProvider.overrideWith((ref) async => null),
          pendingSetupItemsProvider.overrideWith((ref) async => items),
          accountGroupsProvider.overrideWith((ref) async => const []),
          offerableAccountKindsProvider.overrideWithValue(const []),
          setupGuideStatusProvider.overrideWith(
            (ref) async => (sources: false, storage: false, sync: false),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a media setup item on the Photos & videos page', () {
    testWidgets('does not push a second copy of the page', (tester) async {
      final router = _phoneRouter();
      await pump(tester, router);
      expect(find.text(_itemText), findsOneWidget);

      await tester.tap(find.text(_itemText));
      await tester.pumpAndSettle();

      expect(_photosPages(), findsOneWidget);
      expect(_location(router), '/settings/photos-media');
    });

    testWidgets('brings the Using row, which resolves it, into view', (
      tester,
    ) async {
      // Short enough that the card shows and the Using row starts below it.
      const size = Size(400, 220);
      final router = _phoneRouter();
      await pump(tester, router, size: size);
      final using = find.byKey(const Key('photos-using'), skipOffstage: false);
      expect(tester.getRect(using).bottom, greaterThan(size.height));

      await tester.tap(find.text(_itemText));
      await tester.pumpAndSettle();

      expect(tester.getRect(using).bottom, lessThanOrEqualTo(size.height));
      expect(_photosPages(), findsOneWidget);
    });

    testWidgets('a reconnect item does not push the page either', (
      tester,
    ) async {
      final router = _phoneRouter();
      await pump(
        tester,
        router,
        items: const [
          PendingSetupItem(
            kind: SetupItemKind.mediaStoreReconnect,
            key: 'store_marker_s1',
            label: 'Dropbox',
            route: '/settings/photos-media',
          ),
        ],
      );

      await tester.tap(find.text('Reconnect media storage (Dropbox)'));
      await tester.pumpAndSettle();

      expect(_photosPages(), findsOneWidget);
      expect(_location(router), '/settings/photos-media');
    });

    testWidgets('in the desktop pane, does not stack the page again', (
      tester,
    ) async {
      final router = _paneRouter();
      await pump(tester, router);

      await tester.tap(find.text(_itemText));
      await tester.pumpAndSettle();

      expect(_photosPages(), findsOneWidget);
      expect(_paneStack(router), ['photos-media']);
    });
  });

  group('the guided setup storage step opened from the page', () {
    testWidgets('goes back to the page rather than pushing it again', (
      tester,
    ) async {
      final router = _phoneRouter();
      await pump(tester, router, items: const []);
      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(PhotosMediaSetupPage), findsOneWidget);

      await tester.tap(_openButtonOf('Media storage'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PhotosMediaSetupPage), findsNothing);
      expect(_photosPages(), findsOneWidget);
      expect(_location(router), '/settings/photos-media');
    });

    testWidgets('in the desktop pane, closes the guide without a throw', (
      tester,
    ) async {
      final router = _paneRouter();
      await pump(tester, router, items: const []);
      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();
      expect(_paneStack(router), ['photos-media', 'photos-media/setup']);

      await tester.tap(_openButtonOf('Media storage'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PhotosMediaSetupPage), findsNothing);
      expect(_photosPages(), findsOneWidget);
      expect(_paneStack(router), ['photos-media']);
    });

    // Another step's page closing after the guide itself has gone (the pane
    // walked back past it) must not touch the guide's unmounted card.
    testWidgets('a step returning after the guide closed does not throw', (
      tester,
    ) async {
      final router = _paneRouter();
      await pump(tester, router, items: const []);
      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();
      await tester.tap(_openButtonOf('Photo sources'));
      await tester.pumpAndSettle();
      expect(find.text('Sources stub'), findsOneWidget);

      router.go('/settings?selected=data&dataPage=photos-media');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PhotosMediaSetupPage), findsNothing);
      expect(_paneStack(router), ['photos-media']);
    });
  });
}
