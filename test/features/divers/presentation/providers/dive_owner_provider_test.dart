import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// diveOwnerProvider (#4458): "me" on a dive is its owner, falling back to
/// the active diver, and reusing the active diver's instance when it is
/// theirs.
void main() {
  final now = DateTime(2024, 1, 1);
  Diver diver(String id) =>
      Diver(id: id, name: id, createdAt: now, updatedAt: now);

  late List<String> byIdReads;

  ProviderContainer container({
    required Future<Diver?> Function() current,
    Map<String, Diver> diversById = const {},
  }) {
    byIdReads = [];
    final c = ProviderContainer(
      overrides: [
        currentDiverProvider.overrideWith((ref) => current()),
        diverByIdProvider.overrideWith((ref, id) async {
          byIdReads.add(id);
          return diversById[id];
        }),
      ],
      // A failing override must fail at once, not sit in retries.
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a dive with no owner is the active diver', () async {
    final active = diver('active');
    final c = container(current: () async => active);

    expect(await c.awaitFuture(diveOwnerProvider(null).future), same(active));
  });

  test("the active diver's own dive reuses their instance", () async {
    final active = diver('active');
    final c = container(
      current: () async => active,
      diversById: {'active': diver('active')},
    );

    // In the app the active diver is loaded long before a dive opens.
    await c.awaitFuture(currentDiverProvider.future);

    expect(
      await c.awaitFuture(diveOwnerProvider('active').future),
      same(active),
    );
    expect(byIdReads, isEmpty);
  });

  test("an active diver settling late moves onto their instance", () async {
    final active = diver('active');
    final settle = Completer<Diver?>();
    final c = container(
      current: () => settle.future,
      diversById: {'active': diver('active')},
    );
    final sub = c.listen(diveOwnerProvider('active'), (_, _) {});
    addTearDown(sub.close);

    // Not waited for: the owner loads by id meanwhile.
    final early = await c.awaitFuture(diveOwnerProvider('active').future);
    expect(early?.id, 'active');
    expect(early, isNot(same(active)));

    settle.complete(active);
    await c.awaitFuture(currentDiverProvider.future);
    expect(
      await c.awaitFuture(diveOwnerProvider('active').future),
      same(active),
    );
  });

  test("another profile's dive loads that profile", () async {
    final owner = diver('owner');
    final c = container(
      current: () async => diver('active'),
      diversById: {'owner': owner},
    );

    expect(await c.awaitFuture(diveOwnerProvider('owner').future), same(owner));
  });

  test(
    "a failed active-diver lookup does not block another profile's dive",
    () async {
      final owner = diver('owner');
      final c = container(
        current: () async => throw StateError('no active diver'),
        diversById: {'owner': owner},
      );

      expect(
        await c.awaitFuture(diveOwnerProvider('owner').future),
        same(owner),
      );
    },
  );

  test("an active-diver read that never settles does not block another "
      "profile's dive", () async {
    // Stands in for a read stuck loading or in Riverpod's retries.
    final owner = diver('owner');
    final c = container(
      current: () => Completer<Diver?>().future,
      diversById: {'owner': owner},
    );

    expect(await c.awaitFuture(diveOwnerProvider('owner').future), same(owner));
  });
}
