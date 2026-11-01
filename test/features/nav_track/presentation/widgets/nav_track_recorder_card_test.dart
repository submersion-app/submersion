import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_recorder_card.dart';

void main() {
  group('formatSignedVolts', () {
    test('a drained battery reads negative', () {
      expect(formatSignedVolts(-0.12), '-0.12');
    });

    test('a charged battery reads positive', () {
      expect(formatSignedVolts(0.05), '+0.05');
    });

    test('a change too small to show carries no sign', () {
      expect(formatSignedVolts(-0.001), '0.00');
      expect(formatSignedVolts(0), '0.00');
    });
  });

  group('isolateForDirection', () {
    final lri = String.fromCharCode(0x2066);
    final pdi = String.fromCharCode(0x2069);

    test('wraps a signed figure in an LTR isolate inside RTL text', () {
      expect(isolateForDirection('-0.12', TextDirection.rtl), '$lri-0.12$pdi');
    });

    test('leaves LTR text alone', () {
      expect(isolateForDirection('-0.12', TextDirection.ltr), '-0.12');
    });
  });
}
