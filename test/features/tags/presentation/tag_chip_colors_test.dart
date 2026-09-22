import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_chip_colors.dart';

/// A tag chip is a pale tint of the diver's colour (issue #2269).
///
/// The tint is computed once against the theme's own surface and painted
/// opaque, rather than laid over whatever happens to sit behind the chip.
/// That is what lets Settings offer the colour a tag really displays: a
/// translucent fill has no single colour, only a recipe whose result changes
/// per surface.
void main() {
  const amber = Color(0xFFF59E0B);
  const white = Colors.white;

  TagChipColors colorsFor(Color seed, {Color surface = white}) =>
      tagChipColorsFor(seed: seed, surface: surface);

  group('fill', () {
    test('is opaque, so nothing behind the chip can change it', () {
      expect(colorsFor(amber).fill.a, 1.0);
    });

    test('is the surface tinted 15 per cent by the tag colour', () {
      // Amber over white is the pale sand the chips showed before #2255.
      // Pinning the channels pins the tint: at the 0.2 the detail cards
      // used, green and blue both land outside these bounds.
      final fill = colorsFor(amber).fill;

      expect(fill.r, closeTo(0.994, 0.002));
      expect(fill.g, closeTo(0.943, 0.002));
      expect(fill.b, closeTo(0.856, 0.002));
    });

    test('follows the theme surface, not the widget behind the chip', () {
      // The same tag on a dark theme takes the dark surface's tint. What it
      // must never do is take the blue-grey of a selected row, which is what
      // the translucent fill did.
      final onDark = colorsFor(amber, surface: const Color(0xFF121212)).fill;

      expect(onDark.a, 1.0);
      expect(onDark.r, lessThan(0.3));
    });
  });

  group('border', () {
    test('is the stored colour at full strength', () {
      expect(colorsFor(amber).border, amber);
      expect(colorsFor(amber).border.a, 1.0);
    });
  });

  group('label', () {
    test('clears WCAG AA against its own fill for every palette colour', () {
      for (final hex in TagColors.predefined) {
        final colors = colorsFor(TagColors.fromHex(hex));

        expect(
          tagContrastRatio(colors.label, colors.fill),
          greaterThanOrEqualTo(4.5),
          reason: '$hex label is unreadable on its own chip',
        );
      }
    });

    test('gives up lightness only, never hue or saturation', () {
      // #2255 wrote the label in black or white, which is legible but drops
      // the tag's identity from the text. Darkening in HSL keeps both, which
      // an RGB blend towards a dark neutral does not: that cost the
      // saturated mid tones nearly half their saturation.
      for (final hex in TagColors.predefined) {
        final seed = HSLColor.fromColor(TagColors.fromHex(hex));
        final label = HSLColor.fromColor(colorsFor(seed.toColor()).label);

        // Only where there is a hue to keep. Stone and Zinc differ by under
        // 12 of 255 between their strongest and weakest channel, so a
        // one-unit rounding through 8-bit RGB swings their computed hue by
        // degrees. That is the palette's arithmetic, not the label rule.
        if (seed.saturation > 0.2) {
          expect(
            _hueGap(seed.hue, label.hue),
            lessThan(2),
            reason: '$hex label drifted off its own hue',
          );
        }
        expect(
          label.saturation,
          closeTo(seed.saturation, 0.05),
          reason: '$hex label washed out towards a neutral',
        );
        expect(
          label.lightness,
          lessThan(seed.lightness),
          reason: '$hex label had to darken to be readable',
        );
      }
    });

    test('stays readable when the tag is darker than its own fill', () {
      // A tag stored near black, on a dark theme. The fill is the surface
      // tinted, so it comes out LIGHTER than the seed, and picking the
      // direction by comparing the two then walks the label towards black,
      // into the fill, for about 1.1:1. The direction has to be read off the
      // fill alone: whichever end of the lightness range has room against it.
      const darkSurface = Color(0xFF121212);

      for (final seed in [Colors.black, const Color(0xFF050505)]) {
        final colors = colorsFor(seed, surface: darkSurface);

        expect(
          tagContrastRatio(colors.label, colors.fill),
          greaterThanOrEqualTo(4.5),
          reason: '$seed label is unreadable on its own chip',
        );
      }
    });

    test('stays readable when the tag is lighter than its own fill', () {
      // The mirror case on a light theme, where a near-white tag's fill is
      // fractionally darker than the tag.
      for (final seed in [Colors.white, const Color(0xFFFAFAFA)]) {
        final colors = colorsFor(seed);

        expect(
          tagContrastRatio(colors.label, colors.fill),
          greaterThanOrEqualTo(4.5),
          reason: '$seed label is unreadable on its own chip',
        );
      }
    });

    test('darkens the pale colours that the raw hue could not carry', () {
      // Amber on its own 15 per cent tint is about 1.7:1, which is why the
      // pre-#2255 label was close to invisible on the pale end of the
      // palette. The label has to move.
      final colors = colorsFor(amber);

      expect(colors.label, isNot(amber));
      expect(tagContrastRatio(amber, colors.fill), lessThan(4.5));
    });
  });

  group('tagContrastRatio', () {
    test('runs from 1 for identical colours to 21 for black on white', () {
      expect(tagContrastRatio(white, white), closeTo(1, 0.001));
      expect(tagContrastRatio(Colors.black, white), closeTo(21, 0.001));
    });
  });
}

/// The shorter way round the hue circle, in degrees.
double _hueGap(double a, double b) {
  final gap = (a - b).abs() % 360;
  return gap > 180 ? 360 - gap : gap;
}
