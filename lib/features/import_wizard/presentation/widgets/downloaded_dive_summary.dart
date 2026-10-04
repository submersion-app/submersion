import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Title/subtitle shown for a downloaded dive: a dive computer download, or a
/// cloud import's fetch-step selection list, and the shared Review step.
({String title, String subtitle}) formatDownloadedDiveSummary(
  DownloadedDive dive,
  AppSettings settings,
) {
  // The dive's wall clock flagged UTC, like every stored dive time: format it
  // as is. Converting it to the device's zone would shift the listed time,
  // and near midnight the date, by the device's UTC offset.
  final start = dive.startTime;
  final units = UnitFormatter(settings);
  final title = '${units.formatDate(start)} \u2014 ${units.formatTime(start)}';

  final durationMin = dive.duration.inMinutes;
  final tempStr = dive.minTemperature != null
      ? ' · ${units.formatTemperature(dive.minTemperature!, decimals: 1)}'
      : '';
  final subtitle =
      '${units.formatDepth(dive.maxDepth)} max · $durationMin min$tempStr';

  return (title: title, subtitle: subtitle);
}
