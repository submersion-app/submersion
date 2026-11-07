import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/retain_until_idle.dart';

const _idle = Duration(minutes: 5);

FutureProvider<int> Function(String) _family(
  int Function() onBuild,
  void Function() onDispose,
) => FutureProvider.autoDispose.family<int, String>((ref, id) async {
  retainUntilIdle(ref, _idle);
  ref.onDispose(onDispose);
  return onBuild();
}).call;

void main() {
  late int builds;
  late int disposals;
  late FutureProvider<int> Function(String) family;

  setUp(() {
    builds = 0;
    disposals = 0;
    family = _family(() => ++builds, () => disposals++);
  });

  test('an unwatched read is held for the window, then released', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      container.read(family('a').future);
      async.flushMicrotasks();
      expect(builds, 1);

      async.elapse(_idle - const Duration(seconds: 1));
      expect(container.exists(family('a')), isTrue);

      async.elapse(const Duration(seconds: 2));
      expect(container.exists(family('a')), isFalse);
      expect(disposals, 1);
      container.dispose();
    });
  });

  test('a watched entry outlives the window while it is watched', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final sub = container.listen(family('a'), (_, _) {});
      async.elapse(_idle * 3);
      expect(container.exists(family('a')), isTrue);
      expect(disposals, 0);
      sub.close();
      container.dispose();
    });
  });

  test('the window starts when the last listener leaves', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final sub = container.listen(family('a'), (_, _) {});
      async.elapse(_idle * 2);
      sub.close();
      async.flushMicrotasks();

      async.elapse(_idle - const Duration(seconds: 1));
      expect(container.exists(family('a')), isTrue);
      expect(builds, 1);

      async.elapse(const Duration(seconds: 2));
      expect(container.exists(family('a')), isFalse);
      container.dispose();
    });
  });

  test('coming back within the window reuses the value and restarts it', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      var sub = container.listen(family('a'), (_, _) {});
      async.flushMicrotasks();
      sub.close();
      async.elapse(_idle - const Duration(minutes: 1));

      sub = container.listen(family('a'), (_, _) {});
      async.elapse(_idle * 2);
      expect(builds, 1, reason: 'the retained value is reused');
      sub.close();
      async.flushMicrotasks();

      async.elapse(_idle - const Duration(seconds: 1));
      expect(container.exists(family('a')), isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(container.exists(family('a')), isFalse);
      container.dispose();
    });
  });

  test('a rebuild while watched keeps the entry and its window', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final sub = container.listen(family('a'), (_, _) {});
      async.flushMicrotasks();
      container.invalidate(family('a'));
      async.flushMicrotasks();
      async.elapse(_idle * 2);
      expect(builds, 2);
      expect(container.exists(family('a')), isTrue);

      sub.close();
      async.flushMicrotasks();
      async.elapse(_idle - const Duration(seconds: 1));
      expect(container.exists(family('a')), isTrue);
      async.elapse(const Duration(seconds: 2));
      expect(container.exists(family('a')), isFalse);
      container.dispose();
    });
  });

  test('a dependency is released together with its dependent', () {
    fakeAsync((async) {
      final dependent = FutureProvider.autoDispose.family<int, String>((
        ref,
        id,
      ) async {
        retainUntilIdle(ref, _idle);
        return await ref.watch(family(id).future) + 1;
      });
      final container = ProviderContainer();
      final sub = container.listen(dependent('a'), (_, _) {});
      async.flushMicrotasks();
      async.elapse(_idle * 2);
      sub.close();
      async.flushMicrotasks();

      async.elapse(_idle + const Duration(seconds: 1));
      expect(container.exists(dependent('a')), isFalse);
      expect(container.exists(family('a')), isFalse);
      container.dispose();
    });
  });

  test('each entry keeps its own window', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      container.read(family('a').future);
      async.elapse(const Duration(minutes: 3));
      container.read(family('b').future);
      async.elapse(const Duration(minutes: 3));

      expect(container.exists(family('a')), isFalse);
      expect(container.exists(family('b')), isTrue);
      async.elapse(const Duration(minutes: 3));
      expect(container.exists(family('b')), isFalse);
      container.dispose();
    });
  });
}
