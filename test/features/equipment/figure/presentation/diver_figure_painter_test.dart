import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure_painter.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';

/// Goldens are macOS-only in this repo and skipped in CI, so the painter is
/// pinned by sampling pixels: the body where the torso is, the item colour
/// where a piece is, transparency in the gutter, and the flipped piece on a
/// mirrored zone.
void main() {
  // 424 by 400 gives each figure 200 by 400, so figure space maps 1:1 with
  // the front at x offset 6 and the back at x offset 218.
  const size = Size(424, 400);
  final layout = FigureLayout.forSize(size);

  Future<int Function(Offset)> paint(FigureModel model) async {
    final recorder = PictureRecorder();
    DiverFigurePainter(
      model: model,
      palette: FigurePalette.light,
    ).paint(Canvas(recorder), size);
    final image = await recorder.endRecording().toImage(424, 400);
    final bytes = (await image.toByteData())!;
    return (Offset p) {
      final i = (p.dy.round() * 424 + p.dx.round()) * 4;
      return (bytes.getUint8(i + 3) << 24) |
          (bytes.getUint8(i) << 16) |
          (bytes.getUint8(i + 1) << 8) |
          bytes.getUint8(i + 2);
    };
  }

  FigureItemInput item(String id, EquipmentType type) =>
      FigureItemInput(id: id, type: type, name: id);

  testWidgets('paints the mannequin on both views and nothing in the gutter', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixel = await paint(composeFigure(const []));
      expect(
        pixel(layout.toBox(FigureView.front, 100, 140)),
        FigurePalette.light.body,
      );
      // Off the spine shade that runs down the middle of the back.
      expect(
        pixel(layout.toBox(FigureView.back, 80, 140)),
        FigurePalette.light.body,
      );
      expect(
        pixel(Offset(layout.front.right + FigureLayout.gutter / 2, 10)) >> 24,
        0,
      );
    });
  });

  testWidgets('a placed mask paints its lens where the artwork says', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixel = await paint(composeFigure([item('m', EquipmentType.mask)]));
      // mask_front's left lens spans x 85 to 98, y 37 to 45.
      expect(
        pixel(layout.toBox(FigureView.front, 91, 41)),
        FigurePalette.light.gearLight,
      );
      // The frame around it takes the item colour.
      expect(
        pixel(layout.toBox(FigureView.front, 100, 36)),
        FigureColors.black,
      );
    });
  });

  testWidgets('a second computer is flipped onto the right wrist', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixel = await paint(
        composeFigure([
          item('c1', EquipmentType.computer),
          item('c2', EquipmentType.computer),
        ]),
      );
      // computer_wrist_front's case spans x 45 to 61, y 178 to 194, with the
      // screen inset from x 48; mirrored about x = 100 the case is x 139 to
      // 155. Both samples sit on the case, clear of the screen.
      expect(
        pixel(layout.toBox(FigureView.front, 46, 186)),
        FigureColors.black,
      );
      expect(
        pixel(layout.toBox(FigureView.front, 153, 186)),
        FigureColors.black,
      );
      // Unmirrored, the right wrist would show the bare hand there.
      expect(
        pixel(layout.toBox(FigureView.front, 153, 186)),
        isNot(FigurePalette.light.body),
      );
    });
  });

  testWidgets(
    'a jacket BCD shows straps in front and its bladder behind the tank',
    (tester) async {
      await tester.runAsync(() async {
        final pixel = await paint(
          composeFigure([
            item('bcd', EquipmentType.bcd),
            item('suit', EquipmentType.wetsuit),
            item('tank', EquipmentType.tank),
          ]),
        );
        // Front: the left shoulder strap covers the suit...
        expect(
          pixel(layout.toBox(FigureView.front, 83, 120)),
          FigureColors.black,
        );
        // ...but the chest between the straps shows the suit, not a jacket.
        expect(
          pixel(layout.toBox(FigureView.front, 92, 130)),
          FigureColors.darkBlue,
        );
        // Back: the bladder shows beside the tank, and the tank is over it.
        expect(
          pixel(layout.toBox(FigureView.back, 122, 150)),
          FigureColors.black,
        );
        expect(
          pixel(layout.toBox(FigureView.back, 104, 150)),
          FigureColors.aluminium,
        );
      });
    },
  );

  testWidgets(
    'with only one view, the painter draws that view in the single layout',
    (tester) async {
      await tester.runAsync(() async {
        const box = Size(400, 400);
        final single = FigureLayout.forSingle(box);
        Future<int> sample(FigureView only) async {
          final recorder = PictureRecorder();
          DiverFigurePainter(
            model: composeFigure(const []),
            palette: FigurePalette.light,
            layout: single,
            only: only,
          ).paint(Canvas(recorder), box);
          final image = await recorder.endRecording().toImage(400, 400);
          final bytes = (await image.toByteData())!;
          final p = single.toBox(only, 100, 140);
          final i = (p.dy.round() * 400 + p.dx.round()) * 4;
          return (bytes.getUint8(i + 3) << 24) |
              (bytes.getUint8(i) << 16) |
              (bytes.getUint8(i + 1) << 8) |
              bytes.getUint8(i + 2);
        }

        // The centre of the torso is plain body in front and the spine
        // shade behind, so the two samples tell the views apart.
        expect(await sample(FigureView.front), FigurePalette.light.body);
        expect(await sample(FigureView.back), FigurePalette.light.bodyShade);
      });
    },
  );

  test('repaints only when what it draws changes', () {
    final model = composeFigure(const []);
    final painter = DiverFigurePainter(
      model: model,
      palette: FigurePalette.light,
    );
    expect(
      painter.shouldRepaint(
        DiverFigurePainter(model: model, palette: FigurePalette.light),
      ),
      isFalse,
    );
    // A palette rebuilt from the same theme is equal, not identical.
    // Not const: a const copy would be the very same object, which
    // proves nothing about equality.
    // ignore: prefer_const_constructors
    final samePalette = FigurePalette(
      body: 0xFFCBD3DB,
      bodyShade: 0xFFB2BCC6,
      gearDark: 0xFF2A2A2E,
      gearLight: 0xFF8FD3FF,
      metal: 0xFF9AA3AD,
      outline: 0xFF1B1B1F,
      badge: 0xFF0B57D0,
      onBadge: 0xFFFFFFFF,
    );
    expect(
      painter.shouldRepaint(
        DiverFigurePainter(model: model, palette: samePalette),
      ),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        DiverFigurePainter(
          model: composeFigure(const []),
          palette: FigurePalette.light,
        ),
      ),
      isTrue,
    );
    expect(
      painter.shouldRepaint(
        DiverFigurePainter(
          model: model,
          palette: FigurePalette.light,
          only: FigureView.back,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('fins and boots show on the back view too', (tester) async {
    await tester.runAsync(() async {
      final fins = await paint(composeFigure([item('f', EquipmentType.fins)]));
      // Below the foot, where only a fin blade can be.
      expect(fins(layout.toBox(FigureView.back, 70, 372)), FigureColors.black);

      final boots = await paint(
        composeFigure([item('b', EquipmentType.boots)]),
      );
      // On the foot, which is bare body without the boot.
      expect(boots(layout.toBox(FigureView.back, 80, 346)), FigureColors.black);
    });
  });
}
