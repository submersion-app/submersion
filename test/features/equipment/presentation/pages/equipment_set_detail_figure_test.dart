import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The set page shows the figure above its list and numbers the list as the
/// legend, so a label and its row always agree.
void main() {
  EquipmentItem gear(String id, String name, EquipmentType type) =>
      EquipmentItem(id: id, name: name, type: type);

  Future<void> pump(
    WidgetTester tester,
    List<EquipmentItem> items, {
    double width = 900,
    double height = 2400,
    bool showFigure = true,
    Future<ComponentsIndex>? components,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final set = EquipmentSet(
      id: 's1',
      name: 'Reef set',
      equipmentIds: [for (final item in items) item.id],
      items: items,
      showFigure: showFigure,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentSetProvider.overrideWith((ref, id) async => set),
          equipmentSetGeofencesProvider.overrideWith((ref, id) async => []),
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(groupByType: false),
          ),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) =>
                components ?? Future.value(ComponentsIndex.fromRows(const [])),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentSetDetailPage(setId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final three = [
    gear('m', 'Hollis M1', EquipmentType.mask),
    gear('b', 'Hollis SMS75', EquipmentType.bcd),
    gear('f', 'Jet Fins', EquipmentType.fins),
  ];

  testWidgets('the figure appears with one label and one row badge per item', (
    tester,
  ) async {
    await pump(tester, three);
    expect(find.byType(DiverFigure), findsOneWidget);
    expect(find.byType(FigureNumberBadge), findsNWidgets(6));
    expect(find.bySemanticsLabel('Reef set, 3 items'), findsOneWidget);
    // Numbers follow the diver's arrangement, so the test reads the number
    // from the label rather than assuming the input order.
    expect(
      find.bySemanticsLabel(RegExp(r'^[1-3], BCD, Hollis SMS75$')),
      findsOneWidget,
    );
  });

  testWidgets('with the figure off, the page shows no figure and no numbers', (
    tester,
  ) async {
    await pump(tester, three, showFigure: false);
    expect(find.byType(DiverFigure), findsNothing);
    expect(find.byType(FigureNumberBadge), findsNothing);
    expect(find.text('Hollis SMS75'), findsOneWidget);
  });

  testWidgets('no items, no figure', (tester) async {
    await pump(tester, const []);
    expect(find.byType(DiverFigure), findsNothing);
  });

  testWidgets('tapping a label selects its row and the row badge', (
    tester,
  ) async {
    await pump(tester, three);
    await tester.tap(find.byKey(const ValueKey('figure-label-b')));
    await tester.pump();
    final selected = tester
        .widgetList<FigureNumberBadge>(find.byType(FigureNumberBadge))
        .where((b) => b.selected)
        .toList();
    // The label and its legend row, carrying the same number.
    expect(selected.length, 2);
    expect(selected.map((b) => b.number).toSet().length, 1);
    // The highlight clears on its own.
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widgetList<FigureNumberBadge>(find.byType(FigureNumberBadge))
          .any((b) => b.selected),
      isFalse,
    );
  });

  testWidgets('the flashed row takes the contrast-derived highlight', (
    tester,
  ) async {
    await pump(tester, three);
    await tester.tap(find.byKey(const ValueKey('figure-label-b')));
    await tester.pump();
    final context = tester.element(find.byType(DiverFigure));
    final highlight = figureHighlightFor(Theme.of(context).colorScheme);
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Hollis SMS75'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.textColor, highlight.onFill);
    final card = tester.widget<Card>(
      find.ancestor(of: find.byWidget(tile), matching: find.byType(Card)),
    );
    expect(card.color, highlight.fill);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("on a phone, tapping a back item's badge shows the back", (
    tester,
  ) async {
    await pump(tester, three, width: 390);
    expect(find.text('Front · 2'), findsOneWidget);
    expect(find.text('Back · 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('figure-label-b')), findsNothing);
    final bcdRow = find.ancestor(
      of: find.text('Hollis SMS75'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: bcdRow, matching: find.byType(FigureNumberBadge)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('figure-label-b')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the wide figure names every item', (tester) async {
    await pump(tester, three);
    expect(find.text('Hollis M1'), findsNWidgets(2)); // the label and the row
    expect(find.text('Jet Fins'), findsNWidgets(2));
  });

  testWidgets('a tray item shows the carried heading', (tester) async {
    await pump(tester, [...three, gear('t', 'Wrench', EquipmentType.tool)]);
    expect(find.text('Also carried'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^[1-4], Tool, Wrench$')),
      findsOneWidget,
    );
  });

  testWidgets('the figure waits for the parts index before numbering', (
    tester,
  ) async {
    // Until the index loads, assembly parts would count as items of their
    // own and be numbered, then vanish and renumber everything.
    final index = Completer<ComponentsIndex>();
    await pump(tester, three, components: index.future);
    expect(find.byType(DiverFigure), findsNothing);
    expect(find.byType(FigureNumberBadge), findsNothing);

    index.complete(ComponentsIndex.fromRows(const []));
    await tester.pumpAndSettle();
    expect(find.byType(DiverFigure), findsOneWidget);
  });

  testWidgets('a rebuild reuses the composed figure', (tester) async {
    await pump(tester, three);
    final before = tester.widget<DiverFigure>(find.byType(DiverFigure)).model;
    await tester.tap(find.byKey(const ValueKey('figure-label-b')));
    await tester.pump();
    final after = tester.widget<DiverFigure>(find.byType(DiverFigure)).model;
    expect(identical(before, after), isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('tapping a row badge far down the list brings the figure back', (
    tester,
  ) async {
    const types = [
      EquipmentType.mask,
      EquipmentType.regulator,
      EquipmentType.bcd,
      EquipmentType.fins,
      EquipmentType.computer,
      EquipmentType.light,
      EquipmentType.weights,
      EquipmentType.tank,
      EquipmentType.smb,
      EquipmentType.reel,
      EquipmentType.knife,
      EquipmentType.hood,
    ];
    final many = [
      for (var i = 0; i < types.length; i++) gear('i$i', 'Item $i', types[i]),
    ];
    await pump(tester, many, width: 390, height: 700);
    final lastRow = find.ancestor(
      of: find.text('Item 11'),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      lastRow,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.getRect(find.byType(DiverFigure)).bottom,
      lessThan(0),
      reason: 'the figure has scrolled off the top',
    );

    await tester.tap(
      find.descendant(of: lastRow, matching: find.byType(FigureNumberBadge)),
    );
    await tester.pumpAndSettle();

    final figure = tester.getRect(find.byType(DiverFigure));
    expect(figure.overlaps(const Rect.fromLTWH(0, 0, 390, 700)), isTrue);
  });
}
