import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';

void main() {
  FigureItemInput item(String id, EquipmentType type) =>
      FigureItemInput(id: id, type: type, name: 'Item $id');

  Future<void> pump(
    WidgetTester tester,
    FigureModel model, {
    String? selectedItemId,
    ValueChanged<PlacedItem>? onItemTap,
    String? trayTitle,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiverFigure(
              model: model,
              semanticsLabel: 'Reef set, 3 items',
              selectedItemId: selectedItemId,
              onItemTap: onItemTap,
              discLabel: (p) =>
                  '${p.number}, ${p.item.type.name}, ${p.item.name}',
              trayTitle: trayTitle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('one badge per placed item, labelled for a screen reader', (
    tester,
  ) async {
    final model = composeFigure([
      item('mask', EquipmentType.mask),
      item('bcd', EquipmentType.bcd),
      item('fins', EquipmentType.fins),
    ]);
    await pump(tester, model);
    expect(find.byType(FigureNumberBadge), findsNWidgets(3));
    expect(find.bySemanticsLabel('2, bcd, Item bcd'), findsOneWidget);
    expect(find.bySemanticsLabel('Reef set, 3 items'), findsOneWidget);
  });

  testWidgets('tapping a disc reports its item', (tester) async {
    final model = composeFigure([item('mask', EquipmentType.mask)]);
    PlacedItem? tapped;
    await pump(tester, model, onItemTap: (p) => tapped = p);
    await tester.tap(find.byKey(const ValueKey('figure-disc-mask')));
    expect(tapped?.item.id, 'mask');
  });

  testWidgets('a selected disc draws its ring', (tester) async {
    final model = composeFigure([item('mask', EquipmentType.mask)]);
    await pump(tester, model, selectedItemId: 'mask');
    final badge = tester.widget<FigureNumberBadge>(
      find.byType(FigureNumberBadge),
    );
    expect(badge.selected, isTrue);
  });

  testWidgets('the hit box is 40 on both platforms', (tester) async {
    try {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        final model = composeFigure([item('mask', EquipmentType.mask)]);
        await pump(tester, model, onItemTap: (_) {});
        final size = tester.getSize(
          find.byKey(const ValueKey('figure-disc-mask')),
        );
        expect(size.width, greaterThanOrEqualTo(40), reason: platform.name);
        expect(size.height, greaterThanOrEqualTo(40), reason: platform.name);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tray items get badges under a title; no tray, no title', (
    tester,
  ) async {
    final withTray = composeFigure([
      item('mask', EquipmentType.mask),
      item('tool', EquipmentType.tool),
    ]);
    await pump(tester, withTray, trayTitle: 'Also carried');
    expect(find.text('Also carried'), findsOneWidget);
    expect(find.byType(FigureNumberBadge), findsNWidgets(2));

    await pump(
      tester,
      composeFigure([item('mask', EquipmentType.mask)]),
      trayTitle: 'Also carried',
    );
    expect(find.text('Also carried'), findsNothing);
  });

  test('discs sharing an anchor are nudged apart', () {
    final model = composeFigure([
      item('fs', EquipmentType.firstStage),
      item('tx', EquipmentType.transmitter),
    ]);
    final layout = FigureLayout.forSize(const Size(400, 388));
    final positions = discPositions(model, layout);
    expect(
      (positions['fs']! - positions['tx']!).distance,
      greaterThanOrEqualTo(22),
    );
  });
}
