import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_preset_display.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Slug coverage for the built-in cylinder preset display strings.
///
/// `builtInTankPresetName` and `builtInTankPresetDescription` switch on
/// [TankPreset.name] with a `_ => null` fallthrough, and the extension getters
/// fall back to the stored English value when they miss. gen-l10n also falls
/// back to English silently. So a preset added without a switch arm or without
/// ARB keys ships looking fine in English and untranslated everywhere else.
/// These tests turn that into a failure. Same class of guard as
/// `tank_catalog_test.dart`: a map keyed by a slug that no compiler checks.
void main() {
  group('builtInTankPresetName', () {
    test('covers every preset in TankPresets.all', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final missing = TankPresets.all
          .where((p) => builtInTankPresetName(en, p.name) == null)
          .map((p) => p.name)
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'Presets with no switch arm fall back to the untranslated English '
            'displayName in every locale.',
      );
    });

    test('returns null for an unknown slug', () {
      final en = lookupAppLocalizations(const Locale('en'));
      // The camelCase Dart identifiers are not slugs; passing one is the
      // mistake that left kTankCatalog's stage rows unreachable.
      expect(builtInTankPresetName(en, 'al30Stage'), isNull);
      expect(builtInTankPresetName(en, 'nonexistent'), isNull);
    });

    test('matches the const table for the English locale', () {
      final en = lookupAppLocalizations(const Locale('en'));
      for (final preset in TankPresets.all) {
        expect(
          preset.localizedDisplayName(en),
          preset.displayName,
          reason:
              'English is the stable identifier that exports and sync carry, '
              'so it must not drift from the const table.',
        );
      }
    });
  });

  group('builtInTankPresetDescription', () {
    test('covers every preset in TankPresets.all', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final missing = TankPresets.all
          .where((p) => builtInTankPresetDescription(en, p.name) == null)
          .map((p) => p.name)
          .toList();
      expect(missing, isEmpty);
    });

    test('returns null for an unknown slug', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(builtInTankPresetDescription(en, 'al40Stage'), isNull);
      expect(builtInTankPresetDescription(en, 'nonexistent'), isNull);
    });
  });

  group('locale coverage', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.languageCode;

      test('$code has a non-blank name and description for every preset', () {
        final l10n = lookupAppLocalizations(Locale(code));
        for (final preset in TankPresets.all) {
          final name = builtInTankPresetName(l10n, preset.name);
          expect(
            name,
            isNotNull,
            reason: '$code is missing a name for "${preset.name}"',
          );
          expect(
            name!.trim(),
            isNotEmpty,
            reason: '$code has a blank name for "${preset.name}"',
          );

          final description = builtInTankPresetDescription(l10n, preset.name);
          expect(
            description,
            isNotNull,
            reason: '$code is missing a description for "${preset.name}"',
          );
          expect(
            description!.trim(),
            isNotEmpty,
            reason: '$code has a blank description for "${preset.name}"',
          );
        }
      });
    }

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
  });
}
