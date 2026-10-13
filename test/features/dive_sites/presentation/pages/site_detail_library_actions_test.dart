import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _librarySite = DiveSite(
  id: 'site-1',
  name: 'Library Reef',
  sharedLibraryId: 'L',
);
const _personalSite = DiveSite(id: 'site-1', name: 'My Reef', diverId: 'd');

const _library = SharedLibrary(
  id: 'L',
  name: 'Reef Survey',
  connectedAccountId: 'a',
  prefix: 'p',
  roles: SharedLibraryRoles(editors: {'m'}),
);

/// The one library the profile may push to, without a database.
class _FakeStore extends SharedLibraryStore {
  @override
  Future<List<SharedLibrary>> getLibraries() async => const [_library];

  @override
  Future<SharedLibrary?> getLibrary(String id) async =>
      id == _library.id ? _library : null;

  @override
  Future<SharedLibraryMembership?> membership({
    required String diverId,
    required String libraryId,
  }) async => const SharedLibraryMembership(
    id: 'ms',
    diverId: 'd',
    libraryId: 'L',
    memberId: 'm',
    displayName: 'Ann',
    libraryName: 'Reef Survey',
    backendKind: 's3',
  );
}

/// Records each push, or refuses it.
class _FakePublisher extends SharedSitePublisher {
  _FakePublisher({this.refuse = false}) : super(store: _FakeStore());

  final bool refuse;
  final pushes = <String>[];

  @override
  Future<void> push({
    required String siteId,
    required String libraryId,
    required String diverId,
  }) async {
    if (refuse) throw StateError('refused');
    pushes.add('$siteId:$libraryId:$diverId');
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required DiveSite site,
  required SharedLibraryRole role,
  bool connected = true,
  SharedSitePublisher? publisher,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 800);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final router = GoRouter(
    initialLocation: '/sites/site-1',
    routes: [
      GoRoute(
        path: '/sites',
        builder: (context, state) => const Scaffold(body: Text('LIST')),
      ),
      GoRoute(
        path: '/sites/:id',
        builder: (context, state) =>
            SiteDetailPage(siteId: state.pathParameters['id']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await getBaseOverrides(),
        siteListViewModeProvider.overrideWith((ref) => ListViewMode.table),
        siteProvider(site.id).overrideWith((ref) async => site),
        siteDiveCountProvider(site.id).overrideWith((ref) async => 0),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
        sharedLibrariesProvider.overrideWith(
          (ref) => Stream.value(
            connected
                ? const [
                    SharedLibrary(
                      id: 'L',
                      name: 'Reef Survey',
                      connectedAccountId: 'a',
                      prefix: 'p',
                    ),
                  ]
                : const <SharedLibrary>[],
          ),
        ),
        currentMembershipsProvider.overrideWith(
          (ref) async => const [
            SharedLibraryMembership(
              id: 'ms',
              diverId: 'd',
              libraryId: 'L',
              memberId: 'm',
              displayName: 'Ann',
              libraryName: 'Reef Survey',
              backendKind: 's3',
            ),
          ],
        ),
        libraryRoleProvider('L').overrideWith((ref) async => role),
        libraryConnectedHereProvider(
          'L',
        ).overrideWith((ref) async => connected),
        siteLibraryStateProvider('site-1').overrideWith((ref) async => null),
        libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
        sharedLibraryStoreProvider.overrideWithValue(_FakeStore()),
        if (publisher != null)
          sharedSitePublisherProvider.overrideWithValue(publisher),
      ].cast(),
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a reader gets Suggest changes instead of Edit', (tester) async {
    await _pump(tester, site: _librarySite, role: SharedLibraryRole.reader);
    expect(find.byTooltip('Edit Site'), findsNothing);
    expect(find.text('Suggest changes'), findsOneWidget);
    expect(
      find.text('Reef Survey'),
      findsWidgets,
      reason: 'library chip in header',
    );
  });

  testWidgets('an editor gets Edit and a library delete dialog', (
    tester,
  ) async {
    await _pump(tester, site: _librarySite, role: SharedLibraryRole.editor);
    expect(find.byTooltip('Edit Site'), findsOneWidget);
    expect(find.text('Suggest changes'), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete from the shared site library?'), findsOneWidget);
  });

  testWidgets('an unconnected device offers Connect on this device', (
    tester,
  ) async {
    await _pump(
      tester,
      site: _librarySite,
      role: SharedLibraryRole.reader,
      connected: false,
    );
    expect(find.byTooltip('Edit Site'), findsNothing);
    expect(find.text('Suggest changes'), findsNothing);
    expect(find.text('Connect on this device'), findsOneWidget);
  });

  testWidgets(
    'a personal site offers Add to shared site library to an editor',
    (tester) async {
      await _pump(tester, site: _personalSite, role: SharedLibraryRole.editor);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Add to shared site library'), findsOneWidget);
    },
  );

  Future<void> addToLibrary(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to shared site library'));
    await tester.pumpAndSettle();
    expect(find.text('Add My Reef to Reef Survey?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
  }

  testWidgets('adding a personal site confirms, pushes and says where', (
    tester,
  ) async {
    final publisher = _FakePublisher();
    await _pump(
      tester,
      site: _personalSite,
      role: SharedLibraryRole.editor,
      publisher: publisher,
    );
    await addToLibrary(tester);
    expect(publisher.pushes, ['site-1:L:d']);
    expect(find.text('Added to Reef Survey'), findsOneWidget);
  });

  testWidgets('a refused push says so and claims nothing', (tester) async {
    await _pump(
      tester,
      site: _personalSite,
      role: SharedLibraryRole.editor,
      publisher: _FakePublisher(refuse: true),
    );
    await addToLibrary(tester);
    expect(find.text('Added to Reef Survey'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
