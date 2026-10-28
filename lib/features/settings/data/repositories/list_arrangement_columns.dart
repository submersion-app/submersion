import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';

extension ListArrangementColumns on DiverSettingsCompanion {
  /// This companion with every list arrangement column (v323, issue #3748)
  /// set from [arrangements], null where the diver never changed that list.
  DiverSettingsCompanion withListArrangements(ListArrangements arrangements) =>
      copyWith(
        diveListSort: Value(arrangements.diveSort),
        divePlanListSort: Value(arrangements.divePlanSort),
        tripListSort: Value(arrangements.tripSort),
        courseListSort: Value(arrangements.courseSort),
        buddyListSort: Value(arrangements.buddySort),
        diveCenterListSort: Value(arrangements.diveCenterSort),
        siteListSort: Value(arrangements.siteSort),
        certificationListSort: Value(arrangements.certificationSort),
        equipmentListSort: Value(arrangements.equipmentSort),
        siteListGroupBy: Value(arrangements.siteGroupBy),
        certificationListGroupBy: Value(arrangements.certificationGroupBy),
        equipmentArrangement: Value(arrangements.equipmentArrangement),
        equipmentGroupByLocation: Value(arrangements.equipmentGroupByLocation),
      );
}

/// The list arrangements stored on [row], raw, unknown values included.
ListArrangements listArrangementsFromRow(DiverSetting row) => ListArrangements(
  diveSort: row.diveListSort,
  divePlanSort: row.divePlanListSort,
  tripSort: row.tripListSort,
  courseSort: row.courseListSort,
  buddySort: row.buddyListSort,
  diveCenterSort: row.diveCenterListSort,
  siteSort: row.siteListSort,
  certificationSort: row.certificationListSort,
  equipmentSort: row.equipmentListSort,
  siteGroupBy: row.siteListGroupBy,
  certificationGroupBy: row.certificationListGroupBy,
  equipmentArrangement: row.equipmentArrangement,
  equipmentGroupByLocation: row.equipmentGroupByLocation,
);
