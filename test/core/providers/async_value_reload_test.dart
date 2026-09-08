import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/core/providers/ref_invalidate_on_change.dart';

/// `valueOrNull` and the built-in `AsyncValue.value` are not interchangeable,
/// and the difference is narrower than it looks.
///
/// The polyfill is `when(data:, error:, loading:)`, and `when` defaults to
/// `skipLoadingOnRefresh: true` with `skipLoadingOnReload: false`. So an
/// invalidate or refresh keeps the previous value through BOTH getters, while
/// a reload driven by a dependency changing drops it through `valueOrNull`
/// only. `value` keeps it in every case and never throws.
///
/// That asymmetry is why a `valueOrNull` read can look correct for a long
/// time and then flicker once a provider gains a dependency that moves: the
/// profile chart hit it (#1468), and the "Separate combined dives" action
/// reads the same shape (#1504). Pinned so the two getters cannot be swapped
/// on the assumption they agree.
void main() {
  late ProviderContainer container;
  late Completer<int> next;

  final trigger = NotifierProvider<_Trigger, int>(_Trigger.new);
  final refreshed = FutureProvider<int>((ref) => next.future);
  final derived = FutureProvider<int>((ref) {
    ref.watch(trigger);
    return next.future;
  });

  setUp(() {
    next = Completer<int>();
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  test('an invalidate keeps the previous value through both getters', () async {
    container.listen(refreshed, (_, _) {});
    next.complete(2);
    expect(await container.read(refreshed.future), 2);

    next = Completer<int>();
    container.invalidate(refreshed);

    final reloading = container.read(refreshed);
    expect(reloading.isLoading, isTrue, reason: 'expected a refresh');
    expect(reloading.value, 2);
    // when() defaults skipLoadingOnRefresh: true, so the data branch runs.
    expect(reloading.valueOrNull, 2);

    next.complete(3);
  });

  test('a dependency-driven reload drops it through valueOrNull', () async {
    container.listen(derived, (_, _) {});
    next.complete(2);
    expect(await container.read(derived.future), 2);

    next = Completer<int>();
    container.read(trigger.notifier).bump();

    final reloading = container.read(derived);
    expect(reloading.isLoading, isTrue, reason: 'expected a reload');
    expect(reloading.value, 2);
    // skipLoadingOnReload defaults to false, so the loading branch runs.
    expect(reloading.valueOrNull, isNull);
    // A caller's fallback turns that into a wrong answer: 0 segments reads
    // as "this dive was never combined", so the action disappears.
    expect(reloading.value ?? 0, 2);
    expect(reloading.valueOrNull ?? 0, 0);

    next.complete(3);
  });

  // The tick that actually drives diveSegmentCountProvider: a repository
  // change stream feeding invalidateSelfWhen, which calls invalidateSelf.
  // That is a refresh rather than a reload, so both getters keep the previous
  // count. Pinned because the opposite is the intuitive reading, and it is what
  // made the dive-detail read look like a live flicker when it is not (#1504).
  test('an invalidateSelfWhen tick refreshes, so both getters hold', () async {
    final ticks = StreamController<void>.broadcast();
    addTearDown(ticks.close);
    final selfInvalidating = FutureProvider<int>((ref) {
      ref.invalidateSelfWhen(ticks.stream);
      return next.future;
    });

    container.listen(selfInvalidating, (_, _) {});
    next.complete(2);
    expect(await container.read(selfInvalidating.future), 2);

    next = Completer<int>();
    ticks.add(null);
    await Future<void>.delayed(Duration.zero);

    final rebuilding = container.read(selfInvalidating);
    expect(rebuilding.isLoading, isTrue);
    expect(
      rebuilding.isReloading,
      isFalse,
      reason: 'invalidateSelf is a refresh, not a dependency-driven reload',
    );
    expect(rebuilding.value, 2);
    expect(rebuilding.valueOrNull, 2);

    next.complete(3);
  });

  test('both are null on a first load, before any value exists', () {
    container.listen(refreshed, (_, _) {});

    final loading = container.read(refreshed);
    expect(loading.isLoading, isTrue);
    expect(loading.value, isNull);
    expect(loading.valueOrNull, isNull);

    next.complete(1);
  });

  test('value does not throw on an error state', () async {
    container.listen(refreshed, (_, _) {});
    next.completeError(StateError('boom'));
    await expectLater(container.read(refreshed.future), throwsStateError);

    final failed = container.read(refreshed);
    expect(failed.hasError, isTrue);
    expect(failed.value, isNull);
    expect(failed.valueOrNull, isNull);
  });
}

class _Trigger extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
