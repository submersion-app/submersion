import 'package:flutter/material.dart';

import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Air-break (back-gas break) control for the Setup accordion's deco
/// section: a switch, and - once enabled - two compact minute fields for the
/// O2 and break phases of the cycle. Defaults to 12 min on O2 / 6 min on the
/// break gas (the widely taught NOAA-style cycle) when first turned on.
class PlanAirBreaksControl extends StatefulWidget {
  const PlanAirBreaksControl({
    super.key,
    required this.policy,
    required this.onChanged,
  });

  final AirBreakPolicy? policy;
  final ValueChanged<AirBreakPolicy?> onChanged;

  @override
  State<PlanAirBreaksControl> createState() => _PlanAirBreaksControlState();
}

class _PlanAirBreaksControlState extends State<PlanAirBreaksControl> {
  static const _defaultPolicy = AirBreakPolicy();

  late TextEditingController _o2Controller;
  late TextEditingController _breakController;

  static String _minutesText(int seconds) =>
      formatDecimalForInput((seconds / 60).toDouble());

  @override
  void initState() {
    super.initState();
    final policy = widget.policy ?? _defaultPolicy;
    _o2Controller = TextEditingController(text: _minutesText(policy.o2Seconds));
    _breakController = TextEditingController(
      text: _minutesText(policy.breakSeconds),
    );
  }

  @override
  void didUpdateWidget(PlanAirBreaksControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // AirBreakPolicy carries no value equality, so compare the seconds
    // fields directly - otherwise every keystroke (which round-trips through
    // a freshly built policy) would reset the controller and the cursor.
    final oldO2 = oldWidget.policy?.o2Seconds;
    final newO2 = widget.policy?.o2Seconds;
    if (oldO2 != newO2) {
      final text = _minutesText(newO2 ?? _defaultPolicy.o2Seconds);
      if (_o2Controller.text != text) _o2Controller.text = text;
    }
    final oldBreak = oldWidget.policy?.breakSeconds;
    final newBreak = widget.policy?.breakSeconds;
    if (oldBreak != newBreak) {
      final text = _minutesText(newBreak ?? _defaultPolicy.breakSeconds);
      if (_breakController.text != text) _breakController.text = text;
    }
  }

  @override
  void dispose() {
    _o2Controller.dispose();
    _breakController.dispose();
    super.dispose();
  }

  void _toggle(bool enabled) {
    widget.onChanged(enabled ? _defaultPolicy : null);
  }

  void _changeO2Minutes(String value) {
    final minutes = parseUserInt(value);
    if (minutes == null || minutes <= 0) return;
    final current = widget.policy ?? _defaultPolicy;
    widget.onChanged(
      AirBreakPolicy(
        o2Seconds: minutes * 60,
        breakSeconds: current.breakSeconds,
      ),
    );
  }

  void _changeBreakMinutes(String value) {
    final minutes = parseUserInt(value);
    if (minutes == null || minutes <= 0) return;
    final current = widget.policy ?? _defaultPolicy;
    widget.onChanged(
      AirBreakPolicy(o2Seconds: current.o2Seconds, breakSeconds: minutes * 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.policy != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.divePlanner_label_airBreaks,
                style: theme.textTheme.labelMedium,
              ),
            ),
            Switch(value: enabled, onChanged: _toggle),
          ],
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: _MinutesField(
                    label: context.l10n.divePlanner_label_airBreaksOnO2,
                    controller: _o2Controller,
                    onChanged: _changeO2Minutes,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MinutesField(
                    label: context.l10n.divePlanner_label_airBreaksBreak,
                    controller: _breakController,
                    onChanged: _changeBreakMinutes,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MinutesField extends StatelessWidget {
  const _MinutesField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        labelText: label,
      ),
      keyboardType: TextInputType.number,
      onChanged: onChanged,
    );
  }
}
