import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_factor_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #3075: the dive type case fell through to plain slug capitalization
/// because it never received the loaded dive types.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  CategoryShare shareFor(String key) => CategoryShare(
    key: key,
    groupShare: 0.5,
    baselineShare: 0.5,
    groupCount: 1,
    standsOut: false,
  );

  group('dive type category labels', () {
    test('a custom slug with no typesById falls back to slug '
        'capitalization', () {
      expect(
        focusCategoryLabel(FocusFactorId.diveType, shareFor('dpv'), en, units),
        'Dpv',
      );
    });

    test('a custom slug resolves to the diver\'s own name when typesById '
        'is given', () {
      final typesById = {
        'dpv': DiveTypeEntity(
          id: 'dpv',
          diverId: 'diver-1',
          name: 'DPV',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      };
      expect(
        focusCategoryLabel(
          FocusFactorId.diveType,
          shareFor('dpv'),
          en,
          units,
          typesById: typesById,
        ),
        'DPV',
      );
    });
  });
}
