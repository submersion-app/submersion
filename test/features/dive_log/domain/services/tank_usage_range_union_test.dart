import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';

void main() {
  group('unionOfWindows', () {
    test('merges overlapping and touching windows', () {
      expect(
        unionOfWindows([
          (start: 600, end: 900),
          (start: 0, end: 300),
          (start: 300, end: 400),
          (start: 850, end: 1000),
        ]),
        [(start: 0, end: 400), (start: 600, end: 1000)],
      );
    });

    test('keeps separate windows apart', () {
      expect(unionOfWindows([(start: 600, end: 1200), (start: 0, end: 300)]), [
        (start: 0, end: 300),
        (start: 600, end: 1200),
      ]);
    });

    test('drops zero-length windows', () {
      expect(unionOfWindows([(start: 5, end: 5)]), isEmpty);
    });

    test('is empty for no windows', () {
      expect(unionOfWindows(const []), isEmpty);
    });
  });
}
