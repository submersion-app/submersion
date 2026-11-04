import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';

/// How a logged dive goes by in the series bar: its name, else its dive
/// number, else its date.
String seriesLoggedDiveLabel(SeriesLoggedDive dive, UnitFormatter units) {
  final name = dive.name;
  if (name != null && name.isNotEmpty) return name;
  final number = dive.diveNumber;
  if (number != null) return '#$number';
  return units.formatDate(dive.start);
}
