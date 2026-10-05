import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certification_agencies/domain/agency_colors.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

void main() {
  test('the default colour is stable for an id and from the tag palette', () {
    const id = '8c1e5a2e-0000-4000-8000-000000000001';
    final a = defaultAgencyColorArgb(id);
    expect(defaultAgencyColorArgb(id), a);
    final palette = TagColors.predefined
        .map((h) => TagColors.fromHex(h).toARGB32())
        .toSet();
    expect(palette, contains(a));
  });

  test('different ids spread across the palette', () {
    final colors = {
      for (var i = 0; i < 40; i++)
        defaultAgencyColorArgb('8c1e5a2e-0000-4000-8000-0000000000$i'),
    };
    expect(colors.length, greaterThan(5));
  });

  test('the secondary colour is a lighter shade of the primary', () {
    const primary = Color(0xFF0D3B7A);
    final secondary = secondaryAgencyColor(primary);
    expect(
      HSLColor.fromColor(secondary).lightness,
      greaterThan(HSLColor.fromColor(primary).lightness),
    );
  });
}
