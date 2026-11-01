// Issue #3422: the table editor edits stats exclusions, wind direction and
// scrubber fields, so the dive table gains columns for them.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  const newMembers = [
    DiveField.excludedFromStats,
    DiveField.excludedFromGasStats,
    DiveField.windDirection,
    DiveField.scrubberType,
    DiveField.scrubberDuration,
  ];

  final dive = Dive(
    id: 'd1',
    dateTime: DateTime(2026, 1, 1),
    excludedFromStats: true,
    excludedFromGasStats: false,
    windDirection: CurrentDirection.northEast,
    scrubber: const ScrubberInfo(type: 'ExtendAir', ratedMinutes: 180),
  );

  test('the five new members extract their stored values', () {
    expect(DiveField.excludedFromStats.extractFromDive(dive), isTrue);
    expect(DiveField.excludedFromGasStats.extractFromDive(dive), isFalse);
    expect(
      DiveField.windDirection.extractFromDive(dive),
      CurrentDirection.northEast.displayName,
    );
    expect(DiveField.scrubberType.extractFromDive(dive), 'ExtendAir');
    expect(DiveField.scrubberDuration.extractFromDive(dive), 180);
  });

  test('every new member has a label, a width and a category', () {
    final en = AppLocalizationsEn();
    for (final f in newMembers) {
      expect(f.localizedDisplayName(en), isNotEmpty, reason: '$f');
      expect(f.localizedShortLabel(en), isNotEmpty, reason: '$f');
      expect(f.defaultWidth, greaterThan(0), reason: '$f');
      expect(f.minWidth, lessThanOrEqualTo(f.defaultWidth), reason: '$f');
      expect(f.categoryName, isNotEmpty, reason: '$f');
    }
  });

  test('the new members format like their neighbours', () {
    const units = UnitFormatter(AppSettings());
    expect(DiveField.excludedFromStats.formatValue(true, units), 'Yes');
    expect(DiveField.scrubberDuration.formatValue(180, units), '180 min');
    expect(DiveField.scrubberType.formatValue(null, units), '--');
  });
}
