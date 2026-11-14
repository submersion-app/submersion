import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/body_composition.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// One body measurement as the Add measurement dialog collected it, in
/// storage units.
typedef BodyWeightDraft = ({
  double weightKg,
  double? heightCm,
  double? bodyFatPercent,
  DateTime measuredAt,
});

/// Asks for a dated body measurement. Null when the diver cancelled, or
/// saved with no weight: an entry always carries one.
Future<BodyWeightDraft?> showBodyWeightEntryDialog(BuildContext context) =>
    showDialog<BodyWeightDraft>(
      context: context,
      builder: (_) => const BodyWeightEntryDialog(),
    );

/// Weight, optional height, optional body fat percentage and a date.
///
/// Body fat is the diver's own measurement (issue #4525). Left blank, the
/// weight prediction estimates it; the estimate is shown here once the
/// profile knows enough to make it worth reading.
class BodyWeightEntryDialog extends ConsumerStatefulWidget {
  const BodyWeightEntryDialog({super.key});

  @override
  ConsumerState<BodyWeightEntryDialog> createState() =>
      _BodyWeightEntryDialogState();
}

class _BodyWeightEntryDialogState extends ConsumerState<BodyWeightEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightCmController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _bodyFatController = TextEditingController();
  DateTime _measuredAt = DateTime.now();

  @override
  void dispose() {
    _weightController.dispose();
    _heightCmController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  /// A field's number, or null when it is blank or cannot be read. On save
  /// the form has validated first, so null then means blank.
  static double? _number(TextEditingController controller) =>
      switch (readNumber(controller.text)) {
        NumberValue(:final value) => value,
        NumberBlank() || NumberInvalid() => null,
      };

  double? _heightCm(UnitFormatter units) {
    if (units.heightIsMetric) return _number(_heightCmController);
    final feet = _number(_heightFeetController);
    final inches = _number(_heightInchesController);
    return (feet == null && inches == null)
        ? null
        : units.feetInchesToCm(feet ?? 0, inches ?? 0);
  }

  void _save(UnitFormatter units) {
    // An unreadable number used to close the dialog having saved nothing,
    // or saved no height (#1900).
    if (!_formKey.currentState!.validate()) return;
    final weight = _number(_weightController);
    Navigator.of(context).pop<BodyWeightDraft?>(
      weight == null
          ? null
          : (
              weightKg: units.weightToKg(weight),
              heightCm: _heightCm(units),
              bodyFatPercent: _number(_bodyFatController),
              measuredAt: _measuredAt,
            ),
    );
  }

  /// The line under the body fat field: the estimate when the profile can
  /// make one, or where to add what it is missing.
  String? _estimateText(BuildContext context, UnitFormatter units) {
    final profile = ref.watch(diverBodyProfileProvider).valueOrNull;
    if (profile == null) return null;
    if (profile.sex == null || profile.ageYears == null) {
      // A birth year the adult formula does not cover (a junior diver)
      // reads as no age. It is entered all the same, so there is nothing
      // to ask for and no estimate to show.
      final birthYearGiven =
          ref.watch(currentDiverProvider).valueOrNull?.birthYear != null;
      return profile.sex != null && birthYearGiven
          ? null
          : context.l10n.bodyWeight_bodyFatEstimateHint;
    }
    final weight = _number(_weightController);
    final estimate = BodyComposition.displayEstimate(
      weightKg: weight == null ? null : units.weightToKg(weight),
      // Height is optional per entry and carries forward from the last one.
      heightCm:
          _heightCm(units) ?? ref.watch(latestDiverHeightProvider).valueOrNull,
      ageYears: profile.ageYears,
      sex: profile.sex,
    );
    return estimate == null
        ? null
        : context.l10n.bodyWeight_bodyFatEstimate(estimate);
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final estimateText = _estimateText(context, units);
    void refresh(String _) => setState(() {});

    return AlertDialog(
      title: Text(l10n.bodyWeight_addEntry),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _weightController,
              inputFormatters: numberInputFormatters(),
              validator: numberValidator(context),
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.bodyWeight_weightLabel(units.weightSymbol),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: refresh,
            ),
            if (units.heightIsMetric)
              TextFormField(
                controller: _heightCmController,
                inputFormatters: numberInputFormatters(),
                validator: numberValidator(context),
                decoration: InputDecoration(
                  labelText: l10n.bodyWeight_heightLabel,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: refresh,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightFeetController,
                      inputFormatters: numberInputFormatters(),
                      validator: numberValidator(context, integer: true),
                      decoration: InputDecoration(
                        labelText: l10n.bodyWeight_heightFeetLabel,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                      ),
                      onChanged: refresh,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _heightInchesController,
                      inputFormatters: numberInputFormatters(),
                      validator: numberValidator(context),
                      decoration: InputDecoration(
                        labelText: l10n.bodyWeight_heightInchesLabel,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: refresh,
                    ),
                  ),
                ],
              ),
            TextFormField(
              controller: _bodyFatController,
              inputFormatters: numberInputFormatters(),
              validator: numberValidator(
                context,
                allowNegative: false,
                check: (value) => BodyComposition.isPlausibleBodyFat(value)
                    ? null
                    : l10n.bodyWeight_bodyFatRange,
              ),
              decoration: InputDecoration(
                labelText: l10n.bodyWeight_bodyFatLabel,
                helperText: l10n.bodyWeight_bodyFatHelper,
                helperMaxLines: 3,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (estimateText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  estimateText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.bodyWeight_dateLabel}: '
                    '${units.formatDate(_measuredAt)}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showAppDatePicker(
                      context: context,
                      initialDate: _measuredAt,
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && mounted) {
                      setState(() => _measuredAt = picked);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => _save(units),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
