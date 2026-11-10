import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How many types a folded place names before "and N more".
const int _summaryTypeLimit = 3;

const String _separator = ' · ';

/// What a folded place holds (issue #4184): its first three types with their
/// counts, in list order, then "and N more" for the rest, e.g.
/// "BCD 2 · Second Stage 1 · Tank 4 · and 2 more". Null when it holds no
/// typed group (type grouping off), since the count beside it already says
/// everything.
String? foldedLocationSummary(
  AppLocalizations l10n,
  List<(EquipmentType, int)> typeCounts,
) {
  if (typeCounts.isEmpty) return null;
  final shown = [
    for (final (type, count) in typeCounts.take(_summaryTypeLimit))
      l10n.equipment_group_foldedTypeCount(count, type.localizedName(l10n)),
  ];
  final rest = typeCounts.length - shown.length;
  return [
    ...shown,
    if (rest > 0) l10n.equipment_group_foldedMoreTypes(rest),
  ].join(_separator);
}

/// What a folded type group says (issue #4184): how many items inside need
/// service, or null when none do.
String? foldedTypeSummary(
  AppLocalizations l10n, {
  required int serviceDueCount,
}) => serviceDueCount == 0
    ? null
    : l10n.equipment_group_foldedServiceDue(serviceDueCount);

/// A folded group's line while items are ticked, so a ticked item is never
/// hidden without a trace (issue #3364): "2 of 8 selected", counting the
/// [ticked] ids among the group's [itemIds]. Null when none of them is
/// ticked.
String? foldedTickSummary(
  AppLocalizations l10n,
  Iterable<String> itemIds,
  Set<String> ticked,
) {
  var total = 0;
  var selected = 0;
  for (final id in itemIds) {
    total++;
    if (ticked.contains(id)) selected++;
  }
  return selected == 0
      ? null
      : l10n.equipment_group_foldedSelected(selected, total);
}
