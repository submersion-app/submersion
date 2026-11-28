import 'package:submersion/features/equipment/domain/entities/equipment_usage_history.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';

/// Months in the exposure card's recent view.
const int kUsageRecentMonths = 12;

/// An item's usage per month and per year, up to [today].
///
/// Dive dates are wall-clock-as-UTC: their fields are the dive's local
/// calendar. [today] must be built the same way (the device's local date as
/// `DateTime.utc(y, m, d)`), so a late-evening dive lands in its own month
/// whatever the device's offset. A dive dated after today (a clock behind
/// the log) counts in the current month and reads as last dived today.
EquipmentUsageHistory buildUsageHistory({
  required List<EquipmentExposureSample> samples,
  required ExposureClassifier classifier,
  required DateTime today,
}) {
  if (samples.isEmpty) return EquipmentUsageHistory.empty;

  final currentMonth = _monthIndex(today);
  final firstMonth = currentMonth - (kUsageRecentMonths - 1);
  final monthDives = List<int>.filled(kUsageRecentMonths, 0);
  final monthHours = List<double>.filled(kUsageRecentMonths, 0);

  var firstYear = today.year;
  DateTime? last;
  for (final s in samples) {
    if (s.date.year < firstYear) firstYear = s.date.year;
    if (last == null || s.date.isAfter(last)) last = s.date;
  }
  final yearCount = today.year - firstYear + 1;
  final yearDives = List<int>.filled(yearCount, 0);
  final yearHours = List<double>.filled(yearCount, 0);

  for (final s in samples) {
    final dives = classifier.contribution(s, ExposureUnit.dives).round();
    final hours = classifier.contribution(s, ExposureUnit.hours);
    // A future-dated dive belongs to the current period, never past it.
    final month = _monthIndex(s.date).clamp(firstMonth - 1, currentMonth);
    if (month >= firstMonth) {
      monthDives[month - firstMonth] += dives;
      monthHours[month - firstMonth] += hours;
    }
    final year = s.date.year.clamp(firstYear, today.year) - firstYear;
    yearDives[year] += dives;
    yearHours[year] += hours;
  }

  final monthly = [
    for (var i = 0; i < kUsageRecentMonths; i++)
      UsageBucket(
        start: _monthStart(firstMonth + i),
        dives: monthDives[i],
        hours: monthHours[i],
      ),
  ];
  return EquipmentUsageHistory(
    monthly: monthly,
    yearly: [
      for (var i = 0; i < yearCount; i++)
        UsageBucket(
          start: DateTime.utc(firstYear + i),
          dives: yearDives[i],
          hours: yearHours[i],
        ),
    ],
    divesLast12Months: monthDives.fold(0, (a, b) => a + b),
    lastDive: last,
    lastDivedAgo: lastDivedAgo(lastDive: last!, today: today),
  );
}

/// How long before [today] the item was last dived. Both dates are read by
/// their calendar fields only, so the time of day never matters.
///
/// Up to 30 days counts days; past that, whole calendar months (at least
/// one); from 24 months, whole years.
LastDivedAgo lastDivedAgo({
  required DateTime lastDive,
  required DateTime today,
}) {
  final days = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(lastDive.year, lastDive.month, lastDive.day))
      .inDays;
  if (days <= 0) return (unit: LastDivedUnit.today, count: 0);
  if (days <= 30) return (unit: LastDivedUnit.days, count: days);
  var months = _monthIndex(today) - _monthIndex(lastDive);
  if (today.day < lastDive.day) months -= 1;
  if (months < 1) months = 1;
  if (months < 24) return (unit: LastDivedUnit.months, count: months);
  return (unit: LastDivedUnit.years, count: months ~/ 12);
}

int _monthIndex(DateTime d) => d.year * 12 + d.month - 1;

DateTime _monthStart(int index) => DateTime.utc(index ~/ 12, index % 12 + 1);
