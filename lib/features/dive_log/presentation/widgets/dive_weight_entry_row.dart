import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weight_label_field.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// One editable weight on a dive: placement, amount and remove on the first
/// line, the diver's optional name for it on the second (issue #956).
///
/// The row keeps its current value itself and hands every edit to
/// [onChanged]. The amount field does not rebuild the page while the diver
/// types, so a callback holding the weight from the last build would write
/// back a stale amount when the name changed next. Key each row by the
/// weight's id, so removing a row above this one does not hand its fields'
/// state to its neighbour.
class DiveWeightEntryRow extends StatefulWidget {
  final DiveWeight weight;
  final UnitFormatter units;
  final ValueChanged<DiveWeight> onChanged;
  final VoidCallback onRemove;

  const DiveWeightEntryRow({
    super.key,
    required this.weight,
    required this.units,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<DiveWeightEntryRow> createState() => _DiveWeightEntryRowState();
}

class _DiveWeightEntryRowState extends State<DiveWeightEntryRow> {
  late DiveWeight _current = widget.weight;

  @override
  void didUpdateWidget(DiveWeightEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weight != oldWidget.weight) _current = widget.weight;
  }

  void _update(DiveWeight next) {
    _current = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = widget.units;
    // Display in the diver's unit, seeded at three decimals with trailing
    // zeros dropped, so a stored 0.65 kg is not snapped to 0.7 (#1609).
    final displayAmount = units.convertWeight(_current.amountKg);
    return Padding(
      // A row's name sits closer to its own row than to the next.
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<WeightType>(
                  initialValue: _current.weightType,
                  decoration: InputDecoration(
                    labelText: l10n.diveLog_edit_label_type,
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    for (final type in WeightType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(type.localizedName(l10n)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _update(_current.copyWith(weightType: value));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: displayAmount > 0
                      ? formatRoundedForInput(displayAmount, 3)
                      : '',
                  decoration: InputDecoration(
                    labelText: units.weightSymbol,
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: numberInputFormatters(),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: numberValidator(context),
                  onChanged: (value) {
                    final displayValue = switch (readNumber(value)) {
                      NumberValue(:final value) => value,
                      NumberBlank() => 0.0, // an empty amount is 0 kg
                      // Keep the last readable amount; the error blocks save.
                      NumberInvalid() => null,
                    };
                    if (displayValue == null) return;
                    _update(
                      _current.copyWith(
                        amountKg: units.weightToKg(displayValue),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.onRemove,
                tooltip: l10n.diveLog_edit_tooltip_removeWeight,
              ),
            ],
          ),
          const SizedBox(height: 8),
          WeightLabelField(
            initialValue: _current.label,
            onChanged: (value) => _update(_current.copyWith(label: value)),
          ),
        ],
      ),
    );
  }
}
