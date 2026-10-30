import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/models/sort_state_codec.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_group_by_display.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/presentation/utils/site_group_by_display.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Labelers for how the diver left each list (issue #3748): a sort reads as
// its field and direction, a grouping as its sheet names it.

/// A labeler for a sort stored as `field:direction`; null for a value this
/// build cannot decode, so the formatter prints it as stored.
ConflictEnumLabeler _sortLabeler<T extends Enum>(
  List<T> fields,
  String Function(AppLocalizations l10n, T field) name,
) => (l10n, stored) {
  final sort = decodeSortState(stored, fields);
  if (sort == null) return null;
  return l10n.settings_conflict_sortValue(
    name(l10n, sort.field),
    sort.direction.localizedName(l10n),
  );
};

final ConflictEnumLabeler diveListSortLabeler = _sortLabeler(
  DiveSortField.values,
  (l, v) => v.localizedName(l),
);
final ConflictEnumLabeler divePlanListSortLabeler = _sortLabeler(
  DivePlanSortField.values,
  (l, v) => v.localizedName(l),
);
final ConflictEnumLabeler tripListSortLabeler = _sortLabeler(
  TripSortField.values,
  (l, v) => v.localizedName(l),
);
final ConflictEnumLabeler courseListSortLabeler = _sortLabeler(
  CourseSortField.values,
  (l, v) => v.localizedName(l),
);
final ConflictEnumLabeler buddyListSortLabeler = _sortLabeler(
  BuddySortField.values,
  (l, v) => v.localizedName(l),
);
final ConflictEnumLabeler diveCenterListSortLabeler = _sortLabeler(
  DiveCenterSortField.values,
  (l, v) => v.localizedName(l),
);
final ConflictEnumLabeler siteListSortLabeler = _sortLabeler(
  SiteSortField.values,
  (l, v) => v.localizedName(l),
);
final ConflictEnumLabeler certificationListSortLabeler = _sortLabeler(
  CertificationSortField.values,
  (l, v) => v.localizedName(l),
);
final ConflictEnumLabeler equipmentListSortLabeler = _sortLabeler(
  EquipmentSortField.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler siteListGroupByLabeler = enumLabeler(
  SiteGroupBy.values,
  (l, v) => v.localizedName(l),
);
final ConflictEnumLabeler certificationListGroupByLabeler = enumLabeler(
  CertificationGroupBy.values,
  (l, v) => v.localizedName(l),
);
