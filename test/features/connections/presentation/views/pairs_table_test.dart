import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_colors.dart';
import 'package:submersion/features/connections/presentation/views/pairs_table.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import 'package:submersion/features/connections/presentation/views/table_parts.dart';
import 'package:submersion/features/connections/presentation/canvas/connection_kind_icons.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

final _graph = ConnectionGraph(
  nodes: [
    ConnectionNode(ref: _b('ann'), label: 'Ann', diveCount: 9),
    ConnectionNode(ref: _b('bob'), label: 'Bob', diveCount: 4),
    ConnectionNode(ref: _b('cy'), label: 'Cy', diveCount: 2),
  ],
  edges: [
    ConnectionEdge(
      source: _b('ann'),
      target: _b('bob'),
      weight: 2,
      firstDiveAt: DateTime.utc(2020),
      lastDiveAt: DateTime.utc(2021),
    ),
    ConnectionEdge(
      source: _b('ann'),
      target: _b('cy'),
      weight: 7,
      firstDiveAt: DateTime.utc(2020),
      lastDiveAt: DateTime.utc(2024),
    ),
  ],
);

Future<List<GraphSelection?>> _pump(
  WidgetTester tester, {
  double width = 400,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picked = <GraphSelection?>[];
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: PairsTable(
              graph: _graph,
              colors: const ConnectionKindColors({}, Colors.grey),
              selection: null,
              onSelect: picked.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  // Dates are formatted through Intl.defaultLocale, a process global that
  // another file in the same isolate may have changed; pin it and put it back.
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('rows start by shared dives, strongest first', (tester) async {
    await _pump(tester);
    final first = tester.getTopLeft(find.text('Cy')).dy;
    final second = tester.getTopLeft(find.text('Bob')).dy;
    expect(first, lessThan(second));
  });

  testWidgets('tapping a header sorts by it, again reverses', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('sort-b')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Bob')).dy,
      lessThan(tester.getTopLeft(find.text('Cy')).dy),
    );
    await tester.tap(find.byKey(const ValueKey('sort-b')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Cy')).dy,
      lessThan(tester.getTopLeft(find.text('Bob')).dy),
    );
  });

  testWidgets('tapping a row selects that pair', (tester) async {
    final picked = await _pump(tester);
    await tester.tap(find.text('Cy'));
    expect(picked.single, EdgeSelection(_b('ann'), _b('cy')));
  });

  testWidgets(
    'a sort on a hidden column falls back to the default until widened',
    (tester) async {
      bool above(String a, String b) =>
          tester.getTopLeft(find.text(a)).dy <
          tester.getTopLeft(find.text(b)).dy;
      Finder arrowOn(String column) => find.descendant(
        of: find.byKey(ValueKey('sort-$column')),
        matching: find.byType(Icon),
      );

      await _pump(tester, width: 900);
      await tester.tap(find.byKey(const ValueKey('sort-first')));
      await tester.pumpAndSettle();
      expect(above('Bob', 'Cy'), isTrue, reason: 'first shared, ties by name');

      await _pump(tester);
      expect(above('Cy', 'Bob'), isTrue, reason: 'shared dives, most first');
      expect(arrowOn('shared'), findsOneWidget);

      await _pump(tester, width: 900);
      expect(above('Bob', 'Cy'), isTrue, reason: 'the choice comes back');
      expect(arrowOn('first'), findsOneWidget);

      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('sort-shared')));
      await tester.pumpAndSettle();
      expect(
        above('Bob', 'Cy'),
        isTrue,
        reason: 'tapping the shown sort column reverses it',
      );
    },
  );

  testWidgets('first shared shows only when wide', (tester) async {
    await _pump(tester);
    expect(find.text('First shared'), findsNothing);
    await _pump(tester, width: 900);
    expect(find.text('First shared'), findsOneWidget);
  });

  testWidgets('a numeric column keeps a gap before the next column', (
    tester,
  ) async {
    await _pump(tester, width: 900);
    final count = tester.getRect(find.text('7'));
    final date = tester.getRect(find.text('Jan 1, 2024'));
    expect(date.left - count.right, greaterThanOrEqualTo(12));
    final header = tester.getRect(find.text('Shared dives'));
    final next = tester.getRect(find.text('Last shared'));
    expect(next.left - header.right, greaterThanOrEqualTo(12));
  });

  testWidgets('the list ends clear of the year play pill', (tester) async {
    await _pump(tester);
    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      const EdgeInsets.only(bottom: kTableEndPadding),
    );
  });

  testWidgets('each end shows its kind icon', (tester) async {
    await _pump(tester);
    // Two rows, two ends each, every one a buddy.
    expect(
      find.byIcon(connectionKindIcon(ConnectionKind.buddy)),
      findsNWidgets(4),
    );
  });

  testWidgets('right to left, cells line up with their headings', (
    tester,
  ) async {
    await _pump(tester, direction: TextDirection.rtl);
    final heading = tester.getRect(find.text('Entity'));
    final firstCell = tester.getRect(find.byType(KindLabel).first);
    expect((heading.right - firstCell.right).abs(), lessThan(4));
  });
}
