import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chip_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  const settings = AppSettings();

  test('every active axis produces at least one chip label', () {
    const f = DiveFilterState(
      minWaterTemp: 10,
      maxVisibility: 5,
      waterTypes: [WaterType.salt, WaterType.fresh],
      speciesIds: ['a', 'b'],
      siteIds: ['s1', 's2'],
      computerId: 'c',
      weekdays: [1],
      decoOnly: true,
      minRating: 3,
      minBottomTimeMinutes: 30,
      minO2Percent: 32,
      customFieldKey: 'k',
      excludedFromStatsOnly: true,
    );
    final labels = activeFilterChipLabels(
      f,
      l10n,
      settings,
      siteName: (_) => null,
      speciesName: (_) => null,
      computerName: (_) => 'Perdix',
    );
    expect(
      labels.map((c) => c.label),
      containsAll([
        'Water over 10°C',
        'Visibility under 5 m',
        '2 water types',
        '2 species',
        '2 sites',
        'Perdix',
      ]),
    );
    expect(labels.length, 13);
    for (final c in labels) {
      final cleared = c.clear(f);
      expect(cleared.hasActiveFilters, isTrue, reason: c.label);
      expect(
        activeFilterChipLabels(
          cleared,
          l10n,
          settings,
          siteName: (_) => null,
          speciesName: (_) => null,
          computerName: (_) => 'Perdix',
        ).length,
        12,
        reason: 'clearing ${c.label} removes exactly one chip',
      );
    }
  });

  test('single names come from the injected lookups', () {
    const f = DiveFilterState(speciesIds: ['a'], siteIds: ['s1']);
    final labels = activeFilterChipLabels(
      f,
      l10n,
      settings,
      siteName: (id) => 'Salt Pier',
      speciesName: (id) => 'Green Turtle',
      computerName: (_) => null,
    );
    expect(labels.map((c) => c.label), ['Green Turtle', 'Salt Pier']);
  });
}
