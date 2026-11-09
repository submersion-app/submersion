import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/widgets/expandable_ranking_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #4385: a ranking shows its top ten, and "Show all" opens the rest
/// in place instead of a count of what is hidden.
List<RankingItem> _items(int n) => [
  for (var i = 0; i < n; i++)
    RankingItem(id: 'id$i', name: 'Name $i', count: 100 - i),
];

Future<void> _pump(
  WidgetTester tester,
  List<RankingItem> items, {
  void Function(RankingItem)? onItemTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The assertions read English labels, so the locale is pinned rather
      // than left to the host.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExpandableRankingList(
            items: items,
            countLabel: 'dives',
            onItemTap: onItemTap,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ten or fewer rows show them all with no button', (tester) async {
    await _pump(tester, _items(10));

    expect(find.text('Name 9'), findsOneWidget);
    expect(find.text('Show all'), findsNothing);
    expect(find.text('Show less'), findsNothing);
  });

  testWidgets('more than ten rows show the top ten and Show all', (
    tester,
  ) async {
    await _pump(tester, _items(23));

    expect(find.text('Name 9'), findsOneWidget);
    expect(find.text('Name 10'), findsNothing);
    expect(find.text('Show all'), findsOneWidget);
    // The hidden rows are no longer summed up in a count line.
    expect(find.textContaining('more'), findsNothing);
  });

  testWidgets('Show all opens every row, Show less closes them again', (
    tester,
  ) async {
    await _pump(tester, _items(23));

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();

    expect(find.text('Name 22'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);
    // The rank keeps counting past the first ten.
    expect(find.text('23'), findsOneWidget);

    await tester.ensureVisible(find.text('Show less'));
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    expect(find.text('Name 10'), findsNothing);
    expect(find.text('Show all'), findsOneWidget);
  });

  testWidgets('a row past the first ten still opens on tap', (tester) async {
    RankingItem? tapped;
    await _pump(tester, _items(12), onItemTap: (item) => tapped = item);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Name 11'));
    await tester.tap(find.text('Name 11'));

    expect(tapped?.id, 'id11');
  });

  testWidgets('no rows show the empty state and no button', (tester) async {
    await _pump(tester, const []);

    expect(find.byIcon(Icons.leaderboard_outlined), findsOneWidget);
    expect(find.text('Show all'), findsNothing);
  });
}
