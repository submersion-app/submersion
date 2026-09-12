import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/pages/tag_manage_page.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_merge_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/selection_contract.dart';

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

  /// What the bulk paths actually asked for, so an outcome assertion is
  /// backed by real work rather than only by the bar disappearing.
  final List<String> deleted = [];
  final List<List<String>> bulkDeleted = [];

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
  Future<void> deleteTag(String id) async => deleted.add(id);
  @override
  Future<void> deleteTags(List<String> ids) async => bulkDeleted.add(ids);
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

Widget _buildTestWidget({
  List<TagStatistic> stats = const [],
  _MockTagListNotifier? notifier,
  MockSettingsNotifier? settingsNotifier,
}) {
  return ProviderScope(
    overrides: [
      tagStatisticsProvider.overrideWith((ref) => Future.value(stats)),
      tagListNotifierProvider.overrideWith(
        (ref) => notifier ?? _MockTagListNotifier(_tagsFromStats(stats)),
      ),
      tagRepositoryProvider.overrideWithValue(_MockTagRepository()),
      settingsProvider.overrideWith(
        (ref) => settingsNotifier ?? MockSettingsNotifier(),
      ),
    ],
    child: const MaterialApp(
      // flutter_test resolves against the HOST machine's locale list, so an
      // unpinned MaterialApp renders translated on a non-English machine and
      // every English literal here -- including the contract's "n selected" --
      // stops matching.
      locale: Locale('en'),
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
  group('auto-tag imports switch', () {
    testWidgets('reflects the on default from settings', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('reflects an off value from settings', (tester) async {
      final settingsNotifier = MockSettingsNotifier(
        const AppSettings(autoTagImports: false),
      );
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, settingsNotifier: settingsNotifier),
      );
      await tester.pumpAndSettle();

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isFalse);
    });

    testWidgets('toggling it updates settings', (tester) async {
      final settingsNotifier = MockSettingsNotifier();
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, settingsNotifier: settingsNotifier),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(settingsNotifier.state.autoTagImports, isFalse);
    });

    testWidgets('is hidden while a bulk selection is active', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsNothing);
    });
  });

  group('selection contract', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      await verifySelectionContract(
        tester,
        build: () => _buildTestWidget(stats: _testStats),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        rowRoot: find.ancestor(
          of: find.text('Night Dive'),
          matching: find.byType(ListTile),
        ),
        firstRow: find.text('Night Dive'),
        applyFilter: (tester) async {
          // Type into the real search field. Tags previously hid this field
          // during selection and never pruned, so a hidden tag stayed checked.
          await tester.enterText(find.byType(TextField).first, 'Night');
          await tester.pump();
        },
        visibleAfterFilter: 1,
      );
    });
  });

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

    testWidgets('Select button enters selection mode', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // Selection mode indicators: close button, "1 selected" text, checkboxes
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));

      // FAB should be hidden in selection mode
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('long-press on a tag does not enter selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Night Dive'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const ValueKey('enter_selection')), findsOneWidget);
    });

    testWidgets('delete button shows confirmation with dive count', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      // Enter selection mode and check "Night Dive" (12 dives)
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // Delete lives behind the selection bar's overflow menu.
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_delete')));
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
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // Keyed by SelectionAppBar, so this no longer depends on which glyph
      // merge happens to use.
      final mergeButton = find.byKey(const ValueKey('selection_action_merge'));
      expect(mergeButton, findsOneWidget);
      expect(tester.widget<IconButton>(mergeButton).onPressed, isNull);
    });

    testWidgets('merge button enabled when 2 tags selected', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      // Enter selection mode with first tag
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // Select second tag by tapping
      await tester.tap(find.text('Photography'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);

      // Now merge button should be enabled
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('selection_action_merge')),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  group('a bulk action returns the diver to the normal list', () {
    // #1262. This surface used to call _exitSelectionMode() inside each
    // handler; the exit now travels back to SelectionAppBar as a
    // BulkActionOutcome, so these cover the decision that replaced it.

    Future<void> enterSelection(WidgetTester tester, List<String> names) async {
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      for (final name in names) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
    }

    /// Delete sits in the overflow on every surface, never inline.
    Future<void> openDelete(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_delete')));
      await tester.pumpAndSettle();
    }

    testWidgets('deleting several tags ends selection mode', (tester) async {
      final notifier = _MockTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await enterSelection(tester, ['Night Dive', 'Photography']);
      expect(find.text('2 selected'), findsOneWidget);

      await openDelete(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(notifier.bulkDeleted, [
        ['tag1', 'tag2'],
      ]);
      expect(
        find.byKey(const ValueKey('selection_exit')),
        findsNothing,
        reason: 'a completed delete must return the diver to the tag list',
      );
    });

    testWidgets('cancelling a multi-tag delete keeps the selection', (
      tester,
    ) async {
      final notifier = _MockTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await enterSelection(tester, ['Night Dive', 'Photography']);
      await openDelete(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(notifier.bulkDeleted, isEmpty);
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('deleting a single tag ends selection mode', (tester) async {
      final notifier = _MockTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      // One checked row takes the single-tag branch, which names the tag and
      // its dive count rather than counting a selection.
      await enterSelection(tester, ['Night Dive']);
      await openDelete(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(notifier.deleted, ['tag1']);
      expect(find.byKey(const ValueKey('selection_exit')), findsNothing);
    });

    testWidgets('cancelling a single-tag delete keeps the selection', (
      tester,
    ) async {
      final notifier = _MockTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await enterSelection(tester, ['Night Dive']);
      await openDelete(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(notifier.deleted, isEmpty);
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('dismissing the merge sheet keeps the selection', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await enterSelection(tester, ['Night Dive', 'Photography']);
      await tester.tap(find.byKey(const ValueKey('selection_action_merge')));
      await tester.pumpAndSettle();
      expect(find.byType(TagMergeSheet), findsOneWidget);

      // Tapping the barrier dismisses the sheet with no result, which is the
      // diver changing their mind rather than a merge.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(TagMergeSheet), findsNothing);
      expect(find.text('2 selected'), findsOneWidget);
    });
  });
}
