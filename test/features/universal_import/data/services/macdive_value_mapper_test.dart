import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';

void main() {
  group('MacDiveValueMapper.waterType', () {
    test('maps saltwater strings', () {
      expect(MacDiveValueMapper.waterType('saltwater'), isNotNull);
      expect(MacDiveValueMapper.waterType('Salt'), isNotNull);
      expect(MacDiveValueMapper.waterType('sea'), isNotNull);
      expect(MacDiveValueMapper.waterType('Ocean'), isNotNull);
    });

    test('maps freshwater strings', () {
      expect(MacDiveValueMapper.waterType('freshwater'), isNotNull);
      expect(MacDiveValueMapper.waterType('Fresh'), isNotNull);
      expect(MacDiveValueMapper.waterType('lake'), isNotNull);
      expect(MacDiveValueMapper.waterType('river'), isNotNull);
    });

    test('maps brackish strings', () {
      expect(MacDiveValueMapper.waterType('brackish'), isNotNull);
      expect(MacDiveValueMapper.waterType('Brackish'), isNotNull);
    });

    test('returns null for unknown or empty', () {
      expect(MacDiveValueMapper.waterType('swamp'), isNull);
      expect(MacDiveValueMapper.waterType(null), isNull);
      expect(MacDiveValueMapper.waterType(''), isNull);
      expect(MacDiveValueMapper.waterType('   '), isNull);
    });
  });

  group('MacDiveValueMapper.entryType', () {
    test('maps boat and related entries', () {
      expect(MacDiveValueMapper.entryType('boat'), isNotNull);
      expect(MacDiveValueMapper.entryType('Boat'), isNotNull);
      expect(MacDiveValueMapper.entryType('liveaboard'), isNotNull);
    });

    test('maps shore and related entries', () {
      expect(MacDiveValueMapper.entryType('shore'), isNotNull);
      expect(MacDiveValueMapper.entryType('beach'), isNotNull);
      expect(MacDiveValueMapper.entryType('Shore'), isNotNull);
    });

    test('maps back roll entries', () {
      expect(MacDiveValueMapper.entryType('back roll'), isNotNull);
      expect(MacDiveValueMapper.entryType('backroll'), isNotNull);
      expect(MacDiveValueMapper.entryType('Back Roll'), isNotNull);
    });

    test('maps giant stride entries', () {
      expect(MacDiveValueMapper.entryType('giant stride'), isNotNull);
      expect(MacDiveValueMapper.entryType('giantstride'), isNotNull);
      expect(MacDiveValueMapper.entryType('Giant Stride'), isNotNull);
    });

    test('returns null for unknown or empty', () {
      expect(MacDiveValueMapper.entryType(null), isNull);
      expect(MacDiveValueMapper.entryType(''), isNull);
      expect(MacDiveValueMapper.entryType('   '), isNull);
      expect(MacDiveValueMapper.entryType('cave'), isNull);
    });
  });

  group('MacDiveValueMapper.rating', () {
    test('rounds fractional ratings', () {
      expect(MacDiveValueMapper.rating(3.2), 3);
      expect(MacDiveValueMapper.rating(4.7), 5);
      expect(MacDiveValueMapper.rating(2.5), 3);
    });

    test('clamps out-of-range', () {
      expect(MacDiveValueMapper.rating(-1.0), 0);
      expect(MacDiveValueMapper.rating(7.5), 5);
      expect(MacDiveValueMapper.rating(0.0), 0);
      expect(MacDiveValueMapper.rating(5.0), 5);
    });

    test('null passes through', () {
      expect(MacDiveValueMapper.rating(null), isNull);
    });
  });

  group('MacDiveValueMapper.normalizeDiveType', () {
    test('trims whitespace', () {
      expect(
        MacDiveValueMapper.normalizeDiveType('  Recreational  '),
        'Recreational',
      );
      expect(MacDiveValueMapper.normalizeDiveType('\tNight\n'), 'Night');
    });

    test('passes through arbitrary strings', () {
      expect(MacDiveValueMapper.normalizeDiveType('Night'), 'Night');
      expect(MacDiveValueMapper.normalizeDiveType('Cave'), 'Cave');
      expect(
        MacDiveValueMapper.normalizeDiveType('custom-dive-type'),
        'custom-dive-type',
      );
    });
  });
}
