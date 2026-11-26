import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Name and weight for a test item in the try-out sheet (issue #5028),
/// checked inline: a name is required and the weight runs from
/// [minKg] to [maxKg] in the diver's units.
class TrimTestItemForm extends StatefulWidget {
  const TrimTestItemForm({super.key, required this.units, required this.onAdd});

  final UnitFormatter units;
  final void Function(String name, double kg) onAdd;

  static const minKg = 0.1;
  static const maxKg = 20.0;
  static const nameKey = ValueKey('trim-test-name');
  static const weightKey = ValueKey('trim-test-weight');

  @override
  State<TrimTestItemForm> createState() => _TrimTestItemFormState();
}

class _TrimTestItemFormState extends State<TrimTestItemForm> {
  final _name = TextEditingController();
  final _weight = TextEditingController();
  String? _nameError;
  String? _weightError;

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final units = widget.units;
    final name = _name.text.trim();
    final read = readNumber(_weight.text);
    final kg = read is NumberValue ? units.weightToKg(read.value) : null;
    setState(() {
      _nameError = name.isEmpty ? l10n.trim_tryout_nameRequired : null;
      _weightError =
          kg == null ||
              kg < TrimTestItemForm.minKg - 1e-9 ||
              kg > TrimTestItemForm.maxKg + 1e-9
          ? l10n.trim_tryout_weightRange(
              units.formatWeight(TrimTestItemForm.minKg),
              units.formatWeight(TrimTestItemForm.maxKg),
            )
          : null;
    });
    if (_nameError != null || _weightError != null) return;
    widget.onAdd(name, kg!);
    _name.clear();
    _weight.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: TrimTestItemForm.nameKey,
                controller: _name,
                decoration: InputDecoration(
                  labelText: l10n.trim_tryout_testName,
                  errorText: _nameError,
                  isDense: true,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: TrimTestItemForm.weightKey,
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: numberInputFormatters(),
                decoration: InputDecoration(
                  labelText: l10n.trim_tryout_testWeight(
                    widget.units.weightSymbol,
                  ),
                  errorText: _weightError,
                  errorMaxLines: 2,
                  isDense: true,
                ),
                onChanged: (_) {
                  if (_weightError != null) {
                    setState(() => _weightError = null);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.add),
            label: Text(l10n.trim_tryout_addTestItem),
          ),
        ),
      ],
    );
  }
}
