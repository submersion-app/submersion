import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/data/services/bulk_tag_service.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/bulk_tag_sheet.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The bulk tag sheet for media, end to end on a real database (#1970).
void main() {
  late AppDatabase db;
  final links = TagLinkRepository(TagScope.media);
  BulkActionOutcome? outcome;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('m1', 'a', 'photo', 0, 0), ('m2', 'b', 'photo', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, applies_to_dives, '
      "applies_to_media) VALUES ('wreck', 'Wreck', 0, 0, 0, 1), "
      "('fish', 'Fish', 0, 0, 0, 1), ('funny', 'Funny', 0, 0, 0, 1), "
      "('night', 'Night', 0, 0, 1, 0)",
    );
    // m1: Wreck and Fish. m2: Wreck.
    await db.customStatement(
      'INSERT INTO media_tags (id, media_id, tag_id, created_at) VALUES '
      "('l1', 'm1', 'wreck', 0), ('l2', 'm1', 'fish', 1), "
      "('l3', 'm2', 'wreck', 2)",
    );
  });
  tearDown(() async => tearDownTestDatabase());

  Future<Set<String>> tagIdsOf(String id) async =>
      ((await links.getTagIdsByItem([id]))[id] ?? const <String>[]).toSet();

  Future<void> openSheet(WidgetTester tester) async {
    outcome = null;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testAppInShell(
        locale: const Locale('en'),
        overrides: overrides.cast(),
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async {
              outcome = await showBulkTagSheet(
                context,
                ref,
                scope: TagScope.media,
                service: BulkTagService(links, itemTable: 'media'),
                itemIds: const ['m1', 'm2'],
                labels: (
                  confirmAdding: (n) => 'Adding to all $n media items',
                  confirmRemoving: (n) => 'Removing from all $n media items',
                  empty: 'No media tags yet',
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Checkbox toggleOf(WidgetTester tester, String tagId) =>
      tester.widget<Checkbox>(find.byKey(ValueKey('membership-toggle-$tagId')));

  Future<void> tapToggle(WidgetTester tester, String tagId) async {
    final toggle = find.byKey(ValueKey('membership-toggle-$tagId'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  testWidgets('lists media tags with tri-state counts', (tester) async {
    await openSheet(tester);

    expect(find.text('Edit tags on 2 items'), findsOneWidget);
    expect(toggleOf(tester, 'wreck').value, isTrue);
    expect(toggleOf(tester, 'fish').value, isNull);
    expect(toggleOf(tester, 'funny').value, isFalse);
    expect(find.text('Night'), findsNothing, reason: 'a dive-only tag');
  });

  testWidgets('apply writes the change and Undo restores it', (tester) async {
    await openSheet(tester);
    await tapToggle(tester, 'funny');
    await tapToggle(tester, 'wreck');
    await tester.tap(find.byKey(const ValueKey('bulkTags_apply')));
    await tester.pumpAndSettle();

    expect(find.text('Adding to all 2 media items'), findsOneWidget);
    expect(find.text('Removing from all 2 media items'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bulkTags_confirm')));
    await tester.pumpAndSettle();

    expect(outcome, BulkActionOutcome.completed);
    expect(await tester.runAsync(() => tagIdsOf('m1')), {'fish', 'funny'});
    expect(await tester.runAsync(() => tagIdsOf('m2')), {'funny'});

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => tagIdsOf('m1')), {'wreck', 'fish'});
    expect(await tester.runAsync(() => tagIdsOf('m2')), {'wreck'});
  });

  testWidgets('closing the sheet changes nothing', (tester) async {
    await openSheet(tester);
    await tapToggle(tester, 'funny');
    await tester.tap(find.byKey(const ValueKey('bulkTags_cancel')));
    await tester.pumpAndSettle();

    expect(outcome, BulkActionOutcome.cancelled);
    expect(await tester.runAsync(() => tagIdsOf('m2')), {'wreck'});
  });
}
