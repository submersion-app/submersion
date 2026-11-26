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
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_chip_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_figure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_figure_painter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../../helpers/test_app.dart';

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
}
