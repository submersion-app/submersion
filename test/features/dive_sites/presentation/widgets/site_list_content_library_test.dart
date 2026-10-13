import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/select_items_menu.dart';
import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

const _library = SharedLibrary(
  id: 'L',
  name: 'Reef Survey',
  connectedAccountId: 'a',
  prefix: 'p',
  roles: SharedLibraryRoles(editors: {'m'}),
);

/// The one library the profile may push to; the rest is the real store.
class _OneLibraryStore extends SharedLibraryStore {
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
    diverId: 'd2',
    libraryId: 'L',
    memberId: 'm',
    displayName: 'Ann',
    libraryName: 'Reef Survey',
    backendKind: 's3',
  );
}

/// Records each push, or refuses it.
class _FakePublisher extends SharedSitePublisher {
  _FakePublisher({this.refuse = false}) : super(store: _OneLibraryStore());

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

/// The site list's bulk Add to shared site library (issue #2567).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    await seedDivers(db, ['d2']);
    await seedSite(db, 'a', owner: 'd2', name: 'Alpha');
    await seedSite(db, 'b', owner: 'd2', name: 'Bravo');
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, SharedSitePublisher publisher) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: SiteListContent(showAppBar: false)),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd2'),
          sharedLibraryStoreProvider.overrideWithValue(_OneLibraryStore()),
          sharedSitePublisherProvider.overrideWithValue(publisher),
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

  Future<void> addSelected(WidgetTester tester, List<String> names) async {
    await enterSelectionViaMenu(tester);
    for (final name in names) {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
    final direct = find.byKey(const ValueKey('selection_action_addToLibrary'));
    if (direct.evaluate().isEmpty) {
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('selection_menu_addToLibrary')),
      );
    } else {
      await tester.tap(direct);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('one site is named in the confirmation, then pushed', (
    tester,
  ) async {
    final publisher = _FakePublisher();
    await pump(tester, publisher);
    await addSelected(tester, ['Alpha']);
    expect(find.text('Add Alpha to Reef Survey?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(publisher.pushes, ['a:L:d2']);
    expect(find.text('Added to Reef Survey'), findsOneWidget);
  });

  testWidgets('several sites are counted, and cancelling pushes nothing', (
    tester,
  ) async {
    final publisher = _FakePublisher();
    await pump(tester, publisher);
    await addSelected(tester, ['Alpha', 'Bravo']);
    expect(find.text('Add 2 sites to Reef Survey?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(publisher.pushes, isEmpty);
  });

  testWidgets('a refused push says so and claims nothing', (tester) async {
    await pump(tester, _FakePublisher(refuse: true));
    await addSelected(tester, ['Alpha']);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Added to Reef Survey'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
