import 'package:flutter/material.dart';

import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// The three states a plan's air-break policy can be in (issue #3552):
/// follow the diver's Settings default, explicitly off regardless of that
/// default, or a custom policy for this plan.
enum _AirBreaksChoice { default_, off, custom }

/// Air-break (back-gas break) control for the Setup accordion's deco
/// section: a three-way choice (Default/Off/Custom), and - once Custom is
/// picked - two compact minute fields for the O2 and break phases of the
/// cycle. Seeds Custom from the diver's Settings default when there is one,
/// else the widely taught NOAA-style 12/6 min cycle.
class PlanAirBreaksControl extends StatefulWidget {
  const PlanAirBreaksControl({
    super.key,
    required this.policy,
    required this.explicitlyOff,
    required this.defaultPolicy,
    required this.onChanged,
  });

  /// The plan's own custom policy; null when following the default or
  /// explicitly off.
  final AirBreakPolicy? policy;

  /// True = no air breaks for this plan regardless of [defaultPolicy].
  final bool explicitlyOff;

  /// The diver's Settings default; null = no breaks by default.
  final AirBreakPolicy? defaultPolicy;

  /// Receives the new policy and explicit-off flag together, since every
  /// choice sets both (issue #3552).
  final void Function(AirBreakPolicy? policy, {required bool explicitlyOff})
  onChanged;

  @override
  State<PlanAirBreaksControl> createState() => _PlanAirBreaksControlState();
}

class _PlanAirBreaksControlState extends State<PlanAirBreaksControl> {
  static const _fallbackPolicy = AirBreakPolicy();

  late TextEditingController _o2Controller;
  late TextEditingController _breakController;

  static String _minutesText(int seconds) =>
      formatDecimalForInput((seconds / 60).toDouble());

  _AirBreaksChoice get _choice {
    if (widget.explicitlyOff) return _AirBreaksChoice.off;
    if (widget.policy != null) return _AirBreaksChoice.custom;
    return _AirBreaksChoice.default_;
  }

  AirBreakPolicy get _seedPolicy =>
      widget.policy ?? widget.defaultPolicy ?? _fallbackPolicy;

  @override
  void initState() {
    super.initState();
    final policy = _seedPolicy;
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
    final oldPolicy = oldWidget.policy ?? oldWidget.defaultPolicy;
    final newPolicy = widget.policy ?? widget.defaultPolicy;
    if (oldPolicy?.o2Seconds != newPolicy?.o2Seconds) {
      final text = _minutesText(
        newPolicy?.o2Seconds ?? _fallbackPolicy.o2Seconds,
      );
      if (_o2Controller.text != text) _o2Controller.text = text;
    }
    if (oldPolicy?.breakSeconds != newPolicy?.breakSeconds) {
      final text = _minutesText(
        newPolicy?.breakSeconds ?? _fallbackPolicy.breakSeconds,
      );
      if (_breakController.text != text) _breakController.text = text;
    }
  }

  @override
  void dispose() {
    _o2Controller.dispose();
    _breakController.dispose();
    super.dispose();
  }

  void _select(_AirBreaksChoice choice) {
    switch (choice) {
      case _AirBreaksChoice.default_:
        widget.onChanged(null, explicitlyOff: false);
      case _AirBreaksChoice.off:
        widget.onChanged(null, explicitlyOff: true);
      case _AirBreaksChoice.custom:
        widget.onChanged(_seedPolicy, explicitlyOff: false);
    }
  }

  /// Whole minutes above zero, or null to leave the policy alone: blank and
  /// zero as before, and unreadable text, which the field reports itself.
  static int? _minutes(NumberRead read) => switch (read) {
    NumberValue(:final value) when value > 0 => value.toInt(),
    NumberValue() || NumberBlank() || NumberInvalid() => null,
  };

  void _changeO2Minutes(NumberRead read) {
    final minutes = _minutes(read);
    if (minutes == null) return;
    final current = _seedPolicy;
    widget.onChanged(
      AirBreakPolicy(
        o2Seconds: minutes * 60,
        breakSeconds: current.breakSeconds,
      ),
      explicitlyOff: false,
    );
  }

  void _changeBreakMinutes(NumberRead read) {
    final minutes = _minutes(read);
    if (minutes == null) return;
    final current = _seedPolicy;
    widget.onChanged(
      AirBreakPolicy(o2Seconds: current.o2Seconds, breakSeconds: minutes * 60),
      explicitlyOff: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final defaultLabel = widget.defaultPolicy == null
        ? l10n.divePlanner_label_off
        : l10n.divePlanner_label_airBreaksCycle(
            (widget.defaultPolicy!.o2Seconds / 60).round(),
            (widget.defaultPolicy!.breakSeconds / 60).round(),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.divePlanner_label_airBreaks,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        // A Wrap of chips, not a SegmentedButton (issue #3552 follow-up):
        // see PlanLastStopSelector's matching fix for the full reasoning -
        // a SegmentedButton doesn't reliably fit its choices at the Setup
        // accordion's narrow widths, in either labeling. Unlike a
        // SegmentedButton, a Wrap can show the Default chip's resolved
        // value without risking it pushing another chip out of view.
        PlanChoiceWrap<_AirBreaksChoice>(
          options: [
            (
              _AirBreaksChoice.default_,
              l10n.divePlanner_label_defaultWithValue(defaultLabel),
            ),
            (_AirBreaksChoice.off, l10n.divePlanner_label_off),
            (_AirBreaksChoice.custom, l10n.divePlanner_label_airBreaksCustom),
          ],
          selected: _choice,
          onChanged: _select,
        ),
        if (_choice == _AirBreaksChoice.custom)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                _MinutesField(
                  label: context.l10n.divePlanner_label_airBreaksOnO2,
                  controller: _o2Controller,
                  onChanged: _changeO2Minutes,
                ),
                const SizedBox(height: 12),
                _MinutesField(
                  label: context.l10n.divePlanner_label_airBreaksBreak,
                  controller: _breakController,
                  onChanged: _changeBreakMinutes,
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
  final ValueChanged<NumberRead> onChanged;

  @override
  Widget build(BuildContext context) {
    return NumberField(
      controller: controller,
      integer: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        labelText: label,
      ),
      onChanged: onChanged,
    );
  }
}
