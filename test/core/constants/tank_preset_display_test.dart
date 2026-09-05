import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_preset_display.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every built-in preset must resolve through [builtInTankPresetName] in every
/// locale. gen-l10n falls back to English silently and the switch falls back
/// to the const table's English value, so a preset added without ARB keys
/// would ship looking fine in English and untranslated everywhere else.
void main() {
  group('built-in tank preset display strings', () {
    test('every preset resolves a name and a description in every locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final preset in TankPresets.all) {
          expect(
            builtInTankPresetName(l10n, preset.name),
            isNotNull,
            reason: 'missing name for ${preset.name} in $locale',
          );
          expect(
            builtInTankPresetDescription(l10n, preset.name),
            isNotNull,
            reason: 'missing description for ${preset.name} in $locale',
          );
        }
      }
    });

    test('cylinder designations are not translated', () {
      // "AL100" is stamped on the cylinder and quoted on every fill-station
      // price list, so it stays byte-identical across locales.
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        expect(
          builtInTankPresetName(l10n, 'al100'),
          'AL100',
          reason: 'locale $locale',
        );
      }
    });

    test('unknown slugs resolve to null', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(builtInTankPresetName(l10n, 'nonexistent'), isNull);
      expect(builtInTankPresetDescription(l10n, 'nonexistent'), isNull);
    });
  });
}
