import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/pages/tag_manage_page.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_merge_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/selection_leading.dart';

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
  final List<Tag> added = [];
  final List<Tag> updated = [];

  @override
  Future<void> refresh() async {}
  @override
  Future<Tag> addTag(Tag tag) async {
    added.add(tag);
    return tag;
  }

  @override
  Future<Tag> getOrCreateTag(
    String name, {
    String? colorHex,
    TagScope scope = TagScope.dives,
  }) async {
    return Tag.create(
      id: 'new-tag',
      name: name,
      colorHex: colorHex,
      scope: scope,
    );
  }

  @override
  Future<void> updateTag(Tag tag) async => updated.add(tag);
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
  TagRepository? repository,
}) {
  return ProviderScope(
    overrides: [
      tagStatisticsProvider.overrideWith((ref) => Future.value(stats)),
      tagListNotifierProvider.overrideWith(
        (ref) => notifier ?? _MockTagListNotifier(_tagsFromStats(stats)),
      ),
      tagRepositoryProvider.overrideWithValue(
        repository ?? _MockTagRepository(),
      ),
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

/// Like [_buildTestWidget], but under a GoRouter with stub dive and site
/// lists, so a test can prove a row tap does not navigate. [initialFilter]
/// seeds the dive filter the diver had before opening Manage Tags.
Widget _buildRoutedTestWidget({
  required List<TagStatistic> stats,
  DiveFilterState initialFilter = const DiveFilterState(),
}) {
  final router = GoRouter(
    initialLocation: '/tags',
    routes: [
      GoRoute(
        path: '/tags',
        builder: (context, state) => const TagManagePage(),
      ),
      GoRoute(
        path: '/dives',
        builder: (context, state) =>
            const Scaffold(body: Text('DIVES_LIST_PAGE')),
      ),
      GoRoute(
        path: '/sites',
        builder: (context, state) =>
            const Scaffold(body: Text('SITES_LIST_PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      tagStatisticsProvider.overrideWith((ref) => Future.value(stats)),
      tagListNotifierProvider.overrideWith(
        (ref) => _MockTagListNotifier(_tagsFromStats(stats)),
      ),
      tagRepositoryProvider.overrideWithValue(_MockTagRepository()),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      diveFilterProvider.overrideWith((ref) => initialFilter),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('the edit button opens the edit dialog', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tag_edit_tag1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Tag'), findsOneWidget);
      expect(find.text('Tag Name'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // The dialog edits the tag whose button was tapped.
      expect(find.widgetWithText(TextField, 'Night Dive'), findsOneWidget);
    });

    testWidgets('the edit button is hidden while selecting', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tag_edit_tag1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      // A row tap toggles the row during selection, so a second tap target
      // inside the row that does something else would be a trap.
      expect(find.byKey(const ValueKey('tag_edit_tag1')), findsNothing);
      expect(find.text('12 dives'), findsOneWidget);
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

    testWidgets('long-press on a tag does nothing outside selection', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Night Dive'));
      await tester.pumpAndSettle();

      // The edit button is the one way to edit a tag, and a long press must
      // not become a way into multi-select either.
      expect(find.text('Edit Tag'), findsNothing);
      expect(find.text('1 selected'), findsNothing);
      // Selection checkboxes only: the tag edit dialog has scope checkboxes
      // of its own (issue #1765).
      expect(
        find.descendant(
          of: find.byType(SelectionLeading),
          matching: find.byType(Checkbox),
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('enter_selection')), findsOneWidget);
    });

    testWidgets('long-press while selecting toggles the row', (tester) async {
      await tester.pumpWidget(_buildTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Night Dive'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Edit Tag'), findsNothing);
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

  group('a row tap stays on the page', () {
    testWidgets('a row tap neither navigates nor edits', (tester) async {
      await tester.pumpWidget(
        _buildRoutedTestWidget(
          stats: _testStats,
          initialFilter: const DiveFilterState(siteId: 'site-1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Night Dive'));
      await tester.pumpAndSettle();

      expect(find.text('DIVES_LIST_PAGE'), findsNothing);
      expect(find.text('Edit Tag'), findsNothing);
      expect(find.text('1 selected'), findsNothing);
      // The dive list filter is the diver's own and a tap here leaves it be.
      final container = ProviderScope.containerOf(
        tester.element(find.text('Night Dive')),
      );
      final filter = container.read(diveFilterProvider);
      expect(filter.tagIds, isEmpty);
      expect(filter.siteId, 'site-1');
    });

    group('a tag used on sites (issue #1765)', () {
      TagStatistic siteStat({required bool forDives}) => TagStatistic(
        tag: Tag(
          id: 'site-tag',
          name: 'To try',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          appliesToDives: forDives,
          appliesToSites: true,
        ),
        diveCount: forDives ? 2 : 0,
        siteCount: 3,
      );

      Future<void> tapAndExpectStayPut(WidgetTester tester) async {
        await tester.tap(find.text('To try'));
        await tester.pumpAndSettle();

        expect(find.text('SITES_LIST_PAGE'), findsNothing);
        expect(find.text('DIVES_LIST_PAGE'), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.text('To try')),
        );
        expect(container.read(siteFilterProvider).tagIds, isEmpty);
        expect(container.read(diveFilterProvider).tagIds, isEmpty);
      }

      testWidgets('a sites-only tag row stays on the page', (tester) async {
        await tester.pumpWidget(
          _buildRoutedTestWidget(stats: [siteStat(forDives: false)]),
        );
        await tester.pumpAndSettle();

        await tapAndExpectStayPut(tester);
      });

      testWidgets('a tag used on dives and sites stays on the page', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildRoutedTestWidget(stats: [siteStat(forDives: true)]),
        );
        await tester.pumpAndSettle();

        await tapAndExpectStayPut(tester);
      });
    });

    testWidgets('a row tap while selecting toggles it and stays put', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRoutedTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Night Dive'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('DIVES_LIST_PAGE'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Night Dive')),
      );
      expect(container.read(diveFilterProvider).tagIds, isEmpty);
    });

    testWidgets('the edit button edits without leaving the page', (
      tester,
    ) async {
      await tester.pumpWidget(_buildRoutedTestWidget(stats: _testStats));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tag_edit_tag2')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Tag'), findsOneWidget);
      expect(find.text('DIVES_LIST_PAGE'), findsNothing);
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

  group('a tag dialog closes only once its save lands (#1907)', () {
    // Save used to drop its write: create closed at once and edit's Future
    // went unobserved, so a failure gave no feedback and reached the zone
    // unattributed.

    const errorText = 'Something went wrong. Please try again.';

    // Inside the dialog, not a SnackBar: the page's SnackBar renders under
    // the dialog's barrier, dimmed and out of reach.
    final dialogError = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(errorText),
    );

    TextButton button(WidgetTester tester, String label) =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, label));

    Future<void> openCreate(WidgetTester tester, String name) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, name);
    }

    Future<void> openEdit(WidgetTester tester, String name) async {
      await tester.tap(find.byKey(const ValueKey('tag_edit_tag1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Night Dive'),
        name,
      );
    }

    testWidgets('a failed edit shows an error and keeps the edits', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(
          stats: _testStats,
          notifier: _FailingSaveTagListNotifier(_tagsFromStats(_testStats)),
        ),
      );
      await tester.pumpAndSettle();

      await openEdit(tester, 'Night Dive Renamed');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(dialogError, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Edit Tag'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Night Dive Renamed'),
        findsOneWidget,
      );
      expect(button(tester, 'Save').onPressed, isNotNull, reason: 'retry');
    });

    testWidgets('a failed create shows an error and keeps the dialog open', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(
          stats: _testStats,
          notifier: _FailingSaveTagListNotifier(_tagsFromStats(_testStats)),
        ),
      );
      await tester.pumpAndSettle();

      await openCreate(tester, 'Wreck');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(dialogError, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Wreck'), findsOneWidget);
      expect(button(tester, 'Save').onPressed, isNotNull, reason: 'retry');
    });

    testWidgets('a create holds the dialog until the tag is saved', (
      tester,
    ) async {
      final notifier = _GatedSaveTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await openCreate(tester, 'Wreck');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();

      // Mid-save: still open, and neither button can start a second write.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(button(tester, 'Save').onPressed, isNull);
      expect(button(tester, 'Cancel').onPressed, isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();

      notifier.gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(notifier.added.map((t) => t.name), ['Wreck']);
      expect(find.text(errorText), findsNothing);
    });

    testWidgets('an edit disables both buttons until its save lands', (
      tester,
    ) async {
      final notifier = _GatedSaveTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await openEdit(tester, 'Night Dive Renamed');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();

      expect(find.text('Edit Tag'), findsOneWidget);
      expect(button(tester, 'Save').onPressed, isNull);
      expect(button(tester, 'Cancel').onPressed, isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();

      notifier.gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(notifier.updated.map((t) => t.name), ['Night Dive Renamed']);
    });

    testWidgets('a create saves the chosen color and scope', (tester) async {
      final notifier = _MockTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await openCreate(tester, 'To try');
      await tester.tap(find.bySemanticsLabel('Select color #22C55E'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for sites'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for dives'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      final created = notifier.added.single;
      expect(created.name, 'To try');
      expect(created.colorHex, '#22C55E');
      expect(created.appliesToDives, isFalse);
      expect(created.appliesToSites, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Cancel closes either dialog without saving', (tester) async {
      final notifier = _MockTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await openCreate(tester, 'Wreck');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await openEdit(tester, 'Night Dive Renamed');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      expect(notifier.added, isEmpty);
      expect(notifier.updated, isEmpty);
    });

    testWidgets('a retry clears the error while it runs', (tester) async {
      final notifier = _FailOnceTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await openEdit(tester, 'Night Dive Renamed');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(dialogError, findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();
      expect(dialogError, findsNothing, reason: 'the retry is under way');

      notifier.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(notifier.updated.map((t) => t.name), ['Night Dive Renamed']);
    });

    testWidgets('two taps in one frame save once', (tester) async {
      final notifier = _GatedSaveTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await openCreate(tester, 'Wreck');
      // No pump between: the button still holds the callback built before
      // saving flipped, so only a check inside the callback stops the second.
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();

      notifier.gate.complete();
      await tester.pumpAndSettle();
      expect(notifier.added.map((t) => t.name), ['Wreck']);
    });

    testWidgets('a save in flight cannot be dismissed, so a failure keeps '
        'the edits', (tester) async {
      final notifier = _GatedSaveTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(stats: _testStats, notifier: notifier),
      );
      await tester.pumpAndSettle();

      await openEdit(tester, 'Night Dive Renamed');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();

      // The barrier, Escape and Back all ask the route before popping it.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      // Long enough for any dismissal to finish its exit animation.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Edit Tag'), findsOneWidget);

      notifier.gate.completeError(StateError('update failed'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(dialogError, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.widgetWithText(TextField, 'Night Dive Renamed'),
        findsOneWidget,
      );

      // Once the save has settled the dialog dismisses as usual.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Edit Tag'), findsNothing);
    });

    testWidgets('an edit writes the values the diver saved, not later ones', (
      tester,
    ) async {
      // Turning dives off asks for usage first; hold that read open to act
      // in the gap between tapping Save and the write.
      final repository = _GatedUsageTagRepository();
      final notifier = _MockTagListNotifier(_tagsFromStats(_testStats));
      await tester.pumpWidget(
        _buildTestWidget(
          stats: _testStats,
          notifier: notifier,
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tag_edit_tag1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for sites'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for dives'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();

      // Mid-save edits the confirmation never saw.
      await tester.tap(find.bySemanticsLabel('Select color #22C55E'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Use for dives'));
      await tester.pump();

      repository.usage.complete((dives: 0, sites: 0));
      await tester.pumpAndSettle();

      final saved = notifier.updated.single;
      expect(saved.colorHex, '#EF4444');
      expect(saved.appliesToDives, isFalse);
      expect(saved.appliesToSites, isTrue);
    });
  });
}

/// A notifier whose first edit save fails and whose second waits on [gate],
/// so a test can watch a retry while it is in flight.
class _FailOnceTagListNotifier extends _MockTagListNotifier {
  _FailOnceTagListNotifier(super.tags);

  final Completer<void> gate = Completer<void>();
  bool _failed = false;

  @override
  Future<void> updateTag(Tag tag) async {
    if (!_failed) {
      _failed = true;
      throw StateError('update failed for ${tag.id}');
    }
    updated.add(tag);
    await gate.future;
  }
}

/// A repository whose usage read waits on [usage], so a test can act while
/// the narrowing check is in flight.
class _GatedUsageTagRepository extends _MockTagRepository {
  final Completer<({int dives, int sites})> usage = Completer();

  @override
  Future<({int dives, int sites})> getTagUsage(String tagId) => usage.future;
}

/// A notifier whose saves fail, as a database or sync failure would.
class _FailingSaveTagListNotifier extends _MockTagListNotifier {
  _FailingSaveTagListNotifier(super.tags);

  @override
  Future<Tag> addTag(Tag tag) async =>
      throw StateError('create failed for ${tag.name}');

  @override
  Future<void> updateTag(Tag tag) async =>
      throw StateError('update failed for ${tag.id}');
}

/// A notifier whose saves wait on [gate], so a test can act mid-save.
class _GatedSaveTagListNotifier extends _MockTagListNotifier {
  _GatedSaveTagListNotifier(super.tags);

  final Completer<void> gate = Completer<void>();

  @override
  Future<Tag> addTag(Tag tag) async {
    added.add(tag);
    await gate.future;
    return tag;
  }

  @override
  Future<void> updateTag(Tag tag) async {
    updated.add(tag);
    await gate.future;
  }
}
