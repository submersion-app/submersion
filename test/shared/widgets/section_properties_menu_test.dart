import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/section_properties_menu.dart';

enum _Id { alpha, bravo, charlie }

class _Calls {
  final layouts = <DiveDetailLayout>[];
  final toggles = <int>[];
  final reorders = <(int, int)>[];
  int showAll = 0;
  int openSettings = 0;
}

Widget _harness(
  _Calls calls, {
  DiveDetailLayout layout = DiveDetailLayout.detailed,
  List<bool> visible = const [true, true, true],
  double? iconSize,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: AppBar(
        actions: [
          SectionPropertiesMenu(
            layout: layout,
            onLayoutChanged: calls.layouts.add,
            entries: [
              for (final id in _Id.values)
                SectionMenuEntry(
                  id: id,
                  label: id.name,
                  icon: Icons.label_outline,
                  visible: visible[id.index],
                ),
            ],
            onToggle: calls.toggles.add,
            onReorder: (oldIndex, newIndex) =>
                calls.reorders.add((oldIndex, newIndex)),
            onShowAll: () => calls.showAll++,
            onOpenSettings: () => calls.openSettings++,
            iconSize: iconSize,
          ),
        ],
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

MenuItemButton _button(WidgetTester tester, String label) =>
    tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(MenuItemButton),
      ),
    );

void main() {
  Future<void> sized(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('lists both layouts and checks the current one', (tester) async {
    await sized(tester);
    await tester.pumpWidget(_harness(_Calls(), layout: DiveDetailLayout.list));
    await _open(tester);

    expect(find.text('Detailed'), findsOneWidget);
    expect(
      (_button(tester, 'List').leadingIcon as Icon?)!.icon,
      Icons.radio_button_checked,
    );
    expect(
      (_button(tester, 'Detailed').leadingIcon as Icon?)!.icon,
      Icons.radio_button_unchecked,
    );
  });

  testWidgets('choosing a layout reports it and keeps the menu open', (
    tester,
  ) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    await _open(tester);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(calls.layouts, [DiveDetailLayout.list]);
    expect(find.text('Detailed'), findsOneWidget);
  });

  testWidgets('tapping a section reports its index and keeps the menu open', (
    tester,
  ) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    await _open(tester);

    await tester.tap(find.text('bravo'));
    await tester.pumpAndSettle();

    expect(calls.toggles, [1]);
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets('a hidden section shows an empty checkbox', (tester) async {
    await sized(tester);
    await tester.pumpWidget(
      _harness(_Calls(), visible: const [true, false, true]),
    );
    await _open(tester);

    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNWidgets(2));
  });

  testWidgets('show all is disabled while every section is visible', (
    tester,
  ) async {
    await sized(tester);
    await tester.pumpWidget(_harness(_Calls()));
    await _open(tester);

    expect(_button(tester, 'Show all sections').onPressed, isNull);
  });

  testWidgets('show all reports when a section is hidden', (tester) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(
      _harness(calls, visible: const [true, false, true]),
    );
    await _open(tester);

    await tester.tap(find.text('Show all sections'));
    await tester.pumpAndSettle();

    expect(calls.showAll, 1);
  });

  testWidgets('a drop reports the list indices', (tester) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    await _open(tester);

    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 2);
    await tester.pumpAndSettle();

    expect(calls.reorders, [(0, 2)]);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
  });

  testWidgets('the reorder item opens settings', (tester) async {
    await sized(tester);
    final calls = _Calls();
    await tester.pumpWidget(_harness(calls));
    await _open(tester);

    await tester.tap(find.text('Reorder sections...'));
    await tester.pumpAndSettle();

    expect(calls.openSettings, 1);
  });

  testWidgets('iconSize sizes the tune icon', (tester) async {
    await sized(tester);
    await tester.pumpWidget(_harness(_Calls(), iconSize: 20));

    expect(tester.widget<Icon>(find.byIcon(Icons.tune)).size, 20);
  });
}
