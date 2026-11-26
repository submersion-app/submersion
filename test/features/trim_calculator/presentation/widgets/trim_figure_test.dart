import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_chip_layout.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_figure.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_figure_geometry.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_figure_painter.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_space.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_strings.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// The posable trim figure (issue #5028).
void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(weightUnit: WeightUnit.pounds));

  TrimElement lead(
    String id,
    double kg,
    TrimSpot spot, {
    String label = '',
    WeightType? type,
    TrimLateral lateral = TrimLateral.centre,
  }) => TrimElement(
    id: id,
    label: label,
    kind: TrimElementKind.lead,
    sinkKg: kg,
    spot: spot,
    lateral: lateral,
    weightType: type,
    pieceIds: const ['weights_hip_side'],
  );

  TrimScene scene(List<TrimElement> elements) => TrimScene(
    elements: elements,
    modelNetKg: -1,
    liftSpot: TrimSpot.wing,
    body: TrimBody(heightCm: 175, bodyMassKg: 80),
    timestamp: 60,
    suitLiftKg: 5,
  );

  TrimFigurePainter painterOf(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(TrimFigure),
                  matching: find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is TrimFigurePainter,
                  ),
                ),
              )
              .painter!
          as TrimFigurePainter;

  List<String> chipTexts(WidgetTester tester) => [
    for (final c in painterOf(tester).chips)
      painterOf(tester).chipTexts[c.elementId]!,
  ];

  Future<void> pump(
    WidgetTester tester,
    TrimScene s, {
    UnitFormatter units = metric,
    TrimPose pose = TrimPose.standard,
    bool showAllChips = false,
    double width = 400,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = Size(width * 2, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Theme(
          data: ThemeData(brightness: brightness),
          child: SingleChildScrollView(
            child: TrimFigure(
              scene: s,
              pose: pose,
              result: s.trimIn(pose),
              units: units,
              showAllChips: showAllChips,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('chips show each lead weight, its amount and its side', (
    tester,
  ) async {
    await pump(
      tester,
      scene([
        lead(
          'a',
          4,
          TrimSpot.hipPockets,
          type: WeightType.integrated,
          lateral: TrimLateral.left,
        ),
        lead('b', 2, TrimSpot.trimPockets, label: 'Top pocket'),
      ]),
    );
    final texts = chipTexts(tester);
    expect(texts, contains('Integrated Weights 4.0 kg L'));
    expect(texts, contains('Top pocket 2.0 kg'));
  });

  testWidgets('a weightless element never reads as minus zero', (tester) async {
    await pump(
      tester,
      scene([
        const TrimElement(
          id: 'reg',
          label: 'Regulator',
          kind: TrimElementKind.gear,
          sinkKg: -0.0,
          spot: TrimSpot.mouth,
        ),
        const TrimElement(
          id: 'hood',
          label: 'Hood',
          kind: TrimElementKind.gear,
          sinkKg: -0.01,
          spot: TrimSpot.head,
        ),
      ]),
      showAllChips: true,
    );
    expect(
      trimShownKg(-0.0).isNegative || trimShownKg(-0.01).isNegative,
      isFalse,
    );
  });

  testWidgets('an imperial diver reads pounds', (tester) async {
    await pump(
      tester,
      scene([lead('a', 4, TrimSpot.waist, label: 'Belt')]),
      units: imperial,
    );
    expect(chipTexts(tester).single, startsWith('Belt 8.8 lb'));
  });

  testWidgets('the summary names the verdict and every lead spot', (
    tester,
  ) async {
    final s = scene([
      lead(
        'a',
        4,
        TrimSpot.hipPockets,
        label: 'A very long name for a weight that will not fit on a chip',
      ),
    ]);
    await pump(tester, s);
    final label = tester
        .getSemantics(find.byType(TrimFigure))
        .getSemanticsData()
        .label;
    expect(label, contains('A very long name for a weight that will not fit'));
    expect(label, contains('Hip pockets'));
    expect(label, startsWith('Trim figure: '));
  });

  testWidgets('a large rig lays out with no overlapping chips', (tester) async {
    const spots = TrimSpot.values;
    final elements = [
      for (var i = 0; i < 33; i++)
        lead('e$i', 1 + i / 10, spots[i % spots.length], label: 'Item $i'),
    ];
    await pump(tester, scene(elements), showAllChips: true);
    final chips = painterOf(tester).chips;
    expect(chips.length, 33);
    for (var i = 0; i < chips.length; i++) {
      for (var j = i + 1; j < chips.length; j++) {
        expect(
          chips[i].rect.overlaps(chips[j].rect),
          isFalse,
          reason: '${chips[i].elementId} / ${chips[j].elementId}',
        );
      }
    }
  });

  for (final brightness in Brightness.values) {
    for (final pose in [
      TrimPose(armReach: 0, kneeBendDeg: 0),
      TrimPose(armReach: 0.5, kneeBendDeg: 45),
      TrimPose(armReach: 1, kneeBendDeg: 90),
    ]) {
      testWidgets(
        'paints at arms ${pose.armReach}, knees ${pose.kneeBendDeg}, $brightness',
        (tester) async {
          final elements = [
            lead('a', 4, TrimSpot.hipPockets),
            const TrimElement(
              id: 'g',
              label: 'Suit',
              kind: TrimElementKind.gear,
              sinkKg: 0,
              spot: TrimSpot.floatPoint,
              pieceIds: [
                'wetsuit_side_torso',
                'wetsuit_side_arm',
                'wetsuit_side_shin',
              ],
            ),
            const TrimElement(
              id: 'f',
              label: 'Fins',
              kind: TrimElementKind.gear,
              sinkKg: 0.6,
              spot: TrimSpot.fins,
              pieceIds: ['fins_side'],
            ),
            const TrimElement(
              id: 'l',
              label: 'Light',
              kind: TrimElementKind.gear,
              sinkKg: 0.5,
              spot: TrimSpot.hand,
              lateral: TrimLateral.right,
              pieceIds: ['light_hand_side'],
            ),
          ];
          await pump(
            tester,
            scene(elements),
            pose: pose,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(TrimFigure), findsOneWidget);
        },
      );
    }
  }

  test('chip layout keeps back chips above and front chips below', () {
    final layout = packTrimChips(
      [
        const TrimChipRequest(
          elementId: 'back',
          anchor: Offset(100, 50),
          size: Size(60, 20),
          above: true,
        ),
        const TrimChipRequest(
          elementId: 'front',
          anchor: Offset(100, 80),
          size: Size(60, 20),
          above: false,
        ),
      ],
      width: 300,
      figureTop: 40,
      figureBottom: 120,
    );
    final byId = {for (final c in layout.chips) c.elementId: c.rect};
    expect(byId['back']!.bottom, lessThanOrEqualTo(40));
    expect(byId['front']!.top, greaterThanOrEqualTo(120));
  });

  testWidgets('a weight whose spot is not known says so', (tester) async {
    await pump(
      tester,
      scene([
        const TrimElement(
          id: 'm',
          label: '',
          kind: TrimElementKind.lead,
          sinkKg: 6,
          spot: TrimSpot.waist,
          weightType: WeightType.mixed,
          spotUnknown: true,
        ),
      ]),
    );
    expect(chipTexts(tester).single, contains('spot not known'));
  });

  testWidgets('the summary reads cleanly with no lead', (tester) async {
    await pump(tester, scene(const []));
    final label = tester
        .getSemantics(find.byType(TrimFigure))
        .getSemanticsData()
        .label;
    expect(label, isNot(contains('Lead:')));
    expect(label, endsWith('.'));
  });

  test('gear with no spot reads as such, not as spread over the body', () {
    const tray = TrimElement(
      id: 'h',
      label: 'Hose',
      kind: TrimElementKind.gear,
      sinkKg: 0.1,
      spot: TrimSpot.floatPoint,
    );
    const suit = TrimElement(
      id: 's',
      label: 'Suit',
      kind: TrimElementKind.gear,
      sinkKg: 0,
      spot: TrimSpot.floatPoint,
      pieceIds: ['wetsuit_side_torso'],
    );
    expect(trimIsSpreadOverBody(suit), isTrue);
    expect(trimIsSpreadOverBody(tray), isFalse);
  });

  test('centred gear on a sided spot is drawn on both limbs', () {
    const gloves = TrimElement(
      id: 'g',
      label: 'Gloves',
      kind: TrimElementKind.gear,
      sinkKg: 0.2,
      spot: TrimSpot.hand,
    );
    const right = TrimElement(
      id: 'r',
      label: 'Light',
      kind: TrimElementKind.gear,
      sinkKg: 0.2,
      spot: TrimSpot.hand,
      lateral: TrimLateral.right,
    );
    const left = TrimElement(
      id: 'l',
      label: 'Light',
      kind: TrimElementKind.gear,
      sinkKg: 0.2,
      spot: TrimSpot.hand,
      lateral: TrimLateral.left,
    );
    expect(trimOnFarSide(gloves) && trimOnNearSide(gloves), isTrue);
    expect(trimOnFarSide(right) && !trimOnNearSide(right), isTrue);
    expect(!trimOnFarSide(left) && trimOnNearSide(left), isTrue);
  });

  test('stacked elements at one spot are set apart', () {
    TrimElement stage(String id) => TrimElement(
      id: id,
      label: id,
      kind: TrimElementKind.tank,
      sinkKg: 1,
      spot: TrimSpot.stageClip,
      lateral: TrimLateral.left,
      pieceIds: const ['tank_stage_side'],
    );
    final offsets = trimStackOffsets([stage('a'), stage('b'), stage('c')]);
    expect(offsets.values.toSet(), hasLength(3));
    expect(offsets['a'], Offset.zero);
  });

  test('a taller chip later in a row does not overlap the next row', () {
    final layout = packTrimChips(
      const [
        TrimChipRequest(
          elementId: 'a',
          anchor: Offset(50, 80),
          size: Size(60, 16),
          above: false,
        ),
        TrimChipRequest(
          elementId: 'b',
          anchor: Offset(150, 80),
          size: Size(60, 40),
          above: false,
        ),
        TrimChipRequest(
          elementId: 'c',
          anchor: Offset(50, 80),
          size: Size(60, 16),
          above: false,
        ),
      ],
      width: 300,
      figureTop: 0,
      figureBottom: 60,
    );
    final rects = [for (final c in layout.chips) c.rect];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
  });

  testWidgets('the summary names a side in words', (tester) async {
    await pump(
      tester,
      scene([
        lead(
          'a',
          4,
          TrimSpot.hipPockets,
          type: WeightType.integrated,
          lateral: TrimLateral.left,
        ),
      ]),
    );
    final label = tester
        .getSemantics(find.byType(TrimFigure))
        .getSemanticsData()
        .label;
    expect(label, contains('Left'));
    expect(label, isNot(contains(' L ')));
  });

  group('a tank slid along its band (research C)', () {
    final body = TrimBody(heightCm: 175, bodyMassKg: 80);
    const slid = TrimElement(
      id: 't',
      label: 'AL80',
      kind: TrimElementKind.tank,
      sinkKg: 1,
      spot: TrimSpot.backTank,
      shiftM: 0.1,
    );
    const along = 0.1 / 1.75 * kTrimUnitsPerHeight;

    test('draws its pieces that far along the body', () {
      final offset = trimShiftOffset(slid, body);
      expect(offset.dx, closeTo(along, 1e-9));
      expect(offset.dy, 0);
    });

    test('anchors its chip where it now sits', () {
      final g = TrimFigureGeometry(
        box: const Rect.fromLTWH(0, 0, 550, 280),
        body: body,
        pose: TrimPose.standard,
        tiltDeg: 0,
      );
      final moved = g.anchorOfElement(slid) - g.anchorOf(TrimSpot.backTank);
      expect(moved.dx, closeTo(along * g.scale, 1e-6));
      expect(moved.dy, closeTo(0, 1e-6));
    });
  });
}
