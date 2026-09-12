import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every tag has a label and none is the raw name', () {
    for (final tag in ObservationTag.values) {
      final label = tag.localizedName(l10n);
      expect(label, isNotEmpty, reason: tag.name);
      expect(label, isNot(tag.name), reason: tag.name);
    }
    expect(ObservationTag.freeFlow.localizedName(l10n), 'Free flow');
    expect(ObservationStatus.issue.localizedName(l10n), 'Issue');
  });
}
