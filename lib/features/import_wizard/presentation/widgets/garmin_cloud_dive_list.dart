import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/garmin_connect/garmin_dive_mapper.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final _dateFormatter = DateFormat('MMM d, yyyy');
final _timeFormatter = DateFormat('h:mm a');

/// Builds the same title/subtitle text shown for a Garmin dive both in the
/// fetch step's inline selection list and in the shared Review step, so the
/// two stay in sync without duplicating the formatting.
({String title, String subtitle}) formatGarminDiveSummary(
  GarminParsedDive parsed,
  AppSettings settings,
) {
  final dive = parsed.dive;
  final localStart = dive.startTime.toLocal();
  final title =
      '${_dateFormatter.format(localStart)} — ${_timeFormatter.format(localStart)}';

  final units = UnitFormatter(settings);
  final durationMin = dive.duration.inMinutes;
  final tempStr = dive.minTemperature != null
      ? ' · ${units.formatTemperature(dive.minTemperature!, decimals: 1)}'
      : '';
  final subtitle =
      '${units.formatDepth(dive.maxDepth)} max · $durationMin min$tempStr';

  return (title: title, subtitle: subtitle);
}

/// Scrollable, checkbox-per-row list of the dives fetched so far in the
/// Garmin Connect import wizard's fetch step.
///
/// Lets the diver deselect dives they don't want carried into the rest of
/// the wizard before advancing, rather than only deciding that later in the
/// shared Review step.
class GarminCloudDiveList extends StatelessWidget {
  const GarminCloudDiveList({
    super.key,
    required this.dives,
    required this.selectedIndices,
    required this.settings,
    required this.onToggle,
  });

  final List<GarminParsedDive> dives;
  final Set<int> selectedIndices;
  final AppSettings settings;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: dives.length,
      itemBuilder: (context, index) {
        final summary = formatGarminDiveSummary(dives[index], settings);
        return CheckboxListTile(
          value: selectedIndices.contains(index),
          onChanged: (_) => onToggle(index),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(summary.title),
          subtitle: Text(summary.subtitle),
        );
      },
    );
  }
}
