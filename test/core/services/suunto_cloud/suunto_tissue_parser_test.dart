import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_tissue_parser.dart';

// Real EON Core (Fused2 RGBM, 15 compartments) values, in Pascal.
const _eonStartN2 = [
  79000,
  79000,
  79000,
  79000,
  79000,
  79000,
  79008,
  79123,
  79457,
  80568,
  81755,
  82776,
  83604,
  84269,
  85254,
];
const _eonEndN2 = [
  89665,
  97105,
  116432,
  135968,
  142849,
  131069,
  113059,
  103999,
  98930,
  94002,
  91918,
  90918,
  90376,
  90058,
  89736,
];

Map<String, dynamic> _eonCoreDiving() => {
  'Algorithm': 'Suunto Fused2 RGBM',
  'DesaturationTime': 61200,
  'StartTissue': {
    'Nitrogen': _eonStartN2,
    'Helium': List<int>.filled(15, 0),
    'RgbmNitrogen': 1.0,
    'RgbmHelium': 1.0,
    'CNS': 0.0,
    'OTU': 0.0,
  },
  'EndTissue': {
    'Nitrogen': _eonEndN2,
    'Helium': List<int>.filled(15, 0),
    'RgbmNitrogen': 0.98,
    'RgbmHelium': 0.985,
    'CNS': 0.132,
    'OTU': 35.57,
  },
};

void main() {
  group('parseSuuntoTissue (DeviceLog array encoding)', () {
    test('converts an EON Core header into a snapshot', () {
      final snapshot = parseSuuntoTissue(_eonCoreDiving());

      expect(snapshot, isNotNull);
      expect(snapshot!.algorithm, 'Suunto Fused2 RGBM');

      final start = snapshot.start!;
      expect(start.n2Bar, hasLength(15));
      expect(start.n2Bar!.first, 0.79);
      expect(start.n2Bar!.last, 0.85254);
      expect(start.heBar, hasLength(15));
      expect(start.heBar!.every((v) => v == 0), isTrue);

      final end = snapshot.end!;
      expect(end.n2Bar, hasLength(15));
      expect(end.n2Bar![4], 1.42849);
      expect(end.cnsPercent, closeTo(13.2, 1e-9));
      expect(end.otu, 35.57);
      expect(end.rgbmNitrogen, 0.98);
      expect(end.rgbmHelium, 0.985);
    });

    test('keeps five decimals when converting Pascal to bar', () {
      final snapshot = parseSuuntoTissue({
        'EndTissue': {
          'Nitrogen': [142849.4],
        },
      });

      expect(snapshot!.end!.n2Bar, [1.42849]);
    });

    test('leaves fields the source did not carry as null', () {
      final snapshot = parseSuuntoTissue(_eonCoreDiving());

      expect(snapshot!.end!.loadPercent, isNull);
      expect(snapshot.end!.n2LoadPercent, isNull);
      expect(snapshot.end!.gf99Percent, isNull);
      expect(snapshot.end!.surfaceGfPercent, isNull);
    });
  });

  group('parseSuuntoTissue (SML-XML derived encodings)', () {
    test('reads a Nitrogen object holding a Pressure list', () {
      final snapshot = parseSuuntoTissue({
        'Algorithm': 'Suunto Technical RGBM',
        'StartTissue': {
          'Nitrogen': {'Pressure': List<int>.filled(9, 79000)},
          'Helium': {'Pressure': List<int>.filled(9, 0)},
        },
        'EndTissue': {
          'OLF': 0.05,
          'CNS': 0.04,
          'OTU': 12.0,
          'RgbmNitrogen': 0.9,
          'RgbmHelium': 1.0,
        },
      });

      expect(snapshot, isNotNull);
      expect(snapshot!.algorithm, 'Suunto Technical RGBM');
      expect(snapshot.start!.n2Bar, hasLength(9));
      expect(snapshot.start!.n2Bar!.first, 0.79);
      expect(snapshot.start!.heBar, hasLength(9));

      // The HelO2 end state has no compartment arrays, only the summaries.
      final end = snapshot.end!;
      expect(end.n2Bar, isNull);
      expect(end.hasCompartments, isFalse);
      expect(end.cnsPercent, closeTo(4.0, 1e-9));
      expect(end.otu, 12.0);
      expect(end.rgbmNitrogen, 0.9);
      expect(end.rgbmHelium, 1.0);
    });

    test('reads a list of Pressure maps', () {
      final snapshot = parseSuuntoTissue({
        'StartTissue': {
          'Nitrogen': [
            {'Pressure': 79000},
            {'Pressure': 80000},
          ],
        },
      });

      expect(snapshot!.start!.n2Bar, [0.79, 0.8]);
    });

    test('falls back to OLF for the CNS percentage when CNS is absent', () {
      final snapshot = parseSuuntoTissue({
        'EndTissue': {'OLF': 0.25},
      });

      expect(snapshot!.end!.cnsPercent, closeTo(25.0, 1e-9));
    });
  });

  group('parseSuuntoTissue (absent or malformed data)', () {
    test('returns null for a header without tissue state', () {
      expect(parseSuuntoTissue({'GfLow': 30, 'GfHigh': 85}), isNull);
    });

    test('returns null when only the algorithm name is present', () {
      expect(parseSuuntoTissue({'Algorithm': 'Suunto Fused2 RGBM'}), isNull);
    });

    test('skips a state with no numeric content', () {
      final snapshot = parseSuuntoTissue({
        'Algorithm': 'Suunto Fused2 RGBM',
        'StartTissue': {'Nitrogen': <int>[], 'Helium': 'n/a'},
        'EndTissue': {
          'Nitrogen': [89665],
        },
      });

      expect(snapshot, isNotNull);
      expect(snapshot!.start, isNull);
      expect(snapshot.end!.n2Bar, [0.89665]);
    });

    test('drops a compartment list with a non-numeric element', () {
      final snapshot = parseSuuntoTissue({
        'EndTissue': {
          'Nitrogen': [89665, 'x', 90000],
          'CNS': 0.1,
        },
      });

      expect(snapshot!.end!.n2Bar, isNull);
      expect(snapshot.end!.cnsPercent, closeTo(10.0, 1e-9));
    });

    test('ignores a non-map tissue entry and a non-string algorithm', () {
      final snapshot = parseSuuntoTissue({
        'Algorithm': 42,
        'StartTissue': 'bogus',
        'EndTissue': {
          'Nitrogen': [89665],
        },
      });

      expect(snapshot!.algorithm, isNull);
      expect(snapshot.start, isNull);
      expect(snapshot.end!.n2Bar, [0.89665]);
    });
  });
}
