import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/master_detail/remembered_selection.dart';

/// A list returned to reopens the record the diver last opened only while
/// that record is still in the list it shows (#3301).
void main() {
  group('rememberedListedId', () {
    String idOf(String item) => item;

    test('nothing remembered resolves at once, even while loading', () {
      expect(
        rememberedListedId<String>(
          items: const AsyncLoading(),
          rememberedId: null,
          idOf: idOf,
        ),
        const AsyncData<String?>(null),
      );
    });

    test('waits while the items load', () {
      expect(
        rememberedListedId<String>(
          items: const AsyncLoading(),
          rememberedId: 'a',
          idOf: idOf,
        ).isLoading,
        isTrue,
      );
    });

    test(
      'waits for a reload rather than matching the rows it replaces',
      () async {
        // A filter or diver change reloads the list; until the new rows land
        // the old ones are only a previous value.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final source = StateProvider<int>((ref) => 0);
        final rows = FutureProvider<List<String>>((ref) async {
          ref.watch(source);
          return ['a', 'b'];
        });
        container.listen(rows, (_, _) {});
        await container.read(rows.future);
        container.read(source.notifier).state++;
        final reloading = container.read(rows);
        expect(reloading.isLoading && reloading.hasValue, isTrue);

        expect(
          rememberedListedId<String>(
            items: reloading,
            rememberedId: 'b',
            idOf: idOf,
          ).isLoading,
          isTrue,
        );
      },
    );

    test('a listed id resolves to itself', () {
      expect(
        rememberedListedId<String>(
          items: const AsyncData(['a', 'b']),
          rememberedId: 'b',
          idOf: idOf,
        ),
        const AsyncData<String?>('b'),
      );
    });

    test('an id the list does not show resolves to null', () {
      // Deleted, filtered out, or from another diver's log.
      expect(
        rememberedListedId<String>(
          items: const AsyncData(['a']),
          rememberedId: 'gone',
          idOf: idOf,
        ),
        const AsyncData<String?>(null),
      );
    });

    test('a failed load resolves to null rather than waiting forever', () {
      expect(
        rememberedListedId<String>(
          items: AsyncError(Exception('boom'), StackTrace.empty),
          rememberedId: 'a',
          idOf: idOf,
        ),
        const AsyncData<String?>(null),
      );
    });
  });

  testWidgets('opening a record forgets only its own list\'s closed pane', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(closedPaneRecordProvider.notifier).state = const {
      'sites': 's1',
      'dives': 'd1',
    };
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );

    forgetClosedPane(widgetRef, 'sites');

    expect(container.read(closedPaneRecordProvider), {'dives': 'd1'});
  });

  test('closedPaneRecordProvider starts empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(closedPaneRecordProvider), isEmpty);
  });
}
