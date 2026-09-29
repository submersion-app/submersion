import 'package:flutter/material.dart';

import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edits one leg of a DPV mission route. Returns the edited leg, or null
/// when the diver cancels. Values are shown and typed in the diver's units
/// and returned in metres, m/s and degrees.
Future<MissionLeg?> showMissionLegEditor(
  BuildContext context, {
  required MissionLeg leg,
  required bool openWater,
  required MissionUnits units,
}) {
  return showDialog<MissionLeg>(
    context: context,
    builder: (context) =>
        _MissionLegEditor(leg: leg, openWater: openWater, units: units),
  );
}

class _MissionLegEditor extends StatefulWidget {
  const _MissionLegEditor({
    required this.leg,
    required this.openWater,
    required this.units,
  });

  final MissionLeg leg;
  final bool openWater;
  final MissionUnits units;

  @override
  State<_MissionLegEditor> createState() => _MissionLegEditorState();
}

class _MissionLegEditorState extends State<_MissionLegEditor> {
  late final TextEditingController _label;
  late MissionLeg _draft;

  final _fields = <String, GlobalKey<PlanNumberFieldState>>{};

  GlobalKey<PlanNumberFieldState> _field(String id) =>
      _fields.putIfAbsent(id, GlobalKey<PlanNumberFieldState>.new);

  /// Commits every box first: on a touch screen tapping Save does not take
  /// focus from the box, so an out-of-range value would otherwise be lost.
  void _commitFields() {
    for (final field in _fields.values) {
      field.currentState?.commit();
    }
  }

  @override
  void initState() {
    super.initState();
    _draft = widget.leg;
    _label = TextEditingController(text: widget.leg.label);
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = widget.units;
    final current = _draft.current;
    final shore = _draft.shoreExit;
    return AlertDialog(
      title: Text(l10n.plannerMission_route_editLeg),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: l10n.plannerMission_leg_label,
              ),
            ),
            PlanNumberField(
              key: _field('plannerMission_leg_distance'),
              label: l10n.plannerMission_leg_distance,
              value: u.distanceDisplay(_draft.distanceM),
              hintValue: 0,
              suffixText: u.distanceSymbol,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) {
                if (v == null) return;
                setState(
                  () =>
                      _draft = _draft.copyWith(distanceM: u.distanceMeters(v)),
                );
              },
            ),
            PlanNumberField(
              key: _field('plannerMission_leg_depth'),
              label: l10n.plannerMission_leg_depth,
              value: u.distanceDisplay(_draft.depthM),
              hintValue: 0,
              suffixText: u.distanceSymbol,
              decimals: 0,
              min: 0,
              allowEmpty: false,
              onChanged: (v) {
                if (v == null) return;
                setState(
                  () => _draft = _draft.copyWith(depthM: u.distanceMeters(v)),
                );
              },
            ),
            PlanNumberField(
              key: _field('plannerMission_leg_heading'),
              label: l10n.plannerMission_leg_heading,
              value: _draft.headingDeg,
              hintValue: 0,
              suffixText: '°',
              decimals: 0,
              min: 0,
              max: 359,
              allowEmpty: false,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _draft = _draft.copyWith(headingDeg: v));
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.plannerMission_leg_useMissionCurrent),
              value: current == null,
              onChanged: (useDefault) => setState(
                () => _draft = useDefault
                    ? _draft.copyWith(clearCurrent: true)
                    : _draft.copyWith(
                        current: const CurrentVector(
                          speedMps: 0,
                          setsTowardDeg: 0,
                        ),
                      ),
              ),
            ),
            if (current != null) ...[
              PlanNumberField(
                key: _field('plannerMission_current_speed'),
                label: l10n.plannerMission_current_speed,
                value: u.speedDisplay(current.speedMps),
                hintValue: 0,
                suffixText: u.speedSymbol,
                decimals: 0,
                min: 0,
                allowEmpty: false,
                onChanged: (v) {
                  if (v == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      current: CurrentVector(
                        speedMps: u.speedMps(v),
                        setsTowardDeg: current.setsTowardDeg,
                      ),
                    ),
                  );
                },
              ),
              PlanNumberField(
                key: _field('plannerMission_current_setsToward'),
                label: l10n.plannerMission_current_setsToward,
                value: current.setsTowardDeg,
                hintValue: 0,
                suffixText: '°',
                decimals: 0,
                min: 0,
                max: 359,
                allowEmpty: false,
                onChanged: (v) {
                  if (v == null) return;
                  setState(
                    () => _draft = _draft.copyWith(
                      current: CurrentVector(
                        speedMps: current.speedMps,
                        setsTowardDeg: v,
                      ),
                    ),
                  );
                },
              ),
            ],
            if (widget.openWater) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.plannerMission_leg_shoreExit),
                value: shore != null,
                onChanged: (on) => setState(
                  () => _draft = on
                      ? _draft.copyWith(
                          shoreExit: const ShoreExit(surfaceSwimM: 0, walkM: 0),
                        )
                      : _draft.copyWith(clearShoreExit: true),
                ),
              ),
              if (shore != null) ...[
                PlanNumberField(
                  key: _field('plannerMission_leg_shoreSwim'),
                  label: l10n.plannerMission_leg_shoreSwim,
                  value: u.distanceDisplay(shore.surfaceSwimM),
                  hintValue: 0,
                  suffixText: u.distanceSymbol,
                  decimals: 0,
                  min: 0,
                  allowEmpty: false,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(
                      () => _draft = _draft.copyWith(
                        shoreExit: ShoreExit(
                          surfaceSwimM: u.distanceMeters(v),
                          walkM: shore.walkM,
                        ),
                      ),
                    );
                  },
                ),
                PlanNumberField(
                  key: _field('plannerMission_leg_shoreWalk'),
                  label: l10n.plannerMission_leg_shoreWalk,
                  value: u.distanceDisplay(shore.walkM),
                  hintValue: 0,
                  suffixText: u.distanceSymbol,
                  decimals: 0,
                  min: 0,
                  allowEmpty: false,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(
                      () => _draft = _draft.copyWith(
                        shoreExit: ShoreExit(
                          surfaceSwimM: shore.surfaceSwimM,
                          walkM: u.distanceMeters(v),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () {
            _commitFields();
            Navigator.of(
              context,
            ).pop(_draft.copyWith(label: _label.text.trim()));
          },
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
