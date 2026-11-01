import 'package:flutter/material.dart';

import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const double _chartHeight = 280;

/// Whether [profile] has a span of time to pick on.
bool canPickOnProfile(List<DiveProfilePoint> profile) =>
    profile.length >= 2 && profile.last.timestamp > 0;

/// Opens the sheet for picking a gas switch time on the dive's [profile]
/// (issue #4089). Resolves with the chosen seconds, or null on cancel.
///
/// The chart is the dive detail page's own, with its tooltip, limited to depth
/// and pressure. [tankPressures] draws every cylinder, [tankId]'s heavier, and
/// [gasSwitches] marks the dive's other switches. Pass recorded series only.
/// [profile] must pass [canPickOnProfile].
Future<int?> showGasSwitchTimeSheet(
  BuildContext context, {
  required List<DiveProfilePoint> profile,
  required int initialSeconds,
  required UnitFormatter units,
  required List<DiveTank> tanks,
  required String tankId,
  Map<String, List<TankPressurePoint>> tankPressures = const {},
  List<GasSwitchWithTank> gasSwitches = const [],
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    // A vertical drag on the chart belongs to the chart.
    enableDrag: false,
    builder: (_) => _GasSwitchTimeSheet(
      profile: profile,
      initialSeconds: initialSeconds,
      units: units,
      tanks: tanks,
      tankId: tankId,
      tankPressures: tankPressures,
      gasSwitches: gasSwitches,
    ),
  );
}

class _GasSwitchTimeSheet extends StatefulWidget {
  const _GasSwitchTimeSheet({
    required this.profile,
    required this.initialSeconds,
    required this.units,
    required this.tanks,
    required this.tankId,
    required this.tankPressures,
    required this.gasSwitches,
  });

  final List<DiveProfilePoint> profile;
  final int initialSeconds;
  final UnitFormatter units;
  final List<DiveTank> tanks;
  final String tankId;
  final Map<String, List<TankPressurePoint>> tankPressures;
  final List<GasSwitchWithTank> gasSwitches;

  @override
  State<_GasSwitchTimeSheet> createState() => _GasSwitchTimeSheetState();
}

class _GasSwitchTimeSheetState extends State<_GasSwitchTimeSheet> {
  late final int _span = widget.profile.last.timestamp;
  late int _seconds = widget.initialSeconds.clamp(0, _span);

  void _setTime(int seconds) => setState(() => _seconds = seconds);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final depth = profileDepthAt(widget.profile, _seconds);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.diveLog_edit_gasSwitches_pickTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.diveLog_edit_gasSwitches_pickReadout(
                formatMinutesSeconds(_seconds),
                widget.units.formatDepth(depth),
              ),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _chartHeight,
              child: DiveProfileChart(
                profile: widget.profile,
                diveDuration: Duration(seconds: _span),
                showTemperature: false,
                showPressure: true,
                showZoomControls: false,
                depthAndPressureOnly: true,
                tanks: widget.tanks,
                tankPressures: widget.tankPressures,
                emphasizedTankId: widget.tankId,
                gasSwitches: widget.gasSwitches,
                highlightedTimestamp: _seconds,
                onTimeChosen: _setTime,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) => Semantics(
                label: l10n.diveLog_edit_gasSwitches_pickTitle,
                // Time runs left to right on the chart in every language, so
                // the slider must too. Inset to the plot, so its thumb sits
                // under the cursor at the default zoom.
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Slider(
                    value: _seconds.toDouble(),
                    max: _span.toDouble(),
                    padding: EdgeInsets.only(
                      left: DiveProfileChart.plotLeftInset(
                        constraints.maxWidth,
                      ),
                      right: DiveProfileChart.plotRightInset(
                        constraints.maxWidth,
                        hasRightAxis: widget.tankPressures.isNotEmpty,
                      ),
                      top: 16,
                      bottom: 16,
                    ),
                    semanticFormatterCallback: (value) =>
                        formatMinutesSeconds(value.round()),
                    onChanged: (value) => _setTime(value.round()),
                  ),
                ),
              ),
            ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_seconds),
                  child: Text(l10n.diveLog_edit_gasSwitches_pickConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
