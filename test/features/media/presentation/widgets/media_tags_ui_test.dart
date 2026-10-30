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

  testWidgets('the tag sheet saves a typed tag at once', (tester) async {
    await pump(tester, MediaTagSheet(item: item));

    await tester.enterText(
      find.descendant(
        of: find.byType(TagInputWidget),
        matching: find.byType(TextField),
      ),
      'Funny',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final stored = await tester.runAsync(() async {
      final ids = await tagIds();
      return ids;
    });
    expect(stored, hasLength(1));
    expect(find.text('Funny'), findsOneWidget);
    // The tag input refocuses on a short timer after a submit.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the info card lists the tags and offers Edit tags', (
    tester,
  ) async {
    await pump(tester, Scaffold(body: MediaInfoTagsSection(item: item)));
    expect(find.text('No tags yet'), findsOneWidget);

    await tester.runAsync(() => links.replaceTags('m1', ['wreck']));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Show media tagged Wreck'), findsOneWidget);
    expect(find.text('No tags yet'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('media_info_editTags')));
    await tester.pumpAndSettle();
    expect(find.byType(MediaTagSheet), findsOneWidget);
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
    await tester.ensureVisible(wreck);
    await tester.tap(wreck);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).tagIds, {'wreck'});
  });
}
