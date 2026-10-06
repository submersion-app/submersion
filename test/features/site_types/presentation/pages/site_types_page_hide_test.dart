import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/site_types/presentation/pages/site_types_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/built_in_show_column.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Settings > Site Types hide switches (issue #401).
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
      'INSERT INTO site_types (id, diver_id, name, is_built_in, sort_order, '
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteTypesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final lakeKey = builtInShowSwitchKey(BuiltInCatalog.siteTypes, 'lake');

  testWidgets('built-in rows have a labeled switch, custom rows none', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Show'), findsOneWidget);
    expect(find.byKey(lakeKey), findsOneWidget);
    expect(
      find.byKey(builtInShowSwitchKey(BuiltInCatalog.siteTypes, 'mine')),
      findsNothing,
    );
  });

  testWidgets('switching a type off hides it and dims its row', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(lakeKey));
    await tester.pumpAndSettle();

    expect(settings.state.hiddenBuiltIns(BuiltInCatalog.siteTypes), {'lake'});
    final title = tester.widget<ListTile>(
      find.ancestor(of: find.byKey(lakeKey), matching: find.byType(ListTile)),
    );
    final context = tester.element(find.byKey(lakeKey));
    expect(title.textColor, Theme.of(context).disabledColor);
    expect(tester.widget<Switch>(find.byKey(lakeKey)).value, isFalse);
  });
}
