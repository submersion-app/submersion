import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/services/first_sync_cutoff.dart';

void main() {
  group('shearwaterWallclockTicks', () {
    test('uses wallclock fields regardless of isUtc flag', () {
      final utc = DateTime.utc(2026, 6, 12, 14, 30, 5);
      final local = DateTime(2026, 6, 12, 14, 30, 5);
      expect(shearwaterWallclockTicks(utc), shearwaterWallclockTicks(local));
      expect(
        shearwaterWallclockTicks(utc),
        DateTime.utc(2026, 6, 12, 14, 30, 5).millisecondsSinceEpoch ~/ 1000,
      );
    });

    test('drops sub-second precision', () {
      final t = DateTime.utc(2026, 6, 12, 14, 30, 5, 999);
      expect(
        shearwaterWallclockTicks(t),
        DateTime.utc(2026, 6, 12, 14, 30, 5).millisecondsSinceEpoch ~/ 1000,
      );
    });
  });

  group('synthesizeShearwaterFingerprint', () {
    test('encodes ticks as 8 lowercase hex chars, big-endian', () {
      final cutoff = DateTime.utc(2026, 6, 12, 14, 30, 5);
      final hex = synthesizeShearwaterFingerprint(cutoff);
      expect(hex.length, 8);
      expect(hex, hex.toLowerCase());
      expect(int.parse(hex, radix: 16), shearwaterWallclockTicks(cutoff));
    });
  });

  group('supportsTimestampFingerprintFloor', () {
    test('accepts Shearwater petrel-family products', () {
      for (final product in ['Teric', 'Perdix 2', 'Petrel 3', 'Peregrine']) {
        expect(
          supportsTimestampFingerprintFloor(
            vendor: 'Shearwater',
            product: product,
          ),
          isTrue,
        );
      }
    });

    test('rejects Predator, other vendors, and nulls', () {
      expect(
        supportsTimestampFingerprintFloor(
          vendor: 'Shearwater',
          product: 'Predator',
        ),
        isFalse,
      );
      expect(
        supportsTimestampFingerprintFloor(vendor: 'Suunto', product: 'D5'),
        isFalse,
      );
      expect(
        supportsTimestampFingerprintFloor(vendor: null, product: 'Teric'),
        isFalse,
      );
      expect(
        supportsTimestampFingerprintFloor(vendor: 'Shearwater', product: null),
        isFalse,
      );
    });
  });
}
