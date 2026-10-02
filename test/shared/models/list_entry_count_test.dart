import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/models/list_entry_count.dart';
import 'package:submersion/shared/models/subtitle_text.dart';

String _all(int count) => '$count dives';
String _filtered(int shown, int total) => '$shown of $total dives';
String _compact(int shown, int total) => '$shown of $total';

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

  // When a title is too narrow, the count falls back to a short form without
  // the noun; the title above it already names the list.
  group('ListEntryCount.subtitle', () {
    test('pairs the full label with a noun-free compact one', () {
      expect(
        const ListEntryCount.filtered(
          shown: 34,
          total: 812,
        ).subtitle(all: _all, filtered: _filtered, compactFiltered: _compact),
        const SubtitleText('34 of 812 dives', compact: '34 of 812'),
      );
    });

    test('an unfiltered compact form is the bare count', () {
      expect(
        const ListEntryCount.unfiltered(
          812,
        ).subtitle(all: _all, filtered: _filtered, compactFiltered: _compact),
        const SubtitleText('812 dives', compact: '812'),
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

    // A dependency change (another diver, say) reloads the list: the count
    // hides with the rows rather than showing the previous list's number.
    test('is null while the shown list reloads', () async {
      final generation = StateProvider<int>((ref) => 0);
      final pending = <Completer<List<int>>>[];
      final items = FutureProvider<List<int>>((ref) {
        ref.watch(generation);
        final load = Completer<List<int>>();
        pending.add(load);
        return load.future;
      });
      final count = Provider<ListEntryCount?>(
        (ref) => listEntryCount<int>(
          shown: ref.watch(items),
          isFiltered: false,
          total: () => ref.watch(items),
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(count, (_, _) {});
      addTearDown(sub.close);

      pending.last.complete([1, 2, 3]);
      await container.read(items.future);
      expect(container.read(count), const ListEntryCount.unfiltered(3));

      container.read(generation.notifier).state++;
      container.read(items);
      expect(container.read(items).isReloading, isTrue);
      expect(container.read(count), isNull);

      pending.last.complete([1]);
      await container.read(items.future);
      expect(container.read(count), const ListEntryCount.unfiltered(1));
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
