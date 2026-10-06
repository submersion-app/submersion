import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  test('first aid levels exist and are specialties, not ladder rungs', () {
    expect(CertificationLevel.firstAid.displayName, 'First Aid / CPR');
    expect(
      CertificationLevel.oxygenProvider.displayName,
      'Emergency Oxygen Provider',
    );
    expect(
      CertificationLevelCatalog.specialties,
      containsAll([
        CertificationLevel.firstAid,
        CertificationLevel.oxygenProvider,
      ]),
    );
  });

  test('both round trip by enum name, which is how rows store them', () {
    for (final level in [
      CertificationLevel.firstAid,
      CertificationLevel.oxygenProvider,
    ]) {
      final parsed = CertificationLevel.values.firstWhere(
        (v) => v.name == level.name,
        orElse: () => CertificationLevel.other,
      );
      expect(parsed, level);
    }
  });
}
