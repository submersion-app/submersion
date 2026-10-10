import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/trip_group_collapse_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trip_group_header.dart';

import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show groupingOverrides, makeDive;

/// Holds the open dive the way the master-detail scaffold does, so a row's
/// tap and a keyboard move both come back in as [DiveListContent.selectedId].
class _SplitHost extends StatefulWidget {
  const _SplitHost({required this.opened});

  final List<String?> opened;

  @override
  State<_SplitHost> createState() => _SplitHostState();
}

class _SplitHostState extends State<_SplitHost> {
  String? selected;

  @override
  Widget build(BuildContext context) {
    return DiveListContent(
      showAppBar: false,
      selectedId: selected,
      onItemSelected: (id) {
        widget.opened.add(id);
        setState(() => selected = id);
      },
    );
  }
}

Finder _row(String id) =>
    find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

Future<void> _pump(
  WidgetTester tester,
  List<DiveSummary> dives,
  Widget child, {
  Size size = const Size(1400, 1000),
  Map<String, int> tripTotals = const {},
  bool grouping = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await groupingOverrides(
    dives,
    grouping: grouping,
    tripTotals: tripTotals,
  );
  await tester.pumpWidget(
    testApp(locale: const Locale('en'), overrides: overrides, child: child),
  );
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  final fourDives = [
    makeDive('d1'),
    makeDive('d2'),
    makeDive('d3'),
    makeDive('d4'),
  ];

  testWidgets('split view: Down opens the dive below the clicked one', (
    tester,
  ) async {
    final opened = <String?>[];
    await _pump(tester, fourDives, _SplitHost(opened: opened));

    await tester.tap(_row('d1'));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(opened, ['d1', 'd2']);

    // Clicking two rows away from where the keyboard left off, then pressing
    // Down, carries on from the click (#3065).
    await tester.tap(_row('d4'));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(opened, ['d1', 'd2', 'd4', 'd3']);
  });

  testWidgets('split view: Enter does not step to a neighbouring dive', (
    tester,
  ) async {
    final opened = <String?>[];
    await _pump(tester, fourDives, _SplitHost(opened: opened));

    await tester.tap(_row('d2'));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.enter);

    expect(opened.whereType<String>().toSet(), {'d2'});
  });

  testWidgets('phone width: arrows highlight, Enter opens', (tester) async {
    final opened = <String?>[];
    await _pump(
      tester,
      fourDives,
      DiveListContent(showAppBar: false, onItemSelected: opened.add),
      size: const Size(400, 900),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveListContent)),
    );

    // Tab into the list, as a keyboard user would.
    await _press(tester, LogicalKeyboardKey.tab);
    var tabs = 0;
    while (FocusManager.instance.primaryFocus?.debugLabel !=
            'KeyboardListNavigator' &&
        tabs++ < 20) {
      await _press(tester, LogicalKeyboardKey.tab);
    }
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);

    expect(opened, isEmpty, reason: 'an arrow must not open a page');
    expect(container.read(highlightedDiveIdProvider), 'd2');

    await _press(tester, LogicalKeyboardKey.enter);
    expect(opened, ['d2']);
  });

  testWidgets('Left folds the trip under the cursor, Right opens it again', (
    tester,
  ) async {
    final opened = <String?>[];
    await _pump(
      tester,
      [
        makeDive('d1'),
        makeDive('d2', tripId: 't1', tripName: 'Tassie'),
        makeDive('d3', tripId: 't1', tripName: 'Tassie'),
      ],
      _SplitHost(opened: opened),
      grouping: true,
      tripTotals: const {'t1': 2},
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveListContent)),
    );

    await tester.tap(_row('d3'));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(container.read(collapsedTripIdsProvider), {'t1'});
    expect(_row('d3'), findsNothing);

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(container.read(collapsedTripIdsProvider), isEmpty);
    expect(_row('d3'), findsOneWidget);
  });

  testWidgets('the cursor rests on a collapsed trip header between dives', (
    tester,
  ) async {
    final opened = <String?>[];
    await _pump(
      tester,
      [
        makeDive('d1'),
        makeDive('d2', tripId: 't1', tripName: 'Tassie'),
        makeDive('d3'),
      ],
      _SplitHost(opened: opened),
      grouping: true,
      tripTotals: const {'t1': 1},
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveListContent)),
    );
    container.read(collapsedTripIdsProvider.notifier).collapseAll(['t1']);
    await tester.pumpAndSettle();
    expect(find.byType(TripGroupHeader), findsOneWidget);

    await tester.tap(_row('d1'));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);
    // On the header: nothing new opens.
    expect(opened, ['d1']);

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(container.read(collapsedTripIdsProvider), isEmpty);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(opened, ['d1', 'd2']);
  });

  testWidgets('Right does not move focus into another widget', (tester) async {
    final opened = <String?>[];
    await _pump(tester, fourDives, _SplitHost(opened: opened));

    await tester.tap(_row('d1'));
    await tester.pumpAndSettle();
    final listFocus = FocusManager.instance.primaryFocus;
    await _press(tester, LogicalKeyboardKey.arrowRight);

    expect(FocusManager.instance.primaryFocus, same(listFocus));
    expect(listFocus?.debugLabel, 'KeyboardListNavigator');
  });
}
