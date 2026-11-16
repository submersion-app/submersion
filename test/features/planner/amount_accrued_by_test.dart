import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/services/issue_onset.dart';

void main() {
  group('amountAccruedBy', () {
    const steps = [
      RuntimeIncrement(startRuntime: 0, durationSeconds: 100, amount: 50),
      RuntimeIncrement(startRuntime: 100, durationSeconds: 200, amount: 400),
      RuntimeIncrement(startRuntime: 300, durationSeconds: 0, amount: 30),
    ];

    test('counts every stretch finished by the runtime', () {
      expect(amountAccruedBy(steps, 300), 450);
    });

    test('counts a stretch under way in proportion', () {
      expect(amountAccruedBy(steps, 200), closeTo(250, 1e-9));
    });

    test('a lump at the runtime itself is still to come', () {
      expect(amountAccruedBy(steps, 300), 450);
      expect(amountAccruedBy(steps, 301), 480);
    });

    test('nothing before the dive starts', () {
      expect(amountAccruedBy(steps, 0), 0);
      expect(amountAccruedBy(const [], 500), 0);
    });
  });
}
