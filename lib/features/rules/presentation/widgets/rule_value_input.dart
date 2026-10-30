import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/rules/domain/rule_value_kind.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart'
    as num_input;

/// A stored (metric) number in the diver's display unit.
double ruleToDisplay(UnitFormatter u, RuleUnit unit, double v) =>
    switch (unit) {
      RuleUnit.depth => u.convertDepth(v),
      RuleUnit.altitude => u.convertAltitude(v),
      RuleUnit.windSpeed => u.convertWindSpeed(v),
      RuleUnit.millibar => v * 1000,
      RuleUnit.seconds => v / 60,
      RuleUnit.none => v,
    };

/// A number the diver typed, back to its stored (metric) form.
double ruleFromDisplay(UnitFormatter u, RuleUnit unit, double v) =>
    switch (unit) {
      RuleUnit.depth => u.depthToMeters(v),
      RuleUnit.altitude => u.altitudeToMeters(v),
      RuleUnit.windSpeed => u.windSpeedToMs(v),
      RuleUnit.millibar => v / 1000,
      RuleUnit.seconds => v * 60,
      RuleUnit.none => v,
    };

String? ruleUnitSymbol(UnitFormatter u, RuleUnit unit) => switch (unit) {
  RuleUnit.depth => u.depthSymbol,
  RuleUnit.altitude => u.altitudeSymbol,
  RuleUnit.windSpeed => u.windSpeedSymbol,
  RuleUnit.millibar => 'mbar',
  RuleUnit.seconds => 'min',
  RuleUnit.none => null,
};

/// The input for one set-field value, chosen by [kind]: text, a number in
/// the diver's unit, a choice among [enumValues], a switch or a 1-5 rating.
/// [value] and [onChanged] carry the stored form (metric, enum `.name`).
/// Entity references are picked elsewhere, never here.
class RuleValueInput extends StatefulWidget {
  const RuleValueInput({
    super.key,
    required this.kind,
    required this.unit,
    required this.units,
    required this.fieldName,
    required this.value,
    required this.onChanged,
    this.enumValues = const [],
    this.integer = false,
    this.label,
  });

  final RuleValueKind kind;
  final RuleUnit unit;
  final UnitFormatter units;
  final String fieldName;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final List<String> enumValues;
  final bool integer;
  final String? label;

  @override
  State<RuleValueInput> createState() => _RuleValueInputState();
}

class _RuleValueInputState extends State<RuleValueInput> {
  late final TextEditingController _text = TextEditingController(
    text: switch (widget.value) {
      final num n when widget.kind == RuleValueKind.number => _seed(n),
      final String s => s,
      _ => '',
    },
  );

  /// Seeded as the other number fields are, in the locale's digits, so
  /// the field and what the diver types back agree on the separator.
  String _seed(num n) => formatRoundedForInput(
    ruleToDisplay(widget.units, widget.unit, n.toDouble()),
    widget.integer ? 0 : 2,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = widget.label ?? l10n.rules_actionEditor_value;
    switch (widget.kind) {
      case RuleValueKind.number:
        return NumberField(
          key: const ValueKey('rule_value_number'),
          controller: _text,
          integer: widget.integer,
          decoration: InputDecoration(
            labelText: label,
            suffixText: ruleUnitSymbol(widget.units, widget.unit),
          ),
          onChanged: (read) => widget.onChanged(switch (read) {
            num_input.NumberValue(:final value) => _stored(value),
            _ => null,
          }),
        );
      case RuleValueKind.enumName:
        return DropdownButtonFormField<String>(
          key: const ValueKey('rule_value_enum'),
          initialValue: widget.enumValues.contains(widget.value)
              ? widget.value as String
              : null,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final v in widget.enumValues)
              DropdownMenuItem(
                value: v,
                child: Text(ruleEnumValueLabel(l10n, widget.fieldName, v)),
              ),
          ],
          onChanged: widget.onChanged,
        );
      case RuleValueKind.boolean:
        return SwitchListTile(
          key: const ValueKey('rule_value_bool'),
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: widget.value == true,
          onChanged: widget.onChanged,
        );
      case RuleValueKind.rating:
        return DropdownButtonFormField<int>(
          key: const ValueKey('rule_value_rating'),
          initialValue: (widget.value as num?)?.round(),
          decoration: InputDecoration(labelText: label),
          items: [
            for (var i = 1; i <= 5; i++)
              DropdownMenuItem(value: i, child: Text('$i/5')),
          ],
          onChanged: widget.onChanged,
        );
      case RuleValueKind.text:
      case RuleValueKind.entityRef:
        return TextField(
          key: const ValueKey('rule_value_text'),
          controller: _text,
          decoration: InputDecoration(labelText: label),
          onChanged: (s) => widget.onChanged(s.trim().isEmpty ? null : s),
        );
    }
  }

  num _stored(double typed) {
    final v = ruleFromDisplay(widget.units, widget.unit, typed);
    return widget.integer ? v.round() : v;
  }
}
