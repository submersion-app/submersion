import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_action.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The search row sits above every dive list state (#2773), including the
/// filtered empty state that used to replace the whole body.
class _MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _MockPaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<Widget> buildContent(
    DiveFilterState filter,
    List<DiveSummary> dives, {
    List<DiveSummary> jump = const [],
    void Function(String?)? onItemSelected,
  }) async {
    final base = await getBaseOverrides();
    return testApp(
      locale: const Locale('en'),
      overrides: [
        ...base,
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
        diveFilterProvider.overrideWith((ref) => filter),
        paginatedDiveListProvider.overrideWith(
          (ref) => _MockPaginatedNotifier(dives),
        ),
        queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
        diveJumpResultsProvider.overrideWith((ref, _) async => jump),
      ],
      child: DiveListContent(showAppBar: false, onItemSelected: onItemSelected),
    );
  }

  // Review Focus 3.
  testWidgets('the search row stays when nothing matches', (tester) async {
    await tester.pumpWidget(
      await buildContent(
        DiveFilterState(query: TextNode(['nomatch'])),
        const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(kDiveSearchFieldKey), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(kDiveSearchFieldKey));
    expect(field.controller!.text, 'nomatch');
  });

  // Code review: the empty state's Clear filters is the chip row's Clear
  // all by another name, so it offers the same Undo.
  testWidgets('Clear filters in the empty state offers Undo', (tester) async {
    await tester.pumpWidget(
      await buildContent(
        DiveFilterState(query: TextNode(['nomatch'])),
        const [],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Filters'));
    await tester.pump();
    expect(find.text('Undo'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('the row and chips sit above a filtered list', (tester) async {
    final dives = [
      DiveSummary.fromDive(
        Dive(id: 'd1', dateTime: DateTime(2026, 3, 15), diveNumber: 1),
      ),
    ];
    await tester.pumpWidget(
      await buildContent(const DiveFilterState(favoritesOnly: true), dives),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(kDiveSearchFieldKey), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Favorites'), findsOneWidget);
  });

  final summaries = [
    DiveSummary.fromDive(
      Dive(id: 'd1', dateTime: DateTime(2026, 3, 15), diveNumber: 1),
    ),
  ];

  Future<void> searchInSelectionMode(WidgetTester tester) async {
    await tester.tap(find.byKey(kDiveSearchActionKey));
    await tester.pumpAndSettle();
    // "Select items" lives in the overflow menu (#2783).
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(kDiveSearchDebounce);
    await tester.pumpAndSettle();
  }

  // Code review: a jump row is "Jump to dive", whatever mode the list is in.
  testWidgets('a jump row opens its dive in selection mode too', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      await buildContent(
        const DiveFilterState(),
        summaries,
        jump: summaries,
        onItemSelected: (id) => opened = id,
      ),
    );
    await tester.pumpAndSettle();
    await searchInSelectionMode(tester);
    await tester.tap(find.byKey(const ValueKey('dive-jump-d1')));
    await tester.pump();
    expect(opened, 'd1');
  });

  // Code review: Esc during selection leaves selection, as it does in the
  // list, rather than throwing the search away.
  testWidgets('Esc in the field during selection keeps the search', (
    tester,
  ) async {
    await tester.pumpWidget(
      await buildContent(const DiveFilterState(), summaries, jump: summaries),
    );
    await tester.pumpAndSettle();
    await searchInSelectionMode(tester);
    expect(find.byType(SelectionAppBar), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SelectionAppBar), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveListContent)),
    );
    expect(container.read(diveFilterProvider).query, TextNode(['manta']));
  });
}
