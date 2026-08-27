import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';

/// The Set-time dialog's mm:ss field (issue #1090) and the viewer's elapsed
/// chip share one formatter so what the diver types is what they later see.
void main() {
  group('formatElapsedMmSs', () {
    test('pads seconds to two digits', () {
      expect(formatElapsedMmSs(0), '0:00');
      expect(formatElapsedMmSs(65), '1:05');
      expect(formatElapsedMmSs(3599), '59:59');
    });

    test('keeps minutes unpadded past an hour', () {
      expect(formatElapsedMmSs(3600), '60:00');
      expect(formatElapsedMmSs(7325), '122:05');
    });

    test('formats a negative offset with a leading minus', () {
      expect(formatElapsedMmSs(-90), '-1:30');
    });
  });

  group('parseElapsedMmSs', () {
    test('parses m:ss and mm:ss', () {
      expect(parseElapsedMmSs('1:05'), 65);
      expect(parseElapsedMmSs('12:30'), 750);
      expect(parseElapsedMmSs('122:05'), 7325);
    });

    test('parses bare minutes', () {
      expect(parseElapsedMmSs('12'), 720);
    });

    test('tolerates surrounding whitespace', () {
      expect(parseElapsedMmSs(' 1:05 '), 65);
    });

    test('rejects malformed input', () {
      expect(parseElapsedMmSs(''), isNull);
      expect(parseElapsedMmSs('abc'), isNull);
      expect(parseElapsedMmSs('1:5:9'), isNull);
      expect(parseElapsedMmSs('1:75'), isNull);
      expect(parseElapsedMmSs('-1:00'), isNull);
    });
  });
}
