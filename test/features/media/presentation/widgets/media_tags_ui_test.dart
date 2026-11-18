import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_tags_section.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_tag_sheet.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Media tags in the viewer's sheets and the library filter (issue #1970),
/// on a real database.
void main() {
  final links = TagLinkRepository(TagScope.media);
  final item = MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    takenAt: DateTime(2026, 3, 12),
    createdAt: DateTime(2026, 3, 12),
    updatedAt: DateTime(2026, 3, 12),
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('diver-1', 'Ana', 1, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
      "VALUES ('m1', 'a', 'photo', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      "applies_to_dives, applies_to_media) VALUES "
      "('wreck', 'diver-1', 'Wreck', 0, 0, 0, 1), "
      "('night', 'diver-1', 'Night', 0, 0, 1, 0)",
    );
  });
  tearDown(() async => tearDownTestDatabase());

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides.cast(),
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return child;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<Set<String>> tagIds() async =>
      ((await links.getTagIdsByItem(['m1']))['m1'] ?? const <String>[]).toSet();

  testWidgets('the keyboard never covers the tag sheet\'s field (#4406)', (
    tester,
  ) async {
    // pump() sizes the view to 800 x 1200; the keyboard takes half of it.
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    final sitting = EditSession<PhotoRecord>(
      PhotoRecord(item: item, species: const [], people: const []),
    );
    addTearDown(sitting.dispose);
    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMediaTagSheet(context, item, sitting: sitting),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byType(TagInputWidget),
      matching: find.byType(TextField),
    );
    expect(tester.getBottomLeft(field).dy, lessThanOrEqualTo(1200 - 600));
  });

  testWidgets('the info card lists the stored tags', (tester) async {
    await pump(tester, Scaffold(body: MediaInfoTagsSection(item: item)));
    expect(find.text('No tags yet'), findsOneWidget);

    await tester.runAsync(() => links.replaceTags('m1', ['wreck']));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Show media tagged Wreck'), findsOneWidget);
    expect(find.text('No tags yet'), findsNothing);
  });

  testWidgets('the filter sheet offers media tags and applies them', (
    tester,
  ) async {
    final container = await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMediaLibraryFilterSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final wreck = find.byKey(const ValueKey('media_filter_tag_wreck'));
    expect(wreck, findsOneWidget);
    expect(
      find.byKey(const ValueKey('media_filter_tag_night')),
      findsNothing,
      reason: 'a dive-only tag',
    );
    // Drag the sheet open first, as a diver would: at its opening height
    // ensureVisible can leave the chip under the pinned Apply bar.
    await tester.drag(find.text('Attached to'), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(wreck);
    await tester.pumpAndSettle();
    await tester.tap(wreck);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).tagIds, {'wreck'});
  });

  group('the photo\'s lock (issue #4527)', () {
    EditSession<PhotoRecord> sittingOver() {
      final session = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      );
      addTearDown(session.dispose);
      return session;
    }

    testWidgets('with no sitting: the card offers no Edit tags', (
      tester,
    ) async {
      // Edit tags holds its change in a sitting; without one it would have
      // to write at once, outside the photo's lock.
      await pump(tester, Scaffold(body: MediaInfoTagsSection(item: item)));

      expect(find.byKey(const ValueKey('media_info_editTags')), findsNothing);
    });

    testWidgets('in a sitting: Edit tags opens the tag sheet', (tester) async {
      final sitting = sittingOver();
      await pump(
        tester,
        Scaffold(
          body: MediaInfoTagsSection(item: item, sitting: sitting),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('media_info_editTags')));
      await tester.pumpAndSettle();

      expect(find.byType(MediaTagSheet), findsOneWidget);
    });

    testWidgets('read only: the tags section offers no Edit tags', (
      tester,
    ) async {
      await pump(tester, MediaInfoTagsSection(item: item, readOnly: true));

      expect(find.byKey(const ValueKey('media_info_editTags')), findsNothing);
    });

    testWidgets('in a sitting: the section shows the held tags', (
      tester,
    ) async {
      final sitting = sittingOver();
      sitting.set(
        photoTagsField,
        MediaTagEdits.between(const [], [
          Tag(
            id: 'wreck',
            name: 'Wreck',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ]),
      );

      await pump(tester, MediaInfoTagsSection(item: item, sitting: sitting));

      expect(find.text('Wreck'), findsOneWidget);
    });

    testWidgets('in a sitting: the sheet holds a typed tag; no link written', (
      tester,
    ) async {
      final sitting = sittingOver();
      await pump(tester, MediaTagSheet(item: item, sitting: sitting));

      await tester.enterText(
        find.descendant(
          of: find.byType(TagInputWidget),
          matching: find.byType(TextField),
        ),
        'Funny',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final stored = await tester.runAsync(tagIds);
      expect(stored, isEmpty);
      expect(sitting.valueOf(photoTagsField).added.values.map((t) => t.name), [
        'Funny',
      ]);
      // The tag input refocuses on a short timer after a submit.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('in a sitting: the card redraws as the held tags change', (
      tester,
    ) async {
      final sitting = sittingOver();
      await pump(tester, MediaInfoTagsSection(item: item, sitting: sitting));
      expect(find.text('No tags yet'), findsOneWidget);

      sitting.set(
        photoTagsField,
        MediaTagEdits.between(const [], [
          Tag(
            id: 'wreck',
            name: 'Wreck',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wreck'), findsOneWidget);
    });

    testWidgets('a sitting that has ended: the card offers no Edit tags', (
      tester,
    ) async {
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      )..dispose();

      await pump(tester, MediaInfoTagsSection(item: item, sitting: sitting));

      expect(find.byKey(const ValueKey('media_info_editTags')), findsNothing);
    });

    testWidgets('a sitting that ended under the sheet: no tag is written', (
      tester,
    ) async {
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [], people: const []),
      );
      await pump(tester, MediaTagSheet(item: item, sitting: sitting));

      // The photo was deleted elsewhere, say: the sitting ends, then a tag
      // tick rebuilds the sheet.
      sitting.dispose();
      await tester.runAsync(() => links.replaceTags('m1', ['wreck']));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(TagInputWidget),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(await tester.runAsync(tagIds), {'wreck'});
    });
  });
}
