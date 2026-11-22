import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_item_units.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// One equipment number in the Details editor, with a picker for the unit this
/// item's figure is in (issue #4534).
///
/// The figure stays as typed: picking a unit relabels it rather than
/// converting it, because the diver is saying which unit the number printed
/// on the gear is in. Storage stays canonical metric; the picked unit rides
/// along on the attribute as `valueUnit`, kept even while the number is
/// empty so a unit picked first survives.
///
/// A cylinder's volume in cubic feet is rated gas capacity, so it is
/// re-derived from the typed figure whenever [workingPressureBar] changes.
class EquipmentNumberAttributeField extends StatefulWidget {
  final EquipmentAttributeDef def;
  final EquipmentAttribute? current;
  final UnitFormatter units;

  /// The cylinder's working pressure on the form, for a volume in cubic feet.
  final double? workingPressureBar;

  final ValueChanged<EquipmentAttribute> onChanged;

  /// The number was emptied and no unit is picked: the field is unset.
  final VoidCallback onCleared;

  const EquipmentNumberAttributeField({
    super.key,
    required this.def,
    required this.current,
    required this.units,
    required this.onChanged,
    required this.onCleared,
    this.workingPressureBar,
  });

  @override
  State<EquipmentNumberAttributeField> createState() =>
      _EquipmentNumberAttributeFieldState();
}

class _EquipmentNumberAttributeFieldState
    extends State<EquipmentNumberAttributeField> {
  late final TextEditingController _controller;

  /// The picked unit's stored name, or null to follow the diver.
  String? _unitName;

  EquipmentAttributeDef get _def => widget.def;

  EquipmentAttribute get _base =>
      (widget.current ??
              EquipmentAttribute.curated(equipmentId: '', key: _def.key))
          .copyWith(valueUnit: _unitName, clearValueUnit: _unitName == null);

  AttributeUnit? get _inForce =>
      attributeUnitInForce(_def, _base, widget.units);

  /// The unit the figure is typed in; null for a field with no alternative.
  AttributeUnit? get _typing {
    final unit = _inForce;
    return unit == null ? null : attributeTypingUnit(unit, widget.units);
  }

  @override
  void initState() {
    super.initState();
    _unitName = widget.current?.valueUnit;
    final metric = widget.current?.valueNum;
    _controller = TextEditingController(
      text: metric == null ? '' : _seed(metric),
    );
  }

  @override
  void didUpdateWidget(EquipmentNumberAttributeField old) {
    super.didUpdateWidget(old);
    final typing = _typing;
    // The diver's units changed under a field that follows them: the figure
    // on screen is in the old unit, so re-read it from the stored value,
    // which every edit has already reported, or a save would parse the old
    // figure in the new unit.
    final unit = attributeUnitInForce(_def, _base, old.units);
    final wasTyping = unit == null
        ? null
        : attributeTypingUnit(unit, old.units);
    final metric = widget.current?.valueNum;
    if (wasTyping != typing && metric != null) {
      _controller.text = _seed(metric);
      return;
    }
    if (typing != null &&
        isCylinderGasVolume(_def, typing) &&
        old.workingPressureBar != widget.workingPressureBar &&
        _controller.text.trim().isNotEmpty) {
      // Gas capacity at the new pressure, from the figure typed, never from
      // the last stored litres: a preset match on the way through would
      // otherwise move the figure.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emit(_controller.text);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _seed(double metric) {
    final typing = _typing;
    if (typing == null) {
      return formatAttributeNumberForEditing(
        _def.dimension,
        widget.units,
        metric,
      );
    }
    return formatAttributeNumberIn(
      _def,
      typing,
      metric,
      workingPressureBar: widget.workingPressureBar,
    );
  }

  double _metric(double value) {
    final typing = _typing;
    if (typing == null) {
      return attributeMetricFromDisplay(_def.dimension, widget.units, value);
    }
    return attributeMetricFromValue(
      _def,
      typing,
      value,
      workingPressureBar: widget.workingPressureBar,
    );
  }

  /// Reports [text] read in the unit in force; false when it is unreadable
  /// and nothing was reported.
  bool _emit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      if (_unitName == null) {
        widget.onCleared();
      } else {
        widget.onChanged(_base.copyWith(clearValueNum: true));
      }
      return true;
    }
    // Read in the diver's locale, matching how the field is seeded: a blanket
    // replaceAll(',', '.') would misread the en_US thousands separator,
    // turning "1,250" into 1.25.
    final parsed = switch (readNumber(trimmed)) {
      NumberValue(:final value) => value,
      NumberBlank() || NumberInvalid() => null,
    };
    // Non-empty but unreadable (transient like "-", or invalid): keep the
    // last pending value rather than dropping the field; the validator shows
    // why (#1900).
    if (parsed == null) return false;
    widget.onChanged(_base.copyWith(valueNum: _metric(parsed)));
    return true;
  }

  void _pick(AttributeUnit? unit) {
    if (unit == null) return;
    setState(() => _unitName = unit.name);
    // Over unreadable text the number stays as it was, but the unit picked
    // must still reach the form, or the save would drop it.
    if (!_emit(_controller.text)) widget.onChanged(_base);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = attributeLabel(l10n, _def.key);
    final choices = attributeUnitChoices(_def);
    final inForce = _inForce;
    final String labelText;
    Widget? picker;
    if (choices.isNotEmpty && inForce != null) {
      // Both is read on two scales but typed on one, the diver's own: the
      // label names it, or a figure off the other ring would be misread.
      final typing = _typing;
      labelText = inForce == AttributeUnit.dual && typing != null
          ? '$label (${attributeUnitLabel(_def, typing, l10n)})'
          : label;
      picker = Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Semantics(
          label: '$label, ${l10n.attr_unitPicker}',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AttributeUnit>(
              key: ValueKey('attr-unit-${_def.key}'),
              value: inForce,
              isDense: true,
              items: [
                for (final unit in choices)
                  DropdownMenuItem(
                    value: unit,
                    child: Text(attributeUnitLabel(_def, unit, l10n)),
                  ),
              ],
              onChanged: _pick,
            ),
          ),
        ),
      );
    } else {
      final symbol = inForce == null
          ? attributeUnitSymbol(_def.dimension, widget.units)
          : attributeUnitLabel(_def, inForce, l10n);
      labelText = symbol.isEmpty ? label : '$label ($symbol)';
    }
    return TextFormField(
      key: ValueKey('attr-field-${_def.key}'),
      controller: _controller,
      decoration: InputDecoration(labelText: labelText, suffixIcon: picker),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: numberValidator(context),
      onChanged: _emit,
    );
  }
}
