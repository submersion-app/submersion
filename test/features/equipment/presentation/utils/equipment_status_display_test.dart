import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('spare has its own label in English (#1803)', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(EquipmentStatus.spare.localizedName(l10n), 'Spare');
  });

  test('every locale gives every status a distinct, non-empty label', () {
    // The status dropdown and the filter chips show these side by side, so
    // two statuses sharing a label would be indistinguishable.
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final labels = [
        for (final status in EquipmentStatus.values) status.localizedName(l10n),
      ];

      expect(
        labels.every((l) => l.trim().isNotEmpty),
        isTrue,
        reason: '$locale',
      );
      expect(labels.toSet().length, labels.length, reason: '$locale: $labels');
    }
  });
}
