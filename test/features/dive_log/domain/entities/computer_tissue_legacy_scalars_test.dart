import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_legacy_scalars.dart';

void main() {
  group('LegacyTissueScalars.of', () {
    test('reads start and end CNS, end OTU and the algorithm', () {
      final scalars = LegacyTissueScalars.of(const {
        'algorithm': 'Suunto Fused2 RGBM',
        'start': {'cns_percent': 3.0, 'otu': 0.0, 'n2_bar': <double>[]},
        'end': {'cns_percent': 14, 'otu': 35.57},
      });
      expect(scalars.cnsStart, 3.0);
      expect(scalars.cnsEnd, 14.0);
      expect(scalars.otu, 35.57);
      expect(scalars.algorithm, 'Suunto Fused2 RGBM');
      expect(scalars.isEmpty, isFalse);
    });

    test('is empty for a snapshot that never held them', () {
      final scalars = LegacyTissueScalars.of(const {
        'end': {'gf99_percent': 42.0},
      });
      expect(scalars.cnsStart, isNull);
      expect(scalars.cnsEnd, isNull);
      expect(scalars.otu, isNull);
      expect(scalars.algorithm, isNull);
      expect(scalars.isEmpty, isTrue);
    });

    test('reads malformed values as null instead of throwing', () {
      final scalars = LegacyTissueScalars.of(const {
        'algorithm': 7,
        'start': 'junk',
        'end': {'cns_percent': 'high', 'otu': true},
      });
      expect(scalars.isEmpty, isTrue);
    });

    test('a blank algorithm reads as none', () {
      expect(LegacyTissueScalars.of(const {'algorithm': '  '}).isEmpty, isTrue);
    });
  });

  group('LegacyTissueScalars.strip', () {
    test('drops the dive-level keys and keeps the tissue values', () {
      final stripped = LegacyTissueScalars.strip(const {
        'algorithm': 'zhl_16c',
        'start': {'cns_percent': 3.0, 'otu': 0.0, 'surface_gf_percent': 5.0},
        'end': {'cns_percent': 14.0, 'otu': 22.0, 'gf99_percent': 42.0},
        'future_key': 'kept',
      });
      expect(stripped, {
        'start': {'surface_gf_percent': 5.0},
        'end': {'gf99_percent': 42.0},
        'future_key': 'kept',
      });
    });

    test('drops a state the dive-level keys were all of', () {
      final stripped = LegacyTissueScalars.strip(const {
        'start': {'cns_percent': 3.0},
        'end': {'cns_percent': 14.0, 'gf99_percent': 42.0},
      });
      expect(stripped, {
        'end': {'gf99_percent': 42.0},
      });
    });

    test('leaves a non-map state as it is', () {
      final stripped = LegacyTissueScalars.strip(const {'start': 'junk'});
      expect(stripped, {'start': 'junk'});
    });

    test('does not change its argument', () {
      final json = <String, dynamic>{
        'algorithm': 'x',
        'end': <String, dynamic>{'otu': 1.0, 'gf99_percent': 2.0},
      };
      LegacyTissueScalars.strip(json);
      expect(json, {
        'algorithm': 'x',
        'end': {'otu': 1.0, 'gf99_percent': 2.0},
      });
    });
  });
}
