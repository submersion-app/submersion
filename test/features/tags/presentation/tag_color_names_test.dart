import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tags/domain/tag_palette.dart';
import 'package:submersion/features/tags/presentation/tag_color_names.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Screen readers name each palette dot by hue and shade (issue #4384).
void main() {
  TagPaletteEntry entry(int hue, TagShade shade) =>
      tagPalette.firstWhere((e) => e.hue == hue && e.shade == shade);

  const teal = 7;
  const slate = 19;

  test('names a base shade by its hue alone', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(tagColorName(l10n, entry(teal, TagShade.base)), 'Teal');
  });

  test('names a light or dark shade by its hue and shade', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(tagColorName(l10n, entry(teal, TagShade.light)), 'Teal, light');
    expect(tagColorName(l10n, entry(slate, TagShade.dark)), 'Slate, dark');
  });

  test('uses the hue name of the diver language', () {
    final l10n = lookupAppLocalizations(const Locale('de'));
    final name = tagColorName(l10n, entry(teal, TagShade.dark));
    expect(name, contains(l10n.equipment_color_teal));
    expect(name, isNot(contains('dark')));
  });
}
