import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

void main() {
  test('DemoState round-trips through JSON', () {
    final s = DemoState(
      phase: DemoPhase.active,
      fromFirstRun: true,
      enteredAt: DateTime.utc(2026, 10, 26, 9),
    );

    expect(DemoState.fromJson(s.toJson()), s);
  });

  test('copyWith changes only the phase', () {
    final s = DemoState(
      phase: DemoPhase.entering,
      fromFirstRun: false,
      enteredAt: DateTime.utc(2026, 10, 26, 9),
    );

    final next = s.copyWith(phase: DemoPhase.exiting);

    expect(next.phase, DemoPhase.exiting);
    expect(next.fromFirstRun, isFalse);
    expect(next.enteredAt, s.enteredAt);
  });

  test('fromJson throws FormatException for a non-string enteredAt', () {
    expect(
      () => DemoState.fromJson({
        'phase': 'active',
        'fromFirstRun': false,
        'enteredAt': 1761469200000,
      }),
      throwsFormatException,
    );
  });

  test('fromJson throws FormatException for an unknown phase', () {
    expect(
      () => DemoState.fromJson({
        'phase': 'sideways',
        'fromFirstRun': false,
        'enteredAt': '2026-10-26T09:00:00.000Z',
      }),
      throwsFormatException,
    );
  });
}
