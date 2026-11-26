import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_figure_painter.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_tryout_controller.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_pieces_list.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_test_item_form.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_tryout_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// The try-out sheet (issue #5028).
void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(weightUnit: WeightUnit.pounds));

  TrimScene sceneAt(int? t) => TrimScene(
    elements: const [
      TrimElement(
        id: 'belt',
        label: 'Belt',
        kind: TrimElementKind.lead,
        sinkKg: 6,
        spot: TrimSpot.waist,
      ),
      TrimElement(
        id: 'light',
        label: 'Light',
        kind: TrimElementKind.gear,
        sinkKg: 1,
        spot: TrimSpot.hipPockets,
      ),
    ],
    modelNetKg: -1,
    liftSpot: TrimSpot.wing,
    body: TrimBody(heightCm: 175, bodyMassKg: 80),
    timestamp: t ?? 600,
    suitLiftKg: 5,
  );

  late TrimTryoutController controller;

  Future<void> pump(
    WidgetTester tester, {
    UnitFormatter units = metric,
    TrimSceneAt? at,
    List<TrimMoment> moments = const [
      TrimMoment(timestamp: 0, depthM: 0),
      TrimMoment(timestamp: 600, depthM: 18),
      TrimMoment(timestamp: 1200, depthM: 5),
    ],
  }) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    controller = TrimTryoutController(
      sceneAt: at ?? sceneAt,
      openingTimestamp: 600,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: TrimTryoutView(
          controller: controller,
          moments: moments,
          units: units,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TrimFigurePainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is TrimFigurePainter,
                ),
              )
              .painter!
          as TrimFigurePainter;

  testWidgets('dragging a chip to the trim pockets moves it', (tester) async {
    await pump(tester);
    final p = painter(tester);
    final chip = p.chips.singleWhere((c) => c.elementId == 'belt').rect;
    final figure = tester.getTopLeft(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TrimFigurePainter,
      ),
    );
    final target = p.geometry.anchorOf(TrimSpot.trimPockets);
    await tester.dragFrom(figure + chip.center, target - chip.center);
    await tester.pumpAndSettle();
    expect(
      controller.scene.elements.singleWhere((e) => e.id == 'belt').spot,
      TrimSpot.trimPockets,
    );
  });

  testWidgets('tapping a chip changes its side', (tester) async {
    await pump(tester);
    controller.move('belt', TrimSpot.hipPockets);
    await tester.pumpAndSettle();
    final p = painter(tester);
    final chip = p.chips.singleWhere((c) => c.elementId == 'belt').rect;
    final figure = tester.getTopLeft(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TrimFigurePainter,
      ),
    );
    await tester.tapAt(figure + chip.center);
    await tester.pumpAndSettle();
    expect(
      controller.scene.elements.singleWhere((e) => e.id == 'belt').lateral,
      TrimLateral.left,
    );
  });

  testWidgets('the Arms and Knees sliders change the pose', (tester) async {
    await pump(tester);
    await tester.drag(find.byKey(TrimTryoutView.armsKey), const Offset(200, 0));
    await tester.drag(
      find.byKey(TrimTryoutView.kneesKey),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.pose.armReach, greaterThan(0.5));
    expect(controller.pose.kneeBendDeg, lessThan(90));
  });

  testWidgets('the time slider shows run time and depth', (tester) async {
    await pump(tester);
    expect(find.text('10:00, ${metric.formatDepth(18)}'), findsOneWidget);
  });

  testWidgets('no profile, no time slider', (tester) async {
    await pump(tester, moments: const []);
    expect(find.byKey(TrimTryoutView.timeKey), findsNothing);
  });

  testWidgets('the test item form checks its fields inline', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add test item'));
    await tester.pump();
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(find.byKey(TrimTestItemForm.nameKey), 'Canister');
    await tester.enterText(find.byKey(TrimTestItemForm.weightKey), '25');
    await tester.tap(find.text('Add test item'));
    await tester.pump();
    expect(find.text('Enter a weight from 0.1 kg to 20.0 kg'), findsOneWidget);
    expect(
      controller.scene.elements.where((e) => e.kind == TrimElementKind.test),
      isEmpty,
    );
  });

  testWidgets('an imperial diver adds pounds', (tester) async {
    await pump(tester, units: imperial);
    await tester.enterText(find.byKey(TrimTestItemForm.nameKey), 'Canister');
    await tester.enterText(find.byKey(TrimTestItemForm.weightKey), '5');
    await tester.tap(find.text('Add test item'));
    await tester.pumpAndSettle();
    final item = controller.scene.elements.last;
    expect(item.sinkKg, closeTo(5 * 0.45359237, 1e-4));
    expect(painter(tester).chipTexts[item.id], 'Canister 5.0 lbs');
  });

  testWidgets('pitch and roll read in kg m, lb ft for imperial', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('kg·m'), findsOneWidget);
    await pump(tester, units: imperial);
    expect(find.textContaining('lb·ft'), findsOneWidget);
  });

  testWidgets('the Pieces list holds every element and moves one', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('trim-piece-belt')), findsOneWidget);
    expect(find.byKey(const ValueKey('trim-piece-light')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('trim-piece-belt')),
        matching: find.byType(PopupMenuButton<TrimPieceAction>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trim pockets').last);
    await tester.pumpAndSettle();
    expect(
      controller.scene.elements.singleWhere((e) => e.id == 'belt').spot,
      TrimSpot.trimPockets,
    );
  });

  testWidgets('the Pieces list changes a side', (tester) async {
    await pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('trim-piece-light')),
        matching: find.byType(PopupMenuButton<TrimPieceAction>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CheckedPopupMenuItem<TrimPieceAction>),
        matching: find.text('Right'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      controller.scene.elements.singleWhere((e) => e.id == 'light').lateral,
      TrimLateral.right,
    );
  });

  testWidgets('Reset puts everything back', (tester) async {
    await pump(tester);
    controller.move('belt', TrimSpot.trimPockets);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(
      controller.scene.elements.singleWhere((e) => e.id == 'belt').spot,
      TrimSpot.waist,
    );
  });

  testWidgets('a chip drag inside a scrolling sheet moves the chip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    controller = TrimTryoutController(sceneAt: sceneAt, openingTimestamp: 600);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: SingleChildScrollView(
          child: TrimTryoutView(
            controller: controller,
            moments: const [],
            units: metric,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final p = painter(tester);
    final chip = p.chips.singleWhere((c) => c.elementId == 'belt').rect;
    final figure = tester.getTopLeft(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TrimFigurePainter,
      ),
    );
    final target = p.geometry.anchorOf(TrimSpot.trimPockets);
    await tester.dragFrom(figure + chip.center, target - chip.center);
    await tester.pumpAndSettle();
    expect(
      controller.scene.elements.singleWhere((e) => e.id == 'belt').spot,
      TrimSpot.trimPockets,
    );
  });

  testWidgets('opened at the rest anchor, the time slider shows it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    controller = TrimTryoutController(sceneAt: sceneAt, openingTimestamp: null);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: TrimTryoutView(
          controller: controller,
          moments: const [
            TrimMoment(timestamp: 0, depthM: 0),
            TrimMoment(timestamp: 600, depthM: 18),
            TrimMoment(timestamp: 1200, depthM: 0),
          ],
          units: metric,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10:00, ${metric.formatDepth(18)}'), findsOneWidget);
  });

  testWidgets('a dragged chip shows where it will land', (tester) async {
    await pump(tester);
    final p = painter(tester);
    final chip = p.chips.singleWhere((c) => c.elementId == 'belt').rect;
    final figure = tester.getTopLeft(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TrimFigurePainter,
      ),
    );
    final gesture = await tester.startGesture(figure + chip.center);
    await gesture.moveBy(const Offset(-40, -40));
    await tester.pump();
    expect(painter(tester).dragTarget, isNotNull);
    expect(painter(tester).selectedElementId, 'belt');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(painter(tester).dragTarget, isNull);
  });

  testWidgets('imperial range edges as shown are accepted', (tester) async {
    await pump(tester, units: imperial);
    await tester.enterText(find.byKey(TrimTestItemForm.nameKey), 'Low');
    await tester.enterText(find.byKey(TrimTestItemForm.weightKey), '0.2');
    await tester.tap(find.text('Add test item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TrimTestItemForm.nameKey), 'High');
    await tester.enterText(find.byKey(TrimTestItemForm.weightKey), '44.1');
    await tester.tap(find.text('Add test item'));
    await tester.pumpAndSettle();
    expect(
      controller.scene.elements.where((e) => e.kind == TrimElementKind.test),
      hasLength(2),
    );
  });

  testWidgets('pitch and roll use the locale decimal mark', (tester) async {
    // Displayed numbers follow the process locale, as the app sets it.
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'de';
    addTearDown(() => Intl.defaultLocale = previous);
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    controller = TrimTryoutController(sceneAt: sceneAt, openingTimestamp: 600);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('de'),
        child: TrimTryoutView(
          controller: controller,
          moments: const [],
          units: metric,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'\d,\d\d kg·m')), findsWidgets);
  });

  testWidgets('a long dive time slider draws no tick per sample', (
    tester,
  ) async {
    await pump(
      tester,
      moments: [
        for (var i = 0; i < 2000; i++) TrimMoment(timestamp: i * 2, depthM: 10),
      ],
    );
    final slider = tester.widget<Slider>(find.byKey(TrimTryoutView.timeKey));
    expect(slider.divisions, isNull);
    await tester.drag(find.byKey(TrimTryoutView.timeKey), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(controller.timestamp, 3998);
  });

  testWidgets('a cancelled chip drag leaves nothing selected', (tester) async {
    await pump(tester);
    final p = painter(tester);
    final chip = p.chips.singleWhere((c) => c.elementId == 'belt').rect;
    final figure = tester.getTopLeft(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TrimFigurePainter,
      ),
    );
    final gesture = await tester.startGesture(figure + chip.center);
    await gesture.moveBy(const Offset(-40, -40));
    await tester.pump();
    expect(painter(tester).selectedElementId, 'belt');
    await gesture.cancel();
    await tester.pump();
    expect(painter(tester).selectedElementId, isNull);
    expect(
      controller.scene.elements.singleWhere((e) => e.id == 'belt').spot,
      TrimSpot.waist,
    );
  });

  group('tank height (research C)', () {
    TrimScene withTank(int? t) {
      final base = sceneAt(t);
      return base.copyWith(
        elements: [
          ...base.elements,
          const TrimElement(
            id: 'tank',
            label: 'AL80',
            kind: TrimElementKind.tank,
            sinkKg: -1,
            spot: TrimSpot.backTank,
          ),
        ],
      );
    }

    Slider tankSlider(WidgetTester tester) =>
        tester.widget<Slider>(find.byKey(TrimTryoutView.tankKey));

    testWidgets('no back tank, no slider', (tester) async {
      await pump(tester);
      expect(find.byKey(TrimTryoutView.tankKey), findsNothing);
    });

    testWidgets('slides the tank and says how far', (tester) async {
      await pump(tester, at: withTank);
      expect(find.text('As logged'), findsOneWidget);
      tankSlider(tester).onChanged!(-0.05);
      await tester.pumpAndSettle();
      expect(controller.tankShiftM, closeTo(-0.05, 1e-9));
      expect(find.text('5 cm up'), findsOneWidget);
      tankSlider(tester).onChanged!(0.03);
      await tester.pumpAndSettle();
      expect(find.text('3 cm down'), findsOneWidget);
    });

    testWidgets('in inches with feet for depth', (tester) async {
      await pump(
        tester,
        at: withTank,
        units: const UnitFormatter(AppSettings(depthUnit: DepthUnit.feet)),
      );
      tankSlider(tester).onChanged!(-0.0508);
      await tester.pumpAndSettle();
      expect(find.text('2 in up'), findsOneWidget);
    });
  });
}
