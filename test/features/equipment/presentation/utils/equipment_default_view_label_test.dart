import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_default_view_label.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels_settings.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// The default equipment view as one line (issue #2628), for the Manage row
/// and the sync conflict dialog.
void main() {
  final en = AppLocalizationsEn();

  test('the label lists statuses in enum order', () {
    expect(
      equipmentDefaultStatusesLabel({
        EquipmentStatus.lost,
        EquipmentStatus.active,
      }, en),
      'Active, Lost',
    );
    expect(
      equipmentDefaultStatusesLabel(factoryDefaultEquipmentStatuses, en),
      'Active, Spare, Needs Service, In Service, Loaned Out, Lost',
    );
  });

  test(
    'the conflict labeler names a stored set, or nothing it cannot read',
    () {
      expect(
        equipmentDefaultStatusesLabeler(en, '["active","retired"]'),
        'Active, Retired',
      );
      expect(equipmentDefaultStatusesLabeler(en, 'oops'), isNull);
      expect(equipmentDefaultStatusesLabeler(en, '["hovercraft"]'), isNull);
    },
  );
}
