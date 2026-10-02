import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/data/services/deco_classification_service.dart';

void main() {
  group('decoInputsHash', () {
    test('is stable for identical inputs', () {
      final a = decoInputsHash(
        engineVersion: 3,
        settingsFingerprint: 'a1;gf=50/85',
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 3,
        settingsFingerprint: 'a1;gf=50/85',
        diveUpdatedAt: 1000,
      );
      expect(a, b);
    });

    test('changes when a diver setting changes', () {
      final a = decoInputsHash(
        engineVersion: 3,
        settingsFingerprint: 'a1;gf=50/85',
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 3,
        settingsFingerprint: 'a1;gf=50/80',
        diveUpdatedAt: 1000,
      );
      expect(a, isNot(b));
    });

    test('changes when the dive is edited', () {
      final a = decoInputsHash(
        engineVersion: 3,
        settingsFingerprint: 'a1;gf=50/85',
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 3,
        settingsFingerprint: 'a1;gf=50/85',
        diveUpdatedAt: 2000,
      );
      expect(a, isNot(b));
    });

    test('changes when the analysis engine is bumped', () {
      final a = decoInputsHash(
        engineVersion: 3,
        settingsFingerprint: 'a1;gf=50/85',
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 4,
        settingsFingerprint: 'a1;gf=50/85',
        diveUpdatedAt: 1000,
      );
      expect(a, isNot(b));
    });

    test('does not collide when adjacent fields shift a digit', () {
      // A naive concatenation without separators would make (engine 1,
      // revision 21) and (engine 12, revision 1) hash identically.
      final a = decoInputsHash(
        engineVersion: 1,
        settingsFingerprint: 'x',
        diveUpdatedAt: 21,
      );
      final b = decoInputsHash(
        engineVersion: 12,
        settingsFingerprint: 'x',
        diveUpdatedAt: 1,
      );
      expect(a, isNot(b));
    });
  });
}
