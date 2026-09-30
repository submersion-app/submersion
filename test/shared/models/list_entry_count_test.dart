import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/models/list_entry_count.dart';

String _all(int count) => '$count dives';
String _filtered(int shown, int total) => '$shown of $total dives';

void main() {
  group('ListEntryCount.label', () {
    test('an unfiltered list reads its count alone', () {
      expect(
        const ListEntryCount.unfiltered(
          812,
        ).label(all: _all, filtered: _filtered),
        '812 dives',
      );
    });

    test('a filtered list reads shown of total', () {
      expect(
        const ListEntryCount.filtered(
          shown: 34,
          total: 812,
        ).label(all: _all, filtered: _filtered),
        '34 of 812 dives',
      );
    });

    // A filter that happens to match everything is still a filter, so the
    // diver is told the list is narrowed rather than guessing.
    test('a filter matching every entry still reads shown of total', () {
      expect(
        const ListEntryCount.filtered(
          shown: 812,
          total: 812,
        ).label(all: _all, filtered: _filtered),
        '812 of 812 dives',
      );
    });

    test('an empty list reads zero', () {
      expect(
        const ListEntryCount.unfiltered(
          0,
        ).label(all: _all, filtered: _filtered),
        '0 dives',
      );
    });
  });

  test('has value equality', () {
    expect(
      const ListEntryCount.filtered(shown: 1, total: 2),
      const ListEntryCount.filtered(shown: 1, total: 2),
    );
    expect(
      const ListEntryCount.unfiltered(2),
      isNot(const ListEntryCount.filtered(shown: 2, total: 2)),
    );
  });

  group('listEntryCount', () {
    test('is null while the shown list is loading', () {
      expect(
        listEntryCount<int>(
          shown: const AsyncValue.loading(),
          isFiltered: false,
          total: () => const AsyncValue.data([1]),
        ),
        isNull,
      );
    });

    test('counts the shown list when no filter is active', () {
      var totalRead = false;
      expect(
        listEntryCount<int>(
          shown: const AsyncValue.data([1, 2, 3]),
          isFiltered: false,
          total: () {
            totalRead = true;
            return const AsyncValue.data([1, 2, 3, 4]);
          },
        ),
        const ListEntryCount.unfiltered(3),
      );
      expect(totalRead, isFalse, reason: 'unfiltered needs no total query');
    });

    test('counts shown of total when a filter is active', () {
      expect(
        listEntryCount<int>(
          shown: const AsyncValue.data([1]),
          isFiltered: true,
          total: () => const AsyncValue.data([1, 2, 3]),
        ),
        const ListEntryCount.filtered(shown: 1, total: 3),
      );
    });

    test('is null while a filtered list waits on its total', () {
      expect(
        listEntryCount<int>(
          shown: const AsyncValue.data([1]),
          isFiltered: true,
          total: () => const AsyncValue.loading(),
        ),
        isNull,
      );
    });
  });
}
