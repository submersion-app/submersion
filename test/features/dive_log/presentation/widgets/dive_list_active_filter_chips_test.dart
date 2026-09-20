import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
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

  List<ActiveFilterChip> labels(DiveFilterState f, {AppSettings? s}) =>
      activeFilterChipLabels(
        f,
        l10n,
        s ?? settings,
        siteName: (_) => null,
        speciesName: (_) => null,
        computerName: (_) => null,
      );

  test('both-bound axes render as a range', () {
    const f = DiveFilterState(
      minWaterTemp: 10,
      maxWaterTemp: 25,
      minVisibility: 5,
      maxVisibility: 30,
      minBottomTimeMinutes: 20,
      maxBottomTimeMinutes: 60,
      minO2Percent: 21,
      maxO2Percent: 32,
    );
    expect(labels(f).map((c) => c.label), [
      'Water 10 to 25°C',
      'Visibility 5 to 30 m',
      'Bottom time 20 to 60 min',
      'Oxygen 21 to 32%',
    ]);
  });

  test('upper-bound-only axes read as an at-most', () {
    const f = DiveFilterState(
      maxWaterTemp: 25,
      maxBottomTimeMinutes: 60,
      maxO2Percent: 32,
    );
    expect(labels(f).map((c) => c.label), [
      'Water under 25°C',
      'Bottom time at most 60 min',
      'Oxygen at most 32%',
    ]);
  });

  test('a no-deco filter and a custom field with a value', () {
    const f = DiveFilterState(
      decoOnly: false,
      customFieldKey: 'Boat',
      customFieldValue: 'Sea Star',
    );
    expect(labels(f).map((c) => c.label), [
      'No decompression',
      'Boat: Sea Star',
    ]);
  });

  test('a custom field with no value shows the key alone', () {
    const f = DiveFilterState(customFieldKey: 'Boat');
    expect(labels(f).single.label, 'Boat');
  });

  test('bounds convert to the diver units', () {
    const imperial = AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
    );
    const f = DiveFilterState(minWaterTemp: 10, minVisibility: 30);
    expect(labels(f, s: imperial).map((c) => c.label), [
      'Water over 50°F',
      'Visibility over 98 ft',
    ]);
  });

  test('a single water type uses its localized name', () {
    const f = DiveFilterState(waterTypes: [WaterType.fresh]);
    expect(labels(f).single.label, 'Fresh Water');
  });

  test('an empty filter produces no chips', () {
    expect(labels(const DiveFilterState()), isEmpty);
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
