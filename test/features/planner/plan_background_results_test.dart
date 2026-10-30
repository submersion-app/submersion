import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';

typedef _Result = AsyncValue<PlanResult<int>>;

/// A real provider whose dependency moves, the only way to reach the states
/// that hold a previous value: `copyWithPrevious` is internal to Riverpod.
class _Harness {
  _Harness() {
    addTearDown(container.dispose);
    container.listen(result, (_, _) {});
  }

  final container = ProviderContainer();
  final _trigger = StateProvider<int>((ref) => 0);
  var _next = Completer<PlanResult<int>>();

  late final result = FutureProvider<PlanResult<int>>((ref) {
    ref.watch(_trigger);
    return _next.future;
  }, retry: (_, _) => null);

  _Result get state => container.read(result);

  /// Starts a newer run that stays pending.
  void reload() {
    _next = Completer<PlanResult<int>>();
    container.read(_trigger.notifier).state++;
    container.read(result);
  }

  Future<void> landValue(PlanResult<int> value) async {
    _next.complete(value);
    await container.read(result.future);
  }

  Future<void> landError() async {
    _next.completeError(StateError('engine'));
    await expectLater(container.read(result.future), throwsStateError);
  }
}

void expectView(
  PlanResultView<int> view, {
  required int? value,
  required PlanResultStatus status,
}) {
  expect(view.value, value);
  expect(view.status, status);
}

void main() {
  group('planResultView', () {
    test('a finished result for this plan is current', () async {
      final harness = _Harness();
      await harness.landValue(const PlanResult(planId: 'p', value: 1));

      expectView(
        planResultView(harness.state, 'p'),
        value: 1,
        status: PlanResultStatus.current,
      );
    });

    test('a newer run keeps the last value and says it is updating', () async {
      final harness = _Harness();
      await harness.landValue(const PlanResult(planId: 'p', value: 1));
      harness.reload();

      expectView(
        planResultView(harness.state, 'p'),
        value: 1,
        status: PlanResultStatus.updating,
      );
    });

    test('a first run has nothing to show', () {
      final harness = _Harness();

      expectView(
        planResultView(harness.state, 'p'),
        value: null,
        status: PlanResultStatus.calculating,
      );
    });

    test('a pending run never shows another plan\'s value', () async {
      final harness = _Harness();
      await harness.landValue(const PlanResult(planId: 'other', value: 1));
      harness.reload();

      expectView(
        planResultView(harness.state, 'p'),
        value: null,
        status: PlanResultStatus.calculating,
      );
    });

    test('a finished result for another plan is not this plan\'s', () async {
      final harness = _Harness();
      await harness.landValue(const PlanResult(planId: 'other', value: 1));

      expectView(
        planResultView(harness.state, 'p'),
        value: null,
        status: PlanResultStatus.calculating,
      );
    });

    test('a failure with nothing to show says so', () async {
      final harness = _Harness();
      await harness.landError();

      expectView(
        planResultView(harness.state, 'p'),
        value: null,
        status: PlanResultStatus.failed,
      );
    });

    test('a failure keeps the last value and says so', () async {
      final harness = _Harness();
      await harness.landValue(const PlanResult(planId: 'p', value: 1));
      harness.reload();
      await harness.landError();

      expectView(
        planResultView(harness.state, 'p'),
        value: 1,
        status: PlanResultStatus.failed,
      );
    });

    test('a failure does not outlast the next run', () async {
      final harness = _Harness();
      await harness.landValue(const PlanResult(planId: 'p', value: 1));
      harness.reload();
      await harness.landError();
      harness.reload();

      expectView(
        planResultView(harness.state, 'p'),
        value: 1,
        status: PlanResultStatus.updating,
      );
    });

    test('a failed first run reads as calculating once it retries', () async {
      final harness = _Harness();
      await harness.landError();
      harness.reload();

      expectView(
        planResultView(harness.state, 'p'),
        value: null,
        status: PlanResultStatus.calculating,
      );
    });
  });

  test('isMarked is true for every status but current', () {
    bool marked(PlanResultStatus status) =>
        PlanResultView<int>(value: 1, status: status).isMarked;

    expect(marked(PlanResultStatus.current), isFalse);
    expect(marked(PlanResultStatus.updating), isTrue);
    expect(marked(PlanResultStatus.calculating), isTrue);
    expect(marked(PlanResultStatus.failed), isTrue);
  });

  group('combinePlanResultStatus takes the more severe', () {
    const severest = [
      PlanResultStatus.failed,
      PlanResultStatus.calculating,
      PlanResultStatus.updating,
      PlanResultStatus.current,
    ];

    for (var i = 0; i < severest.length; i++) {
      for (var j = i; j < severest.length; j++) {
        test('${severest[i].name} over ${severest[j].name}', () {
          expect(
            combinePlanResultStatus(severest[i], severest[j]),
            severest[i],
          );
          expect(
            combinePlanResultStatus(severest[j], severest[i]),
            severest[i],
          );
        });
      }
    }
  });
}
