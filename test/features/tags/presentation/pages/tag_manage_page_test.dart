import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/pages/tag_manage_page.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _testStats = [
  TagStatistic(
    tag: Tag(
      id: 'tag1',
      diverId: 'diver1',
      name: 'Night Dive',
      colorHex: '#EF4444',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
    diveCount: 12,
  ),
  TagStatistic(
    tag: Tag(
      id: 'tag2',
      diverId: 'diver1',
      name: 'Photography',
      colorHex: '#3B82F6',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
    diveCount: 5,
  ),
];

// ---------------------------------------------------------------------------
// Mock notifiers
// ---------------------------------------------------------------------------

/// Mock TagListNotifier that returns data immediately without database access.
class _MockTagListNotifier extends StateNotifier<AsyncValue<List<Tag>>>
    implements TagListNotifier {
  _MockTagListNotifier(List<Tag> tags) : super(AsyncValue.data(tags));

  @override
  Future<void> refresh() async {}
  @override
  Future<Tag> addTag(Tag tag) async => tag;
  @override
  Future<Tag> getOrCreateTag(String name, {String? colorHex}) async {
    return Tag.create(id: 'new-tag', name: name, colorHex: colorHex);
  }

  @override
  Future<void> updateTag(Tag tag) async {}
  @override
  Future<void> deleteTag(String id) async {}
  @override
  Future<void> deleteTags(List<String> ids) async {}
  @override
  Future<void> mergeTags({
    required List<String> sourceTagIds,
    required String survivingTagId,
    required String name,
    required String? colorHex,
  }) async {}
  @override
  Future<void> setTagsForDive(String diveId, List<Tag> tags) async {}
  @override
  Future<void> addTagToDive(String diveId, String tagId) async {}
  @override
  Future<void> removeTagFromDive(String diveId, String tagId) async {}
}

/// Mock TagRepository used only for [tagRepositoryProvider] overrides.
class _MockTagRepository extends TagRepository {
  @override
  Future<int> getMergedDiveCount(List<String> tagIds) async => 0;

  @override
  Future<int> getTagUsageCount(String tagId) async => 0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<Tag> _tagsFromStats(List<TagStatistic> stats) =>
    stats.map((s) => s.tag).toList();

Widget _buildTestWidget({List<TagStatistic> stats = const []}) {
  return ProviderScope(
    overrides: [
      tagStatisticsProvider.overrideWith((ref) => Future.value(stats)),
      tagListNotifierProvider.overrideWith(
        (ref) => _MockTagListNotifier(_tagsFromStats(stats)),
      ),
      tagRepositoryProvider.overrideWithValue(_MockTagRepository()),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TagManagePage(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TagManagePage', () {
    testWidgets('renders tag list with names and usage counts', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      expect(find.text('Night Dive'), findsOneWidget);
      expect(find.text('Photography'), findsOneWidget);
      // Usage counts: "12 dives" and "5 dives"
      expect(find.text('12 dives'), findsOneWidget);
      expect(find.text('5 dives'), findsOneWidget);
    });

    testWidgets('shows empty state when no tags exist', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('No tags yet. Create one to get started.'),
        findsOneWidget,
      );
    });

    testWidgets('search bar filters visible tags', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      // Both tags visible initially
      expect(find.text('Night Dive'), findsOneWidget);
      expect(find.text('Photography'), findsOneWidget);

      // Type a search query that only matches "Night Dive"
      await tester.enterText(find.byType(TextField), 'Night');
      await tester.pumpAndSettle();

      expect(find.text('Night Dive'), findsOneWidget);
      expect(find.text('Photography'), findsNothing);
    });

    testWidgets('tapping a tag opens edit dialog', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // Edit dialog should appear
      expect(find.text('Edit Tag'), findsOneWidget);
      expect(find.text('Tag Name'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('FAB opens create dialog', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create Tag'), findsNWidgets(2));
      expect(find.text('Tag Name'), findsOneWidget);
      expect(find.text('Color'), findsOneWidget);
    });

    testWidgets('long-press enters selection mode', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      // Long press the first tag to enter selection mode
      await tester.longPress(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // Selection mode indicators: close button, "1 selected" text, checkboxes
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));

      // FAB should be hidden in selection mode
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('delete button shows confirmation with dive count', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      // Enter selection mode by long-pressing "Night Dive" (12 dives)
      await tester.longPress(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // Tap the delete icon in the app bar
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      // Confirmation dialog should show the tag name and dive count
      expect(find.text('Delete Tag?'), findsOneWidget);
      expect(find.textContaining('Night Dive'), findsWidgets);
      expect(find.textContaining('12 dives'), findsWidgets);
    });

    testWidgets('merge button disabled when fewer than 2 selected', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      // Enter selection mode with one tag
      await tester.longPress(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // Find the merge IconButton and verify it is disabled
      final mergeButton = find.byIcon(Icons.merge);
      expect(mergeButton, findsOneWidget);

      final iconButtonWidget = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.merge),
          matching: find.byType(IconButton),
        ),
      );
      expect(iconButtonWidget.onPressed, isNull);
    });

    testWidgets('merge button enabled when 2 tags selected', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      // Enter selection mode with first tag
      await tester.longPress(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // Select second tag by tapping
      await tester.tap(find.text('Photography'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);

      // Now merge button should be enabled
      final iconButtonWidget = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.merge),
          matching: find.byType(IconButton),
        ),
      );
      expect(iconButtonWidget.onPressed, isNotNull);
    });
  });
}
