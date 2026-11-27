import 'package:flutter/material.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/core/opening_hours/opening_status.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/opening_schedule_editor.dart'
    show monthDayLabel;
import 'package:submersion/features/dive_sites/presentation/opening_hours_summary.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// A site's opening hours (issue #5073): whether it is open now, in the
/// site's own time zone, then each schedule's week and the note.
class SiteOpeningHoursCard extends ConsumerWidget {
  const SiteOpeningHoursCard({super.key, required this.site, this.now});

  final DiveSite site;

  /// The current instant; a seam for tests.
  final DateTime Function()? now;

  /// The site's own clock at this moment: from its position when it has
  /// one, else the device's.
  DateTime _wallClock() {
    final instant = (now ?? DateTime.now)();
    final location = site.location;
    if (location == null) return instant.toLocal();
    return SiteTimeZone.wallClockFromInstant(
      instant.toUtc(),
      location.latitude,
      location.longitude,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = site.openingHours;
    if (hours == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final wallClock = _wallClock();
    final note = hours.note?.trim();

    String time(int minutes) =>
        units.formatMinutesOfDay(minutes % minutesPerDay);
    String at(DateTime moment) {
      final clock = time(moment.hour * 60 + moment.minute);
      final sameDay =
          moment.year == wallClock.year &&
          moment.month == wallClock.month &&
          moment.day == wallClock.day;
      if (sameDay) return clock;
      // A week or so ahead, a weekday alone reads as this one: name the
      // date instead.
      final daysAhead = DateTime.utc(moment.year, moment.month, moment.day)
          .difference(
            DateTime.utc(wallClock.year, wallClock.month, wallClock.day),
          )
          .inDays;
      return daysAhead >= 6
          ? '${monthDayLabel(units, MonthDay.of(moment))} $clock'
          : '${weekdayName(context, moment.weekday, short: true)} $clock';
    }

    final status = hours.alwaysOpen ? null : openingStatusAt(hours, wallClock);
    final statusText = switch (status) {
      null || OpeningUnknown() => null,
      OpenNow(:final closesAt) =>
        closesAt == null
            ? l10n.diveSites_hours_openNoClose
            : l10n.diveSites_hours_openUntil(at(closesAt)),
      ClosedNow(:final nextOpen, :final outOfSeason) =>
        nextOpen == null
            ? l10n.diveSites_hours_closedNow
            : outOfSeason
            ? l10n.diveSites_hours_closedForSeason(
                monthDayLabel(units, MonthDay.of(nextOpen)),
              )
            : l10n.diveSites_hours_closedOpensAt(at(nextOpen)),
    };

    String dayHours(DayHours day) => switch (day.kind) {
      DayHoursKind.closed => l10n.diveSites_hours_closed,
      DayHoursKind.open24h => l10n.diveSites_hours_open24h,
      DayHoursKind.ranges =>
        day.ranges
            .map((r) => '${time(r.opensAt)}–${time(r.closesAt)}')
            .join(', '),
    };

    final weekOrder = localeWeekdays(context);
    final schedules = schedulesInDisplayOrder(hours, wallClock);
    final current = scheduleOn(hours, wallClock);
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    String? heading(OpeningSchedule schedule) {
      final name = schedule.name?.trim();
      final season = schedule.season;
      final dates = season == null
          ? null
          : l10n.diveSites_hours_span(
              monthDayLabel(units, season.start),
              monthDayLabel(units, season.end),
            );
      if (name != null && name.isNotEmpty && dates != null) {
        return l10n.diveSites_hours_namedSeason(name, dates);
      }
      return (name != null && name.isNotEmpty) ? name : dates;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordCardHeader(
              title: l10n.diveSites_detail_section_openingHours,
              leading: Icon(
                Icons.schedule,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (statusText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  statusText,
                  key: const ValueKey('site_hours_status'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: status is OpenNow
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (hours.alwaysOpen)
              Text(l10n.diveSites_hours_alwaysOpen)
            else
              for (final schedule in schedules) ...[
                if (heading(schedule) case final title?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Text(
                      title,
                      key: const ValueKey('site_hours_heading'),
                      style: secondary,
                    ),
                  ),
                for (final group in groupDays(schedule, weekOrder: weekOrder))
                  _DayGroupRow(
                    days: group.weekdays.length == 1
                        ? weekdayName(
                            context,
                            group.weekdays.single,
                            short: true,
                          )
                        : l10n.diveSites_hours_span(
                            weekdayName(
                              context,
                              group.weekdays.first,
                              short: true,
                            ),
                            weekdayName(
                              context,
                              group.weekdays.last,
                              short: true,
                            ),
                          ),
                    hours: dayHours(group.hours),
                    today:
                        identical(schedule, current) &&
                        group.weekdays.contains(wallClock.weekday),
                  ),
              ],
            if (note != null && note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(note, style: secondary),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayGroupRow extends StatelessWidget {
  const _DayGroupRow({
    required this.days,
    required this.hours,
    required this.today,
  });

  final String days;
  final String hours;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: today ? FontWeight.bold : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(days, style: style)),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(hours, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
