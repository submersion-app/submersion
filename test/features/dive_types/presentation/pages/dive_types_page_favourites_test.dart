import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_types/presentation/pages/dive_types_page.dart';
import 'package:submersion/features/dive_types/presentation/widgets/dive_type_favourite_button.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Settings > Dive Types favourite stars (issue #4413).
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late MockSettingsNotifier settings;

  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO dive_types (id, diver_id, name, is_built_in, sort_order, '
      "created_at, updated_at) VALUES ('mine', 'diver-1', 'Mine', 0, 99, "
      '1000, 1000)',
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
    settings = MockSettingsNotifier();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester) async {
    // Tall enough that every row is on screen and clear of the FAB.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => 'diver-1',
          ),
          settingsProvider.overrideWith((ref) => settings),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveTypesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> rowTitles(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      if (tile.title case final Text title) title.data!,
  ];

  testWidgets('custom and built-in rows each have a star', (tester) async {
    await pump(tester);
    expect(find.byKey(diveTypeFavouriteButtonKey('mine')), findsOneWidget);
    expect(find.byKey(diveTypeFavouriteButtonKey('night')), findsOneWidget);
  });

  testWidgets('starring a type saves it without opening the editor or '
      'reordering the page', (tester) async {
    await pump(tester);
    final before = rowTitles(tester);

    await tester.tap(find.byKey(diveTypeFavouriteButtonKey('night')));
    await tester.pumpAndSettle();

    expect(settings.state.favouriteDiveTypeIds, {'night'});
    expect(find.byType(AlertDialog), findsNothing);
    expect(rowTitles(tester), before);
  });
}
