import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Title/subtitle shown for a cloud-imported dive in the fetch-step
/// selection list and in the shared Review step.
({String title, String subtitle}) formatCloudDiveSummary(
  DownloadedDive dive,
  AppSettings settings,
) {
  final localStart = dive.startTime.toLocal();
  final units = UnitFormatter(settings);
  final title =
      '${units.formatDate(localStart)} — ${units.formatTime(localStart)}';

  final durationMin = dive.duration.inMinutes;
  final tempStr = dive.minTemperature != null
      ? ' · ${units.formatTemperature(dive.minTemperature!, decimals: 1)}'
      : '';
  final subtitle =
      '${units.formatDepth(dive.maxDepth)} max · $durationMin min$tempStr';

  return (title: title, subtitle: subtitle);
}
