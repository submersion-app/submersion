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
    // Not const: a const copy would be the very same object, which
    // proves nothing about equality.
    // ignore: prefer_const_constructors
    final copy = FigurePalette(
      body: 0xFFCBD3DB,
      bodyShade: 0xFFB2BCC6,
      gearDark: 0xFF2A2A2E,
      gearLight: 0xFF8FD3FF,
      metal: 0xFF9AA3AD,
      outline: 0xFF1B1B1F,
      badge: 0xFF0B57D0,
      onBadge: 0xFFFFFFFF,
    );
    expect(identical(copy, FigurePalette.light), isFalse);
    expect(copy, FigurePalette.light);
    expect(copy.hashCode, FigurePalette.light.hashCode);
  });

  group('rim (issue #3181)', () {
    // A dark page and a card on it, as Material's dark baseline has them.
    const page = 0xFF1C1B1F;
    const card = 0xFF2B2930;
    const rim = 0xFF938F99;
    const black = 0xFF1C1C1E;
    const red = 0xFFEF4444;
    final dark = _withBackdrops(const [page, card], rim);

    test('without backdrops no item needs a rim', () {
      expect(FigurePalette.light.needsRim(black), isFalse);
      expect(FigurePalette.light.needsRim(0xFFFFFFFF), isFalse);
    });

    test('an item lost in the page needs a rim', () {
      expect(dark.needsRim(black), isTrue);
    });

    test('an item close to any one backdrop needs a rim', () {
      // 0xFF424242 stands off the page (1.71:1) but not the card (1.43:1).
      expect(_withBackdrops(const [page], rim).needsRim(0xFF424242), isFalse);
      expect(dark.needsRim(0xFF424242), isTrue);
    });

    test('an item that stands off every backdrop needs none', () {
      expect(dark.needsRim(red), isFalse);
    });

    test('the item keeps its own colour either way', () {
      expect(dark.colorFor(FigureRole.itemColor, black), black);
      expect(
        dark.colorFor(FigureRole.itemShade, black),
        FigurePalette.darken(black, 0.25),
      );
    });

    test('palettes with different backdrops or rims are not equal', () {
      expect(dark, isNot(_withBackdrops(const [page], rim)));
      expect(dark, isNot(_withBackdrops(const [page, card], 0xFFFFFFFF)));
      expect(dark, _withBackdrops(const [page, card], rim));
      expect(dark.hashCode, _withBackdrops(const [page, card], rim).hashCode);
    });
  });
}

FigurePalette _withBackdrops(List<int> backdrops, int rim) {
  const l = FigurePalette.light;
  return FigurePalette(
    body: l.body,
    bodyShade: l.bodyShade,
    gearDark: l.gearDark,
    gearLight: l.gearLight,
    metal: l.metal,
    outline: l.outline,
    badge: l.badge,
    onBadge: l.onBadge,
    backdrops: [...backdrops],
    rim: rim,
  );
}
