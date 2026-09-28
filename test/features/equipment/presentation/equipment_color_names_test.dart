import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('every palette colour has its own name', () {
    final names = [
      for (final hex in TagColors.predefined) equipmentColorName(l10n, hex),
    ];
    expect(names.toSet(), hasLength(TagColors.predefined.length));
    for (final (i, name) in names.indexed) {
      expect(name, isNot(startsWith('#')), reason: TagColors.predefined[i]);
    }
  });

  test('every locale names every palette colour', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final names = lookupAppLocalizations(locale);
      final all = {
        for (final hex in TagColors.predefined) equipmentColorName(names, hex),
      };
      expect(all, hasLength(TagColors.predefined.length), reason: '$locale');
    }
  });

  test('palette lookups ignore case', () {
    expect(equipmentColorName(l10n, '#ef4444'), 'Red');
  });

  test('a colour outside the palette is named by its code', () {
    expect(equipmentColorName(l10n, '#123abc'), '#123ABC');
  });
}
