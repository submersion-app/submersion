import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_picker_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Builds a [TagStatistic] with the fields the picker actually reads.
TagStatistic _stat(String id, String name, int diveCount) => TagStatistic(
  tag: Tag(
    id: id,
    diverId: 'diver1',
    name: name,
    colorHex: '#3B82F6',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  ),
  diveCount: diveCount,
);

void main() {
  // Ordered the way tagStatisticsProvider returns them: most used first.
  final testStats = [
    _stat('tag1', 'Wreck', 42),
    _stat('tag2', 'Night', 31),
    _stat('tag3', 'Deco', 18),
    _stat('tag4', 'Training', 9),
  ];

  List<Tag>? picked;

  setUp(() => picked = null);

  Widget buildTestWidget({
    List<TagStatistic>? stats,
    Set<String> selectedTagIds = const {},
    Object? error,
    bool pending = false,
  }) {
    return ProviderScope(
      overrides: [
        tagStatisticsProvider.overrideWith((ref) {
          // A future that never completes keeps the sheet in its loading
          // state for as long as the test needs it.
          if (pending) return Completer<List<TagStatistic>>().future;
          if (error != null) return Future<List<TagStatistic>>.error(error);
          return Future.value(stats ?? testStats);
        }),
      ],
      child: MaterialApp(
        // Every assertion below matches an English label, so pin the
        // locale instead of inheriting the ambient platform one.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TagPickerSheet(
            scrollController: ScrollController(),
            selectedTagIds: selectedTagIds,
            onTagsPicked: (tags) => picked = tags,
          ),
        ),
      ),
    );
  }

  /// Tag names in the order the picker renders them.
  List<String> renderedTagNames(WidgetTester tester) => tester
      .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
      .map((tile) => ((tile.title as Text).data)!)
      .toList();

  group('TagPickerSheet', () {
    testWidgets('lists previously used tags most-used first', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(renderedTagNames(tester), ['Wreck', 'Night', 'Deco', 'Training']);
    });

    testWidgets('shows how many dives use each tag', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('42 dives'), findsOneWidget);
      expect(find.text('31 dives'), findsOneWidget);
    });

    testWidgets('hides tags already attached to the dive', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(selectedTagIds: {'tag2', 'tag4'}),
      );
      await tester.pumpAndSettle();

      expect(renderedTagNames(tester), ['Wreck', 'Deco']);
    });

    testWidgets('search narrows the list case-insensitively', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ni');
      await tester.pumpAndSettle();

      expect(renderedTagNames(tester), ['Night', 'Training']);
    });

    testWidgets('confirming returns every picked tag in one callback', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wreck'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deco'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add 2 tags'));
      await tester.pumpAndSettle();

      expect(picked?.map((t) => t.id).toList(), ['tag1', 'tag3']);
    });

    testWidgets('confirm button is disabled until a tag is picked', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('unpicking a tag drops it from the confirmed list', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wreck'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deco'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wreck'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add 1 tag'));
      await tester.pumpAndSettle();

      expect(picked?.map((t) => t.id).toList(), ['tag3']);
    });

    testWidgets('shows the empty state when no tags exist yet', (tester) async {
      await tester.pumpWidget(buildTestWidget(stats: []));
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        find.text('No tags yet. Type a tag name to create your first one.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the all-added state when every tag is attached', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(selectedTagIds: {'tag1', 'tag2', 'tag3', 'tag4'}),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('All tags are already added.'), findsOneWidget);
    });

    testWidgets('shows a no-matches state when the search excludes all tags', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('No tags match your search.'), findsOneWidget);
    });

    testWidgets('a load failure reports tags, not some other noun', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(error: Exception('boom')));
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.textContaining('Error loading tags'), findsOneWidget);
    });

    testWidgets('shows a spinner until the tag list resolves', (tester) async {
      await tester.pumpWidget(buildTestWidget(pending: true));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
