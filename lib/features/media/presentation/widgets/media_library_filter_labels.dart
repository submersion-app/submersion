import 'package:submersion/core/utils/unit_formatter.dart';

/// Renders a filter date range for display. Shared by the filter sheet and
/// the active-chip strip so the same range never reads two different ways.
///
/// Takes the caller's [UnitFormatter] so the range honours the diver's date
/// format preference rather than the locale default.
String formatFilterDateRange(
  UnitFormatter units,
  DateTime? from,
  DateTime? to,
) {
  if (from != null && to != null) {
    return '${units.formatDate(from)} - ${units.formatDate(to)}';
  }
  return units.formatDate(from ?? to!);
}
