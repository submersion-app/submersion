import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// TagInputWidget's scope (issue #1765).
void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, diver_id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites) VALUES "
      "('d', 'diver-1', 'Night', 0, 0, 1, 0), "
      "('s', 'diver-1', 'To try', 0, 0, 0, 1)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async => tearDownTestDatabase());

  Widget harness(Widget child) => ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('site scope suggests only site tags', (tester) async {
    await tester.pumpWidget(
      harness(
        TagInputWidget(
          selectedTags: const [],
          onTagsChanged: (_) {},
          scope: TagScope.sites,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 't');
    await tester.pumpAndSettle();

    expect(find.text('To try'), findsOneWidget);
    expect(find.text('Night'), findsNothing);
  });

  testWidgets('dive scope (the default) suggests only dive tags', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(TagInputWidget(selectedTags: const [], onTagsChanged: (_) {})),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 't');
    await tester.pumpAndSettle();

    expect(find.text('Night'), findsOneWidget);
    expect(find.text('To try'), findsNothing);
  });

  testWidgets('a tag created from the site scope applies to sites', (
    tester,
  ) async {
    var picked = <Tag>[];
    await tester.pumpWidget(
      harness(
        TagInputWidget(
          selectedTags: const [],
          onTagsChanged: (tags) => picked = tags,
          scope: TagScope.sites,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Avoid');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // Submitting unfocuses the field, and the widget hides its suggestions
    // on a 200 ms timer; let it fire so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 250));

    expect(picked.single.name, 'Avoid');
    expect(picked.single.appliesToSites, isTrue);
    expect(picked.single.appliesToDives, isFalse);
  });
}
