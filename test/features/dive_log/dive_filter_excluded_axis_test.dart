import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

/// The excluded-dives axis has three implementations that must agree: the
/// statistics SQL subquery, the paginated dive list's WHERE builder, and the
/// in-memory apply() used by export/table/map views. A divergence between them
/// is invisible until a diver notices two screens disagreeing, so this pins
/// the two that can be exercised without a database and asserts the SQL one
/// encodes the same rule.
void main() {
  final included = Dive(id: 'included', dateTime: DateTime(2026, 1, 1));
  final excluded = Dive(
    id: 'excluded',
    dateTime: DateTime(2026, 1, 2),
    excludedFromStats: true,
  );
  final gasExcluded = Dive(
    id: 'gas-excluded',
    dateTime: DateTime(2026, 1, 3),
    excludedFromGasStats: true,
  );

  test('a null axis is inactive and filters nothing', () {
    const filter = DiveFilterState();
    expect(filter.hasActiveFilters, isFalse);
    expect(filter.apply([included, excluded, gasExcluded]), hasLength(3));
    expect(
      buildFilteredDiveIdSubquery(filter).subquery,
      isEmpty,
      reason:
          'an inactive filter must stay a no-op; the exclusion is '
          'enforced by DiveStatsScope alongside this subquery, not inside it',
    );
  });

  test('apply() keeps only excluded dives when the axis is true', () {
    const filter = DiveFilterState(excludedFromStatsOnly: true);
    expect(filter.hasActiveFilters, isTrue);
    expect(
      filter.apply([included, excluded, gasExcluded]).map((d) => d.id),
      ['excluded'],
      reason:
          'the axis tracks the master flag only; a gas-excluded dive is '
          'not "excluded from statistics"',
    );
  });

  test('the SQL subquery encodes the same rule', () {
    const filter = DiveFilterState(excludedFromStatsOnly: true);
    final sql = buildFilteredDiveIdSubquery(filter);
    expect(sql.subquery, contains('excluded_from_stats = 1'));
    expect(
      sql.subquery,
      isNot(contains('excluded_from_gas_stats')),
      reason: 'apply() does not consider the gas flag, so neither may SQL',
    );
    expect(sql.params, isEmpty);
  });

  test('copyWith can set and clear the axis', () {
    const active = DiveFilterState(excludedFromStatsOnly: true);
    expect(
      active.copyWith(clearExcludedFromStatsOnly: true).excludedFromStatsOnly,
      isNull,
    );
    expect(
      const DiveFilterState()
          .copyWith(excludedFromStatsOnly: true)
          .excludedFromStatsOnly,
      isTrue,
    );
  });

  test('the axis composes with other axes rather than replacing them', () {
    final favouriteAndExcluded = Dive(
      id: 'both',
      dateTime: DateTime(2026, 1, 4),
      excludedFromStats: true,
      isFavorite: true,
    );
    const filter = DiveFilterState(
      excludedFromStatsOnly: true,
      favoritesOnly: true,
    );
    expect(
      filter.apply([included, excluded, favouriteAndExcluded]).map((d) => d.id),
      ['both'],
    );
  });
}
