import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';
import 'package:submersion/features/equipment/figure/domain/figure_role.dart';

void main() {
  test('item roles take the item colour and its shade', () {
    const palette = FigurePalette.light;
    expect(palette.colorFor(FigureRole.itemColor, 0xFF4080C0), 0xFF4080C0);
    expect(
      palette.colorFor(FigureRole.itemShade, 0xFF4080C0),
      FigurePalette.darken(0xFF4080C0, 0.25),
    );
    expect(palette.colorFor(FigureRole.body, 0xFF4080C0), palette.body);
    expect(palette.colorFor(FigureRole.metal, 0), palette.metal);
  });

  test('darken keeps alpha and scales the channels', () {
    expect(FigurePalette.darken(0xFF800000, 0.5), 0xFF400000);
    expect(FigurePalette.darken(0xFFFFFFFF, 0.25), 0xFFBFBFBF);
    expect(FigurePalette.darken(0x80FFFFFF, 0.25) >> 24, 0x80);
  });

  test('the outline role takes the palette outline', () {
    const palette = FigurePalette.light;
    expect(palette.colorFor(FigureRole.outline, 0xFF4080C0), palette.outline);
  });

  test('palettes with the same colours are equal', () {
    const copy = FigurePalette(
      body: 0xFFCBD3DB,
      bodyShade: 0xFFB2BCC6,
      gearDark: 0xFF2A2A2E,
      gearLight: 0xFF8FD3FF,
      metal: 0xFF9AA3AD,
      outline: 0xFF1B1B1F,
      badge: 0xFF0B57D0,
      onBadge: 0xFFFFFFFF,
    );
    expect(copy, FigurePalette.light);
    expect(copy.hashCode, FigurePalette.light.hashCode);
  });
}
