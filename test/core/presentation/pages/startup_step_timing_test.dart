import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/presentation/pages/startup_page.dart';

void main() {
  group('timeStartupStep', () {
    test('runs the step to completion', () async {
      var ran = false;
      await timeStartupStep('x', () async {
        ran = true;
      }, log: false);
      expect(ran, isTrue);
    });

    test('awaits the step before returning', () async {
      final order = <String>[];
      await timeStartupStep('x', () async {
        await Future<void>.delayed(Duration.zero);
        order.add('step');
      }, log: false);
      order.add('after');
      expect(order, ['step', 'after']);
    });

    test('logging branch completes without error', () async {
      // Exercises the debugPrint path (log: true) so both branches of the
      // timing helper are covered.
      var ran = false;
      await timeStartupStep('database', () async {
        ran = true;
      }, log: true);
      expect(ran, isTrue);
    });

    test('propagates errors thrown by the step', () async {
      await expectLater(
        timeStartupStep(
          'boom',
          () async => throw StateError('fail'),
          log: false,
        ),
        throwsStateError,
      );
    });
  });
}
