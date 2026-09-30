import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Editing another profile's shared site: sharing is locked and the delete
/// action only removes the site from the active profile (issue #2594).
void main() {
  setUp(() {
    serveFakeHost('api.open-meteo.com');
  });

  late SharedPreferences prefs;
  final divers = [
    for (final (id, name) in [('d1', 'Alice'), ('d2', 'Bob')])
      Diver(
        id: id,
        name: name,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final db = await setUpTestDatabase();
    await seedDivers(db, ['d1', 'd2']);
    await seedSite(db, 'pier', owner: 'd1', shared: true, name: 'Salt Pier');
    await seedDive(db, 'b1', diver: 'd2', siteId: 'pier');
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, {required String active}) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => divers),
          validatedCurrentDiverIdProvider.overrideWith((_) async => active),
          shareByDefaultProvider.overrideWith((_) async => false),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteEditPage(
              siteId: 'pier',
              embedded: true,
              onSaved: (id) {},
              onCancel: () {},
              onDeleted: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openLifeSection(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('shared'),
      50.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('shared'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Share with all dive profiles'),
      50.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('another profile gets Remove, not Delete', (tester) async {
    await pump(tester, active: 'd2');
    expect(find.widgetWithIcon(IconButton, Icons.delete), findsNothing);
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
    );
    await tester.pumpAndSettle();
    expect(find.text("Remove 'Salt Pier' from your profile?"), findsOneWidget);
    expect(find.textContaining('1 of your dives stays linked'), findsOneWidget);
  });

  testWidgets('another profile cannot change sharing', (tester) async {
    await pump(tester, active: 'd2');
    await openLifeSection(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('Only Alice can change sharing'), findsOneWidget);
  });

  testWidgets('the owner deletes, warned about other profiles\' dives', (
    tester,
  ) async {
    await pump(tester, active: 'd1');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete));
    await tester.pumpAndSettle();
    expect(find.text('Delete shared site?'), findsOneWidget);
    expect(
      find.textContaining('1 dive in another profile will lose this site.'),
      findsOneWidget,
    );
  });

  testWidgets('the owner can change sharing', (tester) async {
    await pump(tester, active: 'd1');
    await openLifeSection(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
  });
}
