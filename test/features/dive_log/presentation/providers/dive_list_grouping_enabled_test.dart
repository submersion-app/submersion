import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  ProviderContainer makeContainer({
    required bool toggle,
    required DiveSortField sortField,
    required ListViewMode viewMode,
  }) {
    final container = ProviderContainer(
      overrides: [
        diveListGroupTripsProvider.overrideWith((ref) => toggle),
        diveSortProvider.overrideWith(
          (ref) =>
              SortState(field: sortField, direction: SortDirection.descending),
        ),
        diveListViewModeProvider.overrideWith((ref) => viewMode),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('diveListGroupingEnabledProvider', () {
    test('on under a date sort in detailed mode', () {
      final container = makeContainer(
        toggle: true,
        sortField: DiveSortField.date,
        viewMode: ListViewMode.detailed,
      );
      expect(container.read(diveListGroupingEnabledProvider), isTrue);
    });

    test('on under a dive-number sort in compact mode', () {
      final container = makeContainer(
        toggle: true,
        sortField: DiveSortField.diveNumber,
        viewMode: ListViewMode.compact,
      );
      expect(container.read(diveListGroupingEnabledProvider), isTrue);
    });

    test('off when the toggle is off', () {
      final container = makeContainer(
        toggle: false,
        sortField: DiveSortField.date,
        viewMode: ListViewMode.detailed,
      );
      expect(container.read(diveListGroupingEnabledProvider), isFalse);
    });

    test('off under a depth sort', () {
      final container = makeContainer(
        toggle: true,
        sortField: DiveSortField.depth,
        viewMode: ListViewMode.detailed,
      );
      expect(container.read(diveListGroupingEnabledProvider), isFalse);
    });

    test('off under a site sort', () {
      final container = makeContainer(
        toggle: true,
        sortField: DiveSortField.site,
        viewMode: ListViewMode.detailed,
      );
      expect(container.read(diveListGroupingEnabledProvider), isFalse);
    });

    test('off in table mode', () {
      final container = makeContainer(
        toggle: true,
        sortField: DiveSortField.date,
        viewMode: ListViewMode.table,
      );
      expect(container.read(diveListGroupingEnabledProvider), isFalse);
    });

    test('an ascending date sort still groups', () {
      final container = ProviderContainer(
        overrides: [
          diveListGroupTripsProvider.overrideWith((ref) => true),
          diveSortProvider.overrideWith(
            (ref) => const SortState(
              field: DiveSortField.date,
              direction: SortDirection.ascending,
            ),
          ),
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(diveListGroupingEnabledProvider), isTrue);
    });
  });
}
