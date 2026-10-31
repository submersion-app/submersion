import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/await_future.dart';

void main() {
  test('returns the value of a provider nothing else listens to', () async {
    final value = FutureProvider<int>((ref) async => 1);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.awaitFuture(value.future), 1);
  });

  test('passes on the error of a failed provider', () async {
    final failing = FutureProvider<int>(
      (ref) async => throw StateError('boom'),
      retry: (_, _) => null,
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.awaitFuture(failing.future),
      throwsA(isA<StateError>()),
    );
  });

  test('survives the provider being invalidated mid-load', () async {
    final gate = Completer<void>();
    var builds = 0;
    final slow = FutureProvider<int>((ref) async {
      final build = ++builds;
      await gate.future;
      return build;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = container.awaitFuture(slow.future);
    await pumpEventQueue();
    container.invalidate(slow);
    await pumpEventQueue();
    gate.complete();

    expect(await result.timeout(const Duration(seconds: 5)), 2);
  });

  test('a provider the invalidated one watches is held active too', () async {
    final gate = Completer<void>();
    var builds = 0;
    final inner = FutureProvider<int>((ref) async {
      final build = ++builds;
      await gate.future;
      return build;
    });
    final outer = FutureProvider<int>((ref) async {
      return await ref.watch(inner.future) * 10;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = container.awaitFuture(outer.future);
    await pumpEventQueue();
    container.invalidate(inner);
    await pumpEventQueue();
    gate.complete();

    expect(await result.timeout(const Duration(seconds: 5)), 20);
  });

  test('lets go of the provider once it settles', () async {
    var disposed = false;
    final transient = FutureProvider.autoDispose<int>((ref) async {
      ref.onDispose(() => disposed = true);
      return 1;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.awaitFuture(transient.future);
    await container.pump();

    expect(disposed, isTrue);
  });
}
