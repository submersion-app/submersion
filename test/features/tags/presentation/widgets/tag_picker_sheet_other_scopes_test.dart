import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The tag picker beyond its own scope (issue #4406): a diver whose tags were
/// all made on dives or sites must still find them when tagging a photo, and
/// the picker must be able to create the tag it says to type.
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
      "applies_to_dives, applies_to_sites, applies_to_media) VALUES "
      "('wreck', 'diver-1', 'Wreck', 0, 0, 1, 0, 0), "
      "('reef', 'diver-1', 'Reef', 0, 0, 0, 1, 0), "
      "('macro', 'diver-1', 'Macro', 0, 0, 0, 0, 1)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async => tearDownTestDatabase());

  List<Tag>? picked;

  setUp(() => picked = null);

  Widget harness({
    TagScope scope = TagScope.media,
    Set<String> selectedTagIds = const {},
  }) => ProviderScope(
    overrides: [
      currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TagPickerSheet(
          scrollController: ScrollController(),
          selectedTagIds: selectedTagIds,
          onTagsPicked: (tags) => picked = tags,
          scope: scope,
        ),
      ),
    ),
  );

  /// Tag names in the order the picker renders them.
  List<String> renderedTagNames(WidgetTester tester) => tester
      .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
      .map((tile) => ((tile.title as Text).data)!)
      .toList();

  Future<Tag> storedTag(String id) async =>
      (await TagRepository().getTagById(id))!;

  group('tags from other scopes', () {
    testWidgets('are listed under Other tags, after this scope\'s tags', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      // Unused elsewhere too, so they keep the provider's by-name order.
      expect(renderedTagNames(tester), ['Macro', 'Reef', 'Wreck']);
      expect(find.text('Other tags'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Other tags')).dy,
        greaterThan(tester.getTopLeft(find.text('Macro')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Other tags')).dy,
        lessThan(tester.getTopLeft(find.text('Reef')).dy),
      );
    });

    testWidgets('say where each one is used', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('For: Dives'), findsOneWidget);
      expect(find.text('For: Sites'), findsOneWidget);
    });

    testWidgets('show instead of the empty state when this scope has none', (
      tester,
    ) async {
      final db = DatabaseService.instance.database;
      await db.customStatement("DELETE FROM tags WHERE id = 'macro'");

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(renderedTagNames(tester), ['Reef', 'Wreck']);
      expect(
        find.text('No tags yet. Type a tag name to create your first one.'),
        findsNothing,
      );
    });

    testWidgets('are narrowed by the search too', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ree');
      await tester.pumpAndSettle();

      expect(renderedTagNames(tester), ['Reef']);
    });

    testWidgets('picking one widens it to this scope before reporting it', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wreck'));
      await tester.tap(find.text('Macro'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add 2 tags'));
      await tester.pumpAndSettle();

      expect(picked!.map((t) => t.id), ['macro', 'wreck']);
      expect(picked!.every((t) => t.appliesTo(TagScope.media)), isTrue);

      final wreck = await tester.runAsync(() => storedTag('wreck'));
      expect(wreck!.scopes, {TagScope.dives, TagScope.media});
    });
  });

  group('creating a tag', () {
    testWidgets('a new name offers to create it', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Épave');
      await tester.pumpAndSettle();

      expect(find.text('Create "Épave"'), findsOneWidget);
      expect(find.text('No tags match your search.'), findsNothing);
    });

    testWidgets('no create row before anything is typed', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.textContaining('Create "'), findsNothing);
    });

    testWidgets('a name any tag already has offers no create row', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      // Wreck is a dive tag; it is listed below, ready to tick.
      await tester.enterText(find.byType(TextField), ' wreck ');
      await tester.pumpAndSettle();

      expect(find.textContaining('Create "'), findsNothing);
      expect(renderedTagNames(tester), ['Wreck']);
    });

    testWidgets('creating adds the new tag with the ticked ones', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Macro'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Épave');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create "Épave"'));
      await tester.pumpAndSettle();

      expect(picked!.map((t) => t.name), ['Macro', 'Épave']);
      final created = picked!.last;
      expect(created.appliesTo(TagScope.media), isTrue);

      final stored = await tester.runAsync(() => storedTag(created.id));
      expect(stored!.name, 'Épave');
      expect(stored.appliesTo(TagScope.media), isTrue);
    });
  });

  group('the keyboard', () {
    testWidgets('never covers the picker\'s confirm button', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
            validatedCurrentDiverIdProvider.overrideWith(
              (ref) async => 'diver-1',
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTagPickerSheet(
                    context,
                    selected: const [],
                    onPicked: (_) {},
                    scope: TagScope.media,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'Add tags');
      expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(800 - 300));
    });
  });
}
