import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Stands in for [PaginatedDiveListNotifier], counting page requests and
/// letting a test replay the loading flag a real page load flips.
class _FakePaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _FakePaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: true)),
      );

  int loadNextPageCalls = 0;

  @override
  Future<void> loadNextPage() async => loadNextPageCalls++;

  /// What [PaginatedDiveListNotifier.loadNextPage] does before its query
  /// runs: the same rows, with the trailing row now spinning.
  void startLoadingMore() {
    state = AsyncValue.data(state.value!.copyWith(isLoadingMore: true));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DiveSummary _summary(int n) => DiveSummary(
  id: 'd$n',
  diveNumber: n,
  name: 'Dive $n',
  dateTime: DateTime(2024, 1, 1).add(Duration(days: n)),
  sortTimestamp: DateTime(
    2024,
    1,
    1,
  ).add(Duration(days: n)).millisecondsSinceEpoch,
);

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<_FakePaginatedNotifier> _pumpList(
  WidgetTester tester,
  int rowCount,
) async {
  final notifier = _FakePaginatedNotifier([
    for (var i = rowCount; i >= 1; i--) _summary(i),
  ]);
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...base,
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
        highlightedDiveIdProvider.overrideWith((ref) => null),
        paginatedDiveListProvider.overrideWith((ref) => notifier),
      ],
      child: const DiveListContent(showAppBar: true),
    ),
  );
  // hasMore keeps a spinner running at the end of the list, which never lets
  // pumpAndSettle settle.
  await _pumpFrames(tester);
  return notifier;
}

void main() {
  group('fast scrolling a large log (#3506)', () {
    testWidgets('a freshly opened list does not page in the background', (
      tester,
    ) async {
      final notifier = await _pumpList(tester, 200);
      await _pumpFrames(tester);
      expect(
        notifier.loadNextPageCalls,
        0,
        reason:
            'the loader row is built at once wherever it sits; treating that '
            'build as "on screen" streamed every page of the log in, one '
            'hitch after another, from the moment the list opened',
      );
    });

    testWidgets('the next page is requested well before the loaded rows run '
        'out', (tester) async {
      final notifier = await _pumpList(tester, 200);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position;

      // Several viewports from the end: nothing to fetch yet.
      position.jumpTo(
        position.maxScrollExtent - 5 * position.viewportDimension,
      );
      await tester.pump();
      expect(notifier.loadNextPageCalls, 0);

      // One and a half viewports from the end, so neither the old 200 px
      // margin nor the trailing loader row (built only once it is inside the
      // viewport plus its cache extent) asks for the page. A fling covers that
      // distance in a few frames, so the request has to go out here for the
      // rows to be ready when the scroll arrives.
      position.jumpTo(
        position.maxScrollExtent - 1.5 * position.viewportDimension,
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        notifier.loadNextPageCalls,
        greaterThan(0),
        reason:
            'a fast scroll must not reach the end of the loaded rows and '
            'stall while the next page is fetched',
      );
    });

    testWidgets('starting a page load does not rebuild the loaded rows', (
      tester,
    ) async {
      final notifier = await _pumpList(tester, 60);
      final rowBefore = tester.widget(find.byType(DiveListItem).first);

      notifier.startLoadingMore();
      await tester.pump();

      expect(
        identical(tester.widget(find.byType(DiveListItem).first), rowBefore),
        isTrue,
        reason:
            'only the trailing loader row depends on isLoadingMore; every '
            'card on screen re-rendering for it is a dropped frame mid-fling',
      );
    });

    testWidgets('the trailing loader row still follows the loading flag', (
      tester,
    ) async {
      final notifier = await _pumpList(tester, 60);
      notifier.loadNextPageCalls = 0;
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await _pumpFrames(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // A page that comes back empty drops hasMore while a load is flagged:
      // the row stays until the flag clears too, as before.
      notifier.state = AsyncValue.data(
        notifier.state.value!.copyWith(hasMore: false, isLoadingMore: true),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      notifier.state = AsyncValue.data(
        notifier.state.value!.copyWith(isLoadingMore: false),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
