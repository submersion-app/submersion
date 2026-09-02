import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Renders a filter date range for display. Shared by the filter sheet and
/// the active-chip strip so the same range never reads two different ways.
///
/// Locale-aware by construction: the format comes from the active locale
/// rather than a hard-coded pattern.
String formatFilterDateRange(
  BuildContext context,
  DateTime? from,
  DateTime? to,
) {
  final format = DateFormat.yMMMd(Localizations.localeOf(context).toString());
  if (from != null && to != null) {
    return '${format.format(from)} - ${format.format(to)}';
  }
  return format.format(from ?? to!);
}
