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

  testWidgets('layers paint low to high so a BCD covers the wetsuit', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixel = await paint(
        composeFigure([
          item('bcd', EquipmentType.bcd),
          item('suit', EquipmentType.wetsuit),
        ]),
      );
      // Inside the jacket, between the straps: the jacket (black), not the
      // suit (dark blue).
      expect(
        pixel(layout.toBox(FigureView.front, 100, 120)),
        FigureColors.black,
      );
      // On the thigh, only the suit.
      expect(
        pixel(layout.toBox(FigureView.front, 84, 260)),
        FigureColors.darkBlue,
      );
    });
  });
}
