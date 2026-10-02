import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    List<DiveSummary> dives,
  ) async {
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
        diveJumpResultsProvider.overrideWith((ref, _) async => const []),
      ],
      child: const DiveListContent(showAppBar: false),
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
}
