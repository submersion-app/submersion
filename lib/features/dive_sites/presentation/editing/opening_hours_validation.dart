import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The days that cannot be saved, as (schedule index, weekday): a range
/// that does not close after it opens, or ranges that overlap. Ranges that
/// touch (12:00 to 13:00, then 13:00 on) are fine.
Set<(int, int)> invalidOpeningDays(OpeningHours hours) {
  final invalid = <(int, int)>{};
  for (var i = 0; i < hours.schedules.length; i++) {
    final schedule = hours.schedules[i];
    for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
      final ranges = schedule.dayHours(d).ranges;
      var lastClose = -1;
      for (final range in ranges) {
        if (!range.isValid || range.opensAt < lastClose) {
          invalid.add((i, d));
          break;
        }
        lastClose = range.closesAt;
      }
    }
  }
  return invalid;
}

/// Whether the Opening hours card can be saved. Hours already stored that
/// would fail (from a sync or an import) do not block saving.
bool siteOpeningHoursIsValid(EditSession<DiveSite> session) {
  final hours = session.valueOf(siteOpeningHoursField);
  if (hours == null || invalidOpeningDays(hours).isEmpty) return true;
  return hours == session.stored.openingHours;
}
