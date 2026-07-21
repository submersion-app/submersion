import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_types/presentation/pages/dive_types_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// End-to-end coverage for issue #643: Settings / Manage / Dive Types showed the
/// seeded English built-in names under every locale.
Future<void> _insertDiver() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
}

Widget _buildPage(MockCurrentDiverIdNotifier diverIdNotifier, Locale locale) {
  return ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DiveTypesPage(),
    ),
  );
}

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;

  setUp(() async {
    await setUpTestDatabase();
    await _insertDiver();
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('English locale shows the built-in names', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Recreational'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
  });

  testWidgets('German locale translates the built-in names', (tester) async {
    await tester.pumpWidget(_buildPage(diverIdNotifier, const Locale('de')));
    await tester.pumpAndSettle();

    expect(find.text('Sporttauchen'), findsOneWidget);
    expect(find.text('Wracktauchen'), findsOneWidget);
    // The seeded English literals must not leak through anywhere on the page.
    expect(find.text('Recreational'), findsNothing);
    expect(find.text('Wreck'), findsNothing);
    expect(find.text('Night'), findsNothing);
  });
}
