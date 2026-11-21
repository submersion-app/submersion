import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/ui/app_actions.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A tag suggestion under the app's actions, where a tap off the field drops
/// its focus, a finger's included (#4813).
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
      "('d', 'diver-1', 'Night', 0, 0, 1, 0)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async => tearDownTestDatabase());

  testWidgets('a held press on a suggestion still adds it', (tester) async {
    var picked = <Tag>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => 'diver-1',
          ),
        ],
        child: MaterialApp(
          actions: appActions(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TagInputWidget(
              selectedTags: const [],
              onTagsChanged: (tags) => picked = tags,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ni');
    await tester.pumpAndSettle();

    // Longer than the 200 ms the list outlives the field's focus: the
    // suggestions must count as part of the field, or the finger's down
    // drops the focus and the list is gone before it lifts.
    final finger = await tester.startGesture(
      tester.getCenter(find.text('Night')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await finger.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));

    expect(picked.map((t) => t.name), ['Night']);
  });
}
