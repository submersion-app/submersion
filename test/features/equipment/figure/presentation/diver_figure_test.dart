import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_name_label.dart';

void main() {
  FigureItemInput item(String id, EquipmentType type) =>
      FigureItemInput(id: id, type: type, name: 'Item $id');

  final reef = composeFigure([
    item('mask', EquipmentType.mask),
    item('bcd', EquipmentType.bcd),
    item('fins', EquipmentType.fins),
    item('tank', EquipmentType.tank),
  ]);

  Future<void> pump(
    WidgetTester tester,
    FigureModel model, {
    required double width,
    String? selectedItemId,
    ValueChanged<PlacedItem>? onItemTap,
    String Function(PlacedItem)? labelText,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiverFigure(
              model: model,
              semanticsLabel: 'Reef set',
              labelText: labelText ?? (p) => p.item.name,
              sideLabel: (view, count) =>
                  '${view == FigureView.front ? 'Front' : 'Back'} · $count',
              itemSemantics: (p) =>
                  '${p.number}, ${p.item.type.name}, ${p.item.name}',
              selectedItemId: selectedItemId,
              onItemTap: onItemTap,
              trayTitle: 'Also carried',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder label(String id) => find.byKey(ValueKey('figure-label-$id'));

  group('phone', () {
    testWidgets('a switch with counts shows one side at a time', (
      tester,
    ) async {
      await pump(tester, reef, width: 360);
      expect(find.text('Front · 2'), findsOneWidget);
      expect(find.text('Back · 2'), findsOneWidget);
      expect(label('mask'), findsOneWidget);
      expect(label('tank'), findsNothing);
      await tester.tap(find.text('Back · 2'));
      await tester.pumpAndSettle();
      expect(label('tank'), findsOneWidget);
      expect(label('bcd'), findsOneWidget);
      expect(label('mask'), findsNothing);
    });

    testWidgets('selecting an item on the hidden side switches to it', (
      tester,
    ) async {
      await pump(tester, reef, width: 360);
      expect(label('bcd'), findsNothing);
      await pump(tester, reef, width: 360, selectedItemId: 'bcd');
      expect(label('bcd'), findsOneWidget);
    });

    testWidgets('an empty side reads zero and still draws', (tester) async {
      final frontOnly = composeFigure([item('mask', EquipmentType.mask)]);
      await pump(tester, frontOnly, width: 360);
      expect(find.text('Back · 0'), findsOneWidget);
      await tester.tap(find.text('Back · 0'));
      await tester.pumpAndSettle();
      expect(find.byType(FigureNameLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('599 is the phone layout and 600 the wide one', (tester) async {
      await pump(tester, reef, width: 599);
      expect(find.byType(SegmentedButton<FigureView>), findsOneWidget);
      await pump(tester, reef, width: 600);
      expect(find.byType(SegmentedButton<FigureView>), findsNothing);
    });
  });

  group('wide', () {
    testWidgets('every placed item has a named pill with its number', (
      tester,
    ) async {
      await pump(tester, reef, width: 900);
      expect(find.byType(FigureNameLabel), findsNWidgets(4));
      expect(find.text('Item bcd'), findsOneWidget);
      expect(find.bySemanticsLabel('2, bcd, Item bcd'), findsOneWidget);
      expect(find.bySemanticsLabel('Reef set'), findsOneWidget);
    });

    testWidgets('tapping a label reports its item', (tester) async {
      PlacedItem? tapped;
      await pump(tester, reef, width: 900, onItemTap: (p) => tapped = p);
      await tester.tap(label('fins'));
      expect(tapped?.item.id, 'fins');
    });

    testWidgets('the selected label is marked selected', (tester) async {
      await pump(tester, reef, width: 900, selectedItemId: 'mask');
      final selected = tester
          .widgetList<FigureNameLabel>(find.byType(FigureNameLabel))
          .where((l) => l.selected);
      expect(selected.single.number, 1);
    });

    testWidgets('a very long name truncates inside the box', (tester) async {
      await pump(
        tester,
        reef,
        width: 900,
        labelText: (p) =>
            'An extraordinarily long item name that keeps going ${p.number}',
      );
      expect(tester.takeException(), isNull);
      for (final id in ['mask', 'bcd', 'fins', 'tank']) {
        final rect = tester.getRect(label(id));
        expect(rect.left, greaterThanOrEqualTo(0), reason: id);
        expect(rect.right, lessThanOrEqualTo(900.001), reason: id);
      }
    });
  });

  testWidgets('labels keep a 40 point target on both platforms', (
    tester,
  ) async {
    try {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final width in [360.0, 900.0]) {
          await pump(tester, reef, width: width, onItemTap: (_) {});
          expect(
            tester.getSize(label('mask')).height,
            greaterThanOrEqualTo(40),
            reason: '${platform.name} at $width',
          );
        }
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tray tiles show the name as well as the number', (tester) async {
    final withTray = composeFigure([
      item('mask', EquipmentType.mask),
      item('tool', EquipmentType.tool),
    ]);
    await pump(tester, withTray, width: 900);
    expect(find.text('Also carried'), findsOneWidget);
    expect(find.text('Item tool'), findsOneWidget);
  });
}
