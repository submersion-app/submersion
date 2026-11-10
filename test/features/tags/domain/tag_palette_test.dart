import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/domain/tag_palette.dart';

/// The tag palette's shades and the readers the editor uses (issue #4384).
void main() {
  group('shades', () {
    test(
      'light and dark shades follow the base hues, Tailwind 300 and 700',
      () {
        expect(tagLightShades, hasLength(20));
        expect(tagDarkShades, hasLength(20));
        expect(tagLightShades.first, '#FCA5A5');
        expect(tagDarkShades.first, '#B91C1C');
        expect(tagLightShades[10], '#93C5FD');
        expect(tagDarkShades[10], '#1D4ED8');
        expect(tagLightShades.last, '#CBD5E1');
        expect(tagDarkShades.last, '#334155');
      },
    );

    test('the base palette is untouched: agency colours index into it', () {
      expect(TagColors.predefined, hasLength(20));
      expect(TagColors.predefined.first, '#EF4444');
      expect(TagColors.predefined[10], '#3B82F6');
      expect(TagColors.predefined.last, '#64748B');
    });

    test('the palette lists light, base and dark for each hue in turn', () {
      expect(tagPalette, hasLength(60));
      expect(tagPalette[0], (hue: 0, shade: TagShade.light, hex: '#FCA5A5'));
      expect(tagPalette[1], (hue: 0, shade: TagShade.base, hex: '#EF4444'));
      expect(tagPalette[31], (hue: 10, shade: TagShade.base, hex: '#3B82F6'));
      expect(tagPalette[59], (hue: 19, shade: TagShade.dark, hex: '#334155'));
    });
  });

  group('drawnTagColor', () {
    test('draws no colour as the palette Blue', () {
      expect(drawnTagColor(null), const Color(0xFF3B82F6));
      expect(drawnTagColor(''), const Color(0xFF3B82F6));
      expect(drawnTagColor('red'), const Color(0xFF3B82F6));
    });

    test('keeps the lenient reading an import relies on', () {
      expect(drawnTagColor('FF0000'), const Color(0xFFFF0000));
      expect(drawnTagColor('#ff0000'), const Color(0xFFFF0000));
    });
  });

  group('tagPaletteEntryFor', () {
    const blue = (hue: 10, shade: TagShade.base, hex: '#3B82F6');
    const red = (hue: 0, shade: TagShade.base, hex: '#EF4444');

    test('finds Blue for a tag with no colour or one drawn as Blue', () {
      expect(tagPaletteEntryFor(null), blue);
      expect(tagPaletteEntryFor(''), blue);
      expect(tagPaletteEntryFor('red'), blue);
      expect(tagPaletteEntryFor('#3b82f6'), blue);
    });

    test('matches a palette colour whatever its casing or hash', () {
      expect(tagPaletteEntryFor('#EF4444'), red);
      expect(tagPaletteEntryFor('ef4444'), red);
    });

    test('a translucent import is off the palette, whatever its RGB', () {
      // Drawn see-through, so no opaque swatch is the colour it shows.
      expect(drawnTagColor('80EF4444').a, lessThan(1));
      expect(tagPaletteEntryFor('80EF4444'), isNull);
    });

    test('finds nothing for a colour off the palette', () {
      expect(tagPaletteEntryFor('FF0000'), isNull);
      expect(tagPaletteEntryFor('#123456'), isNull);
    });
  });

  group('parseTagHexInput', () {
    test('accepts six hex digits with or without a hash, in capitals', () {
      expect(parseTagHexInput(' #2e8b57 '), '#2E8B57');
      expect(parseTagHexInput('2E8B57'), '#2E8B57');
    });

    test('rejects anything else', () {
      for (final bad in [
        '#FFF',
        '#GGGGGG',
        '#2E8B571',
        '',
        '#-00001',
        '##2E8B57',
      ]) {
        expect(parseTagHexInput(bad), isNull, reason: bad);
      }
    });
  });

  test('tagHexOf writes capitals and drops alpha', () {
    expect(tagHexOf(const Color(0x80FF0000)), '#FF0000');
    expect(tagHexOf(const Color(0xFF2e8b57)), '#2E8B57');
  });
}
