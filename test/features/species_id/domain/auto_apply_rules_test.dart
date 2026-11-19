import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/auto_apply_rules.dart';

/// Whether the installed pack can ever tag a match on its own (issue
/// #4727): only when one of its confident bars is reachable. A bar above 1
/// is "never", since a score is a share of at most 1.
void main() {
  NamingConfig naming({required double withPlace, required double noPlace}) =>
      NamingConfig(
        provisional: false,
        minCropSide: 64,
        minOpenScore: 0.39,
        suggestScore: 0.64,
        confidentScore: withPlace,
        suggestScoreNoLocation: 0.79,
        confidentScoreNoLocation: noPlace,
        minAllowedCandidates: 200,
        topK: 5,
      );

  test('both bars never: the pack cannot apply', () {
    final n = naming(withPlace: 1.01, noPlace: 1.01);
    expect(packCanApply(n), isFalse);
    expect(packAppliesOnlyWithPlace(n), isFalse);
  });

  test('a bar only with a place: applies, only with a location', () {
    final n = naming(withPlace: 0.95, noPlace: 1.01);
    expect(packCanApply(n), isTrue);
    expect(packAppliesOnlyWithPlace(n), isTrue);
  });

  test('both bars reachable: applies everywhere', () {
    final n = naming(withPlace: 0.95, noPlace: 0.97);
    expect(packCanApply(n), isTrue);
    expect(packAppliesOnlyWithPlace(n), isFalse);
  });
}
