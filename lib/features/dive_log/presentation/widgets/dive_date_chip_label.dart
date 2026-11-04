import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _datePath = FieldPath(['date']);

/// [node] in plain words when it is a condition on the dive's date that those
/// words state exactly (#3457), or null for anything else. A chip must never
/// claim a strictness the filter does not apply, so a strict bound and a
/// negated date stay in the printer's wording.
String? diveDateChipLabel(
  QueryNode node, {
  required AppLocalizations l10n,
  required UnitFormatter units,
}) {
  if (node is! ConditionNode || node.path != _datePath) return null;
  String day(DateTime date) => units.formatMonthDayWithYear(date);
  return switch ((node.op, node.value)) {
    (QueryOp.inList, final DateRangeValue range) => _rangeLabel(
      range,
      l10n: l10n,
      units: units,
    ),
    (QueryOp.eq, DateValue(day: final date)) => day(date),
    (QueryOp.gte, DateValue(day: final date)) => l10n.diveLog_filterChip_from(
      day(date),
    ),
    (QueryOp.lte, DateValue(day: final date)) => l10n.diveLog_filterChip_until(
      day(date),
    ),
    _ => null,
  };
}

String _rangeLabel(
  DateRangeValue range, {
  required AppLocalizations l10n,
  required UnitFormatter units,
}) {
  final DateRangeValue(:start, :end) = range;
  final wholeMonths =
      start.day == 1 && DateTime(end.year, end.month + 1, 0).day == end.day;
  if (wholeMonths && start.year == end.year) {
    if (start.month == 1 && end.month == 12) return '${start.year}';
    if (start.month == end.month) return units.formatMonthYear(start);
  }
  return l10n.diveLog_filterChip_dateRange(
    units.formatMonthDayWithYear(start),
    units.formatMonthDayWithYear(end),
  );
}
